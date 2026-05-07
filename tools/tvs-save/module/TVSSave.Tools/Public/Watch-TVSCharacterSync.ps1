function Watch-TVSCharacterSync {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string]$Path = $script:DefaultPlayerDataDir,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = $(if ($script:DefaultCharacterWorkDir) { Join-Path $script:DefaultCharacterWorkDir 'presets' } else { '' }),

    [Parameter(Mandatory = $false)]
    [switch]$Expand,

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
  )

  if ($script:TVSEnvironmentAvailable) {
    Write-Verbose "TVS.Environment detected, using defaults: playerDataDir=$script:DefaultPlayerDataDir, characterWorkDir=$script:DefaultCharacterWorkDir"
  }

  # If Path is a directory, append SaveFile.es3
  if ($Path -and (Test-Path $Path -PathType Container)) {
    $saveFilePath = Join-Path $Path 'SaveFile.es3'
  } elseif ($Path) {
    $saveFilePath = $Path
  } else {
    throw "Path is required. Either provide -Path or ensure TVS.Environment is available."
  }

  if (-not (Test-Path $saveFilePath -PathType Leaf)) {
    throw "SaveFile.es3 not found at: $saveFilePath"
  }

  if ($OutputPath) {
    $characterWorkDir = $OutputPath
  } else {
    $characterWorkDir = Join-Path (Split-Path $saveFilePath -Parent) "TVSCharacterPresets"
  }

  if (-not (Test-Path $characterWorkDir)) {
    New-Item -Path $characterWorkDir -ItemType Directory -Force | Out-Null
  }

  $logPath = Join-Path $characterWorkDir "tvs-character-sync.log"

  if (-not $Quiet) {
    Write-Host "Starting TVS Character Sync watcher..."
    Write-Host "  Save file: $saveFilePath"
    Write-Host "  Work dir: $characterWorkDir"
    Write-Host "  Log file: $logPath"
  }

  $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
  $iss.ImportPSModule(@(
    "$PSScriptRoot/../TVSSave.Tools.psd1"
  ))

  $runspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, 1, $iss, $Host)
  $runspacePool.Open()

  $eventQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
  $outboundLocks = @{}
  $cancellationTokenSource = [System.Threading.CancellationTokenSource]::new()

  $sharedState = @{
    EventQueue = $eventQueue
    SaveFilePath = $saveFilePath
    CharacterWorkDir = $characterWorkDir
    LogPath = $logPath
    OutboundLocks = $outboundLocks
    CancellationTokenSource = $cancellationTokenSource
  }

  $runspaceScript = {
    param($SharedState)

    $EventQueue = $SharedState.EventQueue
    $SaveFilePath = $SharedState.SaveFilePath
    $CharacterWorkDir = $SharedState.CharacterWorkDir
    $LogPath = $SharedState.LogPath
    $OutboundLocks = $SharedState.OutboundLocks
    $CancellationTokenSource = $SharedState.CancellationTokenSource

    $watcherInfo = New-TVSCharacterWatcher -Path (Split-Path $SaveFilePath -Parent) -EventQueue $EventQueue -LogPath $LogPath

    Invoke-TVSCharacterInitialSync -SaveFilePath $SaveFilePath -CharacterWorkDir $CharacterWorkDir -LogPath $LogPath -OutboundLocks $OutboundLocks

    $watcherInfo.Watcher.EnableRaisingEvents = $true
    Write-TVSCharacterSyncLog -Severity "INFO" -Message "FileSystemWatcher enabled, watching for changes..." -LogPath $LogPath

    Start-TVSCharacterProcessingLoop -EventQueue $EventQueue -SaveFilePath $SaveFilePath -CharacterWorkDir $CharacterWorkDir -LogPath $LogPath -OutboundLocks $OutboundLocks -CancellationTokenSource $CancellationTokenSource

    $watcherInfo.Watcher.EnableRaisingEvents = $false
    $watcherInfo.Watcher.Dispose()
    foreach ($event in $watcherInfo.Events) {
      Unregister-Event -SubscriptionId $event.SubscriptionId -ErrorAction SilentlyContinue
    }

    Write-TVSCharacterSyncLog -Severity "INFO" -Message "Watcher stopped" -LogPath $LogPath
  }

  $powershell = [System.Management.Automation.PowerShell]::Create($iss)
  $powershell.RunspacePool = $runspacePool
  $null = $powershell.AddScript($runspaceScript).AddArgument($sharedState)
  $asyncResult = $powershell.BeginInvoke()

  $watcherId = [guid]::NewGuid().ToString()
  $script:TVSSyncWatchers = @{}
  $script:TVSSyncWatchers[$watcherId] = @{
    PowerShell = $powershell
    AsyncResult = $asyncResult
    RunspacePool = $runspacePool
    CancellationTokenSource = $cancellationTokenSource
    LogPath = $logPath
  }

  if (-not $Quiet) {
    Write-Host "Watcher started with ID: $watcherId"
  }

  return $watcherId
}

function Stop-TVSCharacterSync {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$WatcherId
  )

  if (-not $script:TVSSyncWatchers -or -not $script:TVSSyncWatchers.ContainsKey($WatcherId)) {
    Write-Warning "Watcher ID '$WatcherId' not found"
    return
  }

  $watcher = $script:TVSSyncWatchers[$WatcherId]
  $watcher.CancellationTokenSource.Cancel()

  try {
    $watcher.PowerShell.EndInvoke($watcher.AsyncResult)
  } catch {
    Write-Warning "Error stopping watcher: $_"
  } finally {
    $watcher.PowerShell.Dispose()
    $watcher.RunspacePool.Close()
    $watcher.RunspacePool.Dispose()
    $watcher.CancellationTokenSource.Dispose()
    $script:TVSSyncWatchers.Remove($WatcherId)
  }

  Write-Host "Watcher '$WatcherId' stopped"
}
