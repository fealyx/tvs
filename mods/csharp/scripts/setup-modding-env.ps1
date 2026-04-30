param(
    [switch]$Force,
    [string]$GamePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module TVS.Environment -ErrorAction Stop

# ============================================================================
# Paths and constants
# ============================================================================
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$modsDir = Join-Path $repoRoot 'mods' 'csharp'
$manifestPath = Join-Path $modsDir 'game-assemblies.json'
$localCacheDir = Join-Path $modsDir '.local' 'game-refs' 'managed'
$gameDirPropsPath = Join-Path $modsDir 'GameDir.props'

# ============================================================================
# Helper functions
# ============================================================================



function Invoke-FileHash {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        return $null
    }
    
    $hash = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($Path)
    [byte[]]$buffer = New-Object byte[] 8192
    
    while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $hash.TransformBlock($buffer, 0, $read, $null, 0) | Out-Null
    }
    $hash.TransformFinalBlock($buffer, 0, 0) | Out-Null
    $stream.Dispose()
    
    return [System.BitConverter]::ToString($hash.Hash) -replace '-'
}

function Copy-GameAssemblies {
    param(
        [string]$SourceDir,
        [array]$Assemblies
    )
    
    # Create local cache directory
    if (-not (Test-Path $localCacheDir)) {
        New-Item -ItemType Directory -Path $localCacheDir -Force | Out-Null
        Write-Host "Created local cache directory: $localCacheDir" -ForegroundColor Green
    }
    
    $copied = 0
    $skipped = 0
    $missing = 0
    $required_missing = @()
    
    foreach ($asm in $Assemblies) {
        $asmName = $asm.name
        $isRequired = $asm.required
        $sourcePath = Join-Path $SourceDir $asmName
        $destPath = Join-Path $localCacheDir $asmName
        
        if (-not (Test-Path $sourcePath)) {
            $missing++
            if ($isRequired) {
                $required_missing += $asmName
                Write-Host "  ✗ $asmName (REQUIRED - NOT FOUND)" -ForegroundColor Red
            }
            else {
                Write-Host "  ⊘ $asmName (optional, skipped)" -ForegroundColor Gray
            }
            continue
        }
        
        # Check if file needs copying (hash comparison)
        $sourceHash = Invoke-FileHash $sourcePath
        $destHash = if (Test-Path $destPath) { Invoke-FileHash $destPath } else { $null }
        
        if ($sourceHash -eq $destHash -and -not $Force) {
            $skipped++
            Write-Host "  ✓ $asmName (unchanged, skipped)" -ForegroundColor Cyan
        }
        else {
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            $copied++
            $status = if ($destHash) { "(updated)" } else { "(new)" }
            Write-Host "  ✓ $asmName $status" -ForegroundColor Green
        }
    }
    
    if ($required_missing.Count -gt 0) {
        throw "Required assemblies missing: $($required_missing -join ', ')"
    }
    
    Write-Host "`nCopy Summary: $copied copied, $skipped skipped, $missing missing" -ForegroundColor Cyan
}

function New-GameDirProps {
    param(
        [string]$GameDir,
        [string]$ManagedDir
    )
    
    $content = @"
<Project>
  <PropertyGroup>
            <TVSGameDir>$GameDir</TVSGameDir>
    <TVSManagedDir>$ManagedDir</TVSManagedDir>
            <TVSPluginDeployDir>$GameDir\BepInEx\plugins</TVSPluginDeployDir>
            <TVSAutoDeployOnBuild>true</TVSAutoDeployOnBuild>
    <!-- <TVSPublicizedDir></TVSPublicizedDir> -->
  </PropertyGroup>
</Project>
"@
    
    Set-Content -Path $gameDirPropsPath -Value $content -Encoding UTF8
    Write-Host "Generated: $gameDirPropsPath" -ForegroundColor Green
}



# ============================================================================
# Main
# ============================================================================

Write-Host "TVS Modding Environment Setup" -ForegroundColor Cyan
Write-Host "==============================`n" -ForegroundColor Cyan

# 1. Load manifest
if (-not (Test-Path $manifestPath)) {
    throw "Assembly manifest not found: $manifestPath"
}

Write-Host "Loading manifest: $manifestPath"
$manifest = Get-Content $manifestPath | ConvertFrom-Json
Write-Host "  Found $($manifest.managedAssemblies.Count) required/optional assemblies`n" -ForegroundColor Gray

# 2. Resolve game path via TVS.Environment profile
Write-Host "Resolving TVS install path..."
$gamePath = $null
if ($GamePath) {
    # Explicit path provided: validate, persist to profile, use it
    if (-not (Test-Path $GamePath)) { throw "Provided game path does not exist: $GamePath" }
    if (-not (Test-Path (Join-Path $GamePath 'TheVillainSimulator_Data'))) {
        throw "Directory does not appear to be a valid TVS install: $GamePath"
    }
    $gamePath = $GamePath
    Set-TVSEnvironmentValue -Key gameDir -Value $gamePath
    Write-Host "Using provided game path: $gamePath" -ForegroundColor Green
}
else {
    $gamePath = Get-TVSEnvironment -Key gameDir
    if ($gamePath) {
        Write-Host "Found TVS install: $gamePath" -ForegroundColor Green
    }
}

if (-not $gamePath) {
    Write-Host "`nCould not auto-detect TVS install path." -ForegroundColor Yellow
    Write-Host "Common paths:" -ForegroundColor Cyan
    Write-Host "  C:\Program Files (x86)\Steam\steamapps\common\The Villain Simulator"
    $userInput = Read-Host "`nEnter the full path to The Villain Simulator install directory"
    if (-not $userInput -or -not (Test-Path $userInput)) { throw "Invalid path: $userInput" }
    if (-not (Test-Path (Join-Path $userInput 'TheVillainSimulator_Data'))) {
        throw "Directory does not appear to be a valid TVS install: $userInput"
    }
    $gamePath = $userInput
    Set-TVSEnvironmentValue -Key gameDir -Value $gamePath
    Write-Host "Saved game path to profile." -ForegroundColor Green
}

$managedDir = Join-Path $gamePath 'TheVillainSimulator_Data' 'Managed'
if (-not (Test-Path $managedDir)) {
    throw "Managed directory not found: $managedDir"
}

Write-Host "Using game path: $gamePath`n" -ForegroundColor Green

# 3. Copy assemblies
Write-Host "Copying assemblies to local cache..."
Copy-GameAssemblies -SourceDir $managedDir -Assemblies $manifest.managedAssemblies

# 4. Generate GameDir.props pointing to local cache
Write-Host "`nGenerating MSBuild configuration..."
New-GameDirProps -GameDir $gamePath -ManagedDir $localCacheDir

# 5. Persist player data directory to profile
$playerDataDir = Get-TVSEnvironment -Key playerDataDir
if (-not $playerDataDir) {
    $playerDataDir = "$env:USERPROFILE\AppData\LocalLow\ZnelArts\TheVillainSimulator"
    Set-TVSEnvironmentValue -Key playerDataDir -Value $playerDataDir
    Write-Host "Saved player data directory to profile: $playerDataDir" -ForegroundColor Green
}
else {
    Write-Host "Player data directory: $playerDataDir" -ForegroundColor Gray
}

Write-Host "`n✓ Setup complete!" -ForegroundColor Green
Write-Host "`nNext steps:`n"
Write-Host "  1. Review mods/csharp/GameDir.props and run Get-TVSEnvironment to verify your profile."
Write-Host "  2. Run: cd mods/csharp && dotnet build Mods.sln"
Write-Host "  3. Or: rush build --to @tvs/mods-csharp`n" -ForegroundColor Cyan
