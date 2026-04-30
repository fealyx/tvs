[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$OutputRoot = "$PSScriptRoot/../dist",
    [switch]$Clean,
    [switch]$WriteChecksums = $true,
    [string]$ReleaseRepositoryOwner,
    [string]$ReleaseRepositoryName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Stage {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "[build] $Message"
}

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-ToolVersion {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)
    $packageJsonPath = Join-Path $RepoRoot 'package.json'
    $pkg = Get-Content -Raw -Path $packageJsonPath | ConvertFrom-Json
    $v = [string]$pkg.version
    return $(if ([string]::IsNullOrWhiteSpace($v)) { '0.0.0' } else { $v })
}

function Reset-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Get-FileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

# ---------------------------------------------------------------------------

$repoRoot   = Get-RepoRoot
$version    = Get-ToolVersion -RepoRoot $repoRoot
$moduleDir  = Join-Path $repoRoot 'module' 'TVS.Environment'

Write-Stage "Building TVS.Environment module package v$version"

$outputRoot = (Resolve-Path $OutputRoot -ErrorAction SilentlyContinue)?.Path ?? $OutputRoot
if ($Clean -and (Test-Path -LiteralPath $outputRoot)) {
    Write-Stage "Cleaning output directory: $outputRoot"
    Remove-Item -LiteralPath $outputRoot -Recurse -Force
}
if (-not (Test-Path -LiteralPath $outputRoot)) {
    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
}

$stagingDir = Join-Path $outputRoot 'staging-module'
Reset-Directory -Path $stagingDir

# Copy module contents into staging
$stageModule = Join-Path $stagingDir 'TVS.Environment'
New-Item -ItemType Directory -Path $stageModule -Force | Out-Null
Copy-Item -Path (Join-Path $moduleDir '*') -Destination $stageModule -Recurse -Force

# Zip it
$zipName = "tvs-environment-module-$version.zip"
$zipPath = Join-Path $outputRoot $zipName

if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path $stagingDir\* -DestinationPath $zipPath -Force
Write-Stage "Created: $zipName"

# Checksums
if ($WriteChecksums) {
    $sha256 = Get-FileSha256 -Path $zipPath
    $sumsPath = Join-Path $outputRoot 'SHA256SUMS.txt'
    "$sha256  $zipName" | Set-Content -Path $sumsPath -Encoding UTF8
    Write-Stage "SHA256: $sha256"
}

# Release manifest (optional, for update tooling)
$manifestPath = Join-Path $outputRoot 'tvs-environment-release-manifest.json'
$sha256Final  = Get-FileSha256 -Path $zipPath
$fileSize     = (Get-Item -LiteralPath $zipPath).Length

$manifest = [ordered]@{
    schemaVersion = 1
    toolName      = 'tvs-environment'
    version       = $version
    channel       = 'stable'
    artifacts     = @(
        [ordered]@{
            variant  = 'module'
            fileName = $zipName
            sha256   = $sha256Final
            size     = $fileSize
        }
    )
}

if ($ReleaseRepositoryOwner -and $ReleaseRepositoryName) {
    $manifest['releaseUrl'] = "https://github.com/$ReleaseRepositoryOwner/$ReleaseRepositoryName/releases/latest"
}

$manifest | ConvertTo-Json -Depth 10 |
    ForEach-Object { [System.IO.File]::WriteAllText($manifestPath, $_, [System.Text.UTF8Encoding]::new($false)) }
Write-Stage "Manifest: $manifestPath"

# Cleanup staging
Remove-Item -LiteralPath $stagingDir -Recurse -Force

Write-Stage "Done. Output: $outputRoot"
