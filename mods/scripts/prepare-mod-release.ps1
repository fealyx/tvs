param(
    [string]$Configuration = 'Release',
    [string]$OutputRoot = './release-artifacts/mods',
    # Include PDB debug symbols in release archives. Omitted by default: PDBs expose
    # build-machine source paths and are not useful to end users in Release distributions.
    [switch]$IncludePdbs,
    [switch]$SkipBuild,
    [switch]$SkipValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modsDir = Join-Path $repoRoot 'mods'
$solutionPath = Join-Path $modsDir 'Mods.sln'
$nugetConfigPath = Join-Path $modsDir 'nuget.config'
$validatorScript = Join-Path $PSScriptRoot 'validate-mod-assets.ps1'
$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)

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

function Get-CsprojProperty {
    param(
        [xml]$ProjectXml,
        [string]$PropertyName
    )

    return $ProjectXml.Project.PropertyGroup |
        ForEach-Object { $_.$PropertyName } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -First 1
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

    $assemblyName = Get-CsprojProperty -ProjectXml $projectXml -PropertyName 'AssemblyName'
    if ([string]::IsNullOrWhiteSpace($assemblyName)) {
        $assemblyName = $projectFileName
    }

    # Plugin GUID drives the BepInEx directory name inside the zip so the user can drop
    # the zip contents directly into the game folder and BepInEx discovers the plugin.
    $pluginGuid = Get-CsprojProperty -ProjectXml $projectXml -PropertyName 'GUID'
    if ([string]::IsNullOrWhiteSpace($pluginGuid)) {
        $pluginGuid = $assemblyName
    }

    $version = Get-CsprojProperty -ProjectXml $projectXml -PropertyName 'Version'
    if ([string]::IsNullOrWhiteSpace($version)) {
        $version = '0.0.0'
    }

    $projectDir = Split-Path -Parent $projectFullPath
    $binaryOutputDir = Join-Path $projectDir 'bin' $Configuration

    $dllPath = Join-Path $binaryOutputDir "$assemblyName.dll"
    if (-not (Test-Path -LiteralPath $dllPath)) {
        throw "Expected build output missing: $dllPath"
    }

    $zipFileName = "$assemblyName-$version.zip"
    $zipPath = Join-Path $resolvedOutputRoot $zipFileName

    # Staging directory: BepInEx/plugins/{GUID}/ inside a temp root so ZipFile.CreateFromDirectory
    # produces a zip where BepInEx/ sits at the archive root.
    $stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) "tvs-mod-stage-$([System.Guid]::NewGuid())"
    try {
        $pluginSubDir = Join-Path $stagingDir 'BepInEx' 'plugins' $pluginGuid
        New-Item -ItemType Directory -Path $pluginSubDir -Force | Out-Null

        # Main plugin assembly
        Copy-Item -LiteralPath $dllPath -Destination $pluginSubDir -Force

        # PDB for the dotnet-built assembly — omitted from Release by default.
        # Pass -IncludePdbs to include them (useful for debug/RC builds).
        if ($IncludePdbs) {
            $pdbPath = Join-Path $binaryOutputDir "$assemblyName.pdb"
            if (Test-Path -LiteralPath $pdbPath) {
                Copy-Item -LiteralPath $pdbPath -Destination $pluginSubDir -Force
            }
        }

        # Assets declared in assets.manifest.json
        $projectManifestPath = Join-Path $projectDir 'assets' 'assets.manifest.json'
        if (Test-Path -LiteralPath $projectManifestPath) {
            $manifest = Get-Content -Raw -LiteralPath $projectManifestPath | ConvertFrom-Json -AsHashtable -Depth 40
            $manifestDir = Split-Path -Parent $projectManifestPath

            foreach ($asset in @($manifest.assets)) {
                $assetFileName = [System.IO.Path]::GetFileName([string]$asset.path)

                # PDB assets (e.g. Unity-built debug symbols) are excluded from Release
                # distributions unless -IncludePdbs is requested.
                if (-not $IncludePdbs -and $assetFileName.EndsWith('.pdb', [System.StringComparison]::OrdinalIgnoreCase)) {
                    continue
                }

                $sourcePath = Join-Path $manifestDir $asset.path
                if (-not (Test-Path -LiteralPath $sourcePath)) {
                    if ([bool]$asset.required) {
                        throw "Required asset declared in manifest is missing: $sourcePath"
                    }

                    continue
                }

                # releasePath is relative to the plugin GUID dir (BepInEx/plugins/{GUID}/)
                # so that asset load paths in Plugin.cs (Paths.PluginPath + GUID + relative)
                # resolve correctly after the archive is extracted into the game folder.
                $targetRelative = if ($asset.ContainsKey('releasePath') -and -not [string]::IsNullOrWhiteSpace([string]$asset.releasePath)) {
                    [string]$asset.releasePath
                }
                else {
                    $assetFileName
                }

                $destinationPath = Assert-SafeStagePath -StageRoot $pluginSubDir -RelativePath $targetRelative
                $destinationDirectory = Split-Path -Parent $destinationPath
                New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
                Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
            }
        }

        # Zip the staging root. CreateFromDirectory includes the immediate children of
        # $stagingDir, so BepInEx/ appears at the zip root rather than a staging temp name.
        [System.IO.Compression.ZipFile]::CreateFromDirectory($stagingDir, $zipPath)
    }
    finally {
        if (Test-Path -LiteralPath $stagingDir) {
            Remove-Item -LiteralPath $stagingDir -Recurse -Force
        }
    }

    $zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host "  $zipFileName  [$zipHash]"

    $releaseSummary += [ordered]@{
        project = $assemblyName
        guid    = $pluginGuid
        version = $version
        zipFile = $zipFileName
        sha256  = $zipHash
    }
}

# SHA256 sums cover the zip archives that users download, not individual files inside them.
$checksumLines = @($releaseSummary | ForEach-Object { "$($_.sha256) *$($_.zipFile)" })
Set-Content -LiteralPath (Join-Path $resolvedOutputRoot 'SHA256SUMS.txt') -Value ($checksumLines -join [Environment]::NewLine) -Encoding ascii

$summaryPath = Join-Path $resolvedOutputRoot 'mods-release-manifest.json'
$summaryContent = [ordered]@{
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    configuration  = $Configuration
    projects       = @($releaseSummary)
}
$summaryContent | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding utf8

Write-Host ''
Write-Host "Prepared mods release assets at $resolvedOutputRoot"
Get-ChildItem -LiteralPath $resolvedOutputRoot | Select-Object Name | Format-Table -AutoSize | Out-String | Write-Host
