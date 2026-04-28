<#
.SYNOPSIS
Expands a character.json file into a structured folder hierarchy for collaborative Git development.

.DESCRIPTION
Decomposes a character.json file (from Export-ZnelcharContent) into atomic YAML/JSON files
organized in folders. This enables:
- Better Git diffs (changes are granular)
- Parallel editing of different character sections
- Easier merge conflict resolution (different people edit different files)

The expanded structure includes:
- _metadata.yaml: Schema version and source info
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
- textures/: Texture files copied from the adjacent textures/ folder (if found or specified)

.PARAMETER InputPath
Path to character.json (extracted form from Export-ZnelcharContent).

.PARAMETER OutputPath
Target folder for the expanded structure. Created if it doesn't exist.

.PARAMETER Format
Output format: 'yaml' (default, recommended) or 'json'.

.PARAMETER TexturesPath
Path to the textures folder to absorb into the expanded structure. If not specified,
Expand-ZnelcharData auto-discovers a 'textures' sibling folder next to the input
character.json (i.e. the textures/ folder produced by Export-ZnelcharContent).

.PARAMETER Force
Overwrite existing expanded structure if present.

.EXAMPLE
# Expand a character for collaborative development
Expand-ZnelcharData -InputPath extracted/character.json -OutputPath character-expanded

# Export znelchar, then expand
Export-ZnelcharContent -InputPath character.znelchar -OutputPath extracted
Expand-ZnelcharData -InputPath extracted/character.json -OutputPath character-expanded -Format yaml

.NOTES
The expanded structure is designed for Git workflow:
1. Export znelchar → extracted format
2. Expand extracted → character-expanded (folder with atomicfiles)
3. Edit files in character-expanded
4. Compress → back to character.json
5. Repack with New-ZnelcharFile

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
            if ($ext -ne '.json') {
                throw "Input file must be a .json file (character.json)"
            }
            $true
        })]
        [string]$InputPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [ValidateSet('yaml', 'json')]
        [string]$Format = 'yaml',

        [string]$TexturesPath,

        [switch]$Force
    )

    process {
        # Check if output exists
        if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
            throw "Output path already exists: $OutputPath. Use -Force to overwrite."
        }

        # Load input JSON
        Write-Verbose "Loading character data from: $InputPath"
        try {
            $characterData = Read-JsonFile -Path $InputPath
        } catch {
            throw "Failed to load JSON file: $_"
        }

        # Create output directory
        if (Test-Path -LiteralPath $OutputPath) {
            Remove-Item -LiteralPath $OutputPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        Write-Verbose "Created output directory: $OutputPath"

        # Calculate source hash
        $sourceHash = (Get-FileHash -Path $InputPath -Algorithm SHA256).Hash

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

        # Discover textures: use explicit path or auto-discover sibling textures/ folder
        $effectiveTexturesPath = $null
        if ($PSBoundParameters.ContainsKey('TexturesPath')) {
            if (Test-Path -LiteralPath $TexturesPath -PathType Container) {
                $effectiveTexturesPath = (Resolve-Path -LiteralPath $TexturesPath).ProviderPath
            } else {
                Write-Warning "Specified -TexturesPath not found: $TexturesPath"
            }
        } else {
            $characterDir    = [System.IO.Path]::GetDirectoryName((Resolve-Path -LiteralPath $InputPath).ProviderPath)
            $siblingTextures = Join-Path $characterDir 'textures'
            if (Test-Path -LiteralPath $siblingTextures -PathType Container) {
                $effectiveTexturesPath = $siblingTextures
                Write-Verbose "Auto-discovered textures at: $effectiveTexturesPath"
            }
        }
        $textureFiles = if ($effectiveTexturesPath) {
            @(Get-ChildItem -LiteralPath $effectiveTexturesPath -File)
        } else { @() }

        # Write metadata
        $metadata = @{
            schemaVersion    = 1
            expandedAtUtc    = (Get-Date -AsUTC -Format 'o')
            dataFormat       = $Format
            sourceFile       = (Resolve-Path -LiteralPath $InputPath).ProviderPath
            sourceHashSha256 = $sourceHash
            characterName    = $baseFields['characterName'] ?? ""
            notes            = ""
            hasCustomIcon    = ($null -ne $customIconFileName)
            customIconFile   = $customIconFileName ?? ""
            textureCount     = $textureFiles.Count
        }
        Write-DataFile -InputObject $metadata `
            -OutputPath (Join-Path $OutputPath '_metadata.yaml') `
            -Format 'yaml' `
            -Force
        Write-Verbose "Wrote metadata"

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

        # Copy textures into textures/ subdirectory
        if ($textureFiles.Count -gt 0) {
            $texturesOutDir = Join-Path $OutputPath 'textures'
            New-Item -ItemType Directory -Path $texturesOutDir -Force | Out-Null
            foreach ($tf in $textureFiles) {
                Copy-Item -LiteralPath $tf.FullName -Destination (Join-Path $texturesOutDir $tf.Name) -Force
            }
            Write-Verbose "Copied $($textureFiles.Count) texture(s) to textures/"
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
            ExpandedPath  = (Resolve-Path -LiteralPath $OutputPath).ProviderPath
            FileCount     = @(Get-ChildItem -LiteralPath $OutputPath -Recurse -File).Count
            SchemaVersion = 1
            Format        = $Format
            TextureCount  = $textureFiles.Count
            HasCustomIcon = ($null -ne $customIconFileName)
        }
    }
}

