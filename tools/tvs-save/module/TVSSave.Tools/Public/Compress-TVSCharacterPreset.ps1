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
{characterWorkDir}/presets/{name}.znelchar if TVS.Environment is available.

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

  if ($script:TVSEnvironmentAvailable) {
    Write-Verbose "TVS.Environment detected, using defaults: playerDataDir=$script:DefaultPlayerDataDir, characterWorkDir=$script:DefaultCharacterWorkDir"
  }

  $characterWorkDir = $script:DefaultCharacterWorkDir

  if ($PSCmdlet.ParameterSetName -eq 'ByName') {
    if (-not $characterWorkDir) {
      throw "characterWorkDir not available. Either set TVS.Environment or provide -SourcePath explicitly."
    }
    $SourcePath = Join-Path $characterWorkDir 'expanded' $Name
  }

  if (-not (Test-Path $SourcePath -PathType Container)) {
    throw "Expanded directory not found at: $SourcePath"
  }

  if (-not $OutputPath) {
    if (-not $characterWorkDir) {
      throw "OutputPath is required. Either set TVS.Environment or provide -OutputPath explicitly."
    }
    $baseName = Split-Path $SourcePath -Leaf
    $OutputPath = Join-Path $characterWorkDir 'presets' "${baseName}.znelchar"
  }

  $result = Compress-ZnelcharData -InputPath $SourcePath -OutputPath $OutputPath -Force:$Force

  Write-Verbose "Compressed '$SourcePath' to $($result.OutputPath)"
  return $result.OutputPath
}
