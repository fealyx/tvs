Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:TVSMModuleRoot = $PSScriptRoot

# Ensure PwshSpectreConsole is available for TUI rendering
if (-not (Get-Module -ListAvailable -Name 'PwshSpectreConsole')) {
    Install-Module -Name 'PwshSpectreConsole' -Scope CurrentUser -Force -AllowClobber
}
Import-Module 'PwshSpectreConsole' -Global

# Ensure TVS.Environment is available
if (-not (Get-Module -ListAvailable -Name 'TVS.Environment')) {
    throw "TVS.Environment module is not available. Install it from the TVS Tools bundle or from the module zip."
}
Import-Module 'TVS.Environment' -Global

# Load private helpers
Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }

# Load public cmdlets
Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction Stop |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }
