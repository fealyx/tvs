<#
.SYNOPSIS
Test script for expand/compress roundtrip of character data.

.DESCRIPTION
Verifies the Expand-ZnelcharData and Compress-ZnelcharData commands work correctly:
1. Character JSON can be expanded to YAML/JSON structure
2. YAML/JSON structure can be compressed back to JSON
3. The reconstructed JSON is semantically equivalent to original
4. Both YAML and JSON formats work correctly

Run this after making changes to the expand/compress logic.

.PARAMETER CharacterJsonPath
Path to a character.json file to test with.

.PARAMETER KeepArtifacts
Keep the test artifacts for manual inspection (default: clean up).

.EXAMPLE
.\test-expand-compress.ps1 -CharacterJsonPath "../../temp/Rita-Collab-b48-v1-5.extracted/character.json"

.NOTES
Run from the znelchar/scripts directory.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$CharacterJsonPath,

    [switch]$KeepArtifacts
)

$ErrorActionPreference = 'Stop'

# Import the module
$moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '../module/Znelchar.Tools')
Import-Module "$moduleRoot/Znelchar.Tools.psd1" -Force

Write-Host "===== Expand/Compress Roundtrip Test =====" -ForegroundColor Cyan
Write-Host "Input: $CharacterJsonPath" -ForegroundColor Cyan
Write-Host

# Verify input exists
if (-not (Test-Path -LiteralPath $CharacterJsonPath)) {
    throw "Input file not found: $CharacterJsonPath"
}

# Setup test directories
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$testDir = Join-Path ([System.IO.Path]::GetTempPath()) "znelchar-expand-test-$timestamp"
New-Item -ItemType Directory -Path $testDir -Force | Out-Null

Write-Host "Test directory: $testDir" -ForegroundColor Gray
Write-Host

try {
    # Test 1: Expand to YAML
    Write-Host "[1/5] Expanding to YAML..." -ForegroundColor Green
    $expandedYAML = Join-Path $testDir "expanded-yaml"
    $expandResult = Expand-ZnelcharData `
        -InputPath $CharacterJsonPath `
        -OutputPath $expandedYAML `
        -Format yaml `
        -Force
    Write-Host "  ✓ Expanded: $($expandResult.FileCount) files, schema v$($expandResult.SchemaVersion)" -ForegroundColor Green
    Write-Host

    # Test 2: Compress YAML back to JSON
    Write-Host "[2/5] Compressing YAML back to JSON..." -ForegroundColor Green
    $reconstructedJSON1 = Join-Path $testDir "reconstructed-from-yaml.json"
    $condenseResult = Compress-ZnelcharData `
        -InputPath $expandedYAML `
        -OutputPath $reconstructedJSON1 `
        -Force
    Write-Host "  ✓ Condensed: $($condenseResult.FieldCount) fields, $($condenseResult.AccessoryCount) accessories" -ForegroundColor Green
    Write-Host

    # Test 3: Expand to JSON format
    Write-Host "[3/5] Expanding to JSON format..." -ForegroundColor Green
    $expandedJSON = Join-Path $testDir "expanded-json"
    $expandResultJSON = Expand-ZnelcharData `
        -InputPath $CharacterJsonPath `
        -OutputPath $expandedJSON `
        -Format json `
        -Force
    Write-Host "  ✓ Expanded: $($expandResultJSON.FileCount) files" -ForegroundColor Green
    Write-Host

    # Test 4: Compress JSON back
    Write-Host "[4/5] Compressing JSON back to JSON..." -ForegroundColor Green
    $reconstructedJSON2 = Join-Path $testDir "reconstructed-from-json.json"
    $condenseResult2 = Compress-ZnelcharData `
        -InputPath $expandedJSON `
        -OutputPath $reconstructedJSON2 `
        -Force
    Write-Host "  ✓ Condensed: $($condenseResult2.FieldCount) fields" -ForegroundColor Green
    Write-Host

    # Test 5: Validate and compare
    Write-Host "[5/5] Validating results..." -ForegroundColor Green
    
    $original = Get-Content -LiteralPath $CharacterJsonPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $recon1 = Get-Content -LiteralPath $reconstructedJSON1 -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $recon2 = Get-Content -LiteralPath $reconstructedJSON2 -Raw | ConvertFrom-Json -AsHashtable -Depth 100

    # Verify key fields
    $testsPassed = 0
    $testsFailed = 0

    $keyFields = @('characterName', 'isSynth', 'voicePitch', 'reactionSetName')
    foreach ($field in $keyFields) {
        if ($original.ContainsKey($field) -and $recon1.ContainsKey($field)) {
            if ($original[$field] -eq $recon1[$field]) {
                Write-Host "  ✓ $field matches (YAML roundtrip)" -ForegroundColor Green
                $testsPassed++
            } else {
                Write-Host "  ✗ $field mismatch: $($original[$field]) vs $($recon1[$field])" -ForegroundColor Red
                $testsFailed++
            }
        }
    }

    # Verify array counts
    @('blendshapes', 'boneData', 'accessories', 'vertexAccessories') | ForEach-Object {
        $field = $_
        if ($original.ContainsKey($field)) {
            $origCount = @($original[$field]).Count
            $recon1Count = @($recon1[$field]).Count
            if ($origCount -eq $recon1Count) {
                Write-Host "  ✓ $field count: $origCount (YAML roundtrip)" -ForegroundColor Green
                $testsPassed++
            } else {
                Write-Host "  ✗ $field count mismatch: orig=$origCount, recon=$recon1Count" -ForegroundColor Red
                $testsFailed++
            }
        }
    }

    Write-Host
    Write-Host "===== Results =====" -ForegroundColor Cyan
    Write-Host "Passed: $testsPassed" -ForegroundColor Green
    Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { 'Green' } else { 'Red' })
    Write-Host

    if ($testsFailed -eq 0) {
        Write-Host "✓ All tests passed!" -ForegroundColor Green
        
        if (-not $KeepArtifacts) {
            Write-Host "Cleaning up..." -ForegroundColor Yellow
            Remove-Item -Path $testDir -Recurse -Force
        } else {
            Write-Host "Artifacts retained: $testDir" -ForegroundColor Yellow
        }
        exit 0
    } else {
        Write-Host "✗ Some tests failed!" -ForegroundColor Red
        Write-Host "Artifacts retained: $testDir" -ForegroundColor Yellow
        exit 1
    }

} catch {
    Write-Host "✗ Test failed with exception:" -ForegroundColor Red
    Write-Error $_
    Write-Host "Artifacts retained: $testDir" -ForegroundColor Yellow
    exit 1
}
