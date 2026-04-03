[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$OuterSchemaPath = "$PSScriptRoot/../schemas/znelchar.schema.json",
    [string]$CharacterSchemaPath = "$PSScriptRoot/../schemas/characterData.schema.json",
    [string]$OpinionDataSchemaPath = "$PSScriptRoot/../schemas/opinionDataString.schema.json",

    [switch]$ValidateSchema,
    [switch]$MetadataOnly
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

    throw 'Could not locate Znelchar.Tools module manifest for inspect.'
}

$moduleManifest = Resolve-ZnelcharModuleManifest
Import-Module $moduleManifest -Force -ErrorAction Stop

$result = Get-ZnelcharInfo @PSBoundParameters
$result | ConvertTo-Json -Depth 50
