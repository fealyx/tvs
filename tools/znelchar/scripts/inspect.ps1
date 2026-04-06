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

. "$PSScriptRoot/Resolve-ZnelcharModuleManifest.ps1"
$moduleManifest = Resolve-ZnelcharModuleManifest
Import-Module $moduleManifest -Force -ErrorAction Stop

$result = Get-ZnelcharInfo @PSBoundParameters
$result | ConvertTo-Json -Depth 50
