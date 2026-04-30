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

$repoRoot  = Get-RepoRoot
$version   = Get-ToolVersion -RepoRoot $repoRoot
$moduleDir = Join-Path $repoRoot 'module' 'TVSM'

Write-Stage "Building TVSM module package v$version"

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

# Bundle layout:
#   tvsm.ps1           — entry-point launcher
#   modules/
#     TVSM/            — this module
#     TVS.Environment/ — required dependency
#     PwshSpectreConsole/ — required dependency (installed separately; copied if present)
$stageModulesDir = Join-Path $stagingDir 'modules'
New-Item -ItemType Directory -Path $stageModulesDir -Force | Out-Null

# Copy TVSM module
$stageModule = Join-Path $stageModulesDir 'TVSM'
New-Item -ItemType Directory -Path $stageModule -Force | Out-Null
Copy-Item -Path (Join-Path $moduleDir '*') -Destination $stageModule -Recurse -Force

# Copy TVS.Environment module from sibling package
$tvseModuleDir = Join-Path $repoRoot '..' 'tvs-environment' 'module' 'TVS.Environment'
if (Test-Path -LiteralPath $tvseModuleDir) {
    $stageTVSE = Join-Path $stageModulesDir 'TVS.Environment'
    New-Item -ItemType Directory -Path $stageTVSE -Force | Out-Null
    Copy-Item -Path (Join-Path $tvseModuleDir '*') -Destination $stageTVSE -Recurse -Force
    Write-Stage 'Bundled: TVS.Environment'
} else {
    Write-Warning "TVS.Environment module not found at expected path: $tvseModuleDir"
    Write-Warning 'Bundle will require TVS.Environment to be on PSModulePath at runtime.'
}

# Copy PwshSpectreConsole if available in the local PS module cache
$spectreModule = Get-Module -ListAvailable -Name PwshSpectreConsole | Select-Object -First 1
if ($spectreModule) {
    $stageSpectre = Join-Path $stageModulesDir 'PwshSpectreConsole'
    New-Item -ItemType Directory -Path $stageSpectre -Force | Out-Null
    Copy-Item -Path (Join-Path $spectreModule.ModuleBase '*') -Destination $stageSpectre -Recurse -Force
    Write-Stage "Bundled: PwshSpectreConsole $($spectreModule.Version)"
} else {
    Write-Warning 'PwshSpectreConsole not found in installed modules; it will be auto-installed at runtime.'
}

# Copy entry-point launcher
Copy-Item -Path (Join-Path $repoRoot 'tvsm.ps1') -Destination (Join-Path $stagingDir 'tvsm.ps1') -Force

# Zip it
$zipName = "tvsm-module-$version.zip"
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

# Release manifest
$manifestPath = Join-Path $outputRoot 'tvsm-release-manifest.json'
$sha256Final  = Get-FileSha256 -Path $zipPath
$fileSize     = (Get-Item -LiteralPath $zipPath).Length

$manifest = [ordered]@{
    schemaVersion = 1
    toolName      = 'tvsm'
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
