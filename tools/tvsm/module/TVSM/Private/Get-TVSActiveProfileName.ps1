function Get-TVSActiveProfileName {
<#
.SYNOPSIS
Returns the name of the currently active mod profile by reading {modWorkDir}/.active-profile.
Returns 'default' if the file does not exist or is empty.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModWorkDir
    )

    $path = Join-Path $ModWorkDir '.active-profile'
    if (-not (Test-Path -LiteralPath $path)) {
        return 'default'
    }

    $name = (Get-Content -Raw -LiteralPath $path -ErrorAction SilentlyContinue).Trim()
    return if ([string]::IsNullOrEmpty($name)) { 'default' } else { $name }
}

function Set-TVSActiveProfileName {
<#
.SYNOPSIS
Writes the given profile name to {modWorkDir}/.active-profile.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModWorkDir,
        [Parameter(Mandatory)][string]$ProfileName
    )

    if (-not (Test-Path -LiteralPath $ModWorkDir)) {
        New-Item -ItemType Directory -Path $ModWorkDir -Force | Out-Null
    }

    $path = Join-Path $ModWorkDir '.active-profile'
    [System.IO.File]::WriteAllText($path, $ProfileName, [System.Text.UTF8Encoding]::new($false))
}
