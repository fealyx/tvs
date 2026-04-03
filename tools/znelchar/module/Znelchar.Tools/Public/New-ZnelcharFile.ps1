function New-ZnelcharFile {
<#
.SYNOPSIS
Builds a .znelchar file from extracted artifacts.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$CharacterJsonPath,
        [string]$TexturesDir,
        [string]$ManifestPath,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [switch]$Force
    )

    $resolvedManifestPath = Resolve-PathOrNull -Path $ManifestPath
    $manifest = $null
    if ($resolvedManifestPath) {
        $manifest = (Get-Content -Raw -Path $resolvedManifestPath | ConvertFrom-Json -AsHashtable -Depth 100)
    }

    $manifestDirectory = if ($resolvedManifestPath) { [System.IO.Path]::GetDirectoryName($resolvedManifestPath) } else { $null }
    $manifestCharacterJsonPath = $null
    $manifestTexturesDir = $null
    if ($null -ne $manifest) {
        if ($manifest.ContainsKey('characterFile') -and -not [string]::IsNullOrWhiteSpace([string]$manifest['characterFile'])) {
            $manifestCharacterJsonPath = Join-Path $manifestDirectory ([string]$manifest['characterFile'])
        }
        if ($manifest.ContainsKey('texturesFolder') -and -not [string]::IsNullOrWhiteSpace([string]$manifest['texturesFolder'])) {
            $manifestTexturesDir = Join-Path $manifestDirectory ([string]$manifest['texturesFolder'])
        }
    }

    $effectiveCharacterJsonPath = if ($CharacterJsonPath) { $CharacterJsonPath } else { $manifestCharacterJsonPath }
    $effectiveTexturesDir = if ($TexturesDir) { $TexturesDir } else { $manifestTexturesDir }

    if (-not $effectiveCharacterJsonPath) {
        throw 'CharacterJsonPath was not provided and could not be derived from the manifest'
    }
    if (-not $effectiveTexturesDir) {
        throw 'TexturesDir was not provided and could not be derived from the manifest'
    }

    $resolvedCharacterJsonPath = (Resolve-Path $effectiveCharacterJsonPath).Path
    $resolvedTexturesDir = (Resolve-Path $effectiveTexturesDir).Path
    $resolvedOutputPath = Resolve-UserPath -Path $OutputPath

    if ((Test-Path $resolvedOutputPath) -and -not $Force) {
        throw "Output file already exists. Use -Force to overwrite: $resolvedOutputPath"
    }

    $targetDescription = if ($resolvedManifestPath) { 'Pack .znelchar file using manifest and resolved inputs' } else { 'Pack .znelchar file using explicit inputs' }
    if (-not $PSCmdlet.ShouldProcess($resolvedOutputPath, $targetDescription)) {
        return
    }

    Write-Stage -Prefix 'pack' -Message "Loading character data from $resolvedCharacterJsonPath"
    $character = (Get-Content -Raw -Path $resolvedCharacterJsonPath | ConvertFrom-Json -AsHashtable -Depth 100)

    $resolvedCustomIconPath = $null
    if ($null -ne $manifest -and $manifest.ContainsKey('customIcon') -and $null -ne $manifest['customIcon']) {
        $manifestCustomIcon = $manifest['customIcon']
        if ($manifestCustomIcon -is [hashtable] -and $manifestCustomIcon.ContainsKey('outputFile') -and -not [string]::IsNullOrWhiteSpace([string]$manifestCustomIcon['outputFile'])) {
            $candidateIconPath = Join-Path $manifestDirectory ([string]$manifestCustomIcon['outputFile'])
            $resolvedCustomIconPath = Resolve-PathOrNull -Path $candidateIconPath
            if (-not $resolvedCustomIconPath) {
                throw "Manifest customIcon file was not found: $candidateIconPath"
            }
        }
    }

    if (-not $resolvedCustomIconPath -and -not $character.ContainsKey('customIconData')) {
        $characterDir = [System.IO.Path]::GetDirectoryName($resolvedCharacterJsonPath)
        $customIconCandidate = Get-ChildItem -File -Path $characterDir -Filter 'customIcon.*' -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -First 1
        if ($null -ne $customIconCandidate) {
            $resolvedCustomIconPath = $customIconCandidate.FullName
        }
    }

    if ($resolvedCustomIconPath) {
        $customIconBytes = [System.IO.File]::ReadAllBytes($resolvedCustomIconPath)
        $character['customIconData'] = [System.Convert]::ToBase64String($customIconBytes)
    }

    $character = Convert-CharacterForPacking -Character $character
    $characterCompactJson = $character | ConvertTo-Json -Compress -Depth 100

    $textureDescriptors = @()
    if ($null -ne $manifest -and $manifest.ContainsKey('textures') -and $null -ne $manifest['textures']) {
        foreach ($entry in @($manifest['textures'])) {
            $textureName = if ($entry.ContainsKey('textureName')) { [string]$entry['textureName'] } else { '' }
            $outputFile = if ($entry.ContainsKey('outputFile')) { [string]$entry['outputFile'] } else { '' }

            if (-not [string]::IsNullOrWhiteSpace($outputFile)) {
                $textureDescriptors += [ordered]@{ textureName = $textureName; fileName = $outputFile }
            }
            elseif (-not [string]::IsNullOrWhiteSpace($textureName) -and $manifest.ContainsKey('metadataOnly') -and [bool]$manifest['metadataOnly']) {
                $textureDescriptors += [ordered]@{ textureName = $textureName; fileName = [System.IO.Path]::GetFileName($textureName) }
            }
            else {
                throw "Manifest texture entry for '$textureName' is missing outputFile"
            }
        }
    }

    if ($textureDescriptors.Count -eq 0) {
        $files = Get-ChildItem -File -Path $resolvedTexturesDir | Sort-Object Name
        foreach ($f in $files) {
            $textureDescriptors += [ordered]@{ textureName = $f.Name; fileName = $f.Name }
        }
    }

    if ($null -ne $manifest) {
        Validate-ManifestTextureEntries -Descriptors $textureDescriptors -TexturesRoot $resolvedTexturesDir -Manifest $manifest
    }

    Write-Stage -Prefix 'pack' -Message "Packing $($textureDescriptors.Count) texture entries"
    $packStats = Write-ZnelcharFile -Path $resolvedOutputPath -CharacterCompactJson $characterCompactJson -TextureDescriptors $textureDescriptors -TexturesRoot $resolvedTexturesDir

    Write-Stage -Prefix 'pack' -Message 'Completed'
    return [ordered]@{
        outputFile = $resolvedOutputPath
        textureCount = $textureDescriptors.Count
        usedManifest = [bool]$resolvedManifestPath
        totalTextureBytesRead = $packStats.totalTextureBytesRead
        elapsedSeconds = $packStats.elapsedSeconds
        averageRate = $packStats.averageRate
    }
}
