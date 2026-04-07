[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$ImagePath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('icon', 'texture')]
    [string]$Target,

    [string]$TextureName,
    [string]$OutputPath,
    [string]$BackupOriginalPayloadPath,
    [switch]$BackupOriginalFile,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/Resolve-ZnelcharModuleManifest.ps1"
$moduleManifest = Resolve-ZnelcharModuleManifest
Import-Module $moduleManifest -Force -ErrorAction Stop

$result = Set-ZnelcharImagePayload @PSBoundParameters
$result | ConvertTo-Json -Depth 10