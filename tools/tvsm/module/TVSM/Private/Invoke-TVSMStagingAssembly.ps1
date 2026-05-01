function Invoke-TVSMStagingAssembly {
<#
.SYNOPSIS
Rebuilds the staging directory for a profile by clearing it and re-populating it
from the mod store and dev links. Called exclusively by Invoke-TVSMModApply.

Store mods are copied into staging per their installLayout.
Dev links create directory junctions/symlinks inside staging (bypassing the copy
step so the live build output is used directly — no re-apply needed for rebuilds).

Layout → staging subdirectory mapping:
  plugins-dll  → staging/{profile}/plugins/{modName}/   (junction to src dir)
  plugins-dir  → staging/{profile}/plugins/{modName}/   (junction to src dir)
  patchers-dll → staging/{profile}/patchers/{modName}/  (junction to src dir)
  config-only  → staging/{profile}/config/{modName}/    (junction to src dir)
  gameroot-overlay → not staged; emits a warning (dev links only; not in scope yet)
  bepinex-root → not staged; handled by Invoke-TVSMEnsureBepInEx

.PARAMETER ModWorkDir
Mod working directory.

.PARAMETER GameDir
Game installation directory (used only for the gameroot-overlay warning message).

.PARAMETER ProfileData
Parsed profile hashtable (output of Read-TVSModProfile).

.PARAMETER ProfileName
Name of the profile (used as the staging subdirectory name).

.PARAMETER Force
If set, suppress gameVersionRange warnings (game version range check is still
performed but mismatches are not treated as errors).

.PARAMETER GameVersion
Detected game version string. Pass $null / empty to skip range checks.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModWorkDir,
        [Parameter(Mandatory)][string]$GameDir,
        [Parameter(Mandatory)][hashtable]$ProfileData,
        [Parameter(Mandatory)][string]$ProfileName,
        [switch]$Force,
        [string]$GameVersion = ''
    )

    $stagingBase = Join-Path $ModWorkDir 'staging' $ProfileName

    # ── Clear and recreate per-layout staging subdirectories ────────────────
    foreach ($subdir in @('plugins', 'patchers', 'config')) {
        $stagingSubdir = Join-Path $stagingBase $subdir
        if (Test-Path -LiteralPath $stagingSubdir) {
            $item = Get-Item -LiteralPath $stagingSubdir -Force
            if ($item.LinkType) {
                $item.Delete()  # Remove junction/symlink node without deleting contents
            } else {
                Remove-Item -LiteralPath $stagingSubdir -Recurse -Force
            }
        }
        New-Item -ItemType Directory -Path $stagingSubdir -Force | Out-Null
    }

    # ── Assemble store mods into staging ────────────────────────────────────
    $mods = $ProfileData['mods']
    if ($mods) {
        foreach ($modName in $mods.Keys) {
            $modEntry     = $mods[$modName]
            $enabled      = $modEntry['enabled'] -eq $true
            if (-not $enabled) { continue }

            $version       = $modEntry['version']
            $installLayout = $modEntry['installLayout'] ?? 'plugins-dll'

            # bepinex-root is handled by Invoke-TVSMEnsureBepInEx; skip here
            if ($installLayout -eq 'bepinex-root') { continue }

            # Optional game version range check (warn only at apply time)
            $rangeStr = $modEntry['gameVersionRange']
            if ($rangeStr -and -not [string]::IsNullOrEmpty($GameVersion)) {
                if (-not (Test-TVSGameVersionRange -GameVersion $GameVersion -Range $rangeStr)) {
                    if ($Force) {
                        Write-Verbose "[tvsm] $modName ${version}: game version $GameVersion outside range '$rangeStr' (--force, continuing)"
                    } else {
                        Write-Warning "[tvsm] $modName ${version}: game version $GameVersion is outside supported range '$rangeStr'. Use --force to suppress."
                    }
                }
            }

            $storePath = Join-Path $ModWorkDir 'store' $modName $version
            if (-not (Test-Path -LiteralPath $storePath)) {
                Write-Warning "[tvsm] Store entry missing for $modName@$version — skipping. Re-run 'tvsm mod install $modName' to restore."
                continue
            }

            switch ($installLayout) {
                'plugins-dll' {
                    $dll = Get-ChildItem -LiteralPath $storePath -Filter "$modName.dll" -Recurse -File |
                           Select-Object -First 1
                    if (-not $dll) {
                        Write-Warning "[tvsm] Could not find $modName.dll in store entry: $storePath"
                        continue
                    }
                    Copy-Item -LiteralPath $dll.FullName `
                        -Destination (Join-Path $stagingBase 'plugins' "$modName.dll") -Force
                }
                'plugins-dir' {
                    $dest = Join-Path $stagingBase 'plugins' $modName
                    Copy-Item -LiteralPath $storePath -Destination $dest -Recurse -Force
                }
                'patchers-dll' {
                    $dll = Get-ChildItem -LiteralPath $storePath -Filter "$modName.dll" -Recurse -File |
                           Select-Object -First 1
                    if (-not $dll) {
                        Write-Warning "[tvsm] Could not find $modName.dll in store entry: $storePath"
                        continue
                    }
                    Copy-Item -LiteralPath $dll.FullName `
                        -Destination (Join-Path $stagingBase 'patchers' "$modName.dll") -Force
                }
                'config-only' {
                    $dest = Join-Path $stagingBase 'config' $modName
                    Copy-Item -LiteralPath $storePath -Destination $dest -Recurse -Force
                }
                'gameroot-overlay' {
                    # Store mods with gameroot-overlay are copied directly to gameDir during apply
                    # (handled in Invoke-TVSMModApply after staging assembly)
                }
                default {
                    Write-Warning "[tvsm] Unknown installLayout '$installLayout' for $modName — skipping."
                }
            }
        }
    }

    # ── Overlay dev links as junctions/symlinks inside staging ──────────────
    # Dev links bypass the store download step: a junction in staging points
    # at the live build output so the game loads the freshest DLL on next launch.
    $devLinks = Read-TVSDevLinks -ModWorkDir $ModWorkDir
    $links    = $devLinks['links']
    if ($links) {
        foreach ($linkName in $links.Keys) {
            $link   = $links[$linkName]
            $src    = $link['src']
            $layout = $link['installLayout'] ?? 'plugins-dll'

            if (-not (Test-Path -LiteralPath $src)) {
                Write-Warning "[tvsm] Dev link '$linkName': source path not found at '$src' — skipping."
                continue
            }

            switch ($layout) {
                'plugins-dll' {
                    New-TVSJunctionOrSymlink -Path (Join-Path $stagingBase 'plugins' $linkName) -Target $src
                }
                'plugins-dir' {
                    New-TVSJunctionOrSymlink -Path (Join-Path $stagingBase 'plugins' $linkName) -Target $src
                }
                'patchers-dll' {
                    New-TVSJunctionOrSymlink -Path (Join-Path $stagingBase 'patchers' $linkName) -Target $src
                }
                'config-only' {
                    New-TVSJunctionOrSymlink -Path (Join-Path $stagingBase 'config' $linkName) -Target $src
                }
                'gameroot-overlay' {
                    Write-Warning "[tvsm] Dev link '$linkName': gameroot-overlay is not yet supported for dev links. Place files in '$GameDir' manually."
                }
                'bepinex-root' {
                    Write-Warning "[tvsm] Dev link '$linkName': bepinex-root layout is only valid for registry mods, not dev links."
                }
                default {
                    Write-Warning "[tvsm] Dev link '$linkName': unknown installLayout '$layout' — skipping."
                }
            }
        }
    }
}
