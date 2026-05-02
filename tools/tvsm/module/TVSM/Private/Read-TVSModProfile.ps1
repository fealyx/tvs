function Read-TVSModProfile {
<#
.SYNOPSIS
Reads and deserialises a mod profile JSON file from {modWorkDir}/profiles/{name}.json.

.OUTPUTS
Hashtable representing the profile, or $null if the file does not exist.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModWorkDir,
        [string]$ProfileName = ''
    )

    if ([string]::IsNullOrEmpty($ProfileName)) {
        $ProfileName = Get-TVSActiveProfileName -ModWorkDir $ModWorkDir
    }

    $path = Join-Path $ModWorkDir 'profiles' "$ProfileName.json"
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }

    $data = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -AsHashtable -Depth 20

    if ($data['schemaVersion'] -ne 1) {
        throw "Unsupported mod profile schema version '$($data['schemaVersion'])' in: $path"
    }

    return $data
}
