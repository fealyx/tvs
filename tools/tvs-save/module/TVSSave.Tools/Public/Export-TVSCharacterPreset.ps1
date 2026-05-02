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
{characterWorkDir}/presets/ from TVS.Environment.

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

    $env = Get-TVSEnvironment

    if (-not $OutputPath) {
        $OutputPath = Join-Path $env.characterWorkDir 'presets'
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
        $slots = Get-TVSSaveCharacterList
        $match = $slots | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
        if (-not $match) {
            throw "Character '$Name' not found in any occupied save slot."
        }
        $Slot = $match.SlotIndex
    }
    # else BySlot: $Slot is already set; look up the name
    if ($PSCmdlet.ParameterSetName -eq 'BySlot' -or $PSCmdlet.ParameterSetName -eq 'ByPath') {
        if (-not $Name) {
            $slots = Get-TVSSaveCharacterList
            $match = $slots | Where-Object { $_.SlotIndex -eq $Slot } | Select-Object -First 1
            $Name = if ($match) { $match.Name } else { "Slot$Slot" }
        }
    }

    # Build preset slot path if not directly provided
    if (-not $PresetSlotPath) {
        $PresetSlotPath = Join-Path $env.playerDataDir "presetSlot${Slot}.txt.tmp"
    }

    if (-not (Test-Path $PresetSlotPath -PathType Leaf)) {
        throw "presetSlot file not found at: $PresetSlotPath"
    }

    # Sanitize name for filesystem use: strip zero-width and invisible Unicode
    # characters that can leak from game serialization (defense in depth —
    # Read-TVSSaveIndex also strips these at ingestion).
    $safeName = $Name -replace '[\u200B-\u200D\uFEFF\u00A0]', ''
    $safeName = $safeName.Trim()
    if ([string]::IsNullOrEmpty($safeName)) {
        $safeName = "Slot$Slot"
    }

    if (-not (Test-Path $OutputPath -PathType Container)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $outputFile = Join-Path $OutputPath "${safeName}.znelchar"

    # Delegate to Compose-ZnelcharPreset (in Znelchar.Tools) which:
    # 1. Reads presetSlot and extracts _characterData
    # 2. Parses it to discover custom texture filenames
    # 3. Base64-encodes matching files from SkinPresetTextures/
    # 4. Writes the full {"_characterData": "...", "_textureDatas": [...]} envelope
    $textureDir = Join-Path $env.playerDataDir 'SkinPresetTextures'

    # Ensure Znelchar.Tools is available
    if (-not (Get-Module -Name 'Znelchar.Tools')) {
        if (-not (Get-Module -ListAvailable -Name 'Znelchar.Tools')) {
            throw "Znelchar.Tools module is not available. Install it from the TVS Tools bundle."
        }
        Import-Module 'Znelchar.Tools' -Global -Force
    }

    $result = Znelchar.Tools\Compose-ZnelcharPreset `
        -PresetSlotPath $PresetSlotPath `
        -TextureDir $textureDir `
        -OutputPath $outputFile

    Write-Verbose "Exported slot $Slot ('$Name') to $outputFile"
    return $result
}
