Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:TVSEnvironmentModuleRoot = $PSScriptRoot

# Load private helpers first (alphabetical order for determinism)
Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction Stop |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }

# Load public cmdlets
Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction Stop |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }
