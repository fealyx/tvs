[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$OutputPath,
    [switch]$MetadataOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/Resolve-ZnelcharModuleManifest.ps1"
$moduleManifest = Resolve-ZnelcharModuleManifest
Import-Module $moduleManifest -Force -ErrorAction Stop

$result = Convert-ZnelcharToYaml @PSBoundParameters
$result | ConvertTo-Json -Depth 10
