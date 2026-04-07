param(
    [string]$Configuration = 'Release',
    [string]$OutputRoot = './release-artifacts/mods',
    [switch]$SkipBuild,
    [switch]$SkipValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modsDir = Join-Path $repoRoot 'mods'
$solutionPath = Join-Path $modsDir 'Mods.sln'
$nugetConfigPath = Join-Path $modsDir 'nuget.config'
$validatorScript = Join-Path $PSScriptRoot 'validate-mod-assets.ps1'
$resolvedOutputRoot = [System.IO.Path]::GetFullPath((Join-Path $modsDir $OutputRoot))

function Get-RelativePathFrom {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    $resolvedBasePath = (Resolve-Path -Path $BasePath).Path
    $resolvedTargetPath = (Resolve-Path -Path $TargetPath).Path
    return [System.IO.Path]::GetRelativePath($resolvedBasePath, $resolvedTargetPath)
}

function Assert-SafeStagePath {
    param(
        [string]$StageRoot,
        [string]$RelativePath
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Stage path must be relative: $RelativePath"
    }

    $stageRootFullPath = [System.IO.Path]::GetFullPath($StageRoot)
    $candidatePath = [System.IO.Path]::GetFullPath((Join-Path $stageRootFullPath $RelativePath))
    $prefix = $stageRootFullPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if (-not $candidatePath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Stage path escapes release folder: $RelativePath"
    }

    return $candidatePath
}

function Get-SolutionProjectPaths {
    $paths = @()
    foreach ($line in Get-Content -LiteralPath $solutionPath) {
        if ($line -match '^Project\("\{[^\}]+\}"\)\s*=\s*"[^"]+",\s*"([^"]+\.csproj)"') {
            $relativePath = $Matches[1].Replace('\\', '/')
            $paths += Join-Path $modsDir $relativePath
        }
    }

    return $paths
}

if (-not $SkipValidation) {
    & $validatorScript -All | Out-Null
}

if (-not $SkipBuild) {
    & dotnet restore $solutionPath --configfile $nugetConfigPath --force-evaluate
    if ($LASTEXITCODE -ne 0) {
        throw 'dotnet restore failed.'
    }

    & dotnet build $solutionPath --configuration $Configuration --no-restore
    if ($LASTEXITCODE -ne 0) {
        throw 'dotnet build failed.'
    }
}

if (Test-Path -LiteralPath $resolvedOutputRoot) {
    Remove-Item -LiteralPath $resolvedOutputRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $resolvedOutputRoot -Force | Out-Null

$releaseSummary = @()

foreach ($projectPath in Get-SolutionProjectPaths) {
    $projectFullPath = [System.IO.Path]::GetFullPath($projectPath)
    [xml]$projectXml = Get-Content -LiteralPath $projectFullPath

    $projectFileName = [System.IO.Path]::GetFileNameWithoutExtension($projectFullPath)
    $assemblyName = $projectXml.Project.PropertyGroup.AssemblyName | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($assemblyName)) {
        $assemblyName = $projectFileName
    }

    $projectDir = Split-Path -Parent $projectFullPath
    $projectReleaseDir = Join-Path $resolvedOutputRoot $assemblyName
    New-Item -ItemType Directory -Path $projectReleaseDir -Force | Out-Null

    $binaryOutputDir = Join-Path $projectDir 'bin' $Configuration
    $dllPath = Join-Path $binaryOutputDir "$assemblyName.dll"
    if (-not (Test-Path -LiteralPath $dllPath)) {
        throw "Expected build output missing: $dllPath"
    }

    Copy-Item -LiteralPath $dllPath -Destination $projectReleaseDir -Force

    $pdbPath = Join-Path $binaryOutputDir "$assemblyName.pdb"
    if (Test-Path -LiteralPath $pdbPath) {
        Copy-Item -LiteralPath $pdbPath -Destination $projectReleaseDir -Force
    }

    $projectManifestPath = Join-Path $projectDir 'assets' 'assets.manifest.json'
    if (Test-Path -LiteralPath $projectManifestPath) {
        $manifest = Get-Content -Raw -LiteralPath $projectManifestPath | ConvertFrom-Json -AsHashtable -Depth 40
        $manifestDir = Split-Path -Parent $projectManifestPath

        foreach ($asset in @($manifest.assets)) {
            $sourcePath = Join-Path $manifestDir $asset.path
            if (-not (Test-Path -LiteralPath $sourcePath)) {
                if ([bool]$asset.required) {
                    throw "Required asset declared in manifest is missing: $sourcePath"
                }

                continue
            }

            $targetRelative = if ($asset.ContainsKey('releasePath') -and -not [string]::IsNullOrWhiteSpace([string]$asset.releasePath)) {
                [string]$asset.releasePath
            }
            else {
                Join-Path 'assets' ([System.IO.Path]::GetFileName([string]$asset.path))
            }

            $destinationPath = Assert-SafeStagePath -StageRoot $projectReleaseDir -RelativePath $targetRelative
            $destinationDirectory = Split-Path -Parent $destinationPath
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
            Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
        }
    }

    $stagedFiles = @(Get-ChildItem -LiteralPath $projectReleaseDir -File -Recurse)
    $checksumLines = @()
    foreach ($stagedFile in $stagedFiles) {
        if ($stagedFile.Name -eq 'SHA256SUMS.txt') {
            continue
        }

        $relativeFilePath = Get-RelativePathFrom -BasePath $projectReleaseDir -TargetPath $stagedFile.FullName
        $hash = (Get-FileHash -LiteralPath $stagedFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $checksumLines += "$hash *$($relativeFilePath.Replace('\\', '/'))"
    }

    Set-Content -LiteralPath (Join-Path $projectReleaseDir 'SHA256SUMS.txt') -Value ($checksumLines -join [Environment]::NewLine) -Encoding ascii

    $releaseSummary += [ordered]@{
        project = $assemblyName
        releasePath = $projectReleaseDir
        fileCount = (Get-ChildItem -LiteralPath $projectReleaseDir -File -Recurse).Count
    }
}

$summaryPath = Join-Path $resolvedOutputRoot 'mods-release-manifest.json'
$summaryContent = [ordered]@{
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    configuration = $Configuration
    projects = $releaseSummary
}
$summaryContent | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8

Write-Host "Prepared mods release assets at $resolvedOutputRoot"
Get-ChildItem -LiteralPath $resolvedOutputRoot -Recurse | Select-Object FullName | Format-Table -AutoSize | Out-String | Write-Host
