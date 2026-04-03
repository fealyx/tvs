Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Capture module root at load time; used by Get-ZnelcharToolRoot to resolve schemas/scripts
$script:ZnelcharModuleRoot = $PSScriptRoot

# Load private helpers
Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction Stop |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }

# Load public cmdlets
Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction Stop |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }
