Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Capture module root at load time; used by Get-ZnelcharToolRoot to resolve schemas/scripts
$script:ZnelcharModuleRoot = $PSScriptRoot

# Ensure powershell-yaml is available for YAML serialization
if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
    Install-Module -Name 'powershell-yaml' -Scope CurrentUser -Force -AllowClobber
}
Import-Module 'powershell-yaml' -Global

# Load private helpers
Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction Stop |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }

# Load public cmdlets
Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction Stop |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }
