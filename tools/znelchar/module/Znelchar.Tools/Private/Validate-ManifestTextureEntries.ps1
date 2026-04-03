function Validate-ManifestTextureEntries {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IEnumerable]$Descriptors,
        [Parameter(Mandatory = $true)][string]$TexturesRoot,
        [hashtable]$Manifest
    )

    $seenTextureNames = @{}
    $seenFileNames = @{}

    foreach ($descriptor in $Descriptors) {
        $textureName = [string]$descriptor.textureName
        $fileName = [string]$descriptor.fileName

        if ([string]::IsNullOrWhiteSpace($textureName)) {
            throw 'Manifest contains a texture entry with missing textureName'
        }
        if ([string]::IsNullOrWhiteSpace($fileName)) {
            throw "Manifest entry for texture '$textureName' is missing outputFile/fileName"
        }

        if ($seenTextureNames.ContainsKey($textureName)) {
            throw "Manifest contains duplicate textureName: $textureName"
        }
        $seenTextureNames[$textureName] = $true

        if ($seenFileNames.ContainsKey($fileName)) {
            throw "Manifest maps multiple textures to the same file: $fileName"
        }
        $seenFileNames[$fileName] = $true

        $textureFilePath = Join-Path $TexturesRoot $fileName
        if (-not (Test-Path -LiteralPath $textureFilePath)) {
            throw "Texture file listed in manifest was not found: $textureFilePath"
        }

        if ($null -ne $Manifest -and $Manifest.ContainsKey('metadataOnly') -and [bool]$Manifest['metadataOnly'] -eq $false -and $Manifest.ContainsKey('textures')) {
            $entry = @($Manifest['textures'] | Where-Object {
                    ($_ -is [System.Collections.IDictionary]) -and
                    $_.ContainsKey('textureName') -and
                    ([string]$_.textureName -eq $textureName)
                }) | Select-Object -First 1

            if ($null -ne $entry) {
                $metadata = Get-TextureFileMetadata -Path $textureFilePath
                if ($entry.ContainsKey('estimatedDecodedBytes') -and $null -ne $entry.estimatedDecodedBytes) {
                    $expectedSize = [int64]$entry.estimatedDecodedBytes
                    if ($expectedSize -gt 0 -and $expectedSize -ne $metadata.fileSize) {
                        Write-Warning "Manifest metadata mismatch for '$textureName': expected decoded bytes $expectedSize, actual file size $($metadata.fileSize). Continuing with current file contents."
                    }
                }
                if ($entry.ContainsKey('sha256') -and -not [string]::IsNullOrWhiteSpace([string]$entry.sha256)) {
                    if ([string]$entry.sha256 -ne $metadata.sha256) {
                        Write-Warning "Manifest metadata mismatch for '$textureName': expected sha256 $($entry.sha256), actual $($metadata.sha256). Continuing with current file contents."
                    }
                }
            }
        }
    }

    if ($null -ne $Manifest -and $Manifest.ContainsKey('textureCount') -and $null -ne $Manifest['textureCount']) {
        $expectedCount = [int]$Manifest['textureCount']
        if ($expectedCount -ne @($Descriptors).Count) {
            throw "Manifest textureCount mismatch: expected $expectedCount, resolved $(@($Descriptors).Count)"
        }
    }
}
