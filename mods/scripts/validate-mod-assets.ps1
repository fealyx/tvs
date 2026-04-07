param(
    [string[]]$ManifestPath,
    [switch]$All,
    [switch]$CiSummary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modsDir = Join-Path $repoRoot 'mods'
$schemaPath = Join-Path $modsDir 'schemas' 'assets.manifest.schema.json'

function Get-RelativePathFrom {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    $resolvedBasePath = (Resolve-Path -Path $BasePath).Path
    $resolvedTargetPath = (Resolve-Path -Path $TargetPath).Path
    return [System.IO.Path]::GetRelativePath($resolvedBasePath, $resolvedTargetPath)
}

function Get-ResolvedManifestPaths {
    if ($All -or (-not $PSBoundParameters.ContainsKey('ManifestPath'))) {
        return @(Get-ChildItem -Path $modsDir -Filter 'assets.manifest.json' -Recurse -File | Sort-Object -Property FullName)
    }

    $resolvedPaths = @()
    foreach ($path in $ManifestPath) {
        $resolvedPaths += Get-Item -LiteralPath (Resolve-Path -Path $path).Path
    }

    return @($resolvedPaths | Sort-Object -Property FullName)
}

function Assert-SafeChildPath {
    param(
        [string]$BaseDirectory,
        [string]$RelativePath,
        [string]$Context
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "$Context path must be relative: $RelativePath"
    }

    $baseFullPath = [System.IO.Path]::GetFullPath($BaseDirectory)
    $candidatePath = [System.IO.Path]::GetFullPath((Join-Path $baseFullPath $RelativePath))
    $prefix = $baseFullPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if (-not $candidatePath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Context path escapes base directory: $RelativePath"
    }

    return $candidatePath
}

$manifestFiles = @(Get-ResolvedManifestPaths)
if ($manifestFiles.Count -eq 0) {
    throw 'No assets.manifest.json files were found.'
}

$errors = @()
$warnings = @()
$summaries = @()

foreach ($manifestFile in $manifestFiles) {
    try {
        $manifestRaw = Get-Content -Raw -LiteralPath $manifestFile.FullName
        if (Test-Path -LiteralPath $schemaPath) {
            $isValidJsonSchema = Test-Json -Json $manifestRaw -SchemaFile $schemaPath
            if (-not $isValidJsonSchema) {
                throw "Manifest failed schema validation: $($manifestFile.FullName)"
            }
        }

        $manifest = $manifestRaw | ConvertFrom-Json -AsHashtable -Depth 40
        $manifestDir = Split-Path -Parent $manifestFile.FullName
        $assetEntries = @($manifest.assets)
        $validatedCount = 0

        foreach ($asset in $assetEntries) {
            $assetPath = [string]$asset.path
            $assetRequired = [bool]$asset.required
            $resolvedAssetPath = Assert-SafeChildPath -BaseDirectory $manifestDir -RelativePath $assetPath -Context 'Asset'

            if (-not (Test-Path -LiteralPath $resolvedAssetPath)) {
                if ($assetRequired) {
                    throw "Required asset missing: $resolvedAssetPath"
                }

                $warnings += "Optional asset missing: $resolvedAssetPath"
                continue
            }

            if ($asset.ContainsKey('sha256') -and -not [string]::IsNullOrWhiteSpace([string]$asset.sha256)) {
                $expectedHash = ([string]$asset.sha256).ToLowerInvariant()
                $actualHash = (Get-FileHash -LiteralPath $resolvedAssetPath -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($expectedHash -ne $actualHash) {
                    throw "Hash mismatch for asset '$assetPath' in $($manifestFile.FullName). Expected: $expectedHash Actual: $actualHash"
                }
            }

            if ($asset.ContainsKey('releasePath') -and -not [string]::IsNullOrWhiteSpace([string]$asset.releasePath)) {
                $null = Assert-SafeChildPath -BaseDirectory (Join-Path $modsDir 'release') -RelativePath ([string]$asset.releasePath) -Context 'releasePath'
            }

            $validatedCount++
        }

        $summaries += [ordered]@{
            manifest = Get-RelativePathFrom -BasePath $repoRoot -TargetPath $manifestFile.FullName
            project = [string]$manifest.project.name
            totalAssets = $assetEntries.Count
            validatedAssets = $validatedCount
        }
    }
    catch {
        $errors += $_.Exception.Message
    }
}

if ($warnings.Count -gt 0) {
    foreach ($warning in $warnings) {
        Write-Warning $warning
    }
}

if ($errors.Count -gt 0) {
    foreach ($errorMessage in $errors) {
        Write-Host "ERROR: $errorMessage" -ForegroundColor Red
    }

    throw "Asset manifest validation failed with $($errors.Count) error(s)."
}

if ($CiSummary) {
    [ordered]@{
        passed = $true
        manifestCount = $summaries.Count
        manifests = $summaries
        warningCount = $warnings.Count
    } | ConvertTo-Json -Depth 20
}
else {
    Write-Host 'Asset manifest validation succeeded.' -ForegroundColor Green
    $summaries | ForEach-Object {
        Write-Host (" - {0}: {1}/{2} assets validated" -f $_.manifest, $_.validatedAssets, $_.totalAssets)
    }
}
