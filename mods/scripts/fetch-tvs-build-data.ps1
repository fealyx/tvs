param(
    [string]$Owner = 'fealyx',
    [string]$Repository = 'tvs-build-data',
    [string]$Manifest = 'current',
    [string]$Token = $env:TVS_BUILD_DATA_TOKEN,
    [string]$DestinationRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modsDir = Join-Path $repoRoot 'mods'
$gameDirPropsPath = Join-Path $modsDir 'GameDir.props'

if (-not $DestinationRoot) {
    $DestinationRoot = Join-Path $modsDir '.local' 'game-refs'
}

if (-not $Token) {
    throw 'TVS_BUILD_DATA_TOKEN is required to download private TVS build data.'
}

function New-GitHubHeaders {
    param([string]$Accept)

    return @{
        Authorization          = "Bearer $Token"
        Accept                 = $Accept
        'User-Agent'           = 'tvs-build-data-fetcher'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
}

function Get-ManifestObject {
    param([string]$ManifestName)

    $manifestPath = if ($ManifestName.EndsWith('.json')) { $ManifestName } else { "$ManifestName.json" }
    $uri = "https://api.github.com/repos/$Owner/$Repository/contents/manifests/$manifestPath"
    $response = Invoke-RestMethod -Uri $uri -Headers (New-GitHubHeaders -Accept 'application/vnd.github+json')
    $content = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($response.content))
    return $content | ConvertFrom-Json
}

function Get-ReleaseAsset {
    param(
        [object]$Release,
        [string]$AssetName
    )

    $asset = $Release.assets | Where-Object { $_.name -eq $AssetName } | Select-Object -First 1
    if (-not $asset) {
        throw "Release asset '$AssetName' was not found on tag '$($Release.tag_name)'."
    }

    return $asset
}

function Get-ExpectedChecksum {
    param(
        [string]$ChecksumPath,
        [string]$ExpectedFileName
    )

    $line = (Get-Content -Path $ChecksumPath -Raw).Trim()
    $parts = $line -split '\s+\*', 2
    if ($parts.Count -ne 2) {
        throw "Invalid checksum file format: $ChecksumPath"
    }

    if ($parts[1] -ne $ExpectedFileName) {
        throw "Checksum file references '$($parts[1])' but expected '$ExpectedFileName'."
    }

    return $parts[0].ToLowerInvariant()
}

function Write-GameDirProps {
    param([string]$ManagedDir)

    $content = @"
<Project>
  <PropertyGroup>
    <TVSManagedDir>$ManagedDir</TVSManagedDir>
    <TVSAutoDeployOnBuild>false</TVSAutoDeployOnBuild>
  </PropertyGroup>
</Project>
"@

    Set-Content -Path $gameDirPropsPath -Value $content -Encoding utf8
}

$manifestObject = Get-ManifestObject -ManifestName $Manifest
$releaseUri = "https://api.github.com/repos/$Owner/$Repository/releases/tags/$($manifestObject.releaseTag)"
$release = Invoke-RestMethod -Uri $releaseUri -Headers (New-GitHubHeaders -Accept 'application/vnd.github+json')

$archiveAsset = Get-ReleaseAsset -Release $release -AssetName $manifestObject.assetName
$checksumAsset = Get-ReleaseAsset -Release $release -AssetName $manifestObject.sha256AssetName

$downloadRoot = Join-Path $modsDir '.local' 'downloads' 'tvs-build-data'
$extractRoot = Join-Path $modsDir '.local' 'extract' 'tvs-build-data'
$managedDir = Join-Path $DestinationRoot $manifestObject.archiveRoot
$archivePath = Join-Path $downloadRoot $manifestObject.assetName
$checksumPath = Join-Path $downloadRoot $manifestObject.sha256AssetName

New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null
New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null

Invoke-WebRequest -Uri $archiveAsset.url -Headers (New-GitHubHeaders -Accept 'application/octet-stream') -OutFile $archivePath
Invoke-WebRequest -Uri $checksumAsset.url -Headers (New-GitHubHeaders -Accept 'application/octet-stream') -OutFile $checksumPath

$expectedHash = Get-ExpectedChecksum -ChecksumPath $checksumPath -ExpectedFileName $manifestObject.assetName
$actualHash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($expectedHash -ne $actualHash) {
    throw "Checksum mismatch for downloaded archive '$archivePath'."
}

if (Test-Path $extractRoot) {
    Remove-Item -Path $extractRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
Expand-Archive -Path $archivePath -DestinationPath $extractRoot -Force

$expandedManagedDir = Join-Path $extractRoot $manifestObject.archiveRoot
if (-not (Test-Path $expandedManagedDir)) {
    throw "Archive did not contain expected root '$($manifestObject.archiveRoot)'."
}

if (Test-Path $managedDir) {
    Remove-Item -Path $managedDir -Recurse -Force
}

Move-Item -Path $expandedManagedDir -Destination $managedDir
Write-GameDirProps -ManagedDir $managedDir

Write-Host "Fetched TVS managed refs manifest '$($manifestObject.manifestName)'"
Write-Host "Release tag: $($manifestObject.releaseTag)"
Write-Host "Managed dir: $managedDir"
Write-Host "Generated: $gameDirPropsPath"
