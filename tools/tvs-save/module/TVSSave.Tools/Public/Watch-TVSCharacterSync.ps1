# Script-scoped state for watcher management
$script:Watchers = @{}
$script:OutboundLocks = @{}
$script:WatcherIdCounter = 0

function Watch-TVSCharacterSync {
<#
.SYNOPSIS
Starts a background file-system watcher that syncs character data
between game save files and the character working directory.

.DESCRIPTION
Starts a background PowerShell runspace with a FileSystemWatcher
pointed at the player data directory and characterWorkDir/presets/.
Events are enqueued into a ConcurrentQueue and drained on a single
processing thread to avoid races.

Reaction rules:
  - presetSlot{n}.txt.tmp created/modified → export .znelchar
  - presets/{name}.znelchar created/modified → import to presetSlot
  - SaveFile.es3 modified → detect slot renames

Feedback-loop mitigation:
  - Per-path outbound locks (3 s expiry) prevent reacting to our own writes.
  - 750 ms debounce delay before processing events.
  - expanded/ directory is NOT watched (one-way sync only).

.PARAMETER Path
Path to the player data directory. Defaults to playerDataDir from
TVS.Environment.

.PARAMETER OutputPath
Directory for .znelchar output. Defaults to
{characterWorkDir}/presets/ from TVS.Environment.

.PARAMETER Expand
When present, also calls Expand-TVSCharacterPreset after each export.

.PARAMETER Quiet
Suppress informational output.

.OUTPUTS
String watcher ID for use with Stop-TVSCharacterSync.
#>
    [CmdletBinding()]
    param(
        [string]$Path = '',
        [string]$OutputPath = '',
        [switch]$Expand,
        [switch]$Quiet
    )

    $env = Get-TVSEnvironment

    if (-not $Path) {
        $Path = $env.playerDataDir
    }
    if (-not $OutputPath) {
        $OutputPath = Join-Path $env.characterWorkDir 'presets'
    }

    if (-not (Test-Path $Path -PathType Container)) {
        throw "Player data directory not found at: $Path"
    }

    if (-not (Test-Path $OutputPath -PathType Container)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $script:WatcherIdCounter++
    $watcherId = "tvs-sync-$($script:WatcherIdCounter)"

    # Create the event queue
    $queue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

    # Create cancellation token source
    $cts = [System.Threading.CancellationTokenSource]::new()

    # Store watcher state
    $script:Watchers[$watcherId] = @{
        Id        = $watcherId
        Queue     = $queue
        CTS       = $cts
        Runspace  = $null
        Power     = $null
        Path      = $Path
        OutputPath = $OutputPath
        Expand    = $Expand.IsPresent
    }

    # Build the watcher script block
    $watcherScript = {
        param(
            [string]$WatchPath,
            [string]$PresetsPath,
            [System.Collections.Concurrent.ConcurrentQueue[string]]$EventQueue,
            [System.Threading.CancellationToken]$Token,
            [hashtable]$Locks,
            [bool]$DoExpand,
            [bool]$QuietMode
        )

        $ErrorActionPreference = 'Stop'

        # Create FileSystemWatcher for player data dir
        $fsw = [System.IO.FileSystemWatcher]::new($WatchPath)
        $fsw.IncludeSubdirectories = $false
        $fsw.EnableRaisingEvents = $false
        $fsw.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor
                            [System.IO.NotifyFilters]::LastWrite -bor
                            [System.IO.NotifyFilters]::Size

        # Create FileSystemWatcher for presets dir
        $fswPresets = [System.IO.FileSystemWatcher]::new($PresetsPath)
        $fswPresets.IncludeSubdirectories = $false
        $fswPresets.EnableRaisingEvents = $false
        $fswPresets.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor
                                   [System.IO.NotifyFilters]::LastWrite

        # Event handler: enqueue the full path
        $onChanged = {
            $fullPath = $Event.SourceEventArgs.FullPath
            $Event.MessageData.TryAdd($fullPath)
        }

        $onRenamed = {
            $fullPath = $Event.SourceEventArgs.FullPath
            $Event.MessageData.TryAdd($fullPath)
        }

        # Register events
        $evtChanged = Register-ObjectEvent -InputObject $fsw -EventName 'Changed' -Action $onChanged -MessageData $EventQueue
        $evtCreated = Register-ObjectEvent -InputObject $fsw -EventName 'Created' -Action $onChanged -MessageData $EventQueue
        $evtRenamed = Register-ObjectEvent -InputObject $fsw -EventName 'Renamed' -Action $onRenamed -MessageData $EventQueue

        $evtPresetsChanged = Register-ObjectEvent -InputObject $fswPresets -EventName 'Changed' -Action $onChanged -MessageData $EventQueue
        $evtPresetsCreated = Register-ObjectEvent -InputObject $fswPresets -EventName 'Created' -Action $onChanged -MessageData $EventQueue

        try {
            $fsw.EnableRaisingEvents = $true
            $fswPresets.EnableRaisingEvents = $true

            if (-not $QuietMode) {
                Write-Host "[tvs-save] Watching: $WatchPath"
                Write-Host "[tvs-save] Presets:  $PresetsPath"
                if ($DoExpand) {
                    Write-Host "[tvs-save] Auto-expand: enabled"
                }
            }

            # Processing loop
            while (-not $Token.IsCancellationRequested) {
                # Debounce: collect events over 750 ms
                Start-Sleep -Milliseconds 750

                $paths = [System.Collections.Generic.HashSet[string]]::new()
                $item = $null
                while ($EventQueue.TryDequeue([ref]$item)) {
                    [void]$paths.Add($item)
                }

                foreach ($changedPath in $paths) {
                    if ($Token.IsCancellationRequested) { break }

                    $fileName = Split-Path $changedPath -Leaf

                    # Skip if outbound lock is active
                    $now = [datetime]::UtcNow
                    $lockKey = $changedPath.Replace('\', '/')
                    if ($Locks.ContainsKey($lockKey) -and $Locks[$lockKey] -gt $now) {
                        continue
                    }

                    try {
                        # Case 1: presetSlot{n}.txt.tmp changed
                        if ($fileName -match '^presetSlot(\d+)\.txt\.tmp$') {
                            $slotIndex = [int]$Matches[1]

                            # Read the save index to get the character name
                            $savePath = Join-Path $WatchPath 'SaveFile.es3'
                            if (Test-Path $savePath) {
                                $saveData = Get-Content -Path $savePath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
                                $charName = "Slot$slotIndex"
                                if ($saveData.ContainsKey('SavedPresetNames') -and
                                    $saveData['SavedPresetNames'] -is [hashtable] -and
                                    $saveData['SavedPresetNames'].ContainsKey('value')) {
                                    $values = $saveData['SavedPresetNames']['value']
                                    if ($values -is [array] -and $slotIndex -lt $values.Count -and $null -ne $values[$slotIndex]) {
                                        $charName = $values[$slotIndex]
                                    }
                                }

                                # Convert and write .znelchar
                                $znelcharJson = ConvertFrom-TVSPresetSlot -Path $changedPath
                                $outputFile = Join-Path $PresetsPath "${charName}.znelchar"

                                # Set outbound lock
                                $Locks[$outputFile.Replace('\', '/')] = $now.AddSeconds(3)

                                Set-Content -Path $outputFile -Value $znelcharJson -Encoding UTF8

                                if (-not $QuietMode) {
                                    Write-Host "[tvs-save] Exported slot $slotIndex → ${charName}.znelchar"
                                }

                                # Auto-expand if requested
                                if ($DoExpand) {
                                    $expandedDir = Join-Path (Split-Path $PresetsPath -Parent) 'expanded' $charName
                                    $Locks[$expandedDir.Replace('\', '/')] = $now.AddSeconds(3)
                                    Expand-ZnelcharData -InputPath $outputFile -OutputDir $expandedDir
                                    if (-not $QuietMode) {
                                        Write-Host "[tvs-save] Expanded → $expandedDir"
                                    }
                                }
                            }
                        }
                        # Case 2: .znelchar file changed in presets dir
                        elseif ($fileName -match '\.znelchar$') {
                            $charName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
                            $znelcharPath = $changedPath

                            # Find the slot index for this character
                            $savePath = Join-Path $WatchPath 'SaveFile.es3'
                            if (Test-Path $savePath) {
                                $saveData = Get-Content -Path $savePath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
                                $slotIndex = -1
                                if ($saveData.ContainsKey('SavedPresetNames') -and
                                    $saveData['SavedPresetNames'] -is [hashtable] -and
                                    $saveData['SavedPresetNames'].ContainsKey('value')) {
                                    $values = $saveData['SavedPresetNames']['value']
                                    if ($values -is [array]) {
                                        for ($i = 0; $i -lt $values.Count; $i++) {
                                            if ($values[$i] -eq $charName) {
                                                $slotIndex = $i
                                                break
                                            }
                                        }
                                    }
                                }

                                if ($slotIndex -ge 0) {
                                    $znelcharJson = Get-Content -Path $znelcharPath -Raw -Encoding UTF8
                                    $presetPath = Join-Path $WatchPath "presetSlot${slotIndex}.txt.tmp"

                                    # Set outbound lock
                                    $Locks[$presetPath.Replace('\', '/')] = $now.AddSeconds(3)

                                    ConvertTo-TVSPresetSlot -ZnelcharJson $znelcharJson -OutputPath $presetPath

                                    if (-not $QuietMode) {
                                        Write-Host "[tvs-save] Imported ${charName}.znelchar → slot $slotIndex"
                                    }
                                }
                            }
                        }
                        # Case 3: SaveFile.es3 changed — detect renames
                        elseif ($fileName -eq 'SaveFile.es3') {
                            if (-not $QuietMode) {
                                Write-Host "[tvs-save] SaveFile.es3 changed (rename detection not yet implemented)"
                            }
                        }
                    }
                    catch {
                        if (-not $QuietMode) {
                            Write-Warning "[tvs-save] Error processing '$changedPath': $_"
                        }
                    }
                }
            }
        }
        finally {
            $fsw.EnableRaisingEvents = $false
            $fswPresets.EnableRaisingEvents = $false

            $evtChanged, $evtCreated, $evtRenamed, $evtPresetsChanged, $evtPresetsCreated |
                Where-Object { $_ } |
                ForEach-Object {
                    try { Unregister-Event -SourceIdentifier $_.Name -ErrorAction SilentlyContinue } catch { }
                }

            $fsw.Dispose()
            $fswPresets.Dispose()
        }
    }

    # Start the watcher in a background runspace
    $ps = [PowerShell]::Create()
    $ps.AddScript($watcherScript) | Out-Null
    $ps.AddParameter('WatchPath', $Path) | Out-Null
    $ps.AddParameter('PresetsPath', $OutputPath) | Out-Null
    $ps.AddParameter('EventQueue', $queue) | Out-Null
    $ps.AddParameter('Token', $cts.Token) | Out-Null
    $ps.AddParameter('Locks', $script:OutboundLocks) | Out-Null
    $ps.AddParameter('DoExpand', $Expand.IsPresent) | Out-Null
    $ps.AddParameter('QuietMode', $Quiet.IsPresent) | Out-Null

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ApartmentState = 'STA'
    $runspace.Open()
    $ps.Runspace = $runspace

    $asyncResult = $ps.BeginInvoke()

    $script:Watchers[$watcherId].Runspace = $runspace
    $script:Watchers[$watcherId].Power = $ps
    $script:Watchers[$watcherId].AsyncResult = $asyncResult

    if (-not $Quiet) {
        Write-Host "[tvs-save] Watcher started (ID: $watcherId)"
    }

    return $watcherId
}

function Stop-TVSCharacterSync {
<#
.SYNOPSIS
Stops one or all background character sync watchers.

.DESCRIPTION
Stops the watcher identified by -Id, or all active watchers if
no ID is specified. Cleans up runspace and event subscriptions.

.PARAMETER Id
Watcher ID returned by Watch-TVSCharacterSync. If omitted, stops
all active watchers.
#>
    [CmdletBinding()]
    param(
        [string]$Id = ''
    )

    $idsToStop = if ($Id) { @($Id) } else { $script:Watchers.Keys }

    foreach ($watcherId in $idsToStop) {
        if (-not $script:Watchers.ContainsKey($watcherId)) {
            Write-Warning "No watcher found with ID: $watcherId"
            continue
        }

        $watcher = $script:Watchers[$watcherId]

        # Signal cancellation
        try { $watcher.CTS.Cancel() } catch { }

        # Wait briefly for the runspace to finish
        Start-Sleep -Milliseconds 500

        # Clean up
        try {
            if ($watcher.Power -and $watcher.AsyncResult) {
                $watcher.Power.EndInvoke($watcher.AsyncResult)
            }
        }
        catch {
            # Expected — the runspace may throw on cancellation
        }
        finally {
            try { $watcher.Power?.Dispose() } catch { }
            try { $watcher.Runspace?.Dispose() } catch { }
            try { $watcher.CTS?.Dispose() } catch { }
        }

        $script:Watchers.Remove($watcherId)
        Write-Host "[tvs-save] Watcher stopped (ID: $watcherId)"
    }

    # Clean up expired outbound locks
    $now = [datetime]::UtcNow
    $expired = $script:OutboundLocks.Keys | Where-Object { $script:OutboundLocks[$_] -le $now }
    foreach ($key in $expired) {
        $script:OutboundLocks.Remove($key)
    }
}
