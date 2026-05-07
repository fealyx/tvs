function Import-TVSCharacterPreset {
<#
.SYNOPSIS
Imports a .znelchar file back into the game's preset slot and SkinPresetTextures.

.DESCRIPTION
Decomposes a .znelchar file into its _characterData and _textureDatas
components using Expand-ZnelcharPreset (Znelchar.Tools), writing:
  - _characterData → presetSlot{n}.txt.tmp in the player data directory
  - _textureDatas  → {playerDataDir}/SkinPresetTextures/ as discrete image files

Requires -Force as a safety guard against overwriting live save data.

.PARAMETER Name
Character name (matches the .znelchar filename without extension).

.PARAMETER Slot
Zero-based slot index to write to. If omitted, looks up the slot
by character name in SaveFile.es3.

.PARAMETER SourcePath
Direct path to the .znelchar file. Overrides -Name lookup.

.PARAMETER Force
Required safety switch. Must be explicitly provided to confirm
the intent to write into the live player data directory.
#>
  [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess = $true)]
  param(
    [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
    [string]$Name,

    [Parameter(ParameterSetName = 'ByPath', Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(ParameterSetName = 'ByName')]
    [Parameter(ParameterSetName = 'ByPath')]
    [int]$Slot = -1,

    [Parameter(Mandatory = $true)]
    [switch]$Force
  )

  if ($script:TVSEnvironmentAvailable) {
    Write-Verbose "TVS.Environment detected, using defaults: playerDataDir=$script:DefaultPlayerDataDir, characterWorkDir=$script:DefaultCharacterWorkDir"
  }

  $playerDataDir = $script:DefaultPlayerDataDir
  $characterWorkDir = $script:DefaultCharacterWorkDir

  if (-not $Force) {
    throw '-Force is required to import a character preset into the live player data directory. Ensure the game is not running.'
  }

  if ($PSCmdlet.ParameterSetName -eq 'ByName') {
    if (-not $characterWorkDir) {
      throw "characterWorkDir not available. Either set TVS.Environment or provide -SourcePath explicitly."
    }
    $SourcePath = Join-Path $characterWorkDir 'presets' "${Name}.znelchar"
  }

  if (-not (Test-Path $SourcePath -PathType Leaf)) {
    throw ".znelchar file not found at: $SourcePath"
  }

  # Resolve slot index
  if ($Slot -lt 0) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)
    $info = Get-TVSSlotInfo -Name $baseName
    $Slot = $info.SlotIndex
  }

  if (-not $playerDataDir) {
    throw "playerDataDir not available. Either set TVS.Environment or provide -SourcePath with explicit paths."
  }

  $presetPath = Get-TVSPresetSlotPath -Slot $Slot -PlayerDataDir $playerDataDir
  $textureDir = Join-Path $playerDataDir 'SkinPresetTextures'

  if ($PSCmdlet.ShouldProcess($presetPath, "Decompose znelchar into preset slot $Slot and SkinPresetTextures")) {

    Assert-TVSModuleAvailable -ModuleName 'Znelchar.Tools'

    # Delegate to Expand-ZnelcharPreset which:
    # 1. Parses the znelchar envelope
    # 2. Writes _characterData to presetSlot{n}.txt.tmp
    # 3. Base64-decodes _textureDatas to SkinPresetTextures/
    $result = Znelchar.Tools\Expand-ZnelcharPreset `
        -InputPath $SourcePath `
        -PresetSlotPath $presetPath `
        -TextureDir $textureDir

    Write-Verbose "Imported '$SourcePath' to $presetPath and $textureDir"
    return $presetPath
  }
}
