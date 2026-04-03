[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$WorkDir,
    [switch]$MetadataOnly,
    [switch]$Force,
    [string]$DiffReportPath,
    [switch]$CiSummary,
    [switch]$KeepWorkDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ZnelcharModuleManifest {
    $packagedManifest = Join-Path $PSScriptRoot '../Znelchar.Tools.psd1'
    if (Test-Path -LiteralPath $packagedManifest) {
        return (Resolve-Path $packagedManifest).Path
    }

    $devManifest = Join-Path $PSScriptRoot '../module/Znelchar.Tools/Znelchar.Tools.psd1'
    if (Test-Path -LiteralPath $devManifest) {
        return (Resolve-Path $devManifest).Path
    }

    throw 'Could not locate Znelchar.Tools module manifest for roundtrip verify.'
}

$moduleManifest = Resolve-ZnelcharModuleManifest
Import-Module $moduleManifest -Force -ErrorAction Stop

try {
    $result = Test-ZnelcharRoundtrip @PSBoundParameters
    $result | ConvertTo-Json -Depth 10
    exit 0
}
catch {
    Write-Error $_
    exit 1
}
