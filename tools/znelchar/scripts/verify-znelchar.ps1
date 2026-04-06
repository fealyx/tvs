[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LeftPath,

    [Parameter(Mandatory = $true)]
    [string]$RightPath,

    [switch]$IgnoreTextureOrder = $true,

    [string]$DiffReportPath,

    [switch]$CiSummary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/Resolve-ZnelcharModuleManifest.ps1"
$moduleManifest = Resolve-ZnelcharModuleManifest
Import-Module $moduleManifest -Force -ErrorAction Stop

$result = Test-ZnelcharFile @PSBoundParameters
$result | ConvertTo-Json -Depth 50

if ($result.equivalent) {
    exit 0
}

exit 1
