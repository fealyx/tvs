<#
.SYNOPSIS
Writes a data object to a file in the specified format (YAML or JSON).

.DESCRIPTION
Serializes a PowerShell object to either YAML or JSON format and writes it to a file.
Supports UTF-8 encoding without BOM for consistency across platforms.

.PARAMETER InputObject
The object to write.

.PARAMETER OutputPath
The file path to write to.

.PARAMETER Format
The output format: 'yaml' (default), 'json', or 'auto' (detect from extension).

.PARAMETER Force
Overwrite existing file if it exists.

.EXAMPLE
$data = @{ name = "Rita"; items = @(1, 2, 3) }
Write-DataFile -InputObject $data -OutputPath "data.yaml" -Format yaml

.NOTES
Internal use within Znelchar.Tools module.
#>

function Write-DataFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [ValidateSet('yaml', 'json', 'auto')]
        [string]$Format = 'auto',

        [switch]$Force
    )

    process {
        # Determine format from extension if 'auto'
        if ($Format -eq 'auto') {
            $ext = [System.IO.Path]::GetExtension($OutputPath).ToLower()
            $Format = switch ($ext) {
                { $_ -in @('.yaml', '.yml') } { 'yaml' }
                '.json' { 'json' }
                default { 'yaml' }
            }
        }

        # Check if file exists
        if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
            throw "File already exists: $OutputPath. Use -Force to overwrite."
        }

        # Ensure directory exists
        $dir = Split-Path -Parent $OutputPath
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        # Serialize to string
        $content = switch ($Format) {
            'yaml' {
                $InputObject | ConvertTo-Yaml
            }
            'json' {
                ConvertTo-Json -InputObject $InputObject -Depth 100
            }
        }

        # Write with UTF-8 no-BOM
        Write-Utf8NoBomFile -Path $OutputPath -Content $content
    }
}

