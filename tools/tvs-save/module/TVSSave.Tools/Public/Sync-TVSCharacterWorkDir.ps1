function Sync-TVSCharacterWorkDir {
<#
.SYNOPSIS
Syncs game save state into the character work directory using direct file
copies — no base64 encoding/decoding round-trips.

.DESCRIPTION
Reads a presetSlot{n}.txt.tmp file from the player data directory and
copies its associated skin textures from SkinPresetTextures into the
characterWorkDir layout:

  {characterWorkDir}/
    presets/
      presetSlot{n}/
        characterData.json     ← pretty-printed _characterData
        textures/
          RitaTorso_D.jpg      ← copied from SkinPresetTextures
          ...
    exports/

This function is designed for the live save-watch hot path. Unlike
Compose-ZnelcharPreset / Expand-ZnelcharPreset (which use base64
encoding for portable znelchar exchange), this function copies textures
as raw files without any encoding overhead.

.PARAMETER PresetSlotPath
Path to the presetSlot{n}.txt.tmp file in the player data directory.

.PARAMETER TextureDir
Path to the SkinPresetTextures directory (source of texture image files).

.PARAMETER WorkDir
Root of the characterWorkDir. The presets/presetSlot{n}/ and exports/
subdirectories are created automatically.

.OUTPUTS
Hashtable with keys PresetDir, CharacterData, TexturesDir, ExportsDir,
and CopiedTextures (array of filenames).

.EXAMPLE
Sync-TVSCharacterWorkDir -PresetSlotPath "$env:playerDataDir/presetSlot0.txt.tmp" `
    -TextureDir "$env:playerDataDir/SkinPresetTextures" `
    -WorkDir "$env:characterWorkDir"
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PresetSlotPath,

        [Parameter(Mandatory = $true)]
        [string]$TextureDir,

        [Parameter(Mandatory = $true)]
        [string]$WorkDir
    )

    # Ensure TVSSave.Tools is available for ConvertFrom-TVSPresetSlot
    if (-not (Get-Module -Name 'TVSSave.Tools')) {
        if (-not (Get-Module -ListAvailable -Name 'TVSSave.Tools')) {
            throw "TVSSave.Tools module is not available. Install it from the TVS Tools bundle."
        }
        Import-Module 'TVSSave.Tools' -Global -Force
    }

    # Step 1: Validate inputs
    if (-not (Test-Path $PresetSlotPath -PathType Leaf)) {
        throw "presetSlot file not found at: $PresetSlotPath"
    }

    # Extract slot number from filename (defense in depth)
    $fileName = Split-Path $PresetSlotPath -Leaf
    if ($fileName -notmatch '^presetSlot(\d+)\.txt\.tmp$') {
        throw "PresetSlotPath filename does not match expected pattern 'presetSlot{n}.txt.tmp': $fileName"
    }
    $slotNumber = [int]$Matches[1]

    Write-Verbose "Syncing presetSlot${slotNumber} from '$PresetSlotPath'"

    # Step 2: Create the characterWorkDir layout
    $presetDir = Join-Path $WorkDir 'presets' "presetSlot${slotNumber}"
    $texturesDir = Join-Path $presetDir 'textures'
    $exportsDir = Join-Path $WorkDir 'exports'

    foreach ($dir in @($presetDir, $texturesDir, $exportsDir)) {
        if (-not (Test-Path $dir -PathType Container)) {
            if ($PSCmdlet.ShouldProcess($dir, "Create directory")) {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-Verbose "Created directory: $dir"
            }
        }
    }

    # Step 3: Read presetSlot and convert to pretty-printed characterData.json.
    # ConvertFrom-TVSPresetSlot strips the ES3 wrapper and returns clean
    # character data JSON — this is the _characterData payload.
    $characterDataJson = ConvertFrom-TVSPresetSlot -Path $PresetSlotPath

    if ([string]::IsNullOrEmpty($characterDataJson)) {
        throw "presetSlot file at '$PresetSlotPath' produced empty character data."
    }

    $charDataPath = Join-Path $presetDir 'characterData.json'

    try {
        $parsed = $characterDataJson | ConvertFrom-Json -Depth 100
        $prettyJson = $parsed | ConvertTo-Json -Depth 100
        if ($PSCmdlet.ShouldProcess($charDataPath, "Write characterData.json")) {
            Set-Content -Path $charDataPath -Value $prettyJson -Encoding UTF8
            Write-Verbose "Wrote characterData.json ($($prettyJson.Length) chars): $charDataPath"
        }
    }
    catch {
        throw "Failed to parse character data from presetSlot for pretty-printing: $_"
    }

    # Step 4: Parse character data to discover custom texture references and
    # copy them directly (no base64 round-trip).
    try {
        $charData = $characterDataJson | ConvertFrom-Json -AsHashtable -Depth 100
    }
    catch {
        throw "Failed to parse character data JSON: $_"
    }

    $skinMaterials = @()
    if ($charData.ContainsKey('skinData') -and $charData['skinData'] -is [hashtable]) {
        $skinData = $charData['skinData']
        if ($skinData.ContainsKey('skinMaterials') -and $skinData['skinMaterials'] -is [array]) {
            $skinMaterials = $skinData['skinMaterials']
        }
    }

    $copiedTextures = [System.Collections.Generic.List[string]]::new()

    foreach ($material in $skinMaterials) {
        if ($material -isnot [hashtable]) { continue }
        if (-not $material.ContainsKey('diffuse')) { continue }

        $diffuse = $material['diffuse']
        if ([string]::IsNullOrEmpty($diffuse)) { continue }

        # Only handle custom textures (those with a file extension).
        # Built-in asset names like "Automata-Arms_1004" are not stored
        # as discrete files and are not copied.
        if ($diffuse -notmatch '\.(jpg|jpeg|png|bmp|tga|dds|gif|webp)$') {
            continue
        }

        $sourcePath = Join-Path $TextureDir $diffuse
        $destPath = Join-Path $texturesDir $diffuse

        if (-not (Test-Path $sourcePath -PathType Leaf)) {
            Write-Warning "Custom texture referenced in character data not found in '$TextureDir': $diffuse. Skipping copy — the texture/ subdirectory will be missing this file."
            continue
        }

        if ($PSCmdlet.ShouldProcess($destPath, "Copy texture '$diffuse'")) {
            try {
                Copy-Item -Path $sourcePath -Destination $destPath -Force
                $copiedTextures.Add($diffuse)
                Write-Verbose "Copied texture: $diffuse"
            }
            catch {
                Write-Warning "Failed to copy texture '$diffuse': $_"
            }
        }
    }

    Write-Verbose "Sync complete: presetSlot${slotNumber} → $presetDir ($($copiedTextures.Count) texture(s) copied)"

    return @{
        PresetDir      = $presetDir
        CharacterData  = $charDataPath
        TexturesDir    = $texturesDir
        ExportsDir     = $exportsDir
        CopiedTextures = $copiedTextures.ToArray()
    }
}
