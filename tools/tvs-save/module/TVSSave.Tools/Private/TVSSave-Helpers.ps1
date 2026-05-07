function Get-TVSSlotInfo {
<#
.SYNOPSIS
Resolves a character name or slot index to a unified slot info object.

.DESCRIPTION
Centralizes the logic for resolving character names to slot indices
and vice-versa. Returns a hashtable with SlotIndex (int) and Name (string).

.PARAMETER Name
Character name to look up in SaveFile.es3.

.PARAMETER Slot
Zero-based slot index.

.PARAMETER DefaultName
Fallback name to use if the name cannot be resolved. Defaults to "Slot{N}".

.OUTPUTS
Hashtable with keys: SlotIndex (int), Name (string)
#>
  [CmdletBinding(DefaultParameterSetName = 'ByName')]
  param(
    [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
    [string]$Name,

    [Parameter(ParameterSetName = 'BySlot', Mandatory = $true)]
    [int]$Slot,

    [Parameter(ParameterSetName = 'BySlot')]
    [string]$DefaultName = ''
  )

  $slots = Get-TVSSaveCharacterList

  if ($PSCmdlet.ParameterSetName -eq 'ByName') {
    $match = $slots | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if (-not $match) {
      throw "Character '$Name' not found in any occupied save slot."
    }
    return $match
  }
  else {
    $match = $slots | Where-Object { $_.SlotIndex -eq $Slot } | Select-Object -First 1
    $resolvedName = if ($match) { $match.Name } else {
      if ($DefaultName) { $DefaultName } else { "Slot$Slot" }
    }
    return @{
      SlotIndex = $Slot
      Name = $resolvedName
    }
  }
}

function Assert-TVSModuleAvailable {
<#
.SYNOPSIS
Ensures a TVS module is available, importing it if necessary.

.DESCRIPTION
Checks if a module is loaded, and if not, attempts to import it.
Throws a descriptive error if the module cannot be loaded.

.PARAMETER ModuleName
Name of the module to check/import.

.PARAMETER ErrorMessage
Optional custom error message. Defaults to a standard message.
#>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,

    [string]$ErrorMessage = ''
  )

  if (Get-Module -Name $ModuleName) {
    return
  }

  if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
    $msg = if ($ErrorMessage) {
      $ErrorMessage
    } else {
      "$ModuleName module is not available. Install it from the TVS Tools bundle."
    }
    throw $msg
  }

  Import-Module $ModuleName -Global -Force
}

function Get-TVSSanitizedName {
<#
.SYNOPSIS
Sanitizes a character name for filesystem use.

.DESCRIPTION
Strips zero-width and invisible Unicode characters that can leak
from game serialization. Also trims whitespace.

.PARAMETER Name
The character name to sanitize.

.PARAMETER FallbackName
Fallback name to use if the sanitized result is empty.

.OUTPUTS
Sanitized string safe for use in filenames.
#>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [string]$FallbackName = ''
  )

  $safeName = $Name -replace '[\u200B-\u200D\uFEFF\u00A0]', ''
  $safeName = $safeName.Trim()

  if ([string]::IsNullOrEmpty($safeName)) {
    $safeName = if ($FallbackName) { $FallbackName } else { $Name }
  }

  return $safeName
}

function Get-TVSDefaultPath {
<#
.SYNOPSIS
Gets a default path from TVS.Environment if available.

.DESCRIPTION
Returns the requested default path from the TVS.Environment module.
If TVS.Environment is not available, returns $null.

.PARAMETER PathType
The type of path to retrieve: 'playerDataDir' or 'characterWorkDir'.

.OUTPUTS
String path or $null if not available.
#>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [ValidateSet('playerDataDir', 'characterWorkDir')]
    [string]$PathType
  )

  if ($PathType -eq 'playerDataDir') {
    return $script:DefaultPlayerDataDir
  }
  return $script:DefaultCharacterWorkDir
}

function Get-TVSPresetSlotPath {
<#
.SYNOPSIS
Resolves the filesystem path for a presetSlot file.

.DESCRIPTION
Given a slot index and optional playerDataDir, returns the full path
to the corresponding presetSlot{n}.txt.tmp file.

.PARAMETER Slot
Zero-based slot index.

.PARAMETER PlayerDataDir
Path to the player data directory. Defaults to TVS.Environment value
if available, otherwise throws an error.

.OUTPUTS
Full path to the presetSlot file.
#>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [int]$Slot,

    [string]$PlayerDataDir = ''
  )

  if (-not $PlayerDataDir) {
    $PlayerDataDir = $script:DefaultPlayerDataDir
  }

  if (-not $PlayerDataDir) {
    throw "PlayerDataDir not available. Either set TVS.Environment or provide -PlayerDataDir explicitly."
  }

  return Join-Path $PlayerDataDir "presetSlot${Slot}.txt.tmp"
}
