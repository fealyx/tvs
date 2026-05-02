function Compress-TVSCharacterPreset {
<#
.SYNOPSIS
Compresses an expanded character directory back to a .znelchar file.

.DESCRIPTION
Delegates to Compress-ZnelcharData (Znelchar.Tools) using the direct pipeline:
{characterWorkDir}/expanded/{name}/ is compressed directly back into a
{characterWorkDir}/presets/{name}.znelchar file without requiring an intermediary
character.json or manifest.json.

Texture ordering is restored from the 'textures' map in _metadata.yaml (written
during Expand-TVSCharacterPreset). If no map is present (e.g. the expanded directory
was produced from a character.json rather than a .znelchar), texture filenames are
sorted alphabetically as a fallback.

.PARAMETER Name
Character name (matches the expanded directory name).

.PARAMETER SourcePath
Direct path to the expanded directory. Overrides -Name lookup.

.PARAMETER OutputPath
Path for the output .znelchar file. Defaults to
{characterWorkDir}/presets/{name}.znelchar.

.PARAMETER Force
Overwrite the output .znelchar file if it already exists.
#>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByPath', Mandatory = $true)]
        [string]$SourcePath,

        [string]$OutputPath = '',

        [switch]$Force
    )

    $env = Get-TVSEnvironment

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $SourcePath = Join-Path $env.characterWorkDir 'expanded' $Name
    }

    if (-not (Test-Path $SourcePath -PathType Container)) {
        throw "Expanded directory not found at: $SourcePath"
    }

    if (-not $OutputPath) {
        $baseName = Split-Path $SourcePath -Leaf
        $OutputPath = Join-Path $env.characterWorkDir 'presets' "${baseName}.znelchar"
    }

    $result = Compress-ZnelcharData -InputPath $SourcePath -OutputPath $OutputPath -Force:$Force

    Write-Verbose "Compressed '$SourcePath' to $($result.OutputPath)"
    return $result.OutputPath
}
