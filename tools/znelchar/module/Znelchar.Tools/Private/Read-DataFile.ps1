<#
.SYNOPSIS
Reads a data file in YAML or JSON format and returns the deserialized object.

.DESCRIPTION
Parses a YAML or JSON file and returns the deserialized PowerShell object or hashtable.
Format is auto-detected from file extension if not explicitly specified.

.PARAMETER Path
The file path to read.

.PARAMETER Format
The format: 'yaml', 'json', or 'auto' (detect from extension, default).

.EXAMPLE
$data = Read-DataFile -Path "data.yaml"
$jsonData = Read-DataFile -Path "data.json" -Format json

.NOTES
Internal use within Znelchar.Tools module.
#>

function Read-DataFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [ValidateSet('yaml', 'json', 'auto')]
        [string]$Format = 'auto'
    )

    process {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "File not found: $Path"
        }

        # Determine format from extension if 'auto'
        if ($Format -eq 'auto') {
            $ext = [System.IO.Path]::GetExtension($Path).ToLower()
            $Format = switch ($ext) {
                { $_ -in @('.yaml', '.yml') } { 'yaml' }
                '.json' { 'json' }
                default { 'yaml' }
            }
        }

        # Read file content
        $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)

        # Parse based on format
        $result = switch ($Format) {
            'yaml' {
                ConvertFrom-Yaml -Yaml $content -Ordered
            }
            'json' {
                ConvertFrom-Json -InputObject $content -AsHashtable
            }
        }

        return $result
    }
}

