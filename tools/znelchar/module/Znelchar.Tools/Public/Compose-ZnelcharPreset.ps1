function Compose-ZnelcharPreset {
<#
.SYNOPSIS
Re-composes a full .znelchar file from a presetSlot{n}.tmp.txt file and
its referenced skin textures.

.DESCRIPTION
Reads a presetSlot{n}.tmp.txt file (which contains the _characterData
JSON payload), parses it to discover custom texture filenames referenced
in skinData.skinMaterials[*].diffuse, collects matching texture files
from the SkinPresetTextures directory, base64-encodes them, and assembles
the full znelchar envelope:

  {
    "_characterData": "<escaped character JSON>",
    "_textureDatas": [
      { "_textureName": "RitaTorso_D.jpg", "_textureData": "<base64>" }
    ]
  }

Only diffuse values containing a file extension (.jpg, .png, etc.) are
treated as custom textures. Bare asset names (e.g. "Automata-Arms_1004")
reference built-in game textures and are not collected.

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

    # Ensure TVSSave.Tools is available for ConvertFrom-TVSPresetSlot
    if (-not (Get-Module -Name 'TVSSave.Tools')) {
        if (-not (Get-Module -ListAvailable -Name 'TVSSave.Tools')) {
            throw "TVSSave.Tools module is not available. Install it from the TVS Tools bundle."
        }
        Import-Module 'TVSSave.Tools' -Global -Force
    }

    # Validate presetSlot file exists
    if (-not (Test-Path $PresetSlotPath -PathType Leaf)) {
        throw "presetSlot file not found at: $PresetSlotPath"
    }

    # Validate texture directory exists
    if (-not (Test-Path $TextureDir -PathType Container)) {
        throw "Texture directory not found at: $TextureDir"
    }

    # Step 1: Read the presetSlot file and extract the character data JSON string.
    # ConvertFrom-TVSPresetSlot strips the ES3 wrapper ({...}) and JSON-unescapes
    # the inner payload, returning clean character data JSON.
    $characterDataJson = ConvertFrom-TVSPresetSlot -Path $PresetSlotPath

    if ([string]::IsNullOrEmpty($characterDataJson)) {
        throw "presetSlot file at '$PresetSlotPath' produced empty character data."
    }

    Write-Verbose "Read character data from presetSlot ($($characterDataJson.Length) chars)"

    # Step 2: Parse character data to discover custom texture filenames.
    # Custom textures are identified by diffuse values containing a file extension.
    try {
        $charData = $characterDataJson | ConvertFrom-Json -AsHashtable -Depth 100
    }
    catch {
        throw "Failed to parse character data JSON from presetSlot: $_"
    }

    $skinMaterials = @()
    if ($charData.ContainsKey('skinData') -and $charData['skinData'] -is [hashtable]) {
        $skinData = $charData['skinData']
        if ($skinData.ContainsKey('skinMaterials') -and $skinData['skinMaterials'] -is [array]) {
            $skinMaterials = $skinData['skinMaterials']
        }
    }

    if ($skinMaterials.Count -eq 0) {
        Write-Warning "No skinMaterials found in character data. The znelchar will have no texture entries."
    }

    # Step 3: Collect and base64-encode custom textures
    $textureDatas = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($material in $skinMaterials) {
        if ($material -isnot [hashtable]) { continue }
        if (-not $material.ContainsKey('diffuse')) { continue }

        $diffuse = $material['diffuse']
        if ([string]::IsNullOrEmpty($diffuse)) { continue }

        # Only collect filenames containing a file extension — these are custom
        # textures sourced from SkinPresetTextures. Bare names are built-in assets.
        if ($diffuse -notmatch '\.(jpg|jpeg|png|bmp|tga|dds|gif|webp)$') {
            Write-Verbose "Skipping built-in asset: $diffuse"
            continue
        }

        $texturePath = Join-Path $TextureDir $diffuse

        if (-not (Test-Path $texturePath -PathType Leaf)) {
            Write-Warning "Custom texture referenced in character data not found in '$TextureDir': $diffuse. Skipping — the resulting znelchar will be missing this texture."
            continue
        }

        try {
            $bytes = [System.IO.File]::ReadAllBytes($texturePath)
            $base64 = [System.Convert]::ToBase64String($bytes)

            $textureDatas.Add(@{
                _textureName = $diffuse
                _textureData = $base64
            })

            Write-Verbose "Encoded texture: $diffuse ($($bytes.Length) bytes → $($base64.Length) chars base64)"
        }
        catch {
            Write-Warning "Failed to read/encode texture '$diffuse': $_ — skipping."
        }
    }

    # Step 4: Build the znelchar envelope.
    # PowerShell's ConvertTo-Json will automatically JSON-escape the
    # _characterData string value so it becomes an escaped JSON string
    # in the serialized output, matching the znelchar schema.
    $envelope = [ordered]@{
        _characterData = $characterDataJson
        _textureDatas  = $textureDatas.ToArray()
    }

    # Step 5: Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir -PathType Container)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        Write-Verbose "Created output directory: $outputDir"
    }

    # Step 6: Serialize and write the .znelchar file
    try {
        $json = $envelope | ConvertTo-Json -Depth 100 -Compress
        Set-Content -Path $OutputPath -Value $json -Encoding UTF8 -NoNewline
    }
    catch {
        throw "Failed to serialize or write znelchar file: $_"
    }

    Write-Verbose "Composed znelchar with $($textureDatas.Count) texture(s): $OutputPath"
    return $OutputPath
}
