function Read-TVSDevLinks {
<#
.SYNOPSIS
Reads {modWorkDir}/dev-links.json and returns it as a hashtable.
Returns a default empty structure if the file does not exist.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModWorkDir
    )

    $path = Join-Path $ModWorkDir 'dev-links.json'
    if (-not (Test-Path -LiteralPath $path)) {
        return @{ schemaVersion = 1; links = @{} }
    }

    return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -AsHashtable -Depth 20
}
