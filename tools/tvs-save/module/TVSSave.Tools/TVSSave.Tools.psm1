Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:TVSSaveModuleRoot = $PSScriptRoot

# Helper function to find and import a module from workspace sibling directories
function Import-WorkspaceModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string]$WorkspaceRoot
    )

    # Check if already loaded
    $loaded = Get-Module -Name $ModuleName
    if ($loaded) {
        return $loaded
    }

    # Check if available in PSModulePath
    $available = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1
    if ($available) {
        Import-Module $available -Global
        return $available
    }

    # Try to find in workspace sibling module directories
    $siblingModules = @(
        Join-Path $WorkspaceRoot 'tools/tvs-environment/module'
        Join-Path $WorkspaceRoot 'tools/znelchar/module'
        Join-Path $WorkspaceRoot 'tools/tvsm/module'
    )

    foreach ($modDir in $siblingModules) {
        $modPath = Join-Path $modDir $ModuleName
        $psd1 = Join-Path $modPath "$ModuleName.psd1"
        $psm1 = Join-Path $modPath "$ModuleName.psm1"

        if (Test-Path $psd1) {
            Import-Module $psd1 -Global
            return Get-Module -Name $ModuleName
        }
        elseif (Test-Path $psm1) {
            Import-Module $psm1 -Global
            return Get-Module -Name $ModuleName
        }
    }

    throw "$ModuleName module is not available. Install it from the TVS Tools bundle or from the module zip."
}

# Calculate workspace root (four levels up from TVSSave.Tools.psm1: TVSSave.Tools -> module -> tvs-save -> tools -> workspace root)
$workspaceRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))

# Import dependencies
$null = Import-WorkspaceModule -ModuleName 'TVS.Environment' -WorkspaceRoot $workspaceRoot
$null = Import-WorkspaceModule -ModuleName 'Znelchar.Tools' -WorkspaceRoot $workspaceRoot

# Load private helpers
Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }

# Load public cmdlets
Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction Stop |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }
