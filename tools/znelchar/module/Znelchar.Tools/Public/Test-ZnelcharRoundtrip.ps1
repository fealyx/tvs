function Test-ZnelcharRoundtrip {
<#
.SYNOPSIS
Runs extract, pack, and verify in one command.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [string]$WorkDir,
        [switch]$MetadataOnly,
        [switch]$Force,
        [string]$DiffReportPath,
        [switch]$CiSummary,
        [switch]$KeepWorkDir
    )

    $resolvedInputPath = (Resolve-Path $InputPath).Path
    if (-not $WorkDir) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedInputPath)
        $toolRoot = Get-ZnelcharToolRoot
        $WorkDir = Join-Path $toolRoot ("out/roundtrip-" + $baseName)
    }

    $resolvedWorkDir = [System.IO.Path]::GetFullPath($WorkDir)
    $extractDir = Join-Path $resolvedWorkDir 'extract'
    $packedPath = Join-Path $resolvedWorkDir 'repacked.znelchar'
    $manifestPath = Join-Path $extractDir 'manifest.json'

    if ((Test-Path -LiteralPath $resolvedWorkDir) -and -not $Force) {
        throw "WorkDir already exists. Use -Force to overwrite: $resolvedWorkDir"
    }

    if (-not $PSCmdlet.ShouldProcess($resolvedWorkDir, 'Run roundtrip verify')) {
        return
    }

    if (Test-Path -LiteralPath $resolvedWorkDir) {
        Remove-Item -LiteralPath $resolvedWorkDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $resolvedWorkDir -Force | Out-Null

    Write-Stage -Prefix 'roundtrip' -Message 'Extracting source file'
    Export-ZnelcharContent -InputPath $resolvedInputPath -OutputDir $extractDir -Force -MetadataOnly:$MetadataOnly | Out-Null

    Write-Stage -Prefix 'roundtrip' -Message 'Packing extracted data'
    New-ZnelcharFile -ManifestPath $manifestPath -OutputPath $packedPath -Force | Out-Null

    Write-Stage -Prefix 'roundtrip' -Message 'Running semantic verify'
    $verifyResult = Test-ZnelcharFile -LeftPath $resolvedInputPath -RightPath $packedPath -DiffReportPath $DiffReportPath -CiSummary:$CiSummary

    if (-not $KeepWorkDir) {
        Write-Stage -Prefix 'roundtrip' -Message 'Cleaning up work directory'
        Remove-Item -LiteralPath $resolvedWorkDir -Recurse -Force
    }

    if (-not $verifyResult.equivalent) {
        throw 'Roundtrip verification failed'
    }

    Write-Stage -Prefix 'roundtrip' -Message 'Completed'
    return [ordered]@{
        inputFile = $resolvedInputPath
        workDir = $resolvedWorkDir
        packedFile = $packedPath
        diffReport = if ([string]::IsNullOrWhiteSpace($DiffReportPath)) { $null } else { [System.IO.Path]::GetFullPath($DiffReportPath) }
        metadataOnly = [bool]$MetadataOnly
        keepWorkDir = [bool]$KeepWorkDir
    }
}
