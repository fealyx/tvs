param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('install-bepinex', 'install-dev-mods', 'deploy', 'deploy-all', 'clean-plugins')]
    [string]$Action,
    [string]$Project,
    [string]$PluginsDir,
    [string]$Configuration = 'Debug',
    [string]$BepInExVersion = '5.4.23.2',
    [switch]$Force,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$modsRoot = Join-Path $repoRoot 'mods' 'csharp'
$devModsManifestPath = Join-Path $modsRoot 'dev-mods.manifest.json'

Import-Module TVS.Environment -ErrorAction Stop

function Invoke-SafeCopy {
    param(
        [string]$Source,
        [string]$Destination,
        [switch]$AllowOverwrite
    )

    if (-not (Test-Path $Source)) {
        throw "Source file does not exist: $Source"
    }

    if ((Test-Path $Destination) -and -not $AllowOverwrite) {
        throw "Destination exists and overwrite not allowed: $Destination"
    }

    if ($DryRun) {
        Write-Host "[dry-run] copy $Source -> $Destination" -ForegroundColor Yellow
        return
    }

    $destDir = Split-Path -Parent $Destination
    if ($destDir -and -not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Copy-Item -Path $Source -Destination $Destination -Force
}

function Get-PluginProjects {
    $projectPaths = Get-ChildItem -Path $modsRoot -Recurse -Filter '*.csproj' |
        ForEach-Object { $_.FullName } |
        Where-Object { $_ -notmatch '[\\/]TVS\.Core[\\/]' }

    return @($projectPaths)
}

function Deploy-Project {
    param(
        [string]$ProjectPath,
        [string]$ConfigurationName,
        [string]$PluginsDir
    )

    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectPath)
    $projectDir = Split-Path -Parent $ProjectPath
    $builtDll = Join-Path $projectDir 'bin' $ConfigurationName "$projectName.dll"

    if (-not (Test-Path $builtDll)) {
        throw "Built assembly not found for $projectName at $builtDll. Build the project first."
    }

    $destDll = Join-Path $PluginsDir $projectName "$projectName.dll"
    Invoke-SafeCopy -Source $builtDll -Destination $destDll -AllowOverwrite:$true
    Write-Host "Deployed $projectName -> $destDll" -ForegroundColor Green
}

function Install-BepInEx {
    param(
        [string]$GameDir,
        [string]$Version
    )

    $zipName = "BepInEx_x64_$Version.zip"
    $url = "https://github.com/BepInEx/BepInEx/releases/download/v$Version/$zipName"
    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) $zipName

    Write-Host "Installing BepInEx $Version to $GameDir" -ForegroundColor Cyan
    Write-Host "Source: $url" -ForegroundColor DarkGray

    if ($DryRun) {
        Write-Host "[dry-run] download and extract $zipName" -ForegroundColor Yellow
        return
    }

    Invoke-WebRequest -Uri $url -OutFile $tempZip
    Expand-Archive -Path $tempZip -DestinationPath $GameDir -Force
    Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue

    Write-Host "BepInEx install complete." -ForegroundColor Green
}

function Install-DevMods {
    param([string]$PluginsDir)

    if (-not (Test-Path $devModsManifestPath)) {
        throw "Dev mods manifest not found: $devModsManifestPath"
    }

    $manifest = Get-Content $devModsManifestPath -Raw | ConvertFrom-Json
    if (-not $manifest.mods -or $manifest.mods.Count -eq 0) {
        Write-Host "No default dev mods configured in $devModsManifestPath." -ForegroundColor Yellow
        return
    }

    foreach ($entry in $manifest.mods) {
        $name = $entry.name
        $url = $entry.url
        $fileName = if ($entry.fileName) { $entry.fileName } else { "$name.zip" }
        $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) $fileName

        Write-Host "Installing dev mod: $name" -ForegroundColor Cyan
        if ($DryRun) {
            Write-Host "[dry-run] download and extract $url" -ForegroundColor Yellow
            continue
        }

        Invoke-WebRequest -Uri $url -OutFile $tempZip
        Expand-Archive -Path $tempZip -DestinationPath $PluginsDir -Force
        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
    }
}

function Clean-DeployedPlugins {
    param([string]$PluginsDir)

    $projects = Get-PluginProjects
    foreach ($project in $projects) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($project)
        $target = Join-Path $PluginsDir "$name.dll"
        if (Test-Path $target) {
            if ($DryRun) {
                Write-Host "[dry-run] remove $target" -ForegroundColor Yellow
            }
            else {
                Remove-Item -Path $target -Force
                Write-Host "Removed $target" -ForegroundColor Green
            }
        }
    }
}

$tvsEnv = Get-TVSEnvironment
$resolvedGameDir    = $tvsEnv.gameDir
$resolvedPluginsDir = if ($PluginsDir) { $PluginsDir } else { $tvsEnv.pluginsDir }

switch ($Action) {
    'install-bepinex' {
        if (-not $resolvedGameDir) {
            throw "Unable to resolve TVS game directory. Run Initialize-TVSEnvironment or set gameDir with Set-TVSEnvironmentValue."
        }
        Install-BepInEx -GameDir $resolvedGameDir -Version $BepInExVersion
    }
    'install-dev-mods' {
        if (-not $resolvedPluginsDir) {
            throw "Unable to resolve TVS plugins directory. Run Initialize-TVSEnvironment or pass -PluginsDir."
        }
        if (-not (Test-Path $resolvedPluginsDir) -and -not $DryRun) {
            New-Item -ItemType Directory -Path $resolvedPluginsDir -Force | Out-Null
        }
        Install-DevMods -PluginsDir $resolvedPluginsDir
    }
    'deploy' {
        if (-not $Project) {
            throw "-Project is required for Action=deploy (example: -Project TVS.SampleMod)"
        }
        $candidate = Join-Path $modsRoot $Project "$Project.csproj"
        if (-not (Test-Path $candidate)) {
            throw "Project not found at $candidate"
        }
        if (-not $resolvedPluginsDir) {
            throw "Unable to resolve TVS plugins directory. Run Initialize-TVSEnvironment or pass -PluginsDir."
        }
        Deploy-Project -ProjectPath $candidate -ConfigurationName $Configuration -PluginsDir $resolvedPluginsDir
    }
    'deploy-all' {
        if (-not $resolvedPluginsDir) {
            throw "Unable to resolve TVS plugins directory. Run Initialize-TVSEnvironment or pass -PluginsDir."
        }
        $projects = Get-PluginProjects
        foreach ($project in $projects) {
            Deploy-Project -ProjectPath $project -ConfigurationName $Configuration -PluginsDir $resolvedPluginsDir
        }
    }
    'clean-plugins' {
        if (-not $resolvedPluginsDir) {
            throw "Unable to resolve TVS plugins directory. Run Initialize-TVSEnvironment or pass -PluginsDir."
        }
        Clean-DeployedPlugins -PluginsDir $resolvedPluginsDir
    }
}
