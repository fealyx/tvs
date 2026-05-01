function Get-TVSMModProfileList {
<#
.SYNOPSIS
Lists all available mod profiles in modWorkDir/profiles/, marking the active one.

.PARAMETER Json
Emit structured JSON instead of the text list.

.EXAMPLE
tvsm mod profile list
#>
    [CmdletBinding()]
    param([switch]$Json)

    $modWorkDir  = (Get-TVSEnvironment).modWorkDir
    if ([string]::IsNullOrEmpty($modWorkDir)) { throw "modWorkDir is not configured." }

    $activeName  = Get-TVSActiveProfileName -ModWorkDir $modWorkDir
    $profilesDir = Join-Path $modWorkDir 'profiles'

    $profiles = @()
    if (Test-Path -LiteralPath $profilesDir) {
        $profiles = Get-ChildItem -LiteralPath $profilesDir -Filter '*.json' | ForEach-Object {
            $name = $_.BaseName
            $data = Get-Content -Raw -LiteralPath $_.FullName |
                    ConvertFrom-Json -AsHashtable -Depth 10
            [ordered]@{
                name           = $name
                active         = ($name -eq $activeName)
                modCount       = ($data['mods'] ?? @{}).Count
                snapshotCount  = @(if ($data['snapshots']) { $data['snapshots'] } else { @() }).Count
                bepInExVersion = $data['bepInExVersion']
            }
        }
    }

    if ($Json) { $profiles | ConvertTo-Json -Depth 5; return }

    if ($profiles.Count -eq 0) {
        Write-SpectreHost "[yellow]No profiles found in: $profilesDir[/]"
        return
    }

    foreach ($p in $profiles) {
        $marker = if ($p.active) { '[cyan]●[/] ' } else { '  ' }
        Write-SpectreHost "$marker[white]$($p.name)[/] [grey]($($p.modCount) mods, $($p.snapshotCount) snapshots, BepInEx $($p.bepInExVersion ?? 'n/a'))[/]"
    }
}

function Switch-TVSMModProfile {
<#
.SYNOPSIS
Switches the active mod profile and re-applies the mod environment.

.PARAMETER Name
Name of the profile to activate.

.EXAMPLE
tvsm mod profile switch dev
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    $modWorkDir = (Get-TVSEnvironment).modWorkDir
    if ([string]::IsNullOrEmpty($modWorkDir)) { throw "modWorkDir is not configured." }

    $profilePath = Join-Path $modWorkDir 'profiles' "$Name.json"
    if (-not (Test-Path -LiteralPath $profilePath)) {
        throw "Profile '$Name' not found. Run 'tvsm mod profile list' to see available profiles."
    }

    Set-TVSActiveProfileName -ModWorkDir $modWorkDir -ProfileName $Name
    Write-SpectreHost "[green]✓ Switched to profile:[/] $Name"
    Invoke-TVSMModApply -Profile $Name
}

function New-TVSMModProfile {
<#
.SYNOPSIS
Creates a new named mod profile by cloning the currently active profile.
Snapshots are not copied to the new profile.

.PARAMETER Name
Name for the new profile.

.EXAMPLE
tvsm mod profile new dev
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    $modWorkDir = (Get-TVSEnvironment).modWorkDir
    if ([string]::IsNullOrEmpty($modWorkDir)) { throw "modWorkDir is not configured." }

    $destPath = Join-Path $modWorkDir 'profiles' "$Name.json"
    if (Test-Path -LiteralPath $destPath) {
        throw "Profile '$Name' already exists."
    }

    $activeName  = Get-TVSActiveProfileName -ModWorkDir $modWorkDir
    $activeData  = Read-TVSModProfile -ModWorkDir $modWorkDir -ProfileName $activeName

    $newProfile = if ($activeData) {
        $clone = $activeData | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable -Depth 20
        $clone['name']      = $Name
        $clone['snapshots'] = @()
        $clone
    } else {
        @{ schemaVersion = 1; name = $Name; bepInExVersion = $null; mods = @{}; snapshots = @() }
    }

    Write-TVSModProfile -ModWorkDir $modWorkDir -ProfileData $newProfile -ProfileName $Name
    Write-SpectreHost "[green]✓ Created profile:[/] $Name [grey](cloned from $activeName)[/]"
    Write-SpectreHost "Run [cyan]tvsm mod profile switch $Name[/] to activate it."
}

function Get-TVSMModStoreList {
<#
.SYNOPSIS
Lists all mod versions currently in the mod store with their sizes.

.PARAMETER Json
Emit structured JSON instead of the text list.

.EXAMPLE
tvsm mod store list
#>
    [CmdletBinding()]
    param([switch]$Json)

    $modWorkDir = (Get-TVSEnvironment).modWorkDir
    if ([string]::IsNullOrEmpty($modWorkDir)) { throw "modWorkDir is not configured." }

    $storeDir = Join-Path $modWorkDir 'store'
    $entries  = @()

    if (Test-Path -LiteralPath $storeDir) {
        $entries = Get-ChildItem -LiteralPath $storeDir -Directory | ForEach-Object {
            $modName = $_.Name
            Get-ChildItem -LiteralPath $_.FullName -Directory | ForEach-Object {
                $size = (Get-ChildItem -LiteralPath $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
                         Measure-Object -Property Length -Sum).Sum
                [ordered]@{ name = $modName; version = $_.Name; path = $_.FullName; sizeBytes = $size }
            }
        }
    }

    if ($Json) { $entries | ConvertTo-Json -Depth 5; return }

    if ($entries.Count -eq 0) {
        Write-SpectreHost '[yellow]Store is empty. Run [cyan]tvsm mod install --all[/] to populate it.[/]'
        return
    }

    foreach ($e in $entries) {
        $sizeMB = if ($e.sizeBytes) { '{0:N1} MB' -f ($e.sizeBytes / 1MB) } else { '?' }
        Write-SpectreHost "$($e.name) [cyan]$($e.version)[/] [grey]($sizeMB)[/]"
    }
}

function Invoke-TVSMModStorePrune {
<#
.SYNOPSIS
Removes store entries that are not referenced by any profile or snapshot,
freeing disk space.

.PARAMETER Yes
Skip the confirmation prompt.

.EXAMPLE
tvsm mod store prune
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([switch]$Yes)

    $modWorkDir = (Get-TVSEnvironment).modWorkDir
    if ([string]::IsNullOrEmpty($modWorkDir)) { throw "modWorkDir is not configured." }

    $storeDir = Join-Path $modWorkDir 'store'
    if (-not (Test-Path -LiteralPath $storeDir)) {
        Write-SpectreHost '[grey]Store is empty.[/]'
        return
    }

    # Collect every {modName}/{version} pair referenced by any profile or snapshot
    $referenced  = @{}
    $profilesDir = Join-Path $modWorkDir 'profiles'
    if (Test-Path -LiteralPath $profilesDir) {
        Get-ChildItem -LiteralPath $profilesDir -Filter '*.json' | ForEach-Object {
            $pd = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json -AsHashtable -Depth 10

            if ($pd['bepInExVersion']) {
                $referenced["BepInEx/$($pd['bepInExVersion'])"] = $true
            }
            if ($pd['mods']) {
                foreach ($mn in $pd['mods'].Keys) {
                    $referenced["$mn/$($pd['mods'][$mn]['version'])"] = $true
                }
            }
            foreach ($snap in @(if ($pd['snapshots']) { $pd['snapshots'] } else { @() })) {
                if ($snap['bepInExVersion']) {
                    $referenced["BepInEx/$($snap['bepInExVersion'])"] = $true
                }
                if ($snap['mods']) {
                    foreach ($mn in $snap['mods'].Keys) {
                        $referenced["$mn/$($snap['mods'][$mn]['version'])"] = $true
                    }
                }
            }
        }
    }

    # Find unreferenced store entries
    $toRemove = @()
    Get-ChildItem -LiteralPath $storeDir -Directory | ForEach-Object {
        $modName = $_.Name
        Get-ChildItem -LiteralPath $_.FullName -Directory | ForEach-Object {
            $key = "$modName/$($_.Name)"
            if (-not $referenced.ContainsKey($key)) {
                $toRemove += @{ name = $modName; version = $_.Name; path = $_.FullName }
            }
        }
    }

    if ($toRemove.Count -eq 0) {
        Write-SpectreHost '[green]✓ Store is clean — no unreferenced entries.[/]'
        return
    }

    Write-SpectreHost '[cyan]Unreferenced store entries:[/]'
    foreach ($e in $toRemove) { Write-SpectreHost "  $($e.name) $($e.version)" }
    Write-SpectreHost ''

    if (-not $Yes -and
        -not $PSCmdlet.ShouldProcess("$($toRemove.Count) store entries", 'Remove')) {
        $confirm = Read-SpectreConfirm -Message "Remove $($toRemove.Count) unreferenced entries?" `
                       -DefaultAnswer 'n'
        if (-not $confirm) { Write-SpectreHost '[grey]Prune cancelled.[/]'; return }
    }

    foreach ($e in $toRemove) {
        Remove-Item -LiteralPath $e.path -Recurse -Force
        Write-SpectreHost "[grey]Removed: $($e.name) $($e.version)[/]"
    }
    Write-SpectreHost "[green]✓ Pruned $($toRemove.Count) store entries.[/]"
}
