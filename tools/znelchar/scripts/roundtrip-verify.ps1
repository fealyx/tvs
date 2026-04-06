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

. "$PSScriptRoot/Resolve-ZnelcharModuleManifest.ps1"
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
