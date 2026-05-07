$script:TVSCharacterStateCache = $null
$script:TVSCharacterStateCachePath = $null

function Get-TVSCharacterState {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$SaveFilePath
  )

  if ($script:TVSCharacterStateCache -and $script:TVSCharacterStateCachePath -eq $SaveFilePath) {
    return $script:TVSCharacterStateCache
  }

  if (-not (Test-Path $SaveFilePath)) {
    Write-TVSCharacterSyncLog -Severity "WARN" -Message "SaveFile.es3 not found at: $SaveFilePath"
    return $null
  }

  try {
    $content = Get-Content -Path $SaveFilePath -Raw -ErrorAction Stop
    $state = $content | ConvertFrom-Json -ErrorAction Stop
    $script:TVSCharacterStateCache = $state
    $script:TVSCharacterStateCachePath = $SaveFilePath
    return $state
  } catch {
    Write-TVSCharacterSyncLog -Severity "ERROR" -Message "Failed to parse SaveFile.es3: $_"
    return $null
  }
}

function Test-TVSCharacterSlotOccupied {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object]$SaveState,

    [Parameter(Mandatory = $true)]
    [int]$SlotIndex
  )

  if (-not $SaveState) {
    return $false
  }

  $slotProperty = "characterSlot$SlotIndex"
  if (-not $SaveState.PSObject.Properties.Name.Contains($slotProperty)) {
    return $false
  }

  $slotData = $SaveState.$slotProperty
  if (-not $slotData -or $slotData -eq "") {
    return $false
  }

  return $true
}

function Get-TVSCharacterName {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [object]$SaveState,

    [Parameter(Mandatory = $true)]
    [int]$SlotIndex
  )

  if (-not $SaveState) {
    return $null
  }

  $slotProperty = "characterSlot$SlotIndex"
  if (-not $SaveState.PSObject.Properties.Name.Contains($slotProperty)) {
    return $null
  }

  $slotData = $SaveState.$slotProperty
  if (-not $slotData -or $slotData -eq "") {
    return $null
  }

  try {
    $characterData = $slotData | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($characterData -and $characterData.name) {
      return $characterData.name
    }
  } catch {
    # Ignore parse errors
  }

  return $null
}
