[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$OutputRoot = "$PSScriptRoot/../dist",
    [switch]$CreateModule = $true,
    [switch]$CreateCore = $true,
    [switch]$CreatePortable = $true,
    [switch]$CreateReleaseManifest = $true,
    [switch]$WriteChecksums = $true,
    [string]$ReleaseChannel = 'stable',
    [string]$ReleaseRepositoryOwner,
    [string]$ReleaseRepositoryName,
    [switch]$Clean,
    [string]$PortableRuntimeZipPath,
    [switch]$DownloadPortableRuntime,
    [string]$PortableRuntimeVersion = '7.5.0',
    [string]$PortableRuntimeRid = 'win-x64'
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
    $packageJson = Get-Content -Raw -Path $packageJsonPath | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string]$packageJson.version)) {
        return '0.0.0'
    }

    return [string]$packageJson.version
}

function Reset-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Copy-SharedAssets {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$DestinationRoot
    )

    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null

    $scriptsDest = Join-Path $DestinationRoot 'scripts'
    $schemasDest = Join-Path $DestinationRoot 'schemas'
    New-Item -ItemType Directory -Path $scriptsDest -Force | Out-Null
    New-Item -ItemType Directory -Path $schemasDest -Force | Out-Null

    Copy-Item -Path (Join-Path $RepoRoot 'scripts/*') -Destination $scriptsDest -Recurse -Force
    Copy-Item -Path (Join-Path $RepoRoot 'schemas/*') -Destination $schemasDest -Recurse -Force
}

function Copy-PortableRuntimeFromZip {
    param(
        [Parameter(Mandatory = $true)][string]$ZipPath,
        [Parameter(Mandatory = $true)][string]$DestinationRuntimeDir
    )

    $resolvedZip = (Resolve-Path $ZipPath).Path
    $tempExpand = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempExpand -Force | Out-Null
    try {
        Expand-Archive -LiteralPath $resolvedZip -DestinationPath $tempExpand -Force

        $pwshExe = Get-ChildItem -Path $tempExpand -Filter 'pwsh.exe' -File -Recurse | Select-Object -First 1
        if ($null -eq $pwshExe) {
            throw "Could not find pwsh.exe in runtime zip: $resolvedZip"
        }

        $runtimeRoot = Split-Path -Parent $pwshExe.FullName
        New-Item -ItemType Directory -Path $DestinationRuntimeDir -Force | Out-Null
        Copy-Item -Path (Join-Path $runtimeRoot '*') -Destination $DestinationRuntimeDir -Recurse -Force
    }
    finally {
        if (Test-Path -LiteralPath $tempExpand) {
            Remove-Item -LiteralPath $tempExpand -Recurse -Force
        }
    }
}

function Download-PortableRuntimeZip {
    param(
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$Rid,
        [Parameter(Mandatory = $true)][string]$DownloadDir
    )

    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
    $fileName = "PowerShell-$Version-$Rid.zip"
    $url = "https://github.com/PowerShell/PowerShell/releases/download/v$Version/$fileName"
    $target = Join-Path $DownloadDir $fileName

    Write-Stage "Downloading portable runtime from $url"
    Invoke-WebRequest -Uri $url -OutFile $target
    return $target
}

function Write-PerToolLaunchers {
    param([Parameter(Mandatory = $true)][string]$PortableRoot)

    $tools = [ordered]@{
        'inspect'          = 'inspect.ps1'
        'extract'          = 'extract.ps1'
        'pack'             = 'pack.ps1'
        'dump-yaml'        = 'dump-yaml.ps1'
        'verify'           = 'verify-znelchar.ps1'
        'verify-roundtrip' = 'roundtrip-verify.ps1'
        'update'           = 'update-znelchar.ps1'
    }

    foreach ($entry in $tools.GetEnumerator()) {
        $verb   = $entry.Key
        $script = $entry.Value

        $cmdContent = @"
@echo off
setlocal enabledelayedexpansion
set SCRIPT_DIR=%~dp0
set PWSH_EXE=%SCRIPT_DIR%runtime\pwsh.exe
if exist "%PWSH_EXE%" (
  "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\$script" %*
) else (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\$script" %*
)
exit /b %ERRORLEVEL%
"@

        $shContent = @"
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="`$(cd "`$(dirname "`${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "`$SCRIPT_DIR/runtime/pwsh" ]]; then
  "`$SCRIPT_DIR/runtime/pwsh" -NoProfile -File "`$SCRIPT_DIR/scripts/$script" "`$@"
else
  pwsh -NoProfile -File "`$SCRIPT_DIR/scripts/$script" "`$@"
fi
"@

        [System.IO.File]::WriteAllText((Join-Path $PortableRoot "$verb.cmd"), $cmdContent, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $PortableRoot "$verb.sh"), $shContent, [System.Text.UTF8Encoding]::new($false))
    }

    # Legacy compatibility shims — deprecated in favour of the per-tool launchers above.
    $legacyCmdContent = @'
@echo off
echo [znelchar] run-znelchar.cmd is deprecated. Use per-tool launchers (e.g., inspect.cmd, extract.cmd) instead. 1>&2
setlocal enabledelayedexpansion
set SCRIPT_DIR=%~dp0
set PWSH_EXE=%SCRIPT_DIR%runtime\pwsh.exe
if exist "%PWSH_EXE%" (
  "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\invoke-tool.ps1" %*
) else (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\invoke-tool.ps1" %*
)
exit /b %ERRORLEVEL%
'@

    $legacyShContent = @'
#!/usr/bin/env bash
set -euo pipefail
echo '[znelchar] run-znelchar.sh is deprecated. Use per-tool launchers (e.g., inspect.sh, extract.sh) instead.' >&2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/runtime/pwsh" ]]; then
  "$SCRIPT_DIR/runtime/pwsh" -NoProfile -File "$SCRIPT_DIR/scripts/invoke-tool.ps1" "$@"
else
  pwsh -NoProfile -File "$SCRIPT_DIR/scripts/invoke-tool.ps1" "$@"
fi
'@

    [System.IO.File]::WriteAllText((Join-Path $PortableRoot 'run-znelchar.cmd'), $legacyCmdContent, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $PortableRoot 'run-znelchar.sh'), $legacyShContent, [System.Text.UTF8Encoding]::new($false))
}

function Initialize-PortableTree {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$DestinationRoot
    )

    Copy-SharedAssets -RepoRoot $RepoRoot -DestinationRoot $DestinationRoot
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'module') -Destination (Join-Path $DestinationRoot 'module') -Recurse -Force
    Write-PerToolLaunchers -PortableRoot $DestinationRoot
}

function Get-DistributionArchives {
    param([Parameter(Mandatory = $true)][string]$OutputRoot)

    return @(Get-ChildItem -LiteralPath $OutputRoot -File -Filter 'znelchar-*.zip' | Sort-Object Name)
}

function Get-CurrentVersionDistributionArchives {
    param(
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [Parameter(Mandatory = $true)][string]$Version
    )

    $allArchives = Get-DistributionArchives -OutputRoot $OutputRoot
    $versionSuffix = "-$Version.zip"
    return @($allArchives | Where-Object { $_.Name.EndsWith($versionSuffix, [System.StringComparison]::OrdinalIgnoreCase) } | Sort-Object Name)
}

function Get-ArtifactVariant {
    param([Parameter(Mandatory = $true)][string]$FileName)

    if ($FileName -like 'znelchar-module-*') { return 'module' }
    if ($FileName -like 'znelchar-core-*') { return 'core' }
    if ($FileName -like 'znelchar-portable-*') { return 'portable' }
    return $null
}

function Test-ArchiveHasBundledRuntime {
    param([Parameter(Mandatory = $true)][string]$ArchivePath)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -eq 'znelchar-tools/runtime/pwsh' -or $entry.FullName -eq 'znelchar-tools/runtime/pwsh.exe') {
                return $true
            }
        }
        return $false
    }
    finally {
        $zip.Dispose()
    }
}

function Write-ChecksumsFile {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo[]]$Archives,
        [Parameter(Mandatory = $true)][string]$OutputRoot
    )

    $checksumPath = Join-Path $OutputRoot 'SHA256SUMS.txt'
    $lines = foreach ($archive in $Archives) {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive.FullName).Hash.ToLowerInvariant()
        "$hash  $($archive.Name)"
    }
    [System.IO.File]::WriteAllLines($checksumPath, $lines, [System.Text.UTF8Encoding]::new($false))
    return $checksumPath
}

function Write-ReleaseManifest {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo[]]$Archives,
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$Channel,
        [string]$RepositoryOwner,
        [string]$RepositoryName
    )

    $releaseTag = "v$Version"
    $canBuildUrls = -not [string]::IsNullOrWhiteSpace($RepositoryOwner) -and -not [string]::IsNullOrWhiteSpace($RepositoryName)

    $artifacts = @()
    foreach ($archive in $Archives) {
        $variant = Get-ArtifactVariant -FileName $archive.Name
        if ($null -eq $variant) {
            continue
        }

        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive.FullName).Hash.ToLowerInvariant()
        $runtimeBundled = $false
        if ($variant -eq 'portable') {
            $runtimeBundled = Test-ArchiveHasBundledRuntime -ArchivePath $archive.FullName
        }

        $downloadUrl = $null
        if ($canBuildUrls) {
            $downloadUrl = "https://github.com/$RepositoryOwner/$RepositoryName/releases/download/$releaseTag/$($archive.Name)"
        }

        $artifacts += [ordered]@{
            variant = $variant
            fileName = $archive.Name
            sha256 = $hash
            sizeBytes = $archive.Length
            runtimeBundled = $runtimeBundled
            runtimeVersion = $null
            runtimeRid = $null
            downloadUrl = $downloadUrl
        }
    }

    $manifest = [ordered]@{
        schemaVersion = 1
        toolName = 'znelchar'
        toolVersion = $Version
        releaseTag = $releaseTag
        channel = $Channel
        generatedAtUtc = [DateTime]::UtcNow.ToString('o')
        artifacts = $artifacts
    }

    $manifestPath = Join-Path $OutputRoot 'znelchar-release-manifest.json'
    $manifestJson = $manifest | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.UTF8Encoding]::new($false))
    return $manifestPath
}

function Test-ReleaseManifestSchema {
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $schemaPath = Join-Path $RepoRoot 'schemas/releaseManifest.schema.json'
    if (-not (Test-Path -LiteralPath $schemaPath)) {
        return
    }

    $manifestJson = Get-Content -Raw -LiteralPath $ManifestPath
    $null = $manifestJson | Test-Json -SchemaFile $schemaPath -ErrorAction Stop
}

$repoRoot = Get-RepoRoot
$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$version = Get-ToolVersion -RepoRoot $repoRoot

$isCiBuild = ($env:CI -eq 'true')
$ciBuildMarker = Join-Path $resolvedOutputRoot '.ci-build-initialized'

if ($isCiBuild -and -not $Clean -and -not (Test-Path -LiteralPath $ciBuildMarker)) {
    if (Test-Path -LiteralPath $resolvedOutputRoot) {
        if ($PSCmdlet.ShouldProcess($resolvedOutputRoot, 'Clean output root for CI build')) {
            Remove-Item -LiteralPath $resolvedOutputRoot -Recurse -Force
        }
    }
}

if ($Clean -and (Test-Path -LiteralPath $resolvedOutputRoot)) {
    if ($PSCmdlet.ShouldProcess($resolvedOutputRoot, 'Clean output root')) {
        Remove-Item -LiteralPath $resolvedOutputRoot -Recurse -Force
    }
}

New-Item -ItemType Directory -Path $resolvedOutputRoot -Force | Out-Null

if ($isCiBuild -and -not (Test-Path -LiteralPath $ciBuildMarker)) {
    [System.IO.File]::WriteAllText($ciBuildMarker, [DateTime]::UtcNow.ToString('o'), [System.Text.UTF8Encoding]::new($false))
}

$artifacts = @()

if ($CreateModule) {
    $moduleStageRoot = Join-Path $resolvedOutputRoot 'module-stage'
    $moduleOutputDir = Join-Path $moduleStageRoot 'Znelchar.Tools'
    $moduleSourceDir = Join-Path $repoRoot 'module/Znelchar.Tools'

    if ($PSCmdlet.ShouldProcess($moduleOutputDir, 'Build module package')) {
        Write-Stage 'Building PowerShell module package'
        Reset-Directory -Path $moduleStageRoot
        New-Item -ItemType Directory -Path $moduleOutputDir -Force | Out-Null
        Copy-Item -Path (Join-Path $moduleSourceDir '*') -Destination $moduleOutputDir -Recurse -Force
        Copy-SharedAssets -RepoRoot $repoRoot -DestinationRoot $moduleOutputDir

        $moduleZip = Join-Path $resolvedOutputRoot ("znelchar-module-$version.zip")
        if (Test-Path -LiteralPath $moduleZip) {
            Remove-Item -LiteralPath $moduleZip -Force
        }
        Compress-Archive -Path (Join-Path $moduleStageRoot '*') -DestinationPath $moduleZip -CompressionLevel Optimal
        $artifacts += $moduleZip
    }
}

if ($CreateCore) {
    $coreStageRoot = Join-Path $resolvedOutputRoot 'core-stage'
    $coreRoot = Join-Path $coreStageRoot 'znelchar-tools'

    if ($PSCmdlet.ShouldProcess($coreRoot, 'Build core distribution')) {
        Write-Stage 'Building core distribution'
        Reset-Directory -Path $coreStageRoot
        New-Item -ItemType Directory -Path $coreRoot -Force | Out-Null

        Initialize-PortableTree -RepoRoot $repoRoot -DestinationRoot $coreRoot

        $coreZip = Join-Path $resolvedOutputRoot ("znelchar-core-$version.zip")
        if (Test-Path -LiteralPath $coreZip) {
            Remove-Item -LiteralPath $coreZip -Force
        }
        Compress-Archive -Path (Join-Path $coreStageRoot '*') -DestinationPath $coreZip -CompressionLevel Optimal
        $artifacts += $coreZip
    }
}

if ($CreatePortable) {
    $portableStageRoot = Join-Path $resolvedOutputRoot 'portable-stage'
    $portableRoot = Join-Path $portableStageRoot 'znelchar-tools'

    if ($PSCmdlet.ShouldProcess($portableRoot, 'Build portable distribution')) {
        Write-Stage 'Building portable distribution'
        Reset-Directory -Path $portableStageRoot
        New-Item -ItemType Directory -Path $portableRoot -Force | Out-Null

        Initialize-PortableTree -RepoRoot $repoRoot -DestinationRoot $portableRoot

        $runtimeDestination = Join-Path $portableRoot 'runtime'
        $runtimeZipToUse = $null

        if (-not [string]::IsNullOrWhiteSpace($PortableRuntimeZipPath)) {
            $runtimeZipToUse = $PortableRuntimeZipPath
        }
        elseif ($DownloadPortableRuntime) {
            $runtimeZipToUse = Download-PortableRuntimeZip -Version $PortableRuntimeVersion -Rid $PortableRuntimeRid -DownloadDir (Join-Path $resolvedOutputRoot 'downloads')
        }

        if ($runtimeZipToUse) {
            Write-Stage "Including PowerShell runtime from zip: $runtimeZipToUse"
            Copy-PortableRuntimeFromZip -ZipPath $runtimeZipToUse -DestinationRuntimeDir $runtimeDestination
        }
        else {
            Write-Stage 'No runtime zip provided; portable package will require pwsh to be available on PATH.'
        }

        $portableZip = Join-Path $resolvedOutputRoot ("znelchar-portable-$version.zip")
        if (Test-Path -LiteralPath $portableZip) {
            Remove-Item -LiteralPath $portableZip -Force
        }
        Compress-Archive -Path (Join-Path $portableStageRoot '*') -DestinationPath $portableZip -CompressionLevel Optimal
        $artifacts += $portableZip
    }
}

$archives = @(Get-CurrentVersionDistributionArchives -OutputRoot $resolvedOutputRoot -Version $version)
$checksumsPath = $null
$manifestPath = $null

if ($WriteChecksums -and $archives.Count -gt 0) {
    Write-Stage 'Writing SHA256SUMS.txt'
    $checksumsPath = Write-ChecksumsFile -Archives $archives -OutputRoot $resolvedOutputRoot
}

if ($CreateReleaseManifest -and $archives.Count -gt 0) {
    Write-Stage 'Writing release manifest'
    $manifestPath = Write-ReleaseManifest -Archives $archives -OutputRoot $resolvedOutputRoot -Version $version -Channel $ReleaseChannel -RepositoryOwner $ReleaseRepositoryOwner -RepositoryName $ReleaseRepositoryName
    Test-ReleaseManifestSchema -ManifestPath $manifestPath -RepoRoot $repoRoot
}

Write-Stage 'Build complete'
[ordered]@{
    outputRoot = $resolvedOutputRoot
    version = $version
    artifacts = $artifacts
    checksumsFile = $checksumsPath
    releaseManifestFile = $manifestPath
} | ConvertTo-Json -Depth 10
