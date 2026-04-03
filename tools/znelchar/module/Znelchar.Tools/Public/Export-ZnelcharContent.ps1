function Export-ZnelcharContent {
<#
.SYNOPSIS
Extracts character and texture data from a .znelchar file.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [string]$OutputDir,
        [switch]$MetadataOnly,
        [switch]$Force
    )

    function Get-DecodedByteEstimateFromBase64 {
        param([Parameter(Mandatory = $true)][string]$Base64)

        # Remove whitespace so line-wrapped base64 does not skew size math.
        $normalized = ($Base64 -replace '\s', '')
        if ([string]::IsNullOrEmpty($normalized)) {
            return [int64]0
        }

        $padding = 0
        if ($normalized.EndsWith('==')) {
            $padding = 2
        }
        elseif ($normalized.EndsWith('=')) {
            $padding = 1
        }

        return [int64](($normalized.Length / 4) * 3 - $padding)
    }

    $resolvedInputPath = (Resolve-Path $InputPath).Path
    $inputRootName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedInputPath)

    if (-not $OutputDir) {
        $OutputDir = Join-Path ([System.IO.Path]::GetDirectoryName($resolvedInputPath)) ($inputRootName + '.extracted')
    }
    $OutputDir = Resolve-UserPath -Path $OutputDir

    if ((Test-Path $OutputDir) -and -not $Force) {
        throw "Output directory already exists. Use -Force to overwrite: $OutputDir"
    }

    if (-not $PSCmdlet.ShouldProcess($OutputDir, 'Extract .znelchar contents')) {
        return
    }

    Write-Stage -Prefix 'extract' -Message "Loading $resolvedInputPath"
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    $texturesDir = Join-Path $OutputDir 'textures'
    New-Item -ItemType Directory -Force -Path $texturesDir | Out-Null

    $outer = Read-JsonFile -Path $resolvedInputPath
    if (-not $outer.ContainsKey('_characterData')) {
        throw 'Input file does not contain required key: _characterData'
    }

    $characterPath = $null
    $customIconPath = $null
    $manifestCustomIcon = $null
    if (-not $MetadataOnly) {
        $character = ($outer['_characterData'] | ConvertFrom-Json -AsHashtable -Depth 100)
        $character = Expand-NestedCharacterData -Character $character -WarnOnFailure

        if ($character.ContainsKey('customIconData') -and $character['customIconData'] -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$character['customIconData'])) {
            $customIconBase64 = [string]$character['customIconData']
            $normalizedCustomIconBase64 = ($customIconBase64 -replace '\s', '')
            try {
                $customIconBytes = [System.Convert]::FromBase64String($normalizedCustomIconBase64)
                $customIconFormat = Get-ImageFormatInfoFromBytes -Bytes $customIconBytes
                $customIconFileName = 'customIcon' + $customIconFormat.extension
                $customIconPath = Join-Path $OutputDir $customIconFileName

                [System.IO.File]::WriteAllBytes($customIconPath, $customIconBytes)
                $customIconSha256 = (Get-FileHash -Algorithm SHA256 -Path $customIconPath).Hash
                $null = $character.Remove('customIconData')

                $manifestCustomIcon = [ordered]@{
                    outputFile = $customIconFileName
                    base64Length = [int64]$customIconBase64.Length
                    estimatedDecodedBytes = [int64]$customIconBytes.Length
                    sha256 = $customIconSha256
                    mimeType = $customIconFormat.mimeType
                }
            }
            catch {
                Write-Warning "Failed to extract character.customIconData; keeping original field in character.json. $($_.Exception.Message)"
            }
        }

        Write-Stage -Prefix 'extract' -Message 'Writing character.json'
        $characterPath = Join-Path $OutputDir 'character.json'
        Write-Utf8NoBomFile -Path $characterPath -Content ($character | ConvertTo-Json -Depth 100)
    }
    else {
        Write-Stage -Prefix 'extract' -Message 'Metadata-only mode: skipping _characterData nested parse and character.json write'
    }

    $textures = @()
    if ($outer.ContainsKey('_textureDatas') -and $null -ne $outer['_textureDatas']) {
        $textures = @($outer['_textureDatas'])
    }
    Write-Stage -Prefix 'extract' -Message "Processing $($textures.Count) texture entries"

    $manifestTextures = @()
    for ($textureIndex = 0; $textureIndex -lt $textures.Count; $textureIndex++) {
        $t = $textures[$textureIndex]
        $textureName = if ($t.ContainsKey('_textureName')) { [string]$t['_textureName'] } else { 'unnamed.bin' }
        $base64 = if ($t.ContainsKey('_textureData') -and $null -ne $t['_textureData']) { [string]$t['_textureData'] } else { '' }
        Write-Host "[extract] Texture $($textureIndex + 1)/$($textures.Count): $textureName"

        $safeName = [System.IO.Path]::GetFileName($textureName)
        if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = 'unnamed.bin' }

        $targetPath = Join-Path $texturesDir $safeName
        $nameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($safeName)
        $ext = [System.IO.Path]::GetExtension($safeName)
        $counter = 1
        while (Test-Path $targetPath) {
            $targetPath = Join-Path $texturesDir ('{0}_{1}{2}' -f $nameNoExt, $counter, $ext)
            $counter++
        }

        $decodedBytes = Get-DecodedByteEstimateFromBase64 -Base64 $base64
        $sha256 = $null
        $writtenOutputFile = $null
        if (-not $MetadataOnly -and $base64.Length -gt 0) {
            Write-Base64StringToFile -Base64 $base64 -OutputPath $targetPath
            $sha256 = (Get-FileHash -Algorithm SHA256 -Path $targetPath).Hash
            $writtenOutputFile = [System.IO.Path]::GetFileName($targetPath)
        }

        $manifestTextures += [ordered]@{
            textureName = $textureName
            outputFile = $writtenOutputFile
            base64Length = [int64]$base64.Length
            estimatedDecodedBytes = $decodedBytes
            sha256 = $sha256
        }
    }

    $manifest = [ordered]@{
        sourceFile = $resolvedInputPath
        extractedAtUtc = [DateTime]::UtcNow.ToString('o')
        metadataOnly = [bool]$MetadataOnly
        characterFile = if ($MetadataOnly) { $null } else { 'character.json' }
        customIcon = $manifestCustomIcon
        texturesFolder = 'textures'
        textureCount = $manifestTextures.Count
        textures = $manifestTextures
    }

    $manifestPath = Join-Path $OutputDir 'manifest.json'
    Write-Stage -Prefix 'extract' -Message 'Writing manifest.json'
    Write-Utf8NoBomFile -Path $manifestPath -Content ($manifest | ConvertTo-Json -Depth 100)

    Write-Stage -Prefix 'extract' -Message 'Completed'
    return [ordered]@{
        outputDir = $OutputDir
        characterFile = $characterPath
        customIconFile = $customIconPath
        manifestFile = $manifestPath
        textureCount = $manifestTextures.Count
        metadataOnly = [bool]$MetadataOnly
    }
}
