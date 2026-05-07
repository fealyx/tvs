function Export-TVSCharacterPreset {
<#
.SYNOPSIS
Exports one preset slot to a valid .znelchar file.

.DESCRIPTION
Composes a full .znelchar file from a presetSlot{n}.txt.tmp file
and its referenced skin textures in SkinPresetTextures/, producing
the proper {"_characterData": "...", "_textureDatas": [...]} envelope.

.PARAMETER Slot
Zero-based slot index to export. If omitted, uses the slot index
from a SaveFile.es3 lookup by -Name.

.PARAMETER Name
Character name to look up in SaveFile.es3. If both -Slot and -Name
are provided, -Slot takes precedence.

.PARAMETER OutputPath
Directory for .znelchar output. Defaults to
{characterWorkDir}/presets/ from TVS.Environment if available.

.PARAMETER PresetSlotPath
Direct path to a presetSlot{n}.txt.tmp file. Overrides -Slot/-Name
lookup.
#>
  [CmdletBinding(DefaultParameterSetName = 'ByName')]
  param(
    [Parameter(ParameterSetName = 'BySlot', Mandatory = $true)]
    [int]$Slot,

    [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
    [string]$Name,

    [string]$OutputPath = '',

    [Parameter(ParameterSetName = 'ByPath', Mandatory = $true)]
    [string]$PresetSlotPath
  )

  if ($script:TVSEnvironmentAvailable) {
    Write-Verbose "TVS.Environment detected, using defaults: playerDataDir=$script:DefaultPlayerDataDir, characterWorkDir=$script:DefaultCharacterWorkDir"
  }

  $playerDataDir = $script:DefaultPlayerDataDir

  if (-not $OutputPath -and $script:DefaultCharacterWorkDir) {
    $OutputPath = Join-Path $script:DefaultCharacterWorkDir 'presets'
  }

  # Resolve slot index and character name
  if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
    # Extract slot number from filename: presetSlot{n}.txt.tmp
    $fileName = Split-Path $PresetSlotPath -Leaf
    if ($fileName -match 'presetSlot(\d+)\.txt\.tmp') {
      $Slot = [int]$Matches[1]
    }
    else {
      throw "PresetSlotPath filename does not match expected pattern 'presetSlot{n}.txt.tmp': $fileName"
    }
    # Read the preset to get the name
    $znelcharJson = ConvertFrom-TVSPresetSlot -Path $PresetSlotPath
    try {
      $data = $znelcharJson | ConvertFrom-Json -Depth 10
      $Name = if ($data.characterName) { $data.characterName } else { "Slot$Slot" }
    }
    catch {
      $Name = "Slot$Slot"
    }
  }
  elseif ($PSCmdlet.ParameterSetName -eq 'ByName') {
    $info = Get-TVSSlotInfo -Name $Name
    $Slot = $info.SlotIndex
  }
  # else BySlot: $Slot is already set; look up the name
  if ($PSCmdlet.ParameterSetName -eq 'BySlot') {
    $info = Get-TVSSlotInfo -Slot $Slot -DefaultName "Slot$Slot"
    $Name = $info.Name
  }

  # Build preset slot path if not directly provided
  if (-not $PresetSlotPath) {
    $PresetSlotPath = Get-TVSPresetSlotPath -Slot $Slot -PlayerDataDir $playerDataDir
  }

  if (-not (Test-Path $PresetSlotPath -PathType Leaf)) {
    throw "presetSlot file not found at: $PresetSlotPath"
  }

  # Sanitize name for filesystem use
  $safeName = Get-TVSSanitizedName -Name $Name -FallbackName "Slot$Slot"

  if (-not (Test-Path $OutputPath -PathType Container)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
  }

  $outputFile = Join-Path $OutputPath "${safeName}.znelchar"

  # Delegate to Compose-ZnelcharPreset (in Znelchar.Tools) which:
  # 1. Reads presetSlot and extracts _characterData
  # 2. Parses it to discover custom texture filenames
  # 3. Base64-encodes matching files from SkinPresetTextures/
  # 4. Writes the full {"_characterData": "...", "_textureDatas": [...]} envelope
  if (-not $playerDataDir) {
    throw "PlayerDataDir not available. Either set TVS.Environment or provide -PresetSlotPath directly."
  }

  $textureDir = Join-Path $playerDataDir 'SkinPresetTextures'

  Assert-TVSModuleAvailable -ModuleName 'Znelchar.Tools'

  $result = Znelchar.Tools\Compose-ZnelcharPreset `
      -PresetSlotPath $PresetSlotPath `
      -TextureDir $textureDir `
      -OutputPath $outputFile

  Write-Verbose "Exported slot $Slot ('$Name') to $outputFile"
  return $result
}
