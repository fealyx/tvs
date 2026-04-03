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

function Resolve-ZnelcharModuleManifest {
    $packagedManifest = Join-Path $PSScriptRoot '../Znelchar.Tools.psd1'
    if (Test-Path -LiteralPath $packagedManifest) {
        return (Resolve-Path $packagedManifest).Path
    }

    $devManifest = Join-Path $PSScriptRoot '../module/Znelchar.Tools/Znelchar.Tools.psd1'
    if (Test-Path -LiteralPath $devManifest) {
        return (Resolve-Path $devManifest).Path
    }

    throw 'Could not locate Znelchar.Tools module manifest for extract.'
}

$moduleManifest = Resolve-ZnelcharModuleManifest
Import-Module $moduleManifest -Force -ErrorAction Stop

$result = Export-ZnelcharContent @PSBoundParameters
$result | ConvertTo-Json -Depth 10
