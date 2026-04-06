[CmdletBinding()]
param(
    [string]$ManifestPath = './dist/znelchar-release-manifest.json',
    [ValidateSet('module', 'core', 'portable')]
    [string]$Variant = 'core',
    [string[]]$Variants
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Copy-Hashtable {
    param([hashtable]$Value)

    return ($Value | ConvertTo-Json -Depth 40 | ConvertFrom-Json -AsHashtable -Depth 40)
}

function Get-ArtifactByVariant {
    param(
        [hashtable]$Manifest,
        [string]$SelectedVariant
    )

    $artifact = @($Manifest.artifacts | Where-Object { $_.variant -eq $SelectedVariant } | Select-Object -First 1)
    if ($artifact.Count -eq 0) {
        throw "No artifact found for variant '$SelectedVariant' in manifest."
    }

    return $artifact[0]
}

function Write-ManifestFile {
    param(
        [hashtable]$Manifest,
        [string]$Path
    )

    $json = $Manifest | ConvertTo-Json -Depth 40
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Invoke-VariantSelfTest {
    param(
        [hashtable]$Manifest,
        [System.Management.Automation.PathInfo]$ResolvedManifestPath,
        [string]$DistDir,
        [string]$SelectedVariant,
        [string]$VariantWorkRoot
    )

    $selectedArtifact = Get-ArtifactByVariant -Manifest $Manifest -SelectedVariant $SelectedVariant

    $preferredMismatchVariant = if ($SelectedVariant -eq 'module') { 'core' } else { 'module' }
    $mismatchArtifact = @($Manifest.artifacts | Where-Object { $_.variant -eq $preferredMismatchVariant } | Select-Object -First 1)
    if ($mismatchArtifact.Count -eq 0) {
        $mismatchArtifact = @($Manifest.artifacts | Where-Object { $_.variant -ne $SelectedVariant } | Select-Object -First 1)
    }

    Assert-Condition -Condition ($mismatchArtifact.Count -gt 0) -Message "No mismatch artifact available in manifest for rollback simulation of variant '$SelectedVariant'."
    $mismatchArtifact = $mismatchArtifact[0]

    $variantArchivePath = Join-Path $DistDir $selectedArtifact.fileName
    $mismatchArchivePath = Join-Path $DistDir $mismatchArtifact.fileName

    Assert-Condition -Condition (Test-Path -LiteralPath $variantArchivePath) -Message "Variant archive not found: $variantArchivePath"
    Assert-Condition -Condition (Test-Path -LiteralPath $mismatchArchivePath) -Message "Mismatch archive not found: $mismatchArchivePath"

    $installPath = Join-Path $VariantWorkRoot "install-$SelectedVariant"
    $scratchPath = Join-Path $VariantWorkRoot 'scratch'

    if (Test-Path -LiteralPath $VariantWorkRoot) {
        Remove-Item -LiteralPath $VariantWorkRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Path $scratchPath -Force | Out-Null

    $results = [ordered]@{}

    # 1) Baseline check/install/verify
    $checkResult = Update-ZnelcharTools -Operation check -Variant $SelectedVariant -ManifestPath $ResolvedManifestPath
    $results.check = $checkResult

    $installResult = Update-ZnelcharTools -Operation install -Variant $SelectedVariant -ManifestPath $ResolvedManifestPath -AssetDirectory $DistDir -InstallPath $installPath -Force
    $results.install = $installResult

    $verifyResult = Update-ZnelcharTools -Operation verify -Variant $SelectedVariant -ManifestPath $ResolvedManifestPath -InstallPath $installPath
    $results.verify = $verifyResult

    Assert-Condition -Condition $verifyResult.verification.verified -Message "Baseline verify operation reported verified=false for variant '$SelectedVariant'."

    $statePath = Join-Path $installPath '.znelchar-install.json'
    Assert-Condition -Condition (Test-Path -LiteralPath $statePath) -Message "Missing install state after baseline install: $statePath"
    $stateBeforeRollback = Get-Content -Raw -LiteralPath $statePath

    # 2) Rollback simulation: valid checksum but wrong payload archive for selected variant.
    $rollbackManifest = Copy-Hashtable -Value $Manifest
    $rollbackArtifact = Get-ArtifactByVariant -Manifest $rollbackManifest -SelectedVariant $SelectedVariant
    $rollbackArtifact.fileName = $mismatchArtifact.fileName
    $rollbackArtifact.sha256 = $mismatchArtifact.sha256
    $rollbackManifestPath = Join-Path $scratchPath 'manifest-rollback.json'
    Write-ManifestFile -Manifest $rollbackManifest -Path $rollbackManifestPath

    $rollbackFailureCaught = $false
    $rollbackError = $null
    try {
        Update-ZnelcharTools -Operation install -Variant $SelectedVariant -ManifestPath $rollbackManifestPath -AssetDirectory $DistDir -InstallPath $installPath -Force | Out-Null
    }
    catch {
        $rollbackFailureCaught = $true
        $rollbackError = $_.Exception.Message
    }

    Assert-Condition -Condition $rollbackFailureCaught -Message "Rollback simulation expected install failure, but install succeeded for variant '$SelectedVariant'."
    Assert-Condition -Condition (Test-Path -LiteralPath $installPath) -Message 'Install path missing after rollback simulation failure.'
    Assert-Condition -Condition (Test-Path -LiteralPath $statePath) -Message 'State file missing after rollback simulation failure.'

    $stateAfterRollback = Get-Content -Raw -LiteralPath $statePath
    Assert-Condition -Condition ($stateBeforeRollback -eq $stateAfterRollback) -Message 'Install state changed during rollback simulation failure.'

    $verifyAfterRollback = Update-ZnelcharTools -Operation verify -Variant $SelectedVariant -ManifestPath $ResolvedManifestPath -InstallPath $installPath
    Assert-Condition -Condition $verifyAfterRollback.verification.verified -Message "Install did not remain verifiable after rollback simulation for variant '$SelectedVariant'."

    $results.rollbackSimulation = [ordered]@{
        mismatchVariant = $mismatchArtifact.variant
        mismatchArtifact = $mismatchArtifact.fileName
        failureCaught = $rollbackFailureCaught
        error = $rollbackError
        verification = $verifyAfterRollback.verification
    }

    # 3) Checksum failure simulation.
    $checksumManifest = Copy-Hashtable -Value $Manifest
    $checksumArtifact = Get-ArtifactByVariant -Manifest $checksumManifest -SelectedVariant $SelectedVariant
    $checksumArtifact.sha256 = ('0' * 64)
    $checksumManifestPath = Join-Path $scratchPath 'manifest-bad-checksum.json'
    Write-ManifestFile -Manifest $checksumManifest -Path $checksumManifestPath

    $checksumFailureCaught = $false
    $checksumError = $null
    try {
        Update-ZnelcharTools -Operation install -Variant $SelectedVariant -ManifestPath $checksumManifestPath -AssetDirectory $DistDir -InstallPath $installPath -Force | Out-Null
    }
    catch {
        $checksumFailureCaught = $true
        $checksumError = $_.Exception.Message
    }

    Assert-Condition -Condition $checksumFailureCaught -Message "Checksum simulation expected install failure, but install succeeded for variant '$SelectedVariant'."

    $verifyAfterChecksumFailure = Update-ZnelcharTools -Operation verify -Variant $SelectedVariant -ManifestPath $ResolvedManifestPath -InstallPath $installPath
    Assert-Condition -Condition $verifyAfterChecksumFailure.verification.verified -Message "Install did not remain verifiable after checksum failure simulation for variant '$SelectedVariant'."

    $results.checksumSimulation = [ordered]@{
        failureCaught = $checksumFailureCaught
        error = $checksumError
        verification = $verifyAfterChecksumFailure.verification
    }

    $results.summary = [ordered]@{
        variant = $SelectedVariant
        manifest = $ResolvedManifestPath.Path
        installPath = $installPath
        passed = $true
    }

    return $results
}

$resolvedManifestPath = Resolve-Path -Path $ManifestPath

. "$PSScriptRoot/Resolve-ZnelcharModuleManifest.ps1"
$moduleManifest = Resolve-ZnelcharModuleManifest
Import-Module $moduleManifest -Force -ErrorAction Stop

$manifest = Get-Content -Raw -LiteralPath $resolvedManifestPath | ConvertFrom-Json -AsHashtable -Depth 40
$distDir = Split-Path -Parent $resolvedManifestPath
$workRoot = Join-Path $distDir 'update-selftest'

$allowedVariants = @('module', 'core', 'portable')

$selectedVariants = @()
if ($PSBoundParameters.ContainsKey('Variants') -and $null -ne $Variants -and $Variants.Count -gt 0) {
    $expandedVariants = @()
    foreach ($entry in $Variants) {
        if ([string]::IsNullOrWhiteSpace($entry)) {
            continue
        }

        $expandedVariants += @($entry -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $selectedVariants = @($expandedVariants | Select-Object -Unique)
}
else {
    $selectedVariants = @($Variant)
}

Assert-Condition -Condition ($selectedVariants.Count -gt 0) -Message 'No variants were provided for self-test execution.'
foreach ($selectedVariant in $selectedVariants) {
    Assert-Condition -Condition ($allowedVariants -contains $selectedVariant) -Message "Unsupported variant '$selectedVariant'. Allowed variants: module, core, portable."
}

$aggregateResults = [ordered]@{}
foreach ($selectedVariant in $selectedVariants) {
    $variantWorkRoot = Join-Path $workRoot $selectedVariant
    $aggregateResults[$selectedVariant] = Invoke-VariantSelfTest -Manifest $manifest -ResolvedManifestPath $resolvedManifestPath -DistDir $distDir -SelectedVariant $selectedVariant -VariantWorkRoot $variantWorkRoot
}

if ($selectedVariants.Count -eq 1 -and -not $PSBoundParameters.ContainsKey('Variants')) {
    $aggregateResults[$selectedVariants[0]] | ConvertTo-Json -Depth 40
}
else {
    [ordered]@{
        variants = $selectedVariants
        variantResults = $aggregateResults
        summary = [ordered]@{
            passed = $true
            variantCount = $selectedVariants.Count
            manifest = $resolvedManifestPath.Path
        }
    } | ConvertTo-Json -Depth 50
}
