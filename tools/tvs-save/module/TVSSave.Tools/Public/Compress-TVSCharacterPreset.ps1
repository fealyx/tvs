function Compress-TVSCharacterPreset {
<#
.SYNOPSIS
Compresses an expanded character directory back to a .znelchar file.

.DESCRIPTION
Delegates to Compress-ZnelcharData (Znelchar.Tools) to compress
{characterWorkDir}/expanded/{name}/ back into
{characterWorkDir}/presets/{name}.znelchar.

.PARAMETER Name
Character name (matches the expanded directory name).

.PARAMETER SourcePath
Direct path to the expanded directory. Overrides -Name lookup.

.PARAMETER OutputPath
Path for the output .znelchar file. Defaults to
{characterWorkDir}/presets/{name}.znelchar.
#>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByPath', Mandatory = $true)]
        [string]$SourcePath,

        [string]$OutputPath = ''
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

    Compress-ZnelcharData -InputDir $SourcePath -OutputPath $OutputPath

    Write-Verbose "Compressed '$SourcePath' to $OutputPath"
    return $OutputPath
}
