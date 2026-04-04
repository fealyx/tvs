param(
    [switch]$Force,
    [string]$GamePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================================
# Paths and constants
# ============================================================================
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modsDir = Join-Path $repoRoot 'mods'
$manifestPath = Join-Path $modsDir 'game-assemblies.json'
$localCacheDir = Join-Path $modsDir '.local' 'game-refs' 'managed'
$gameDirPropsPath = Join-Path $modsDir 'GameDir.props'
$envFilePath = Join-Path $repoRoot '.env'

# ============================================================================
# Helper functions
# ============================================================================

function Get-GameInstallPath {
    param([string]$ExplicitPath)
    
    # 1. If explicitly provided, use it
    if ($ExplicitPath -and (Test-Path $ExplicitPath)) {
        return $ExplicitPath
    }
    
    # 2. Try to find Steam Registry entry for TVS
    try {
        $steamKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 1906350'
        if (Test-Path $steamKey) {
            $installDir = (Get-ItemProperty -Path $steamKey -ErrorAction SilentlyContinue).InstallLocation
            if ($installDir -and (Test-Path (Join-Path $installDir 'TheVillainSimulator_Data'))) {
                Write-Host "Found TVS in Steam registry: $installDir" -ForegroundColor Green
                return $installDir
            }
        }
    }
    catch {
        # Registry lookup failed, continue to next method
    }
    
    # 3. If local GameDir.props exists with TVSGameDir, extract it
    $existingGameDir = $null
    if (Test-Path $gameDirPropsPath) {
        try {
            [xml]$propsXml = Get-Content $gameDirPropsPath
            $existingGameDir = $propsXml.Project.PropertyGroup.TVSGameDir
            if ($existingGameDir -and (Test-Path (Join-Path $existingGameDir 'TheVillainSimulator_Data'))) {
                Write-Host "Found TVS from existing GameDir.props: $existingGameDir" -ForegroundColor Green
                return $existingGameDir
            }
        }
        catch {
            # Failed to parse existing props, continue
        }
    }
    
    # 4. Prompt user
    Write-Host "`nCould not auto-detect TVS install path." -ForegroundColor Yellow
    Write-Host "Common paths:" -ForegroundColor Cyan
    Write-Host "  C:\Program Files (x86)\Steam\steamapps\common\The Villain Simulator"
    $userPath = Read-Host "`nEnter the full path to The Villain Simulator install directory"
    
    if (-not $userPath -or -not (Test-Path $userPath)) {
        throw "Invalid path: $userPath"
    }
    
    if (-not (Test-Path (Join-Path $userPath 'TheVillainSimulator_Data'))) {
        throw "Directory does not appear to be a valid TVS install: $userPath"
    }
    
    return $userPath
}

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
    param([string]$ManagedDir)
    
    $content = @"
<Project>
  <PropertyGroup>
    <TVSGameDir></TVSGameDir>
    <TVSManagedDir>$ManagedDir</TVSManagedDir>
    <!-- <TVSPublicizedDir></TVSPublicizedDir> -->
  </PropertyGroup>
</Project>
"@
    
    Set-Content -Path $gameDirPropsPath -Value $content -Encoding UTF8
    Write-Host "Generated: $gameDirPropsPath" -ForegroundColor Green
}

function New-EnvFile {
    param(
        [string]$GameDir,
        [string]$PlayerDataDir
    )
    
    $content = @"
# TVS Modding Environment
# Generated by mods/scripts/setup-modding-env.ps1

TVS_GAME_DIR=$GameDir
TVS_PLAYER_DATA_DIR=$PlayerDataDir
"@
    
    Set-Content -Path $envFilePath -Value $content -Encoding UTF8
    Write-Host "Generated: $envFilePath" -ForegroundColor Green
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

# 2. Detect game path
Write-Host "Detecting TVS install path..."
$gamePath = Get-GameInstallPath -ExplicitPath $GamePath
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
New-GameDirProps -ManagedDir $localCacheDir

# 5. Generate .env file
Write-Host "Generating environment file..."
$playerDataDir = "$env:USERPROFILE\AppData\LocalLow\ZnelArts\TheVillainSimulator"
New-EnvFile -GameDir $gamePath -PlayerDataDir $playerDataDir

Write-Host "`n✓ Setup complete!" -ForegroundColor Green
Write-Host "`nNext steps:`n"
Write-Host "  1. Review the generated .env and mods/GameDir.props files"
Write-Host "  2. Run: cd mods && dotnet build Mods.sln"
Write-Host "  3. Or: rush build --to @tvs/mods`n" -ForegroundColor Cyan
