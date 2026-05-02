function Write-TVSDevLinks {
<#
.SYNOPSIS
Serialises and writes the dev-links hashtable to {modWorkDir}/dev-links.json.
Writes UTF-8 without BOM.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModWorkDir,
        [Parameter(Mandatory)][hashtable]$DevLinks
    )

    if (-not (Test-Path -LiteralPath $ModWorkDir)) {
        New-Item -ItemType Directory -Path $ModWorkDir -Force | Out-Null
    }

    $path = Join-Path $ModWorkDir 'dev-links.json'
    $json = $DevLinks | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
}
