# package-unified.ps1
# Builds the Unified TVS Tools bundle (Phase 4) producing both -full and -core variants.
#
# Usage (from tools/tvsm/build/ directory):
#   ./package-unified.ps1
#   ./package-unified.ps1 -OutputRoot ../dist -FullRuntimeVersion '7.5.0'
#   ./package-unified.ps1 -WhatIf
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$OutputRoot = "$PSScriptRoot/../dist",
    [switch]$Clean,
    [switch]$WriteChecksums = $true,
    [string]$FullRuntimeVersion = '7.5.0',
    [string]$FullRuntimeRid = 'win-x64',
    [string]$PortableRuntimeZipPath,
    [switch]$DownloadPortableRuntime,
    [string]$ReleaseRepositoryOwner,
    [string]$ReleaseRepositoryName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------------------------------------

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
    if (-not (Test-Path -LiteralPath $packageJsonPath)) { return '0.0.0' }
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

function Copy-ModuleContent {
    param(
        [Parameter(Mandatory = $true)][string]$SourceModuleDir,
        [Parameter(Mandatory = $true)][string]$DestinationModulesDir,
        [Parameter(Mandatory = $true)][string]$ModuleName
    )
    $dest = Join-Path $DestinationModulesDir $ModuleName
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item -Path (Join-Path $SourceModuleDir '*') -Destination $dest -Recurse -Force
    Write-Stage "Copied module: $ModuleName"
}

function Invoke-ModulePackageScript {
    param(
        [Parameter(Mandatory = $true)][string]$PackageScriptPath,
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [string]$ToolName
    )
    if (-not (Test-Path -LiteralPath $PackageScriptPath)) {
        Write-Warning "Package script not found for $ToolName`: $PackageScriptPath"
        return $false
    }
    Write-Stage "Invoking package script for $ToolName..."
    
    # Check if the script supports the znelchar-style parameters
    $scriptContent = Get-Content -Raw -Path $PackageScriptPath
    $hasCreateModule = $scriptContent -match 'CreateModule'
    
    if ($hasCreateModule) {
        # Script supports the full parameter set (znelchar-style)
        & $PackageScriptPath -OutputRoot $OutputDir -CreateModule:$true -CreateCore:$false -CreatePortable:$false -Clean:$false -WriteChecksums:$false
    } else {
        # Script has simpler parameter set (tvs-environment-style)
        & $PackageScriptPath -OutputRoot $OutputDir -Clean:$false -WriteChecksums:$false
    }
    return $true
}

function Get-StagingModulePath {
    param(
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [Parameter(Mandatory = $true)][string]$ModuleName
    )
    # The package script creates a staging directory with the module content
    $stagingModule = Join-Path $OutputDir 'staging-module' 'modules' $ModuleName
    if (Test-Path -LiteralPath $stagingModule) {
        return $stagingModule
    }
    # Alternative: some scripts might put it directly
    $altPath = Join-Path $OutputDir 'staging-module' $ModuleName
    if (Test-Path -LiteralPath $altPath) {
        return $altPath
    }
    return $null
}

function New-VersionJson {
    param(
        [Parameter(Mandatory = $true)][string]$BundleVersion,
        [Parameter(Mandatory = $true)][string]$Variant,
        [Parameter(Mandatory = $true)][hashtable]$Components
    )
    $obj = [ordered]@{
        bundleVersion = $BundleVersion
        variant       = $Variant
        components    = $Components
    }
    return $obj | ConvertTo-Json -Depth 10
}

function New-Launchers {
    param(
        [Parameter(Mandatory = $true)][string]$LaunchersDir,
        [Parameter(Mandatory = $true)][string]$Variant  # 'full' or 'core'
    )
    # Per-tool launcher definitions:
    #   key   = launcher base name (inspect, extract, ...)
    #   value = relative path to the PowerShell script from the bundle root
    $tools = [ordered]@{
        'inspect'     = 'modules/Znelchar.Tools/Public/Get-ZnelcharInfo.ps1'
        'extract'     = 'modules/Znelchar.Tools/Public/Expand-ZnelcharData.ps1'
        'expand'      = 'modules/Znelchar.Tools/Public/Expand-ZnelcharData.ps1'
        'compress'    = 'modules/Znelchar.Tools/Public/Compress-ZnelcharData.ps1'
        'pack'        = 'modules/Znelchar.Tools/Public/Compose-ZnelcharPreset.ps1'
        'dump-yaml'   = 'modules/Znelchar.Tools/Public/Convert-ZnelcharToYaml.ps1'
        'verify'      = 'modules/Znelchar.Tools/Public/Test-ZnelcharFile.ps1'
        'update'      = 'tvsm.ps1 update apply'   # special: calls tvsm.ps1 with arguments
    }

    New-Item -ItemType Directory -Path $LaunchersDir -Force | Out-Null

    foreach ($entry in $tools.GetEnumerator()) {
        $verb   = $entry.Key
        $target = $entry.Value

        # ---- Windows .cmd launcher (full variant only) ----
        if ($Variant -eq 'full') {
            # full variant: use bundled pwsh.exe
            # Use single-quoted here-string to avoid PowerShell variable expansion
            $cmdContent = @'
@echo off
setlocal enabledelayedexpansion
set BUNDLE_DIR=%~dp0..
set PWSH_EXE=%BUNDLE_DIR%\runtime\pwsh\pwsh.exe
if exist "%PWSH_EXE%" (
  "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "& '%BUNDLE_DIR%\$TARGET_PLACEHOLDER' %*"
) else (
  pwsh -NoProfile -ExecutionPolicy Bypass -Command "& '%BUNDLE_DIR%\$TARGET_PLACEHOLDER' %*"
)
exit /b %ERRORLEVEL%
'@
            $cmdContent = $cmdContent.Replace('$TARGET_PLACEHOLDER', $target)
            [System.IO.File]::WriteAllText((Join-Path $LaunchersDir "$verb.cmd"), $cmdContent, [System.Text.UTF8Encoding]::new($false))
        }

        # ---- Linux/macOS .sh launcher (core variant only) ----
        if ($Variant -eq 'core') {
            # core variant: assume pwsh is on PATH
            $shContent = @'
#!/usr/bin/env bash
set -euo pipefail
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -Command "& '$BUNDLE_DIR/$TARGET_PLACEHOLDER' \"$@\""
else
  echo "Error: pwsh not found on PATH. Please install PowerShell." >&2
  exit 1
fi
'@
            $shContent = $shContent.Replace('$TARGET_PLACEHOLDER', $target)
            [System.IO.File]::WriteAllText((Join-Path $LaunchersDir "$verb.sh"), $shContent, [System.Text.UTF8Encoding]::new($false))
        }
    }

    Write-Stage "Created $Variant launchers in $LaunchersDir"
}

# ------------------------------------------------------------------------------------------------
# Main build logic
# ------------------------------------------------------------------------------------------------

$repoRoot = Get-RepoRoot
$bundleVersion = Get-ToolVersion -RepoRoot $repoRoot

Write-Stage "Building Unified TVS Tools Bundle v$bundleVersion"
Write-Stage "Repo root: $repoRoot"

# Resolve output root
$outputRoot = (Resolve-Path $OutputRoot -ErrorAction SilentlyContinue)?.Path ?? $OutputRoot
if ($Clean -and (Test-Path -LiteralPath $outputRoot)) {
    Write-Stage "Cleaning output directory: $outputRoot"
    Remove-Item -LiteralPath $outputRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

# ------------------------------------------------------------------------------------------------
# Step 1: Create staging directory
# ------------------------------------------------------------------------------------------------
$stagingDir = Join-Path $outputRoot 'staging-unified'
Reset-Directory -Path $stagingDir

$stageModulesDir = Join-Path $stagingDir 'modules'
New-Item -ItemType Directory -Path $stageModulesDir -Force | Out-Null

# ------------------------------------------------------------------------------------------------
# Step 2: Call existing package scripts to get module content
# ------------------------------------------------------------------------------------------------

# Znelchar.Tools
$znelcharPackageScript = Join-Path $repoRoot '..' 'znelchar' 'build' 'package.ps1'
$znelcharDist = Join-Path $outputRoot 'znelchar-temp'
Reset-Directory -Path $znelcharDist
if (Test-Path -LiteralPath $znelcharPackageScript) {
    Invoke-ModulePackageScript -PackageScriptPath $znelcharPackageScript -OutputDir $znelcharDist -ToolName 'Znelchar.Tools'
    $znelcharStagingModule = Get-StagingModulePath -OutputDir $znelcharDist -ModuleName 'Znelchar.Tools'
    if ($null -ne $znelcharStagingModule) {
        Copy-ModuleContent -SourceModuleDir $znelcharStagingModule -DestinationModulesDir $stageModulesDir -ModuleName 'Znelchar.Tools'
    } else {
        Write-Warning "Could not find Znelchar.Tools staging module in $znelcharDist"
    }
} else {
    Write-Warning "Znelchar.Tools package script not found at: $znelcharPackageScript"
}

# TVSSave.Tools
$tvsSavePackageScript = Join-Path $repoRoot '..' 'tvs-save' 'build' 'package.ps1'
$tvsSaveDist = Join-Path $outputRoot 'tvs-save-temp'
Reset-Directory -Path $tvsSaveDist
if (Test-Path -LiteralPath $tvsSavePackageScript) {
    Invoke-ModulePackageScript -PackageScriptPath $tvsSavePackageScript -OutputDir $tvsSaveDist -ToolName 'TVSSave.Tools'
    $tvsSaveStagingModule = Get-StagingModulePath -OutputDir $tvsSaveDist -ModuleName 'TVSSave.Tools'
    if ($null -ne $tvsSaveStagingModule) {
        Copy-ModuleContent -SourceModuleDir $tvsSaveStagingModule -DestinationModulesDir $stageModulesDir -ModuleName 'TVSSave.Tools'
    } else {
        Write-Warning "Could not find TVSSave.Tools staging module in $tvsSaveDist"
    }
} else {
    Write-Warning "TVSSave.Tools package script not found at: $tvsSavePackageScript"
}

# TVS.Environment
$tvsEnvPackageScript = Join-Path $repoRoot '..' 'tvs-environment' 'build' 'package.ps1'
$tvsEnvDist = Join-Path $outputRoot 'tvs-environment-temp'
Reset-Directory -Path $tvsEnvDist
if (Test-Path -LiteralPath $tvsEnvPackageScript) {
    Invoke-ModulePackageScript -PackageScriptPath $tvsEnvPackageScript -OutputDir $tvsEnvDist -ToolName 'TVS.Environment'
    $tvsEnvStagingModule = Get-StagingModulePath -OutputDir $tvsEnvDist -ModuleName 'TVS.Environment'
    if ($null -ne $tvsEnvStagingModule) {
        Copy-ModuleContent -SourceModuleDir $tvsEnvStagingModule -DestinationModulesDir $stageModulesDir -ModuleName 'TVS.Environment'
    } else {
        Write-Warning "Could not find TVS.Environment staging module in $tvsEnvDist"
    }
} else {
    Write-Warning "TVS.Environment package script not found at: $tvsEnvPackageScript"
}

# TVSM (this module)
$tvsmModuleDir = Join-Path $repoRoot 'module' 'TVSM'
Copy-ModuleContent -SourceModuleDir $tvsmModuleDir -DestinationModulesDir $stageModulesDir -ModuleName 'TVSM'

# ------------------------------------------------------------------------------------------------
# Step 3: Copy tvsm.ps1 entry-point
# ------------------------------------------------------------------------------------------------
Copy-Item -Path (Join-Path $repoRoot 'tvsm.ps1') -Destination (Join-Path $stagingDir 'tvsm.ps1') -Force
Write-Stage 'Copied tvsm.ps1 entry-point'

# ------------------------------------------------------------------------------------------------
# Step 4: Create launchers directory (shared structure, populated per-variant later)
# ------------------------------------------------------------------------------------------------
$launchersDir = Join-Path $stagingDir 'launchers'
New-Item -ItemType Directory -Path $launchersDir -Force | Out-Null

# ------------------------------------------------------------------------------------------------
# Step 5: Build -core variant (runtime-free, cross-platform)
# ------------------------------------------------------------------------------------------------
Write-Stage 'Building -core variant...'

$coreStaging = Join-Path $outputRoot 'staging-core'
Reset-Directory -Path $coreStaging

# Copy modules and tvsm.ps1
Copy-Item -Path (Join-Path $stagingDir 'modules') -Destination (Join-Path $coreStaging 'modules') -Recurse -Force
Copy-Item -Path (Join-Path $stagingDir 'tvsm.ps1') -Destination (Join-Path $coreStaging 'tvsm.ps1') -Force

# Create core launchers (Linux/macOS .sh only)
$coreLaunchersDir = Join-Path $coreStaging 'launchers'
New-Launchers -LaunchersDir $coreLaunchersDir -Variant 'core'

# VERSION.json for core
$coreComponents = [ordered]@{
    'TVSM'           = (Get-ToolVersion -RepoRoot $repoRoot)
    'Znelchar.Tools' = if (Test-Path -LiteralPath $znelcharPackageScript) { (Get-ToolVersion -RepoRoot (Join-Path $repoRoot '..' 'znelchar')) } else { '0.0.0' }
    'TVSSave.Tools'  = if (Test-Path -LiteralPath $tvsSavePackageScript) { (Get-ToolVersion -RepoRoot (Join-Path $repoRoot '..' 'tvs-save')) } else { '0.0.0' }
    'TVS.Environment' = if (Test-Path -LiteralPath $tvsEnvPackageScript) { (Get-ToolVersion -RepoRoot (Join-Path $repoRoot '..' 'tvs-environment')) } else { '0.0.0' }
}
$coreVersionJson = New-VersionJson -BundleVersion $bundleVersion -Variant 'core' -Components $coreComponents
$coreVersionPath = Join-Path $coreStaging 'VERSION.json'
[System.IO.File]::WriteAllText($coreVersionPath, $coreVersionJson, [System.Text.UTF8Encoding]::new($false))
Write-Stage "Created VERSION.json for -core"

# Zip the -core variant
$coreZipName = "tvs-tools-core-$bundleVersion.zip"
$coreZipPath = Join-Path $outputRoot $coreZipName
if (Test-Path -LiteralPath $coreZipPath) { Remove-Item -LiteralPath $coreZipPath -Force }
Compress-Archive -Path (Join-Path $coreStaging '*') -DestinationPath $coreZipPath -Force
Write-Stage "Created: $coreZipName"

# ------------------------------------------------------------------------------------------------
# Step 6: Build -full variant (includes bundled pwsh runtime)
# ------------------------------------------------------------------------------------------------
Write-Stage 'Building -full variant...'

$fullStaging = Join-Path $outputRoot 'staging-full'
Reset-Directory -Path $fullStaging

# Copy modules and tvsm.ps1
Copy-Item -Path (Join-Path $stagingDir 'modules') -Destination (Join-Path $fullStaging 'modules') -Recurse -Force
Copy-Item -Path (Join-Path $stagingDir 'tvsm.ps1') -Destination (Join-Path $fullStaging 'tvsm.ps1') -Force

# Create full launchers (Windows .cmd only)
$fullLaunchersDir = Join-Path $fullStaging 'launchers'
New-Launchers -LaunchersDir $fullLaunchersDir -Variant 'full'

# Download or copy bundled pwsh runtime
$fullRuntimeDir = Join-Path $fullStaging 'runtime' 'pwsh'
if ($DownloadPortableRuntime -or $PortableRuntimeZipPath) {
    New-Item -ItemType Directory -Path $fullRuntimeDir -Force | Out-Null
    if ($PortableRuntimeZipPath -and (Test-Path -LiteralPath $PortableRuntimeZipPath)) {
        Write-Stage "Copying pwsh runtime from $PortableRuntimeZipPath"
        # Extract from provided zip
        $tempExpand = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempExpand -Force | Out-Null
        try {
            Expand-Archive -LiteralPath $PortableRuntimeZipPath -DestinationPath $tempExpand -Force
            $pwshExe = Get-ChildItem -Path $tempExpand -Filter 'pwsh.exe' -File -Recurse | Select-Object -First 1
            if ($null -eq $pwshExe) { throw "Could not find pwsh.exe in runtime zip: $PortableRuntimeZipPath" }
            $runtimeRoot = Split-Path -Parent $pwshExe.FullName
            Copy-Item -Path (Join-Path $runtimeRoot '*') -Destination $fullRuntimeDir -Recurse -Force
        } finally {
            if (Test-Path -LiteralPath $tempExpand) { Remove-Item -LiteralPath $tempExpand -Recurse -Force }
        }
    } elseif ($DownloadPortableRuntime) {
        Write-Stage "Downloading pwsh runtime v$FullRuntimeVersion ($FullRuntimeRid)..."
        $fileName = "PowerShell-$FullRuntimeVersion-$FullRuntimeRid.zip"
        $url = "https://github.com/PowerShell/PowerShell/releases/download/v$FullRuntimeVersion/$fileName"
        $tempZip = Join-Path $outputRoot $fileName
        try {
            Invoke-WebRequest -Uri $url -OutFile $tempZip
            # Extract
            $tempExpand = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $tempExpand -Force | Out-Null
            try {
                Expand-Archive -LiteralPath $tempZip -DestinationPath $tempExpand -Force
                $pwshExe = Get-ChildItem -Path $tempExpand -Filter 'pwsh.exe' -File -Recurse | Select-Object -First 1
                if ($null -eq $pwshExe) { throw "Could not find pwsh.exe in downloaded runtime zip" }
                $runtimeRoot = Split-Path -Parent $pwshExe.FullName
                Copy-Item -Path (Join-Path $runtimeRoot '*') -Destination $fullRuntimeDir -Recurse -Force
            } finally {
                if (Test-Path -LiteralPath $tempExpand) { Remove-Item -LiteralPath $tempExpand -Recurse -Force }
            }
        } finally {
            if (Test-Path -LiteralPath $tempZip) { Remove-Item -LiteralPath $tempZip -Force }
        }
    }
    Write-Stage "Bundled pwsh runtime v$FullRuntimeVersion"
} else {
    Write-Stage 'Skipping pwsh runtime bundling (use -DownloadPortableRuntime or -PortableRuntimeZipPath to include it)'
}

# VERSION.json for full
$fullComponents = [ordered]@{
    'TVSM'           = (Get-ToolVersion -RepoRoot $repoRoot)
    'Znelchar.Tools' = if (Test-Path -LiteralPath $znelcharPackageScript) { (Get-ToolVersion -RepoRoot (Join-Path $repoRoot '..' 'znelchar')) } else { '0.0.0' }
    'TVSSave.Tools'  = if (Test-Path -LiteralPath $tvsSavePackageScript) { (Get-ToolVersion -RepoRoot (Join-Path $repoRoot '..' 'tvs-save')) } else { '0.0.0' }
    'TVS.Environment' = if (Test-Path -LiteralPath $tvsEnvPackageScript) { (Get-ToolVersion -RepoRoot (Join-Path $repoRoot '..' 'tvs-environment')) } else { '0.0.0' }
    'pwsh'           = $FullRuntimeVersion
}
$fullVersionJson = New-VersionJson -BundleVersion $bundleVersion -Variant 'full' -Components $fullComponents
$fullVersionPath = Join-Path $fullStaging 'VERSION.json'
[System.IO.File]::WriteAllText($fullVersionPath, $fullVersionJson, [System.Text.UTF8Encoding]::new($false))
Write-Stage "Created VERSION.json for -full"

# Zip the -full variant
$fullZipName = "tvs-tools-full-$bundleVersion.zip"
$fullZipPath = Join-Path $outputRoot $fullZipName
if (Test-Path -LiteralPath $fullZipPath) { Remove-Item -LiteralPath $fullZipPath -Force }
Compress-Archive -Path (Join-Path $fullStaging '*') -DestinationPath $fullZipPath -Force
Write-Stage "Created: $fullZipName"

# ------------------------------------------------------------------------------------------------
# Step 7: Generate SHA256SUMS.txt
# ------------------------------------------------------------------------------------------------
if ($WriteChecksums) {
    $sumsPath = Join-Path $outputRoot 'SHA256SUMS.txt'
    $lines = @()
    foreach ($zipPath in @($coreZipPath, $fullZipPath)) {
        if (Test-Path -LiteralPath $zipPath) {
            $sha256 = Get-FileSha256 -Path $zipPath
            $lines += "$sha256  $(Split-Path -Leaf $zipPath)"
            Write-Stage "SHA256 ($((Split-Path -Leaf $zipPath))): $sha256"
        }
    }
    $lines | Set-Content -Path $sumsPath -Encoding UTF8
    Write-Stage "Checksums written to SHA256SUMS.txt"
}

# ------------------------------------------------------------------------------------------------
# Step 8: Cleanup temporary directories
# ------------------------------------------------------------------------------------------------
Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $coreStaging -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $fullStaging -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $znelcharDist -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $tvsSaveDist -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $tvsEnvDist -Recurse -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------------------------------------------
# Step 9: Release manifest (optional)
# ------------------------------------------------------------------------------------------------
if ($ReleaseRepositoryOwner -and $ReleaseRepositoryName) {
    $manifestPath = Join-Path $outputRoot 'tvs-tools-release-manifest.json'
    $artifacts = @()
    foreach ($zipPath in @($coreZipPath, $fullZipPath)) {
        if (Test-Path -LiteralPath $zipPath) {
            $sha256 = Get-FileSha256 -Path $zipPath
            $fileSize = (Get-Item -LiteralPath $zipPath).Length
            $artifacts += [ordered]@{
                variant  = if ($zipPath -eq $coreZipPath) { 'core' } else { 'full' }
                fileName = Split-Path -Leaf $zipPath
                sha256   = $sha256
                size     = $fileSize
            }
        }
    }
    $manifest = [ordered]@{
        schemaVersion = 1
        toolName      = 'tvs-tools'
        version       = $bundleVersion
        channel       = 'stable'
        releaseUrl    = "https://github.com/$ReleaseRepositoryOwner/$ReleaseRepositoryName/releases/latest"
        artifacts     = $artifacts
    }
    $manifest | ConvertTo-Json -Depth 10 |
        ForEach-Object { [System.IO.File]::WriteAllText($manifestPath, $_, [System.Text.UTF8Encoding]::new($false)) }
    Write-Stage "Release manifest: $manifestPath"
}

Write-Stage "Done. Output: $outputRoot"
Write-Host ""
Write-Host "Artifacts produced:"
if (Test-Path -LiteralPath $coreZipPath) { Write-Host "  - $coreZipName" }
if (Test-Path -LiteralPath $fullZipPath) { Write-Host "  - $fullZipName" }
if (Test-Path -LiteralPath $sumsPath) { Write-Host "  - SHA256SUMS.txt" }
