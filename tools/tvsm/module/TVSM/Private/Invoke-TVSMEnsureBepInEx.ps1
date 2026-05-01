function Invoke-TVSMEnsureBepInEx {
<#
.SYNOPSIS
Copies the BepInEx doorstop loader files (winhttp.dll, doorstop_config.ini) and
core assemblies from the mod store into the game directory.
Called as part of every mod apply cycle.

.PARAMETER ModWorkDir
Mod working directory.

.PARAMETER GameDir
Game installation directory.

.PARAMETER BepInExVersion
Version string of BepInEx to apply (must be in the store).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModWorkDir,
        [Parameter(Mandatory)][string]$GameDir,
        [Parameter(Mandatory)][string]$BepInExVersion
    )

    $storePath = Join-Path $ModWorkDir 'store' 'BepInEx' $BepInExVersion
    if (-not (Test-Path -LiteralPath $storePath)) {
        throw "BepInEx $BepInExVersion is not in the store. Run 'tvsm mod install BepInEx' first."
    }

    # Ensure game directory exists
    if (-not (Test-Path -LiteralPath $GameDir)) {
        throw "Game directory does not exist: $GameDir"
    }

    # Copy doorstop loader files to game root
    foreach ($loaderFile in @('winhttp.dll', 'doorstop_config.ini')) {
        $src  = Join-Path $storePath $loaderFile
        $dest = Join-Path $GameDir $loaderFile
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination $dest -Force
        }
    }

    # Copy BepInEx/core/ if present and not already the same version
    $coreSrc  = Join-Path $storePath 'BepInEx' 'core'
    $coreDest = Join-Path $GameDir 'BepInEx' 'core'
    if (Test-Path -LiteralPath $coreSrc) {
        $bepInExGameDir = Join-Path $GameDir 'BepInEx'
        if (-not (Test-Path -LiteralPath $bepInExGameDir)) {
            New-Item -ItemType Directory -Path $bepInExGameDir -Force | Out-Null
        }
        if (Test-Path -LiteralPath $coreDest) {
            Remove-Item -LiteralPath $coreDest -Recurse -Force
        }
        Copy-Item -LiteralPath $coreSrc -Destination $coreDest -Recurse -Force
    }
}
