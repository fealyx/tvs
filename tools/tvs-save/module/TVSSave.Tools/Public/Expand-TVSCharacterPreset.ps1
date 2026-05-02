function Expand-TVSCharacterPreset {
<#
.SYNOPSIS
Expands a .znelchar preset file to the multi-file character format.

.DESCRIPTION
Delegates to Expand-ZnelcharData (Znelchar.Tools) using the direct pipeline:
the .znelchar file is expanded directly into {characterWorkDir}/expanded/{name}/
without requiring an intermediary extraction step.

The resulting expanded directory is fully self-contained — Compress-TVSCharacterPreset
can produce a valid .znelchar from it without any external manifest.

.PARAMETER Name
Character name (matches the .znelchar filename without extension).

.PARAMETER SourcePath
Direct path to the .znelchar file. Overrides -Name lookup.

.PARAMETER OutputPath
Directory for expanded output. Defaults to
{characterWorkDir}/expanded/{name}/ from TVS.Environment.

.PARAMETER Force
Overwrite the expanded directory if it already exists.
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
        $SourcePath = Join-Path $env.characterWorkDir 'presets' "${Name}.znelchar"
    }

    if (-not (Test-Path $SourcePath -PathType Leaf)) {
        throw ".znelchar file not found at: $SourcePath"
    }

    if (-not $OutputPath) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)
        $OutputPath = Join-Path $env.characterWorkDir 'expanded' $baseName
    }

    $result = Expand-ZnelcharData -InputPath $SourcePath -OutputPath $OutputPath -Force:$Force

    Write-Verbose "Expanded '$SourcePath' to $($result.ExpandedPath)"
    return $result.ExpandedPath
}
