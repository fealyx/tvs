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

    $resolvedInputPath = (Resolve-Path $InputPath).Path
    $inputRootName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedInputPath)

    if (-not $OutputDir) {
        $OutputDir = Join-Path ([System.IO.Path]::GetDirectoryName($resolvedInputPath)) ($inputRootName + '.extracted')
    }
    $OutputDir = [System.IO.Path]::GetFullPath($OutputDir)

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
    if (-not $MetadataOnly) {
        $character = ($outer['_characterData'] | ConvertFrom-Json -AsHashtable -Depth 100)
        $character = Expand-NestedCharacterData -Character $character -WarnOnFailure
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

        $decodedBytes = [int64][Math]::Floor(($base64.Length * 3) / 4)
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
        manifestFile = $manifestPath
        textureCount = $manifestTextures.Count
        metadataOnly = [bool]$MetadataOnly
    }
}
