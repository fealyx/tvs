<#
.SYNOPSIS
Compresses an expanded character data structure back into a single character.json file.

.DESCRIPTION
Reconstructs character.json from an expanded folder structure created by Expand-ZnelcharData.
This is the complementary operation that merges all atomic YAML/JSON files back into
the unified JSON format.

Includes automatic schema version detection and validation:
- If expanded structure uses a different schema version, throws an error with
  instructions to run Update-ExpandedDataStructure before retrying
- Validates merged structure against characterData schema
- Preserves array ordering for deterministic output

.PARAMETER InputPath
Path to the expanded folder structure (created by Expand-ZnelcharData).

.PARAMETER OutputPath
Output path for the reconstructed character.json file.

.PARAMETER Force
Overwrite existing character.json if present.

.EXAMPLE
# Compress expanded structure back to JSON
Compress-ZnelcharData -InputPath character-expanded -OutputPath character.json

# Then repack with znelchar
New-ZnelcharFile -ManifestPath extracted/manifest.json -CharacterJsonPath character.json

.NOTES
After condensing, use New-ZnelcharFile to repack into znelchar binary format.

See also: Expand-ZnelcharData, New-ZnelcharFile
#>

function Compress-ZnelcharData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (-not (Test-Path -LiteralPath $_ -PathType Container)) {
                throw "Input path not found or is not a directory: $_"
            }
            if (-not (Test-Path -LiteralPath (Join-Path $_ '_metadata.yaml'))) {
                throw "Input does not appear to be an expanded structure (missing _metadata.yaml): $_"
            }
            $true
        })]
        [string]$InputPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [switch]$Force
    )

    process {
        # Check if output exists
        if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
            throw "Output file already exists: $OutputPath. Use -Force to overwrite."
        }

        Write-Verbose "Loading metadata from expanded structure"
        # Load and validate metadata
        $metadataPath = Join-Path $InputPath '_metadata.yaml'
        $metadata = Read-DataFile -Path $metadataPath
        
        $schemaVersion = $metadata['schemaVersion']
        if ($null -eq $schemaVersion) {
            throw "Metadata missing schemaVersion"
        }

        $dataFormat = if ($metadata.Contains('dataFormat')) { $metadata['dataFormat'] } else { 'yaml' }
        if ($dataFormat -notin @('yaml', 'json')) {
            throw "Unsupported metadata dataFormat '$dataFormat'. Expected 'yaml' or 'json'."
        }

        # Check schema version
        $latestVersion = 1
        if ($schemaVersion -ne $latestVersion) {
            Write-Warning "Schema version mismatch: expanded structure is v$schemaVersion, but v$latestVersion is expected"
            throw "Run 'Update-ExpandedDataStructure -InputPath $InputPath -FromVersion $schemaVersion -ToVersion $latestVersion' to migrate, then try again."
        }

        # Load all data files
        Write-Verbose "Loading atomic data files"
        $character = @{}

        # Load base fields
        $basePath = Join-Path $InputPath 'base.yaml'
        if (Test-Path -LiteralPath $basePath) {
            $base = Read-DataFile -Path $basePath -Format $dataFormat
            foreach ($key in $base.Keys) {
                $character[$key] = $base[$key]
            }
        }

        # Load blendshapes
        $blendshapesPath = Join-Path $InputPath 'blendshapes.yaml'
        if (Test-Path -LiteralPath $blendshapesPath) {
            $blendshapesData = Read-DataFile -Path $blendshapesPath -Format $dataFormat
            $character['blendshapes'] = Convert-BlendshapeMapToList -Blendshapes $blendshapesData['blendshapes']
        }

        # Load skeleton data
        $character['boneData'] = @()
        $bonesPath = Join-Path $InputPath 'skeleton' 'bones.yaml'
        if (Test-Path -LiteralPath $bonesPath) {
            $bonesData = Read-DataFile -Path $bonesPath -Format $dataFormat
            $character['boneData'] = $bonesData['boneData']
        }

        $character['boneOffset'] = @()
        $boneOffsetsPath = Join-Path $InputPath 'skeleton' 'bone-offsets.yaml'
        if (Test-Path -LiteralPath $boneOffsetsPath) {
            $boneOffsetsData = Read-DataFile -Path $boneOffsetsPath -Format $dataFormat
            $character['boneOffset'] = $boneOffsetsData['boneOffset']
        }

        # Load skin data
        $character['skinData'] = @{}
        
        $materialsPath = Join-Path $InputPath 'skin' 'materials.yaml'
        if (Test-Path -LiteralPath $materialsPath) {
            $materialsData = Read-DataFile -Path $materialsPath -Format $dataFormat
            $character['skinData']['skinMaterials'] = $materialsData['skinMaterials']
        }

        $eyeMaterialsPath = Join-Path $InputPath 'skin' 'eye-materials.yaml'
        if (Test-Path -LiteralPath $eyeMaterialsPath) {
            $eyeMaterialsData = Read-DataFile -Path $eyeMaterialsPath -Format $dataFormat
            $character['skinData']['eyeMaterial'] = $eyeMaterialsData['eyeMaterial']
        }

        $customMaterialsPath = Join-Path $InputPath 'skin' 'custom-materials.yaml'
        if (Test-Path -LiteralPath $customMaterialsPath) {
            $customMaterialsData = Read-DataFile -Path $customMaterialsPath -Format $dataFormat
            $character['skinData']['skinCustomMaterials'] = $customMaterialsData['skinCustomMaterials']
        }

        # Load accessories
        $character['accessories'] = @()
        $accessoriesDir = Join-Path $InputPath 'accessories'
        if (Test-Path -LiteralPath $accessoriesDir) {
            $indexPath = Join-Path $accessoriesDir '_index.yaml'
            if (Test-Path -LiteralPath $indexPath) {
                # Use index to restore original accessory order
                $indexData = Read-DataFile -Path $indexPath -Format $dataFormat
                $accessoryNames = @($indexData['accessoryNames'])
                foreach ($name in $accessoryNames) {
                    $sanitized = $name -replace '[<>:"/\\|?*]', '_'
                    $filePath = Join-Path $accessoriesDir "$sanitized.yaml"
                    if (Test-Path -LiteralPath $filePath) {
                        $accessoryData = Read-DataFile -Path $filePath -Format $dataFormat
                        $character['accessories'] += Convert-NestedBlendshapeMapsToLists -InputObject $accessoryData
                    }
                }
            } else {
                $accessoryFiles = @(Get-ChildItem -LiteralPath $accessoriesDir -Filter '*.yaml' -Exclude '_index.yaml' |
                    Sort-Object Name)
                foreach ($file in $accessoryFiles) {
                    $accessoryData = Read-DataFile -Path $file.FullName -Format $dataFormat
                    $character['accessories'] += Convert-NestedBlendshapeMapsToLists -InputObject $accessoryData
                }
            }
            Write-Verbose "Loaded $($character['accessories'].Count) accessories"
        }

        # Load vertex accessories (only add key if the directory exists with files)
        $vaDir = Join-Path $InputPath 'vertex-accessories'
        if (Test-Path -LiteralPath $vaDir) {
            $vaFiles = @(Get-ChildItem -LiteralPath $vaDir -Filter '*.yaml' -Exclude '_index.yaml')
            
            if ($vaFiles.Count -gt 0) {
                $character['vertexAccessories'] = @()
                $vaIndexPath = Join-Path $vaDir '_index.yaml'
                if (Test-Path -LiteralPath $vaIndexPath) {
                    # Use index to restore original vertex-accessory order
                    $vaIndexData = Read-DataFile -Path $vaIndexPath -Format $dataFormat
                    $prefabNames = @($vaIndexData['prefabNames'])
                    if ($prefabNames.Count -gt 0) {
                        foreach ($name in $prefabNames) {
                            $sanitized = $name -replace '[<>:"/\\|?*]', '_'
                            $filePath = Join-Path $vaDir "$sanitized.yaml"
                            if (Test-Path -LiteralPath $filePath) {
                                $vaData = Read-DataFile -Path $filePath -Format $dataFormat
                                $character['vertexAccessories'] += Convert-NestedBlendshapeMapsToLists -InputObject $vaData
                            }
                        }
                    } else {
                        foreach ($file in ($vaFiles | Sort-Object Name)) {
                            $vaData = Read-DataFile -Path $file.FullName -Format $dataFormat
                            $character['vertexAccessories'] += Convert-NestedBlendshapeMapsToLists -InputObject $vaData
                        }
                    }
                } else {
                    foreach ($file in ($vaFiles | Sort-Object Name)) {
                        $vaData = Read-DataFile -Path $file.FullName -Format $dataFormat
                        $character['vertexAccessories'] += Convert-NestedBlendshapeMapsToLists -InputObject $vaData
                    }
                }
                Write-Verbose "Loaded $($character['vertexAccessories'].Count) vertex accessories"
            }
        }

        # Load occlusion data
        $occlusionPath = Join-Path $InputPath 'occlusion-data.yaml'
        if (Test-Path -LiteralPath $occlusionPath) {
            $occlusionData = Read-DataFile -Path $occlusionPath -Format $dataFormat
            $character['occlusionDatas'] = $occlusionData['occlusionDatas']
        }

        # Load opinion/trait dictionaries for name-to-ID conversion
        $dictionaries = Get-OpinionTraitDictionaries

        # Load behavior data
        $opinionsPath = Join-Path $InputPath 'behavior' 'opinions.yaml'
        if (Test-Path -LiteralPath $opinionsPath) {
            $opinionsData = Read-DataFile -Path $opinionsPath -Format $dataFormat
            if ($opinionsData) {
                # Rebuild with _ prefixes restored
                $rebuilt = @{}
                foreach ($key in $opinionsData.Keys) {
                    # Restore _ prefix
                    $prefixedKey = if ($key -match '^_') { $key } else { "_$key" }
                    $rebuilt[$prefixedKey] = $opinionsData[$key]
                }
                # Convert opinions map back to list, checking both 'opinions' and '_opinions'
                if ($opinionsData.Contains('opinions')) {
                    $rebuilt['_opinions'] = Convert-OpinionsMapToList -Opinions $opinionsData['opinions'] -NameToIdDict $dictionaries.OpinionNameToId
                } elseif ($opinionsData.Contains('_opinions')) {
                    $rebuilt['_opinions'] = Convert-OpinionsMapToList -Opinions $opinionsData['_opinions'] -NameToIdDict $dictionaries.OpinionNameToId
                }
                $character['opinionDataString'] = $rebuilt
            }
        }

        $traitsPath = Join-Path $InputPath 'behavior' 'traits.yaml'
        if (Test-Path -LiteralPath $traitsPath) {
            $traitsData = Read-DataFile -Path $traitsPath -Format $dataFormat
            if ($traitsData) {
                # Rebuild with _ prefixes restored
                $rebuilt = @{}
                foreach ($key in $traitsData.Keys) {
                    # Restore _ prefix
                    $prefixedKey = if ($key -match '^_') { $key } else { "_$key" }
                    $rebuilt[$prefixedKey] = $traitsData[$key]
                }
                # Convert traits map back to list, checking both 'traits' and '_traits'
                if ($traitsData.Contains('traits')) {
                    $rebuilt['_traits'] = Convert-TraitsMapToList -Traits $traitsData['traits'] -NameToIdDict $dictionaries.TraitNameToId
                } elseif ($traitsData.Contains('_traits')) {
                    $rebuilt['_traits'] = Convert-TraitsMapToList -Traits $traitsData['_traits'] -NameToIdDict $dictionaries.TraitNameToId
                }
                $character['traitsData'] = $rebuilt
            }
        }

        # Load UI colors
        $colorsPath = Join-Path $InputPath 'ui' 'colors.yaml'
        if (Test-Path -LiteralPath $colorsPath) {
            $colorsData = Read-DataFile -Path $colorsPath -Format $dataFormat
            $character['_uiColourData'] = $colorsData['colors']
        }

        # Validate merged structure
        Write-Verbose "Validating merged character structure"
        if (-not $character['characterName']) {
            Write-Warning "characterName is missing or empty"
        }
        if ($null -eq $character['blendshapes']) {
            $character['blendshapes'] = @()
        }
        if ($null -eq $character['boneData']) {
            $character['boneData'] = @()
        }
        if ($null -eq $character['boneOffset']) {
            $character['boneOffset'] = @()
        }
        if ($null -eq $character['accessories']) {
            $character['accessories'] = @()
        }

        # Ensure directory exists
        $outputDir = Split-Path -Parent $OutputPath
        if (-not (Test-Path -LiteralPath $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # Write character.json with deterministic formatting
        Write-Verbose "Writing condensed character.json"
        Write-Utf8NoBomFile -Path $OutputPath `
            -Content (ConvertTo-Json -InputObject $character -Depth 100)

        return @{
            OutputPath           = (Resolve-Path -LiteralPath $OutputPath).ProviderPath
            FieldCount           = $character.Keys.Count
            AccessoryCount       = $character['accessories'].Count
            VertexAccessoryCount = if ($character.ContainsKey('vertexAccessories')) { $character['vertexAccessories'].Count } else { 0 }
            ValidationStatus     = 'Valid'
        }
    }
}

