function Compose-ZnelcharPreset {
<#
.SYNOPSIS
Re-composes a full .znelchar file from a presetSlot{n}.tmp.txt file and
its referenced skin textures. Thin orchestrator wrapper over Znelchar.Tools.

.DESCRIPTION
Delegates to Compose-ZnelcharPreset from Znelchar.Tools. See the
Znelchar.Tools version for full parameter and behaviour documentation.

.PARAMETER PresetSlotPath
Path to the presetSlot{n}.txt.tmp file in the player data directory.

.PARAMETER TextureDir
Path to the SkinPresetTextures directory containing custom texture image files.

.PARAMETER OutputPath
Path for the output .znelchar file. Parent directories are created if needed.

.OUTPUTS
String path to the created .znelchar file.

.EXAMPLE
Compose-ZnelcharPreset -PresetSlotPath "$env:playerDataDir/presetSlot0.txt.tmp" `
    -TextureDir "$env:playerDataDir/SkinPresetTextures" `
    -OutputPath "$env:characterWorkDir/exports/MyCharacter.znelchar"
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PresetSlotPath,

        [Parameter(Mandatory = $true)]
        [string]$TextureDir,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    # Znelchar.Tools and TVSSave.Tools are RequiredModules of TVSM.
    # Lazy import kept as defense-in-depth.
    if (-not (Get-Module -Name 'Znelchar.Tools')) {
        if (-not (Get-Module -ListAvailable -Name 'Znelchar.Tools')) {
            throw "Znelchar.Tools module is not available. Install it from the TVS Tools bundle."
        }
        Import-Module 'Znelchar.Tools' -Global -Force
    }
    if (-not (Get-Module -Name 'TVSSave.Tools')) {
        if (-not (Get-Module -ListAvailable -Name 'TVSSave.Tools')) {
            throw "TVSSave.Tools module is not available. Install it from the TVS Tools bundle."
        }
        Import-Module 'TVSSave.Tools' -Global -Force
    }

    # Module-qualified call to avoid shadowing the local wrapper
    Znelchar.Tools\Compose-ZnelcharPreset @PSBoundParameters
}

function Expand-ZnelcharPreset {
<#
.SYNOPSIS
Decomposes a .znelchar file into game-ready format: a presetSlot{n}.tmp.txt
file and decoded skin texture image files. Thin orchestrator wrapper over
Znelchar.Tools.

.DESCRIPTION
Delegates to Expand-ZnelcharPreset from Znelchar.Tools. See the
Znelchar.Tools version for full parameter and behaviour documentation.

.PARAMETER InputPath
Path to the input .znelchar file.

.PARAMETER PresetSlotPath
Path where the presetSlot{n}.txt.tmp file should be written.

.PARAMETER TextureDir
Path to the SkinPresetTextures directory where decoded texture images
will be written. The directory is created if it does not exist.

.PARAMETER NoClobber
When present, skip writing texture files that already exist in the
target directory (default behaviour is to overwrite).

.OUTPUTS
Hashtable with keys PresetSlotPath, TextureDir, and TextureCount.

.EXAMPLE
Expand-ZnelcharPreset -InputPath './MyCharacter.znelchar' `
    -PresetSlotPath "$env:playerDataDir/presetSlot0.txt.tmp" `
    -TextureDir "$env:playerDataDir/SkinPresetTextures"
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath,

        [Parameter(Mandatory = $true)]
        [string]$PresetSlotPath,

        [Parameter(Mandatory = $true)]
        [string]$TextureDir,

        [switch]$NoClobber
    )

    # Znelchar.Tools and TVSSave.Tools are RequiredModules of TVSM.
    # Lazy import kept as defense-in-depth.
    if (-not (Get-Module -Name 'Znelchar.Tools')) {
        if (-not (Get-Module -ListAvailable -Name 'Znelchar.Tools')) {
            throw "Znelchar.Tools module is not available. Install it from the TVS Tools bundle."
        }
        Import-Module 'Znelchar.Tools' -Global -Force
    }
    if (-not (Get-Module -Name 'TVSSave.Tools')) {
        if (-not (Get-Module -ListAvailable -Name 'TVSSave.Tools')) {
            throw "TVSSave.Tools module is not available. Install it from the TVS Tools bundle."
        }
        Import-Module 'TVSSave.Tools' -Global -Force
    }

    # Module-qualified call to avoid shadowing the local wrapper
    Znelchar.Tools\Expand-ZnelcharPreset @PSBoundParameters
}
