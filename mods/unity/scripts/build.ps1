param(
    [string]$UnityPath,
    [string]$OutputDir = './Builds/AssetBundles/Windows64',
    [string]$BuildTarget = 'StandaloneWindows64',
    [switch]$Strict
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedOutputDir = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $OutputDir))

function Resolve-UnityExecutable {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        return $ExplicitPath
    }

    foreach ($candidate in @($env:UNITY_EXECUTABLE, $env:UNITY_PATH, $env:UNITY_EDITOR_PATH)) {
        if ($candidate) {
            return $candidate
        }
    }

    foreach ($commandName in @('Unity', 'unity', 'unity-editor')) {
        $unityCommand = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($unityCommand) {
            return $unityCommand.Source
        }
    }

    foreach ($knownPath in @(
        '/opt/unity/Editor/Unity',
        '/Applications/Unity/Hub/Editor/Unity.app/Contents/MacOS/Unity',
        'C:\Program Files\Unity\Hub\Editor\Unity.exe'
    )) {
        if (Test-Path -LiteralPath $knownPath) {
            return $knownPath
        }
    }

    return $null
}

if (-not $UnityPath) {
    $UnityPath = Resolve-UnityExecutable -ExplicitPath $UnityPath
}

if (-not $UnityPath) {
    throw 'Unable to resolve Unity executable. Set UNITY_EXECUTABLE (or UNITY_PATH / UNITY_EDITOR_PATH) or pass -UnityPath.'
}

if (-not (Test-Path -LiteralPath $UnityPath)) {
    throw "Unity executable not found at path: $UnityPath"
}

if (-not (Test-Path -LiteralPath $resolvedOutputDir)) {
    New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null
}

$logPath = Join-Path $projectRoot 'Builds' 'unity-batch-build.log'
$logDir = Split-Path -Parent $logPath
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$arguments = @(
    '-batchmode',
    '-nographics',
    '-quit',
    '-projectPath', $projectRoot,
    '-executeMethod', 'TVS.Mods.Unity.Editor.BatchBuild.BuildAll',
    '-assetBundleOutputPath', $resolvedOutputDir,
    '-assetBundleTarget', $BuildTarget,
    '-logFile', $logPath
)

Write-Host "Starting Unity batch build..." -ForegroundColor Cyan
Write-Host "  Unity: $UnityPath" -ForegroundColor DarkGray
Write-Host "  Project: $projectRoot" -ForegroundColor DarkGray
Write-Host "  Output: $resolvedOutputDir" -ForegroundColor DarkGray
Write-Host "  Target: $BuildTarget" -ForegroundColor DarkGray
Write-Host "  Log: $logPath" -ForegroundColor DarkGray

& $UnityPath @arguments
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    throw "Unity batch build failed with exit code $exitCode. Check log: $logPath"
}

if ($Strict -and -not (Get-ChildItem -LiteralPath $resolvedOutputDir -File -ErrorAction SilentlyContinue)) {
    throw "Unity batch build completed but produced no files in: $resolvedOutputDir"
}

Write-Host 'Unity batch build completed successfully.' -ForegroundColor Green
