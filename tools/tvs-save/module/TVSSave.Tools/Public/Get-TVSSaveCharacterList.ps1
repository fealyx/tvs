function Get-TVSSaveCharacterList {
<#
.SYNOPSIS
Lists occupied character slots from SaveFile.es3.

.DESCRIPTION
Reads the player's SaveFile.es3 (via TVS.Environment playerDataDir
if available) and returns an array of occupied character slots with
their index and character name.

.PARAMETER Path
Path to SaveFile.es3. Defaults to playerDataDir from TVS.Environment
if available.

.OUTPUTS
Hashtable array with SlotIndex (int) and Name (string) for each
occupied slot.
#>
  [CmdletBinding()]
  param(
    [string]$Path = ''
  )

  if ($script:TVSEnvironmentAvailable) {
    Write-Verbose "TVS.Environment detected, using defaults: playerDataDir=$script:DefaultPlayerDataDir, characterWorkDir=$script:DefaultCharacterWorkDir"
  }

  if (-not $Path) {
    $Path = $script:DefaultPlayerDataDir
  }

  if (-not $Path) {
    throw "Path is required. Either set TVS.Environment or provide -Path explicitly."
  }

  # If Path is a directory, append SaveFile.es3
  if (Test-Path $Path -PathType Container) {
    $Path = Join-Path $Path 'SaveFile.es3'
  }

  $index = Read-TVSSaveIndex -Path $Path
  return $index.Slots
}
