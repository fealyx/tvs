function Expand-ZnelcharPreset {
<#
.SYNOPSIS
Decomposes a .znelchar file into game-ready format: a presetSlot{n}.tmp.txt
file and decoded skin texture image files.

.DESCRIPTION
Parses a .znelchar JSON envelope and extracts:

  1. _characterData — written to a presetSlot{n}.txt.tmp file (wrapped in
     the ES3 {…} format via ConvertTo-TVSPresetSlot).
  2. _textureDatas[*] — each entry's _textureData is base64-decoded and
     written as a discrete image file to the SkinPresetTextures directory.

After extraction, validates that every custom texture referenced in
_characterData.skinData.skinMaterials[*].diffuse is present in the
texture directory (warn-only).

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

    # Ensure TVSSave.Tools is available for ConvertTo-TVSPresetSlot
    if (-not (Get-Module -Name 'TVSSave.Tools')) {
        if (-not (Get-Module -ListAvailable -Name 'TVSSave.Tools')) {
            throw "TVSSave.Tools module is not available. Install it from the TVS Tools bundle."
        }
        Import-Module 'TVSSave.Tools' -Global -Force
    }

    # Validate input file exists
    if (-not (Test-Path $InputPath -PathType Leaf)) {
        throw ".znelchar file not found at: $InputPath"
    }

    # Step 1: Parse the .znelchar JSON envelope
    try {
        $znelcharJson = Get-Content -Path $InputPath -Raw -Encoding UTF8
        $envelope = $znelcharJson | ConvertFrom-Json -AsHashtable -Depth 100
    }
    catch {
        throw "Failed to parse znelchar file at '$InputPath' as JSON: $_"
    }

    if ($envelope -isnot [hashtable]) {
        throw "znelchar file at '$InputPath' does not contain a JSON object."
    }

    if (-not $envelope.ContainsKey('_characterData')) {
        throw "Input file '$InputPath' does not contain '_characterData'. Not a valid znelchar file."
    }

    $characterDataJson = $envelope['_characterData']

    if ([string]::IsNullOrEmpty($characterDataJson)) {
        throw "Input file '$InputPath' has an empty '_characterData' field."
    }

    Write-Verbose "Parsed znelchar envelope (_characterData: $($characterDataJson.Length) chars)"

    # Step 2: Write _characterData to the presetSlot file.
    # ConvertTo-TVSPresetSlot wraps the character JSON in the ES3 {…} format
    # that the game expects for presetSlot{n}.txt.tmp files.
    try {
        ConvertTo-TVSPresetSlot -ZnelcharJson $characterDataJson -OutputPath $PresetSlotPath
        Write-Verbose "Wrote presetSlot file: $PresetSlotPath"
    }
    catch {
        throw "Failed to write presetSlot file to '$PresetSlotPath': $_"
    }

    # Step 3: Ensure texture output directory exists
    if (-not (Test-Path $TextureDir -PathType Container)) {
        New-Item -Path $TextureDir -ItemType Directory -Force | Out-Null
        Write-Verbose "Created texture directory: $TextureDir"
    }

    # Step 4: Decode and write texture files
    $textureDatas = if ($envelope.ContainsKey('_textureDatas') -and $envelope['_textureDatas'] -is [array]) {
        $envelope['_textureDatas']
    }
    else {
        @()
    }

    $writtenCount = 0
    $skippedCount = 0

    foreach ($tex in $textureDatas) {
        if ($tex -isnot [hashtable]) {
            Write-Warning "Skipping invalid _textureDatas entry (not an object)."
            continue
        }

        $texName = $tex['_textureName']
        $texData = $tex['_textureData']

        if ([string]::IsNullOrEmpty($texName)) {
            Write-Warning "Skipping texture entry with empty _textureName."
            continue
        }

        if ([string]::IsNullOrEmpty($texData)) {
            Write-Warning "Skipping texture '$texName' with empty _textureData."
            continue
        }

        $outputFile = Join-Path $TextureDir $texName

        # Honour NoClobber: skip if file exists
        if ($NoClobber -and (Test-Path $outputFile -PathType Leaf)) {
            Write-Verbose "NoClobber: skipping existing texture '$texName'"
            $skippedCount++
            continue
        }

        if ($PSCmdlet.ShouldProcess($outputFile, "Write decoded texture '$texName'")) {
            try {
                $bytes = [System.Convert]::FromBase64String($texData)
                [System.IO.File]::WriteAllBytes($outputFile, $bytes)
                Write-Verbose "Wrote texture: $outputFile ($($bytes.Length) bytes)"
                $writtenCount++
            }
            catch {
                Write-Warning "Failed to decode/write texture '$texName': $_"
            }
        }
    }

    # Step 5: Validation — confirm every custom diffuse filename in
    # _characterData is present in SkinPresetTextures after extraction.
    try {
        $charData = $characterDataJson | ConvertFrom-Json -AsHashtable -Depth 100
        $skinMaterials = @()

        if ($charData.ContainsKey('skinData') -and $charData['skinData'] -is [hashtable]) {
            $skinData = $charData['skinData']
            if ($skinData.ContainsKey('skinMaterials') -and $skinData['skinMaterials'] -is [array]) {
                $skinMaterials = $skinData['skinMaterials']
            }
        }

        foreach ($material in $skinMaterials) {
            if ($material -isnot [hashtable]) { continue }
            if (-not $material.ContainsKey('diffuse')) { continue }

            $diffuse = $material['diffuse']
            if ([string]::IsNullOrEmpty($diffuse)) { continue }

            # Only validate custom textures (those with file extensions)
            if ($diffuse -notmatch '\.(jpg|jpeg|png|bmp|tga|dds|gif|webp)$') {
                continue
            }

            $expectedPath = Join-Path $TextureDir $diffuse
            if (-not (Test-Path $expectedPath -PathType Leaf)) {
                Write-Warning "Texture referenced in character data not found after extraction: '$diffuse'. The game may display a missing texture for this slot."
            }
        }
    }
    catch {
        Write-Warning "Could not validate texture references against character data: $_"
    }

    if ($skippedCount -gt 0) {
        Write-Verbose "Skipped $skippedCount existing texture(s) (NoClobber)."
    }

    return @{
        PresetSlotPath = $PresetSlotPath
        TextureDir     = $TextureDir
        TextureCount   = $writtenCount
        SkippedCount   = $skippedCount
    }
}
