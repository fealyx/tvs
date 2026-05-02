function ConvertFrom-TVSPresetSlot {
<#
.SYNOPSIS
Parses a presetSlot{n}.txt.tmp file into a valid znelchar JSON string.

.DESCRIPTION
The presetSlot file contains a znelchar JSON payload that has been
JSON-stringified and wrapped in { … } brackets (an artefact of the
Easy Save 3 serialiser). This function:

  1. Reads the raw file content.
  2. Strips the leading { and, if present, trailing }.
  3. JSON-unescapes the resulting string to recover valid znelchar JSON.
  4. Parses and re-serialises to produce clean, normalised output.

Both forms (with and without closing brace) are tolerated on input.

.PARAMETER Path
Path to the presetSlot{n}.txt.tmp file.

.PARAMETER Raw
Switch. When present, returns the raw znelchar JSON string without
parsing/re-serialising.

.OUTPUTS
A valid znelchar JSON string. If -Raw is specified, the unescaped
string as-is from the file (may contain formatting variations).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [switch]$Raw
    )

    if (-not (Test-Path $Path -PathType Leaf)) {
        throw "presetSlot file not found at: $Path"
    }

    $content = Get-Content -Path $Path -Raw -Encoding UTF8

    # Strip leading { and trailing } if present
    $inner = $content.Trim()
    if ($inner.StartsWith('{')) {
        $inner = $inner.Substring(1)
    }
    if ($inner.EndsWith('}')) {
        $inner = $inner.Substring(0, $inner.Length - 1)
    }
    $inner = $inner.Trim()

    # The inner string is JSON-escaped znelchar JSON.
    # We need to JSON-unescape it. The safest way is to wrap it
    # as a JSON string value and parse it.
    try {
        $wrapped = '"' + $inner + '"'
        $unescaped = $wrapped | ConvertFrom-Json
    }
    catch {
        # Fallback: try with escaped content as-is (some files may
        # have inconsistent escaping)
        throw "Failed to JSON-unescape presetSlot content at '$Path': $_"
    }

    if ($Raw) {
        return $unescaped
    }

    # Parse and re-serialise to produce clean znelchar JSON
    try {
        $parsed = $unescaped | ConvertFrom-Json -AsHashtable -Depth 100
        return $parsed | ConvertTo-Json -Depth 100 -Compress
    }
    catch {
        throw "presetSlot content at '$Path' does not contain valid znelchar JSON after unescaping: $_"
    }
}
