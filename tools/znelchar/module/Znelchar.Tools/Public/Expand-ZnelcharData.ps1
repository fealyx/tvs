<#
.SYNOPSIS
Expands a .znelchar file or a character.json file into a structured folder hierarchy for collaborative Git development.

.DESCRIPTION
Decomposes character data into atomic YAML/JSON files organized in folders. This enables:
- Better Git diffs (changes are granular)
- Parallel editing of different character sections
- Easier merge conflict resolution (different people edit different files)

Accepts either:
- A .znelchar file directly (direct pipeline — no intermediary extraction step needed)
- A character.json file produced by Export-ZnelcharContent (explicit pipeline)

The expanded structure includes:
- _metadata.yaml: Schema version, source info, and texture name map (when input is .znelchar)
- base.yaml: Top-level metadata
- blendshapes.yaml: Blendshape definitions
- skeleton/: Bone and offset data
- skin/: Material definitions (diffuse, specular, normals)
- accessories/: Individual accessory definitions
- vertex-accessories/: Vertex-based accessories
- occlusion-data.yaml: Occlusion mappings
- behavior/: Opinions and traits
- ui/: UI color data
- customIcon.<ext>: Custom icon image (decoded from character data, if present)
- textures/: Texture files (from .znelchar payload or adjacent textures/ folder)

.PARAMETER InputPath
Path to a .znelchar file (direct pipeline) or character.json (explicit pipeline).

.PARAMETER OutputPath
Target folder for the expanded structure. Created if it doesn't exist.

.PARAMETER Format
Output format: 'yaml' (default, recommended) or 'json'.

.PARAMETER TexturesPath
Path to the textures folder to absorb into the expanded structure. Only relevant when
InputPath is a character.json. When InputPath is a .znelchar, textures are extracted
from the file payload directly; this parameter is ignored.

.PARAMETER Force
Overwrite existing expanded structure if present.

.EXAMPLE
# Direct pipeline: expand a .znelchar file directly
Expand-ZnelcharData -InputPath character.znelchar -OutputPath character-expanded

# Explicit pipeline: expand from a previously extracted character.json
Expand-ZnelcharData -InputPath extracted/character.json -OutputPath character-expanded -Format yaml

.NOTES
Direct pipeline (.znelchar input):
  The expanded directory is fully self-contained. Compress-ZnelcharData can reproduce a
  .znelchar from the expanded directory alone — no manifest.json needed.

Explicit pipeline (character.json input):
  Use Export-ZnelcharContent first to produce extracted/character.json, then call
  Compress-ZnelcharData → New-ZnelcharFile for the roundtrip.

See also: Compress-ZnelcharData, Export-ZnelcharContent, New-ZnelcharFile
#>

function Expand-ZnelcharData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (-not (Test-Path -LiteralPath $_)) {
                throw "Input file not found: $_"
            }
            $ext = [System.IO.Path]::GetExtension($_).ToLower()
            if ($ext -notin @('.json', '.znelchar')) {
                throw "Input file must be a .znelchar file or a .json file (character.json)"
            }
            $true
        })]
        [string]$InputPath,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [ValidateSet('yaml', 'json')]
        [string]$Format = 'yaml',

        [string]$TexturesPath,

        [switch]$Force
    )

    process {
        $resolvedInputPath = (Resolve-Path -LiteralPath $InputPath).ProviderPath
        $inputExt = [System.IO.Path]::GetExtension($resolvedInputPath).ToLower()
        $isZnelchar = ($inputExt -eq '.znelchar')

        # Resolve OutputPath: optional — fall back to TVS.Environment characterWorkDir if not supplied
        if (-not $OutputPath) {
            try {
                $workDir = Get-TVSEnvironment -Key characterWorkDir
                if ($workDir) {
                    if ($isZnelchar) {
                        $inputBaseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedInputPath)
                    } else {
                        $inputBaseName = [System.IO.Path]::GetFileNameWithoutExtension(
                            (Split-Path -Leaf (Split-Path -Parent $resolvedInputPath))
                        ) -replace '\.extracted$', ''
                    }
                    $OutputPath = Join-Path $workDir ($inputBaseName + '.expanded')
                }
            } catch { }
        }
        if (-not $OutputPath) {
            throw "Parameter -OutputPath is required. Provide it explicitly or configure 'characterWorkDir' via Initialize-TVSEnvironment."
        }

        # Check if output exists
        if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
            throw "Output path already exists: $OutputPath. Use -Force to overwrite."
        }

        # --- Input resolution: .znelchar vs character.json ---
        $characterData = $null
        $textureMap = @()   # array of [ordered]@{ textureName; file } — populated from .znelchar only
        $inlineTextures = @{}  # filename -> byte[] — for writing textures/ when input is .znelchar

        if ($isZnelchar) {
            Write-Verbose "Direct pipeline: extracting character data from .znelchar: $resolvedInputPath"
            $outer = Read-JsonFile -Path $resolvedInputPath
            if (-not $outer.ContainsKey('_characterData')) {
                throw "Input .znelchar file does not contain required key: _characterData"
            }
            $characterData = ($outer['_characterData'] | ConvertFrom-Json -AsHashtable -Depth 100)
            $characterData = Expand-NestedCharacterData -Character $characterData -WarnOnFailure

            # Build texture map and cache texture bytes from _textureDatas
            if ($outer.ContainsKey('_textureDatas') -and $null -ne $outer['_textureDatas']) {
                foreach ($t in @($outer['_textureDatas'])) {
                    $textureName = if ($t.ContainsKey('_textureName')) { [string]$t['_textureName'] } else { '' }
                    $base64 = if ($t.ContainsKey('_textureData') -and $null -ne $t['_textureData']) { [string]$t['_textureData'] } else { '' }
                    $safeName = if ([string]::IsNullOrWhiteSpace([System.IO.Path]::GetFileName($textureName))) { 'unnamed.bin' } else { [System.IO.Path]::GetFileName($textureName) }

                    # Deduplicate filename
                    $candidate = $safeName
                    $counter = 1
                    while ($inlineTextures.ContainsKey($candidate)) {
                        $nameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($safeName)
                        $ext2 = [System.IO.Path]::GetExtension($safeName)
                        $candidate = '{0}_{1}{2}' -f $nameNoExt, $counter, $ext2
                        $counter++
                    }

                    if ($base64.Length -gt 0) {
                        $normalized = ($base64 -replace '\s', '')
                        $inlineTextures[$candidate] = [System.Convert]::FromBase64String($normalized)
                    } else {
                        $inlineTextures[$candidate] = [byte[]]@()
                    }

                    $textureMap += [ordered]@{ textureName = $textureName; file = $candidate }
                }
            }
        } else {
            # Explicit pipeline: character.json input
            Write-Verbose "Explicit pipeline: loading character data from: $resolvedInputPath"
            try {
                $characterData = Read-JsonFile -Path $resolvedInputPath
            } catch {
                throw "Failed to load JSON file: $_"
            }
        }

        # Create output directory
        if (Test-Path -LiteralPath $OutputPath) {
            Remove-Item -LiteralPath $OutputPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-Verbose "Created output directory: $OutputPath"

        # Calculate source hash
        $sourceHash = (Get-FileHash -Path $resolvedInputPath -Algorithm SHA256).Hash

        # Extract base fields early for metadata
        $baseFields = [ordered]@{
            version           = $characterData['version'] ?? ""
            isSynth           = $characterData['isSynth']
            voicePitch        = $characterData['voicePitch']
            reactionSetName   = $characterData['reactionSetName'] ?? ""
        }
        # Only include characterName if it exists and is non-empty in the source
        if ($characterData.ContainsKey('characterName') -and -not [string]::IsNullOrEmpty($characterData['characterName'])) {
            $baseFields['characterName'] = $characterData['characterName']
        }

        # Discover custom icon: decode to a file rather than keeping raw base64 in base.yaml
        $customIconFileName = $null
        $customIconBytes    = $null
        if ($characterData.ContainsKey('customIconData') -and -not [string]::IsNullOrWhiteSpace([string]$characterData['customIconData'])) {
            $normalizedBase64 = ([string]$characterData['customIconData'] -replace '\s', '')
            try {
                $customIconBytes    = [System.Convert]::FromBase64String($normalizedBase64)
                $customIconFormat   = Get-ImageFormatInfoFromBytes -Bytes $customIconBytes
                $customIconFileName = 'customIcon' + $customIconFormat.extension
            } catch {
                Write-Warning "Failed to decode customIconData: $_. Keeping in base.yaml."
                $baseFields['customIconData'] = $characterData['customIconData']
            }
        }

        # Resolve textures:
        #   - .znelchar input: write inline bytes from $inlineTextures
        #   - character.json input: copy from explicit -TexturesPath or auto-discovered sibling textures/
        $texturesOutDir = Join-Path $OutputPath 'textures'
        $writtenTextureCount = 0

        if ($isZnelchar) {
            # Write texture bytes extracted from the .znelchar payload
            if ($inlineTextures.Count -gt 0) {
                New-Item -ItemType Directory -Path $texturesOutDir -Force | Out-Null
                foreach ($entry in $inlineTextures.GetEnumerator()) {
                    if ($entry.Value.Length -gt 0) {
                        [System.IO.File]::WriteAllBytes((Join-Path $texturesOutDir $entry.Key), $entry.Value)
                    }
                }
                $writtenTextureCount = $inlineTextures.Count
                Write-Verbose "Wrote $writtenTextureCount texture(s) from .znelchar payload to textures/"
            }
        } else {
            # Explicit pipeline: discover textures from filesystem
            $effectiveTexturesPath = $null
            if ($PSBoundParameters.ContainsKey('TexturesPath')) {
                if (Test-Path -LiteralPath $TexturesPath -PathType Container) {
                    $effectiveTexturesPath = (Resolve-Path -LiteralPath $TexturesPath).ProviderPath
                } else {
                    Write-Warning "Specified -TexturesPath not found: $TexturesPath"
                }
            } else {
                $characterDir    = [System.IO.Path]::GetDirectoryName($resolvedInputPath)
                $siblingTextures = Join-Path $characterDir 'textures'
                if (Test-Path -LiteralPath $siblingTextures -PathType Container) {
                    $effectiveTexturesPath = $siblingTextures
                    Write-Verbose "Auto-discovered textures at: $effectiveTexturesPath"
                }
            }
            if ($effectiveTexturesPath) {
                $textureFiles = @(Get-ChildItem -LiteralPath $effectiveTexturesPath -File)
                if ($textureFiles.Count -gt 0) {
                    New-Item -ItemType Directory -Path $texturesOutDir -Force | Out-Null
                    foreach ($tf in $textureFiles) {
                        Copy-Item -LiteralPath $tf.FullName -Destination (Join-Path $texturesOutDir $tf.Name) -Force
                    }
                    $writtenTextureCount = $textureFiles.Count
                    Write-Verbose "Copied $writtenTextureCount texture(s) to textures/"
                }
            }
        }

        # Write metadata (schema v2)
        $metadata = [ordered]@{
            schemaVersion    = 2
            expandedAtUtc    = (Get-Date -AsUTC -Format 'o')
            dataFormat       = $Format
            sourceFile       = $resolvedInputPath
            sourceHashSha256 = $sourceHash
            characterName    = $baseFields['characterName'] ?? ""
            notes            = ""
            hasCustomIcon    = ($null -ne $customIconFileName)
            customIconFile   = $customIconFileName ?? ""
            textureCount     = $writtenTextureCount
        }
        # Embed texture map only when expanded from .znelchar (direct pipeline)
        if ($isZnelchar -and $textureMap.Count -gt 0) {
            $metadata['textures'] = $textureMap
        }

        Write-DataFile -InputObject $metadata `
            -OutputPath (Join-Path $OutputPath '_metadata.yaml') `
            -Format 'yaml' `
            -Force
        Write-Verbose "Wrote _metadata.yaml (schema v2)"

        # Write base fields to file (customIconData not included; icon is stored as a separate file)
        Write-DataFile -InputObject $baseFields `
            -OutputPath (Join-Path $OutputPath 'base.yaml') `
            -Format $Format `
            -Force
        Write-Verbose "Wrote base.yaml"

        # Write custom icon file if decoded successfully
        if ($null -ne $customIconBytes) {
            $customIconOutPath = Join-Path $OutputPath $customIconFileName
            [System.IO.File]::WriteAllBytes($customIconOutPath, $customIconBytes)
            Write-Verbose "Wrote $customIconFileName"
        }

        # Extract blendshapes as a key/value map for cleaner diffs
        $blendshapesSource = if ($characterData.ContainsKey('blendshapes')) { $characterData['blendshapes'] } else { @() }
        $blendshapesData = @{
            blendshapes = Convert-BlendshapeListToMap -Blendshapes $blendshapesSource
        }
        Write-DataFile -InputObject $blendshapesData `
            -OutputPath (Join-Path $OutputPath 'blendshapes.yaml') `
            -Format $Format `
            -Force
        Write-Verbose "Wrote blendshapes.yaml"

        # Extract skeleton data
        $skeletonDir = Join-Path $OutputPath 'skeleton'
        New-Item -ItemType Directory -Path $skeletonDir -Force | Out-Null
        
        $bonesData = @{
            boneData = @(if ($characterData.ContainsKey('boneData')) { $characterData['boneData'] })
        }
        Write-DataFile -InputObject $bonesData `
            -OutputPath (Join-Path $skeletonDir 'bones.yaml') `
            -Format $Format `
            -Force
        Write-Verbose "Wrote skeleton/bones.yaml"

        $boneOffsetsData = @{
            boneOffset = @(if ($characterData.ContainsKey('boneOffset')) { $characterData['boneOffset'] })
        }
        Write-DataFile -InputObject $boneOffsetsData `
            -OutputPath (Join-Path $skeletonDir 'bone-offsets.yaml') `
            -Format $Format `
            -Force
        Write-Verbose "Wrote skeleton/bone-offsets.yaml"

        # Extract skin data
        $skinDir = Join-Path $OutputPath 'skin'
        New-Item -ItemType Directory -Path $skinDir -Force | Out-Null

        $skinData = if ($characterData.ContainsKey('skinData')) { $characterData['skinData'] } else { @{} }

        $skinMaterialsData = @{
            skinMaterials = @(if ($skinData.ContainsKey('skinMaterials')) { $skinData['skinMaterials'] })
        }
        Write-DataFile -InputObject $skinMaterialsData `
            -OutputPath (Join-Path $skinDir 'materials.yaml') `
            -Format $Format `
            -Force
        Write-Verbose "Wrote skin/materials.yaml"

        $eyeMaterialsData = @{
            eyeMaterial = @(if ($skinData.ContainsKey('eyeMaterial')) { $skinData['eyeMaterial'] })
        }
        Write-DataFile -InputObject $eyeMaterialsData `
            -OutputPath (Join-Path $skinDir 'eye-materials.yaml') `
            -Format $Format `
            -Force
        Write-Verbose "Wrote skin/eye-materials.yaml"

        $customMaterialsData = @{
            skinCustomMaterials = @(if ($skinData.ContainsKey('skinCustomMaterials')) { $skinData['skinCustomMaterials'] })
        }
        Write-DataFile -InputObject $customMaterialsData `
            -OutputPath (Join-Path $skinDir 'custom-materials.yaml') `
            -Format $Format `
            -Force
        Write-Verbose "Wrote skin/custom-materials.yaml"

        # Extract accessories
        $accessoriesDir = Join-Path $OutputPath 'accessories'
        New-Item -ItemType Directory -Path $accessoriesDir -Force | Out-Null

        $accessories = @(
            if ($characterData.ContainsKey('accessories')) {
                $characterData['accessories']
            }
        )
        $accessoryIndex = @{
            count             = $accessories.Count
            accessoryNames    = @($accessories | ForEach-Object { $_.itemName })
        }
        Write-DataFile -InputObject $accessoryIndex `
            -OutputPath (Join-Path $accessoriesDir '_index.yaml') `
            -Format $Format `
            -Force
        Write-Verbose "Wrote accessories/_index.yaml"

        foreach ($accessory in $accessories) {
            $itemName = $accessory.itemName -replace '[<>:"/\\|?*]', '_'  # Sanitize filename
            $accessoryPath = Join-Path $accessoriesDir "$itemName.yaml"
            $normalizedAccessory = Convert-NestedBlendshapeListsToMaps -InputObject $accessory
            Write-DataFile -InputObject $normalizedAccessory `
                -OutputPath $accessoryPath `
                -Format $Format `
                -Force
        }
        Write-Verbose "Wrote $($accessories.Count) accessories"

        # Extract vertex accessories
        $vertexAccessories = @(
            if ($characterData.ContainsKey('vertexAccessories')) {
                $characterData['vertexAccessories']
            }
        )
        if ($vertexAccessories.Count -gt 0) {
            $vaDir = Join-Path $OutputPath 'vertex-accessories'
            New-Item -ItemType Directory -Path $vaDir -Force | Out-Null

            $vaIndex = @{
                count       = $vertexAccessories.Count
                prefabNames = @($vertexAccessories | ForEach-Object {
                    if ($_ -is [hashtable]) { $_['_prefabName'] } else { $_._prefabName }
                })
            }
            Write-DataFile -InputObject $vaIndex `
                -OutputPath (Join-Path $vaDir '_index.yaml') `
                -Format $Format `
                -Force
            Write-Verbose "Wrote vertex-accessories/_index.yaml"

            foreach ($va in $vertexAccessories) {
                $prefabName = $va._prefabName -replace '[<>:"/\\|?*]', '_'
                $vaPath = Join-Path $vaDir "$prefabName.yaml"
                $normalizedVertexAccessory = Convert-NestedBlendshapeListsToMaps -InputObject $va
                Write-DataFile -InputObject $normalizedVertexAccessory `
                    -OutputPath $vaPath `
                    -Format $Format `
                    -Force
            }
            Write-Verbose "Wrote $($vertexAccessories.Count) vertex accessories"
        }

        # Extract occlusion data
        if ($characterData.ContainsKey('occlusionDatas') -and $characterData['occlusionDatas']) {
            $occlusionData = @{
                occlusionDatas = $characterData['occlusionDatas']
            }
            Write-DataFile -InputObject $occlusionData `
                -OutputPath (Join-Path $OutputPath 'occlusion-data.yaml') `
                -Format $Format `
                -Force
            Write-Verbose "Wrote occlusion-data.yaml"
        }

        # Extract behavior (opinions and traits) as key/value maps
        $behaviorDir = Join-Path $OutputPath 'behavior'
        New-Item -ItemType Directory -Path $behaviorDir -Force | Out-Null

        # Load opinion/trait dictionaries for ID-to-name conversion
        $dictionaries = Get-OpinionTraitDictionaries

        $opinionsSource = if ($characterData.ContainsKey('opinionDataString')) { $characterData['opinionDataString'] } else { @{} }
        $opinionsData = @{}
        if ($opinionsSource) {
            foreach ($key in $opinionsSource.Keys) {
                # Strip _ prefix from keys
                $cleanKey = if ($key -match '^_(.+)$') { $matches[1] } else { $key }
                $opinionsData[$cleanKey] = $opinionsSource[$key]
            }
            if ($opinionsSource.ContainsKey('_opinions')) {
                $opinionsData['opinions'] = Convert-OpinionsListToMap -Opinions $opinionsSource['_opinions'] -IdToNameDict $dictionaries.OpinionIdToName
            }
        }
        Write-DataFile -InputObject $opinionsData `
            -OutputPath (Join-Path $behaviorDir 'opinions.yaml') `
            -Format $Format `
            -Force
        Write-Verbose "Wrote behavior/opinions.yaml"

        $traitsSource = if ($characterData.ContainsKey('traitsData')) { $characterData['traitsData'] } else { @{} }
        $traitsData = @{}
        if ($traitsSource) {
            foreach ($key in $traitsSource.Keys) {
                # Strip _ prefix from keys
                $cleanKey = if ($key -match '^_(.+)$') { $matches[1] } else { $key }
                $traitsData[$cleanKey] = $traitsSource[$key]
            }
            if ($traitsSource.ContainsKey('_traits')) {
                $traitsData['traits'] = Convert-TraitsListToMap -Traits $traitsSource['_traits'] -IdToNameDict $dictionaries.TraitIdToName
            }
        }
        Write-DataFile -InputObject $traitsData `
            -OutputPath (Join-Path $behaviorDir 'traits.yaml') `
            -Format $Format `
            -Force
        Write-Verbose "Wrote behavior/traits.yaml"

        # Extract UI colors
        if ($characterData.ContainsKey('_uiColourData') -and $characterData['_uiColourData']) {
            $uiDir = Join-Path $OutputPath 'ui'
            New-Item -ItemType Directory -Path $uiDir -Force | Out-Null

            $colorsData = @{
                colors = $characterData['_uiColourData']
            }
            Write-DataFile -InputObject $colorsData `
                -OutputPath (Join-Path $uiDir 'colors.yaml') `
                -Format $Format `
                -Force
            Write-Verbose "Wrote ui/colors.yaml"
        }

        return @{
            ExpandedPath    = (Resolve-Path -LiteralPath $OutputPath).ProviderPath
            FileCount       = @(Get-ChildItem -LiteralPath $OutputPath -Recurse -File).Count
            SchemaVersion   = 2
            Format          = $Format
            TextureCount    = $writtenTextureCount
            HasCustomIcon   = ($null -ne $customIconFileName)
            DirectPipeline  = $isZnelchar
        }
    }
}

