function Set-ZnelcharImagePayload {
<#
.SYNOPSIS
Replaces customIconData or a named texture payload in a .znelchar file.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$ImagePath,
        [Parameter(Mandatory = $true)][ValidateSet('icon', 'texture')][string]$Target,
        [string]$TextureName,
        [string]$OutputPath,
        [string]$BackupOriginalPayloadPath,
        [switch]$BackupOriginalFile,
        [switch]$Force
    )

    if ($Target -eq 'texture' -and [string]::IsNullOrWhiteSpace($TextureName)) {
        throw 'TextureName is required when -Target texture is selected.'
    }

    $resolvedInputPath = (Resolve-Path -LiteralPath $InputPath).Path
    $resolvedImagePath = (Resolve-Path -LiteralPath $ImagePath).Path
    $resolvedOutputPath = if ([string]::IsNullOrWhiteSpace($OutputPath)) { $resolvedInputPath } else { Resolve-UserPath -Path $OutputPath }
    $writeInPlace = [string]::Equals($resolvedInputPath, $resolvedOutputPath, [System.StringComparison]::OrdinalIgnoreCase)

    if ((Test-Path -LiteralPath $resolvedOutputPath) -and -not $writeInPlace -and -not $Force) {
        throw "Output file already exists. Use -Force to overwrite: $resolvedOutputPath"
    }

    $resolvedPayloadBackupPath = $null
    if (-not [string]::IsNullOrWhiteSpace($BackupOriginalPayloadPath)) {
        $resolvedPayloadBackupPath = Resolve-UserPath -Path $BackupOriginalPayloadPath
        if ((Test-Path -LiteralPath $resolvedPayloadBackupPath) -and -not $Force) {
            throw "Backup payload file already exists. Use -Force to overwrite: $resolvedPayloadBackupPath"
        }
    }

    $resolvedFileBackupPath = $null
    if ($BackupOriginalFile) {
        $inputDirectory = [System.IO.Path]::GetDirectoryName($resolvedInputPath)
        $inputName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedInputPath)
        $inputExtension = [System.IO.Path]::GetExtension($resolvedInputPath)
        $resolvedFileBackupPath = Join-Path $inputDirectory ($inputName + '.bak' + $inputExtension)
        if ((Test-Path -LiteralPath $resolvedFileBackupPath) -and -not $Force) {
            throw "Backup file already exists. Use -Force to overwrite: $resolvedFileBackupPath"
        }
    }

    $actionDescription = if ($Target -eq 'icon') { 'Replace customIconData payload' } else { "Replace texture payload '$TextureName'" }
    if (-not $PSCmdlet.ShouldProcess($resolvedOutputPath, $actionDescription)) {
        return
    }

    Write-Stage -Prefix 'swap-image' -Message "Loading $resolvedInputPath"
    $outer = Read-JsonFile -Path $resolvedInputPath

    $newImageBytes = [System.IO.File]::ReadAllBytes($resolvedImagePath)
    $newImageInfo = Get-ImageFormatInfoFromBytes -Bytes $newImageBytes
    $newBase64 = [System.Convert]::ToBase64String($newImageBytes)

    $oldBase64 = $null
    $targetDescription = $null

    if ($Target -eq 'icon') {
        if (-not $outer.ContainsKey('_characterData') -or $outer['_characterData'] -isnot [string]) {
            throw 'Input file does not contain required _characterData string.'
        }

        $character = ($outer['_characterData'] | ConvertFrom-Json -AsHashtable -Depth 100)
        if (-not $character.ContainsKey('customIconData') -or [string]::IsNullOrWhiteSpace([string]$character['customIconData'])) {
            throw 'customIconData was not found or is empty in _characterData.'
        }

        $oldBase64 = [string]$character['customIconData']
        $character['customIconData'] = $newBase64
        $outer['_characterData'] = ($character | ConvertTo-Json -Compress -Depth 100)
        $targetDescription = 'character.customIconData'
    }
    else {
        if (-not $outer.ContainsKey('_textureDatas') -or $null -eq $outer['_textureDatas']) {
            throw 'Input file does not contain _textureDatas entries.'
        }

        $textures = @($outer['_textureDatas'])
        $matchingIndices = @()
        for ($index = 0; $index -lt $textures.Count; $index++) {
            $entry = $textures[$index]
            $entryName = if ($entry.ContainsKey('_textureName')) { [string]$entry['_textureName'] } else { '' }
            if ([string]::Equals($entryName, $TextureName, [System.StringComparison]::Ordinal)) {
                $matchingIndices += $index
            }
        }

        if ($matchingIndices.Count -eq 0) {
            throw "No _textureDatas entry matched _textureName '$TextureName'."
        }

        if ($matchingIndices.Count -gt 1) {
            throw "Multiple _textureDatas entries matched _textureName '$TextureName'. Use unique texture names before replacing."
        }

        $targetIndex = $matchingIndices[0]
        $targetEntry = $textures[$targetIndex]
        if (-not $targetEntry.ContainsKey('_textureData') -or [string]::IsNullOrWhiteSpace([string]$targetEntry['_textureData'])) {
            throw "Matched texture '$TextureName' does not contain _textureData."
        }

        $oldBase64 = [string]$targetEntry['_textureData']
        $targetEntry['_textureData'] = $newBase64
        $targetDescription = "_textureDatas[$targetIndex]._textureData"
    }

    if ($resolvedPayloadBackupPath) {
        Write-Stage -Prefix 'swap-image' -Message "Writing payload backup to $resolvedPayloadBackupPath"
        Write-Base64StringToFile -Base64 $oldBase64 -OutputPath $resolvedPayloadBackupPath
    }

    if ($resolvedFileBackupPath) {
        Write-Stage -Prefix 'swap-image' -Message "Writing full-file backup to $resolvedFileBackupPath"
        Copy-Item -LiteralPath $resolvedInputPath -Destination $resolvedFileBackupPath -Force:$Force
    }

    $outputDirectory = [System.IO.Path]::GetDirectoryName($resolvedOutputPath)
    if ([string]::IsNullOrWhiteSpace($outputDirectory)) {
        $outputDirectory = [System.IO.Path]::GetDirectoryName($resolvedInputPath)
    }

    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    $tempOutputPath = Join-Path $outputDirectory ([System.IO.Path]::GetFileName($resolvedOutputPath) + '.' + [System.Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $updatedJson = $outer | ConvertTo-Json -Compress -Depth 100
        Write-Utf8NoBomFile -Path $tempOutputPath -Content $updatedJson
        [System.IO.File]::Move($tempOutputPath, $resolvedOutputPath, $true)
    }
    finally {
        if (Test-Path -LiteralPath $tempOutputPath) {
            Remove-Item -LiteralPath $tempOutputPath -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Stage -Prefix 'swap-image' -Message "Replaced $targetDescription in $resolvedOutputPath"
    return [ordered]@{
        inputFile = $resolvedInputPath
        outputFile = $resolvedOutputPath
        target = $Target
        textureName = if ($Target -eq 'texture') { $TextureName } else { $null }
        oldBase64Length = [int64]$oldBase64.Length
        newBase64Length = [int64]$newBase64.Length
        payloadBackupFile = $resolvedPayloadBackupPath
        fileBackupPath = $resolvedFileBackupPath
        newImageMimeType = [string]$newImageInfo.mimeType
        newImageExtension = [string]$newImageInfo.extension
        wroteInPlace = [bool]$writeInPlace
    }
}