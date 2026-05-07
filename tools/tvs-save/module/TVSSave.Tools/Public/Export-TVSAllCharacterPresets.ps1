function Export-TVSAllCharacterPresets {
<#
.SYNOPSIS
Exports all occupied preset slot files to .znelchar files.

.DESCRIPTION
Iterates all occupied character slots detected in SaveFile.es3 and
calls Export-TVSCharacterPreset for each one.

.PARAMETER OutputPath
Directory for .znelchar output. Defaults to
{characterWorkDir}/presets/ from TVS.Environment if available.

.OUTPUTS
Array of output file paths.
#>
  [CmdletBinding()]
  param(
    [string]$OutputPath = ''
  )

  if ($script:TVSEnvironmentAvailable) {
    Write-Verbose "TVS.Environment detected, using defaults: playerDataDir=$script:DefaultPlayerDataDir, characterWorkDir=$script:DefaultCharacterWorkDir"
  }

  if (-not $OutputPath -and $script:DefaultCharacterWorkDir) {
    $OutputPath = Join-Path $script:DefaultCharacterWorkDir 'presets'
  }

  if (-not $OutputPath) {
    throw "OutputPath is required. Either set TVS.Environment or provide -OutputPath explicitly."
  }

  if (-not (Test-Path $OutputPath -PathType Container)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
  }

  $playerDataDir = $script:DefaultPlayerDataDir

  if (-not $playerDataDir) {
    throw "PlayerDataDir not available. Either set TVS.Environment or the function will use explicit paths."
  }

  $slots = Get-TVSSaveCharacterList
  $results = [System.Collections.Generic.List[string]]::new()

  foreach ($slot in $slots) {
    $presetPath = Join-Path $playerDataDir "presetSlot$($slot.SlotIndex).txt.tmp"
    if (Test-Path $presetPath -PathType Leaf) {
      $outputFile = Export-TVSCharacterPreset -Slot $slot.SlotIndex -OutputPath $OutputPath
      $results.Add($outputFile)
    }
    else {
      Write-Warning "presetSlot$($slot.SlotIndex).txt.tmp not found for character '$($slot.Name)'; skipping."
    }
  }

  return $results.ToArray()
}
