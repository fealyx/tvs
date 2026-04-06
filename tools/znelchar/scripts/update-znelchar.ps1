[CmdletBinding()]
param(
    [ValidateSet('check', 'install', 'verify')]
    [string]$Operation = 'check',

    [ValidateSet('module', 'core', 'portable')]
    [string]$Variant = 'core',

    [string]$InstallPath,
    [string]$ManifestPath,
    [string]$ManifestUrl,
    [string]$TargetVersion,
    [string]$AssetDirectory,
    [switch]$Force,
    [switch]$SkipChecksum
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/Resolve-ZnelcharModuleManifest.ps1"
$moduleManifest = Resolve-ZnelcharModuleManifest
Import-Module $moduleManifest -Force -ErrorAction Stop

$result = Update-ZnelcharTools @PSBoundParameters
$result | ConvertTo-Json -Depth 20
