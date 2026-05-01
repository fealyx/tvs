function Invoke-TVSMModApply {
<#
.SYNOPSIS
Assembles the staging directory from the mod store and establishes junctions from
the game directory into staging. Dev link overlays are applied on top.

This is the core idempotent repair operation. Safe to re-run at any time; after a
game update that wipes BepInEx/plugins, re-running restores all links without
re-downloading anything.

.PARAMETER Profile
Named profile to apply. Defaults to the active profile.

.PARAMETER Force
Suppress gameVersionRange warnings. Mods outside their range are still applied.

.EXAMPLE
Invoke-TVSMModApply
tvsm mod apply --force
#>
    [CmdletBinding()]
    param(
        [string]$Profile = '',
        [switch]$Force
    )

    $tvse       = Get-TVSEnvironment
    $modWorkDir = $tvse.modWorkDir
    $gameDir    = $tvse.gameDir

    if ([string]::IsNullOrEmpty($modWorkDir)) {
        throw "modWorkDir is not configured. Run 'tvsm config init' first."
    }
    if ([string]::IsNullOrEmpty($gameDir)) {
        throw "gameDir is not configured. Run 'tvsm config init' first."
    }

    $profileName = if (-not [string]::IsNullOrEmpty($Profile)) {
        $Profile
    } else {
        Get-TVSActiveProfileName -ModWorkDir $modWorkDir
    }

    $profileData = Read-TVSModProfile -ModWorkDir $modWorkDir -ProfileName $profileName
    if (-not $profileData) {
        throw "Profile '$profileName' not found. Run 'tvsm mod install --all' to initialise."
    }

    $gameVersion = Get-TVSGameVersion -GameDir $gameDir

    Write-SpectreHost "[cyan]Applying profile:[/] $profileName"
    if ($gameVersion) { Write-SpectreHost "[grey]Game version:[/] $gameVersion" }

    # BepInEx doorstop + core
    $bepInExVersion = $profileData['bepInExVersion']
    if ($bepInExVersion) {
        Invoke-TVSMEnsureBepInEx -ModWorkDir $modWorkDir -GameDir $gameDir `
            -BepInExVersion $bepInExVersion
    }

    # Staging assembly (store files + dev-link junctions)
    Invoke-TVSMStagingAssembly -ModWorkDir $modWorkDir -GameDir $gameDir `
        -ProfileData $profileData -ProfileName $profileName `
        -Force:$Force -GameVersion ($gameVersion ?? '')

    # gameroot-overlay store mods — copy directly to gameDir
    $mods = $profileData['mods']
    if ($mods) {
        foreach ($modName in $mods.Keys) {
            $modEntry = $mods[$modName]
            if ($modEntry['enabled'] -ne $true) { continue }
            if (($modEntry['installLayout'] ?? 'plugins-dll') -ne 'gameroot-overlay') { continue }

            $storePath = Join-Path $modWorkDir 'store' $modName $modEntry['version']
            if (-not (Test-Path -LiteralPath $storePath)) {
                Write-Warning "[tvsm] Store entry missing for $modName — skipping."
                continue
            }
            Get-ChildItem -LiteralPath $storePath -Exclude 'tvsm-meta.json' |
                Copy-Item -Destination $gameDir -Recurse -Force
        }
    }

    # Create/refresh junctions: gameDir/BepInEx/{plugins,patchers,config} → staging
    $bepInExDir  = Join-Path $gameDir 'BepInEx'
    $stagingBase = Join-Path $modWorkDir 'staging' $profileName

    if (-not (Test-Path -LiteralPath $bepInExDir)) {
        New-Item -ItemType Directory -Path $bepInExDir -Force | Out-Null
    }

    foreach ($subdir in @('plugins', 'patchers', 'config')) {
        New-TVSJunctionOrSymlink -Path (Join-Path $bepInExDir $subdir) `
            -Target (Join-Path $stagingBase $subdir)
    }

    Write-SpectreHost "[green]✓ Mod environment applied[/] [grey](profile: $profileName)[/]"
}

function Get-TVSMModStatus {
<#
.SYNOPSIS
Shows the current mod installation status: profile contents, store presence,
junction health, dev links, and any out-of-range version warnings.

.PARAMETER Profile
Named profile to inspect. Defaults to the active profile.

.PARAMETER Json
Emit structured JSON output instead of the Spectre table.

.EXAMPLE
tvsm mod status
tvsm mod status --json
#>
    [CmdletBinding()]
    param(
        [string]$Profile = '',
        [switch]$Json
    )

    $tvse       = Get-TVSEnvironment
    $modWorkDir = $tvse.modWorkDir
    $gameDir    = $tvse.gameDir

    if ([string]::IsNullOrEmpty($modWorkDir)) {
        Write-SpectreHost '[yellow]modWorkDir is not configured. Run [cyan]tvsm config init[/].[/]'
        return
    }

    $profileName = if (-not [string]::IsNullOrEmpty($Profile)) {
        $Profile
    } else {
        Get-TVSActiveProfileName -ModWorkDir $modWorkDir
    }

    $profileData = Read-TVSModProfile -ModWorkDir $modWorkDir -ProfileName $profileName
    $gameVersion = if ($gameDir) { Get-TVSGameVersion -GameDir $gameDir } else { $null }

    # Junction health check
    $bepInExDir   = if ($gameDir) { Join-Path $gameDir 'BepInEx' } else { $null }
    $pluginsPath  = if ($bepInExDir) { Join-Path $bepInExDir 'plugins' } else { $null }
    $junctionsUp  = $false
    $wipeDetected = $false

    if ($pluginsPath) {
        if (Test-Path -LiteralPath $pluginsPath) {
            $item        = Get-Item -LiteralPath $pluginsPath -Force
            $junctionsUp = $null -ne $item.LinkType
        } elseif ($bepInExDir -and (Test-Path -LiteralPath $bepInExDir)) {
            $wipeDetected = $true
        }
    }

    # Build row list
    $rows = [System.Collections.Generic.List[hashtable]]::new()

    if ($profileData -and $profileData['bepInExVersion']) {
        $ver         = $profileData['bepInExVersion']
        $storeExists = Test-Path -LiteralPath (Join-Path $modWorkDir 'store' 'BepInEx' $ver)
        $rows.Add(@{ name = 'BepInEx'; version = $ver; enabled = $true; inStore = $storeExists;
                     linked = $junctionsUp; tag = ''; installLayout = 'bepinex-root' })
    }

    if ($profileData -and $profileData['mods']) {
        foreach ($modName in $profileData['mods'].Keys) {
            $mod         = $profileData['mods'][$modName]
            $ver         = $mod['version']
            $enabled     = $mod['enabled'] -eq $true
            $layout      = $mod['installLayout'] ?? 'plugins-dll'
            $storeExists = Test-Path -LiteralPath (Join-Path $modWorkDir 'store' $modName $ver)

            $tag = ''
            $rangeStr = $mod['gameVersionRange']
            if ($rangeStr -and $gameVersion) {
                if (-not (Test-TVSGameVersionRange -GameVersion $gameVersion -Range $rangeStr)) {
                    $tag = '[OUTDATED RANGE]'
                }
            } elseif ($rangeStr -and -not $gameVersion) {
                $tag = '[VERSION UNKNOWN]'
            }

            $rows.Add(@{ name = $modName; version = $ver; enabled = $enabled;
                         inStore = $storeExists; linked = ($junctionsUp -and $enabled);
                         tag = $tag; installLayout = $layout })
        }
    }

    $devLinks = Read-TVSDevLinks -ModWorkDir $modWorkDir
    $links    = $devLinks['links']
    if ($links) {
        foreach ($linkName in $links.Keys) {
            $link      = $links[$linkName]
            $srcExists = Test-Path -LiteralPath $link['src']
            $rows.Add(@{ name = $linkName; version = '[DEV]'; enabled = $true;
                         inStore = $srcExists; linked = ($srcExists -and $junctionsUp);
                         tag = '[DEV]'; installLayout = $link['installLayout'] ?? 'plugins-dll' })
        }
    }

    if ($Json) {
        [ordered]@{
            profile      = $profileName
            gameVersion  = $gameVersion
            wipeDetected = $wipeDetected
            junctionsUp  = $junctionsUp
            mods         = $rows
        } | ConvertTo-Json -Depth 10
        return
    }

    if ($wipeDetected) {
        Write-SpectreHost '[red bold]⚠ Game update wipe detected![/] Run [cyan]tvsm mod apply[/] to restore.'
        Write-SpectreHost ''
    }

    if ($rows.Count -eq 0) {
        Write-SpectreHost '[yellow]No mods installed. Run [cyan]tvsm mod install --all[/] to get started.[/]'
        return
    }

    $tableRows = foreach ($r in $rows) {
        $statusIcon  = if ($r.linked) { '[green]●[/]' } elseif ($r.enabled) { '[yellow]○[/]' } else { '[grey]–[/]' }
        $nameDisplay = if ($r.tag -eq '[DEV]') { "[cyan]$($r.name)[/] [grey](dev)[/]" } `
                       elseif ($r.tag) { "$($r.name) [yellow]$($r.tag)[/]" } `
                       else { $r.name }
        $storeDisplay   = if ($r.inStore) { '[green]✓[/]' } else { '[red]✗[/]' }
        $enabledDisplay = if ($r.enabled) { '[green]on[/]' } else { '[grey]off[/]' }
        [pscustomobject]@{ ' ' = $statusIcon; Name = $nameDisplay; Version = $r.version;
                           Layout = $r.installLayout; Store = $storeDisplay; Enabled = $enabledDisplay }
    }

    $tableRows | Format-SpectreTable -Border Rounded -Color Blue `
        -Title "[cyan]$profileName[/]" -AllowMarkup

    if ($profileData -and $profileData['snapshots'] -and @($profileData['snapshots']).Count -gt 0) {
        Write-SpectreHost "[grey]$(@($profileData['snapshots']).Count) snapshot(s) available — run [cyan]tvsm mod rollback[/] to revert.[/]"
    }
}

function Install-TVSMMod {
<#
.SYNOPSIS
Installs one or more mods from the community registry into the mod store,
updates the active profile, and applies the changes to the game directory.

.PARAMETER Name
Name of the mod to install (e.g. 'TVSLib'). Mutually exclusive with -All.

.PARAMETER All
Install all recommended and required mods from the registry.

.PARAMETER Profile
Named profile to update. Defaults to the active profile.

.PARAMETER Yes
Skip confirmation prompts (non-interactive / CI mode).

.EXAMPLE
tvsm mod install TVSLib
tvsm mod install --all
#>
    [CmdletBinding()]
    param(
        [string]$Name    = '',
        [switch]$All,
        [string]$Profile = '',
        [switch]$Yes
    )

    $tvse       = Get-TVSEnvironment
    $modWorkDir = $tvse.modWorkDir
    $gameDir    = $tvse.gameDir

    if ([string]::IsNullOrEmpty($modWorkDir)) {
        throw "modWorkDir is not configured. Run 'tvsm config init' first."
    }

    $registry = Get-TVSCommunityRegistry -ModWorkDir $modWorkDir

    # Resolve candidate mods
    $candidates = @()
    if ($All) {
        $candidates = @($registry.mods | Where-Object { $_.required -or $_.recommended })
    } elseif (-not [string]::IsNullOrEmpty($Name)) {
        $regEntry = $registry.mods | Where-Object { $_.name -eq $Name }
        if (-not $regEntry) { throw "Mod '$Name' not found in the community registry." }
        $candidates = @($regEntry)
        # Add declared dependencies
        $latestVer = $regEntry.versions |
            Sort-Object { [version]$_.version } -Descending | Select-Object -First 1
        if ($latestVer.requires) {
            foreach ($dep in $latestVer.requires) {
                $depEntry = $registry.mods | Where-Object { $_.name -eq $dep }
                if ($depEntry -and -not ($candidates | Where-Object { $_.name -eq $dep })) {
                    $candidates = @($depEntry) + $candidates
                }
            }
        }
    } else {
        throw "Specify a mod name or use --all."
    }

    # Load or create profile
    $profileName = if (-not [string]::IsNullOrEmpty($Profile)) {
        $Profile
    } else {
        Get-TVSActiveProfileName -ModWorkDir $modWorkDir
    }
    $profileData = Read-TVSModProfile -ModWorkDir $modWorkDir -ProfileName $profileName
    if (-not $profileData) {
        $profileData = @{ schemaVersion = 1; name = $profileName;
                          bepInExVersion = $null; mods = @{}; snapshots = @() }
    }

    # Auto-snapshot before any changes (skip for fresh/empty profiles)
    $hasMods = ($profileData['mods'] -and $profileData['mods'].Count -gt 0) -or
               $profileData['bepInExVersion']
    if ($hasMods) {
        $modsDeepCopy = $profileData['mods'] | ConvertTo-Json -Depth 10 |
                        ConvertFrom-Json -AsHashtable -Depth 10
        $snap = @{ id = [DateTimeOffset]::UtcNow.ToString('o');
                   label = "before-install-$($candidates.name -join ',')";
                   bepInExVersion = $profileData['bepInExVersion']; mods = $modsDeepCopy }
        $profileData['snapshots'] = @($snap) + @(if ($profileData['snapshots']) { $profileData['snapshots'] } else { @() })
    }

    # Install BepInEx first, then other mods
    $bepInExCand  = $candidates | Where-Object { $_.name -eq 'BepInEx' }
    $otherCands   = $candidates | Where-Object { $_.name -ne 'BepInEx' }
    $installOrder = @()
    if ($bepInExCand) { $installOrder += $bepInExCand }
    $installOrder += $otherCands

    $gameVersion = if ($gameDir) { Get-TVSGameVersion -GameDir $gameDir } else { $null }

    foreach ($mod in $installOrder) {
        $latestVer = $mod.versions | Sort-Object { [version]$_.version } -Descending |
                     Select-Object -First 1

        # Hard block on version range at install time
        if ($latestVer.gameVersionRange -and $gameVersion) {
            if (-not (Test-TVSGameVersionRange -GameVersion $gameVersion `
                      -Range $latestVer.gameVersionRange)) {
                throw "Cannot install $($mod.name) $($latestVer.version): game version $gameVersion is outside supported range '$($latestVer.gameVersionRange)'."
            }
        }

        $storePath = Join-Path $modWorkDir 'store' $mod.name $latestVer.version
        if (-not (Test-Path -LiteralPath $storePath)) {
            Install-TVSMModFromRegistry -ModWorkDir $modWorkDir -ModName $mod.name `
                -VersionEntry $latestVer
        } else {
            Write-SpectreHost "[grey]  Already in store:[/] $($mod.name) $($latestVer.version)"
        }

        if ($mod.name -eq 'BepInEx') {
            $profileData['bepInExVersion'] = $latestVer.version
        } else {
            if (-not $profileData['mods']) { $profileData['mods'] = @{} }
            $profileData['mods'][$mod.name] = @{
                version          = $latestVer.version
                enabled          = $true
                installLayout    = $latestVer.installLayout ?? 'plugins-dll'
                gameVersionRange = $latestVer.gameVersionRange ?? $null
            }
        }
    }

    Write-TVSModProfile -ModWorkDir $modWorkDir -ProfileData $profileData `
        -ProfileName $profileName
    Invoke-TVSMModApply -Profile $profileName
}

function Remove-TVSMMod {
<#
.SYNOPSIS
Removes a mod from the active profile and re-applies. The store entry is
preserved so the mod can be reinstalled without re-downloading.

.PARAMETER Name
Name of the mod to remove.

.PARAMETER Yes
Skip the confirmation prompt.

.EXAMPLE
tvsm mod remove TVSLib
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Yes
    )

    $tvse       = Get-TVSEnvironment
    $modWorkDir = $tvse.modWorkDir
    if ([string]::IsNullOrEmpty($modWorkDir)) { throw "modWorkDir is not configured." }

    $profileName = Get-TVSActiveProfileName -ModWorkDir $modWorkDir
    $profileData = Read-TVSModProfile -ModWorkDir $modWorkDir -ProfileName $profileName
    if (-not $profileData) { throw "Profile '$profileName' not found." }
    if (-not $profileData['mods'] -or -not $profileData['mods'].ContainsKey($Name)) {
        throw "Mod '$Name' is not in the active profile '$profileName'."
    }

    if (-not $Yes -and -not $PSCmdlet.ShouldProcess($Name, "Remove from profile '$profileName'")) {
        Write-SpectreHost '[grey]Cancelled.[/]'
        return
    }

    # Auto-snapshot
    $modsDeepCopy = $profileData['mods'] | ConvertTo-Json -Depth 10 |
                    ConvertFrom-Json -AsHashtable -Depth 10
    $snap = @{ id = [DateTimeOffset]::UtcNow.ToString('o'); label = "before-remove-$Name";
               bepInExVersion = $profileData['bepInExVersion']; mods = $modsDeepCopy }
    $profileData['snapshots'] = @($snap) + @(if ($profileData['snapshots']) { $profileData['snapshots'] } else { @() })

    $profileData['mods'].Remove($Name)
    Write-TVSModProfile -ModWorkDir $modWorkDir -ProfileData $profileData `
        -ProfileName $profileName

    Write-SpectreHost "[green]✓ Removed from profile:[/] $Name [grey](store entry preserved)[/]"
    Invoke-TVSMModApply -Profile $profileName
}

function Invoke-TVSMModRollback {
<#
.SYNOPSIS
Restores the active profile to its most recent pre-mutation snapshot and
re-applies the mod environment. Dev links are not affected.

.PARAMETER Profile
Named profile to roll back. Defaults to the active profile.

.PARAMETER Yes
Skip the confirmation prompt.

.EXAMPLE
tvsm mod rollback
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Profile = '',
        [switch]$Yes
    )

    $tvse       = Get-TVSEnvironment
    $modWorkDir = $tvse.modWorkDir
    if ([string]::IsNullOrEmpty($modWorkDir)) { throw "modWorkDir is not configured." }

    $profileName = if (-not [string]::IsNullOrEmpty($Profile)) {
        $Profile
    } else {
        Get-TVSActiveProfileName -ModWorkDir $modWorkDir
    }

    $profileData = Read-TVSModProfile -ModWorkDir $modWorkDir -ProfileName $profileName
    if (-not $profileData) { throw "Profile '$profileName' not found." }

    $snapshots = @(if ($profileData['snapshots']) { $profileData['snapshots'] } else { @() })
    if ($snapshots.Count -eq 0) {
        throw "No snapshots available for profile '$profileName'. Cannot roll back."
    }

    $snapshot      = $snapshots[0]
    $snapshotLabel = $snapshot['label'] ?? $snapshot['id']

    Write-SpectreHost "[cyan]Rolling back profile[/] '$profileName' [cyan]to:[/] $snapshotLabel"
    Write-SpectreHost "  BepInEx: $($snapshot['bepInExVersion'] ?? '(unchanged)')"
    $modList = if ($snapshot['mods']) { $snapshot['mods'].Keys -join ', ' } else { '(none)' }
    Write-SpectreHost "  Mods: $modList"
    Write-SpectreHost ''

    if (-not $Yes -and -not $PSCmdlet.ShouldProcess($profileName, "Roll back to '$snapshotLabel'")) {
        Write-SpectreHost '[grey]Rollback cancelled.[/]'
        return
    }

    $profileData['bepInExVersion'] = $snapshot['bepInExVersion']
    $profileData['mods']           = $snapshot['mods'] ?? @{}
    $profileData['snapshots']      = @($snapshots | Select-Object -Skip 1)

    Write-TVSModProfile -ModWorkDir $modWorkDir -ProfileData $profileData `
        -ProfileName $profileName

    Write-SpectreHost '[green]✓ Profile restored. Applying...[/]'
    Invoke-TVSMModApply -Profile $profileName
}

function Test-TVSMModEnvironment {
<#
.SYNOPSIS
Verifies the mod environment: BepInEx doorstop presence, junction health,
TVSLib version, and store integrity.

.PARAMETER Profile
Named profile to check against. Defaults to the active profile.

.PARAMETER Json
Emit structured JSON results instead of the check list.

.EXAMPLE
tvsm mod verify
#>
    [CmdletBinding()]
    param(
        [string]$Profile = '',
        [switch]$Json
    )

    $tvse       = Get-TVSEnvironment
    $modWorkDir = $tvse.modWorkDir
    $gameDir    = $tvse.gameDir

    $checks = [System.Collections.Generic.List[hashtable]]::new()
    $checks.Add(@{ name = 'modWorkDir configured'; pass = -not [string]::IsNullOrEmpty($modWorkDir) })
    $checks.Add(@{ name = 'gameDir configured';    pass = -not [string]::IsNullOrEmpty($gameDir) })

    if ($gameDir) {
        $gameDirExists = Test-Path -LiteralPath $gameDir
        $checks.Add(@{ name = 'gameDir exists'; pass = $gameDirExists })

        if ($gameDirExists) {
            $checks.Add(@{ name = 'BepInEx doorstop (winhttp.dll)';
                           pass = (Test-Path -LiteralPath (Join-Path $gameDir 'winhttp.dll')) })

            $bepInExDir = Join-Path $gameDir 'BepInEx'
            $checks.Add(@{ name = 'BepInEx directory'; pass = (Test-Path -LiteralPath $bepInExDir) })

            foreach ($subdir in @('plugins', 'patchers', 'config')) {
                $linkPath    = Join-Path $bepInExDir $subdir
                $linkPresent = $false
                $linkHealthy = $false
                if (Test-Path -LiteralPath $linkPath) {
                    $item        = Get-Item -LiteralPath $linkPath -Force
                    if ($item.LinkType) {
                        $linkPresent = $true
                        $linkHealthy = Test-Path -LiteralPath $item.Target
                    }
                }
                $checks.Add(@{ name = "BepInEx/$subdir junction present"; pass = $linkPresent })
                if ($linkPresent) {
                    $checks.Add(@{ name = "BepInEx/$subdir junction target reachable"; pass = $linkHealthy })
                }
            }
        }
    }

    if ($modWorkDir) {
        $pName = if (-not [string]::IsNullOrEmpty($Profile)) {
            $Profile
        } else {
            Get-TVSActiveProfileName -ModWorkDir $modWorkDir
        }
        $pd = Read-TVSModProfile -ModWorkDir $modWorkDir -ProfileName $pName
        $checks.Add(@{ name = "profile '$pName' exists"; pass = $null -ne $pd })
        if ($pd -and $pd['mods'] -and $pd['mods'].ContainsKey('TVSLib')) {
            $tvslibVer = $pd['mods']['TVSLib']['version']
            $checks.Add(@{ name = "TVSLib $tvslibVer in store";
                           pass = (Test-Path -LiteralPath (Join-Path $modWorkDir 'store' 'TVSLib' $tvslibVer)) })
        }
    }

    if ($Json) { $checks | ConvertTo-Json -Depth 5; return }

    $allPass = $true
    foreach ($check in $checks) {
        $icon = if ($check.pass) { '[green]✓[/]' } else { '[red]✗[/]'; $allPass = $false }
        Write-SpectreHost "$icon $($check.name)"
    }
    Write-SpectreHost ''
    if ($allPass) {
        Write-SpectreHost '[green bold]✓ Environment is healthy.[/]'
    } else {
        Write-SpectreHost '[yellow]Some checks failed. Run [cyan]tvsm mod apply[/] to repair junctions.[/]'
    }
}

function New-TVSMModSnapshot {
<#
.SYNOPSIS
Manually creates a named snapshot of the current mod profile state.
The snapshot is prepended to the profile's snapshots array and can be
restored with tvsm mod rollback.

.PARAMETER Name
Optional label. Defaults to an ISO 8601 timestamp.

.EXAMPLE
tvsm mod snapshot before-experiment
#>
    [CmdletBinding()]
    param(
        [string]$Name = ''
    )

    $tvse       = Get-TVSEnvironment
    $modWorkDir = $tvse.modWorkDir
    if ([string]::IsNullOrEmpty($modWorkDir)) { throw "modWorkDir is not configured." }

    $profileName = Get-TVSActiveProfileName -ModWorkDir $modWorkDir
    $profileData = Read-TVSModProfile -ModWorkDir $modWorkDir -ProfileName $profileName
    if (-not $profileData) { throw "Profile '$profileName' not found." }

    $id    = [DateTimeOffset]::UtcNow.ToString('o')
    $label = if (-not [string]::IsNullOrEmpty($Name)) { $Name } else { $id }

    $modsDeepCopy = if ($profileData['mods']) {
        $profileData['mods'] | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable -Depth 10
    } else { @{} }

    $snap = @{ id = $id; label = $label; bepInExVersion = $profileData['bepInExVersion'];
               mods = $modsDeepCopy }
    $profileData['snapshots'] = @($snap) + @(if ($profileData['snapshots']) { $profileData['snapshots'] } else { @() })

    Write-TVSModProfile -ModWorkDir $modWorkDir -ProfileData $profileData `
        -ProfileName $profileName
    Write-SpectreHost "[green]✓ Snapshot created:[/] $label"
}
