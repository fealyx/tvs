[CmdletBinding()]
param(
    [string]$CharacterJsonPath,
    [string]$TexturesDir,
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/Resolve-ZnelcharModuleManifest.ps1"
$moduleManifest = Resolve-ZnelcharModuleManifest
Import-Module $moduleManifest -Force -ErrorAction Stop

$result = New-ZnelcharFile @PSBoundParameters
$result | ConvertTo-Json -Depth 10
