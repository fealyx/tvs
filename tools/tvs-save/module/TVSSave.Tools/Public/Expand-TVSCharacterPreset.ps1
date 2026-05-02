function Expand-TVSCharacterPreset {
<#
.SYNOPSIS
Expands a .znelchar preset file to the multi-file character format.

.DESCRIPTION
Delegates to Expand-ZnelcharData (Znelchar.Tools) to expand a
.znelchar file into {characterWorkDir}/expanded/{name}/.

.PARAMETER Name
Character name (matches the .znelchar filename without extension).

.PARAMETER SourcePath
Direct path to the .znelchar file. Overrides -Name lookup.

.PARAMETER OutputPath
Directory for expanded output. Defaults to
{characterWorkDir}/expanded/{name}/ from TVS.Environment.
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
        $SourcePath = Join-Path $env.characterWorkDir 'presets' "${Name}.znelchar"
    }

    if (-not (Test-Path $SourcePath -PathType Leaf)) {
        throw ".znelchar file not found at: $SourcePath"
    }

    if (-not $OutputPath) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)
        $OutputPath = Join-Path $env.characterWorkDir 'expanded' $baseName
    }

    Expand-ZnelcharData -InputPath $SourcePath -OutputDir $OutputPath

    Write-Verbose "Expanded '$SourcePath' to $OutputPath"
    return $OutputPath
}
