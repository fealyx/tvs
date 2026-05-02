function Update-TVSMMod {
<#
.SYNOPSIS
Checks the community registry for newer versions of installed mods and updates them.
Auto-snapshots before making changes.

.PARAMETER Name
Specific mod to update. If omitted, checks all mods in the active profile.

.PARAMETER Yes
Skip confirmation prompts.

.EXAMPLE
tvsm mod update
tvsm mod update TVSLib
#>
    [CmdletBinding()]
    param(
        [string]$Name = '',
        [switch]$Yes
    )

    $tvse       = Get-TVSEnvironment
    $modWorkDir = $tvse.modWorkDir
    $gameDir    = $tvse.gameDir
    if ([string]::IsNullOrEmpty($modWorkDir)) { throw "modWorkDir is not configured." }

    $registry    = Get-TVSCommunityRegistry -ModWorkDir $modWorkDir
    $profileName = Get-TVSActiveProfileName -ModWorkDir $modWorkDir
    $profileData = Read-TVSModProfile -ModWorkDir $modWorkDir -ProfileName $profileName
    if (-not $profileData) { throw "No active profile found. Run 'tvsm mod install --all' first." }

    # Determine mods to check
    $modsToCheck = @()
    if (-not [string]::IsNullOrEmpty($Name)) {
        $modsToCheck = @($Name)
    } else {
        if ($profileData['bepInExVersion']) { $modsToCheck += 'BepInEx' }
        if ($profileData['mods']) { $modsToCheck += @($profileData['mods'].Keys) }
    }

    $updates = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($modName in $modsToCheck) {
        $regEntry = $registry.mods | Where-Object { $_.name -eq $modName }
        if (-not $regEntry) {
            Write-SpectreHost "[grey]  ${modName}: not in registry — skipped[/]"
            continue
        }
        $latestVer = $regEntry.versions | Sort-Object { [version]$_.version } -Descending |
                     Select-Object -First 1

        $currentVersion = if ($modName -eq 'BepInEx') {
            $profileData['bepInExVersion']
        } else {
            $profileData['mods'][$modName]?['version']
        }
        if (-not $currentVersion) { continue }

        if ([version]$latestVer.version -gt [version]$currentVersion) {
            $updates.Add(@{ name = $modName; current = $currentVersion;
                            latest = $latestVer.version; versionEntry = $latestVer })
        }
    }

    if ($updates.Count -eq 0) {
        Write-SpectreHost '[green]✓ All mods are up to date.[/]'
        return
    }

    Write-SpectreHost '[cyan]Updates available:[/]'
    foreach ($u in $updates) {
        Write-SpectreHost "  $($u.name): $($u.current) → [green]$($u.latest)[/]"
    }
    Write-SpectreHost ''

    # Auto-snapshot
    $modsDeepCopy = if ($profileData['mods']) {
        $profileData['mods'] | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable -Depth 10
    } else { @{} }
    $snap = @{ id = [DateTimeOffset]::UtcNow.ToString('o');
               label = "before-update-$([DateTimeOffset]::UtcNow.ToString('yyyy-MM-dd'))";
               bepInExVersion = $profileData['bepInExVersion']; mods = $modsDeepCopy }
    $profileData['snapshots'] = @($snap) + @(if ($profileData['snapshots']) { $profileData['snapshots'] } else { @() })

    $gameVersion = if ($gameDir) { Get-TVSGameVersion -GameDir $gameDir } else { $null }

    foreach ($u in $updates) {
        $storePath = Join-Path $modWorkDir 'store' $u.name $u.latest
        if (-not (Test-Path -LiteralPath $storePath)) {
            Install-TVSMModFromRegistry -ModWorkDir $modWorkDir -ModName $u.name `
                -VersionEntry $u.versionEntry
        }
        if ($u.name -eq 'BepInEx') {
            $profileData['bepInExVersion'] = $u.latest
        } else {
            $profileData['mods'][$u.name]['version'] = $u.latest
        }
    }

    Write-TVSModProfile -ModWorkDir $modWorkDir -ProfileData $profileData `
        -ProfileName $profileName
    Invoke-TVSMModApply -Profile $profileName
}
