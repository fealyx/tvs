function ConvertTo-TVSPresetSlot {
<#
.SYNOPSIS
Converts a znelchar JSON string into the presetSlot{n}.txt.tmp file format.

.DESCRIPTION
Performs the reverse of ConvertFrom-TVSPresetSlot:
  1. JSON-escapes the znelchar JSON string.
  2. Strips the wrapping double quotes from the escaped result.
  3. Wraps the content in { … } (no closing brace, matching
     the observed game output format).

.PARAMETER ZnelcharJson
The znelchar JSON string to convert.

.PARAMETER OutputPath
Path to write the presetSlot{n}.txt.tmp file.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZnelcharJson,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    # Validate that the input is valid JSON
    try {
        $null = $ZnelcharJson | ConvertFrom-Json -Depth 100
    }
    catch {
        throw "ZnelcharJson is not valid JSON: $_"
    }

    # JSON-escape the znelchar string by serialising it as a JSON string value
    # ConvertTo-Json on a string produces "escaped content"
    $escaped = $ZnelcharJson | ConvertTo-Json -Compress

    # Strip the leading and trailing double quotes added by ConvertTo-Json
    if ($escaped.StartsWith('"') -and $escaped.EndsWith('"')) {
        $escaped = $escaped.Substring(1, $escaped.Length - 2)
    }

    # Wrap in { … } (matching observed game output: no closing brace)
    $wrapped = '{' + $escaped

    $parentDir = Split-Path $OutputPath -Parent
    if ($parentDir -and -not (Test-Path $parentDir -PathType Container)) {
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    Set-Content -Path $OutputPath -Value $wrapped -Encoding UTF8 -NoNewline
}
