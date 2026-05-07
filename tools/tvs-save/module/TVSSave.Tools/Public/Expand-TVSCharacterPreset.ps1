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
{characterWorkDir}/expanded/{name}/ from TVS.Environment if available.

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

  if ($script:TVSEnvironmentAvailable) {
    Write-Verbose "TVS.Environment detected, using defaults: playerDataDir=$script:DefaultPlayerDataDir, characterWorkDir=$script:DefaultCharacterWorkDir"
  }

  $characterWorkDir = $script:DefaultCharacterWorkDir

  if ($PSCmdlet.ParameterSetName -eq 'ByName') {
    if (-not $characterWorkDir) {
      throw "characterWorkDir not available. Either set TVS.Environment or provide -SourcePath explicitly."
    }
    $SourcePath = Join-Path $characterWorkDir 'presets' "${Name}.znelchar"
  }

  if (-not (Test-Path $SourcePath -PathType Leaf)) {
    throw ".znelchar file not found at: $SourcePath"
  }

  if (-not $OutputPath) {
    if (-not $characterWorkDir) {
      throw "OutputPath is required. Either set TVS.Environment or provide -OutputPath explicitly."
    }
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)
    $OutputPath = Join-Path $characterWorkDir 'expanded' $baseName
  }

  $result = Expand-ZnelcharData -InputPath $SourcePath -OutputPath $OutputPath -Force:$Force

  Write-Verbose "Expanded '$SourcePath' to $($result.ExpandedPath)"
  return $result.ExpandedPath
}
