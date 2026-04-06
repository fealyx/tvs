[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$OutputDir,
    [switch]$MetadataOnly,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/Resolve-ZnelcharModuleManifest.ps1"
$moduleManifest = Resolve-ZnelcharModuleManifest
Import-Module $moduleManifest -Force -ErrorAction Stop

$result = Export-ZnelcharContent @PSBoundParameters
$result | ConvertTo-Json -Depth 10
