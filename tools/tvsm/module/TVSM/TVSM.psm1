Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:TVSMModuleRoot = $PSScriptRoot

# ---------------------------------------------------------------------------
# Helper: find and import a workspace-sibling module (dev-layout fallback).
# In a bundled release RequiredModules handles this via PSModulePath; in the
# dev workspace the manifest loader may not find sibling modules unless the
# caller (tvsm.ps1) has pre-pended them to $env:PSModulePath.
# ---------------------------------------------------------------------------
function Import-TVSMSiblingModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string]$WorkspaceRoot
    )

    $loaded = Get-Module -Name $ModuleName
    if ($loaded) { return $loaded }

    $available = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1
    if ($available) {
        Import-Module $available -Global -Force
        return $available
    }

    # Dev-layout fallback: search sibling tool directories
    $siblingDirs = @(
        Join-Path $WorkspaceRoot 'tools/tvs-environment/module'
        Join-Path $WorkspaceRoot 'tools/tvs-save/module'
        Join-Path $WorkspaceRoot 'tools/znelchar/module'
    )

    foreach ($dir in $siblingDirs) {
        $psd1 = Join-Path $dir $ModuleName "$ModuleName.psd1"
        if (Test-Path $psd1) {
            Import-Module $psd1 -Global -Force
            return Get-Module -Name $ModuleName
        }
    }

    throw "$ModuleName module is not available. Install it from the TVS Tools bundle or from the module zip."
}

# Calculate workspace root (four levels up from TVSM.psm1: TVSM -> module -> tvsm -> tools -> workspace root)
$workspaceRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))

# Ensure PwshSpectreConsole is available for TUI rendering
if (-not (Get-Module -ListAvailable -Name 'PwshSpectreConsole')) {
    Install-Module -Name 'PwshSpectreConsole' -Scope CurrentUser -Force -AllowClobber
}
Import-Module 'PwshSpectreConsole' -Global

# Ensure TVS.Environment is available
$null = Import-TVSMSiblingModule -ModuleName 'TVS.Environment' -WorkspaceRoot $workspaceRoot

# Ensure TVSSave.Tools is available (RequiredModules in .psd1, but dev-layout needs sibling search)
$null = Import-TVSMSiblingModule -ModuleName 'TVSSave.Tools' -WorkspaceRoot $workspaceRoot

# Ensure Znelchar.Tools is available (RequiredModules in .psd1, but dev-layout needs sibling search)
$null = Import-TVSMSiblingModule -ModuleName 'Znelchar.Tools' -WorkspaceRoot $workspaceRoot

# Load private helpers
Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }

# Load public cmdlets
Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction Stop |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }
