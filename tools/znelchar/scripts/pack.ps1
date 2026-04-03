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

function Resolve-ZnelcharModuleManifest {
    $packagedManifest = Join-Path $PSScriptRoot '../Znelchar.Tools.psd1'
    if (Test-Path -LiteralPath $packagedManifest) {
        return (Resolve-Path $packagedManifest).Path
    }

    $devManifest = Join-Path $PSScriptRoot '../module/Znelchar.Tools/Znelchar.Tools.psd1'
    if (Test-Path -LiteralPath $devManifest) {
        return (Resolve-Path $devManifest).Path
    }

    throw 'Could not locate Znelchar.Tools module manifest for pack.'
}

$moduleManifest = Resolve-ZnelcharModuleManifest
Import-Module $moduleManifest -Force -ErrorAction Stop

$result = New-ZnelcharFile @PSBoundParameters
$result | ConvertTo-Json -Depth 10
