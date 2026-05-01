function Write-TVSModProfile {
<#
.SYNOPSIS
Serialises and writes a mod profile hashtable to {modWorkDir}/profiles/{name}.json.
Creates the profiles directory if it does not exist. Writes UTF-8 without BOM.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModWorkDir,
        [Parameter(Mandatory)][hashtable]$ProfileData,
        [string]$ProfileName = ''
    )

    if ([string]::IsNullOrEmpty($ProfileName)) {
        $ProfileName = $ProfileData['name']
        if ([string]::IsNullOrEmpty($ProfileName)) {
            $ProfileName = Get-TVSActiveProfileName -ModWorkDir $ModWorkDir
        }
    }

    $dir = Join-Path $ModWorkDir 'profiles'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $path = Join-Path $dir "$ProfileName.json"
    $json = $ProfileData | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
}
