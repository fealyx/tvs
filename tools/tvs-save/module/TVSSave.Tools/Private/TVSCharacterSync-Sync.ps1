function Invoke-TVSCharacterSync {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [int]$SlotIndex,

    [Parameter(Mandatory = $true)]
    [string]$SaveFilePath,

    [Parameter(Mandatory = $true)]
    [string]$CharacterWorkDir,

    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [hashtable]$OutboundLocks
  )

  $lockKey = "slot$SlotIndex"
  $lockPath = Join-Path $CharacterWorkDir "outbound-lock-$SlotIndex.txt"

  if ($OutboundLocks -and $OutboundLocks.ContainsKey($lockKey)) {
    $lockTime = $OutboundLocks[$lockKey]
    if ((Get-Date) - $lockTime -lt [TimeSpan]::FromSeconds(3)) {
      Write-TVSCharacterSyncLog -Severity "INFO" -Message "Slot ${SlotIndex}: Skipping sync due to recent outbound lock" -LogPath $LogPath
      return
    } else {
      $OutboundLocks.Remove($lockKey)
    }
  }

  $presetDir = Join-Path $CharacterWorkDir "Character$SlotIndex"
  $presetPath = Join-Path $presetDir "preset.json"

  $saveState = Get-TVSCharacterState -SaveFilePath $SaveFilePath
  $slotOccupied = Test-TVSCharacterSlotOccupied -SaveState $saveState -SlotIndex $SlotIndex

  if (-not $slotOccupied) {
    if (Test-Path $presetDir) {
      Write-TVSCharacterSyncLog -Severity "INFO" -Message "Slot ${SlotIndex}: Character deleted, removing preset directory" -LogPath $LogPath
      Remove-TVSCharacterPresetDirectory -PresetDirectory $presetDir -LogPath $LogPath
    }
    return
  }

  $characterName = Get-TVSCharacterName -SaveState $saveState -SlotIndex $SlotIndex
  $logName = if ($characterName) { $characterName } else { "Slot ${SlotIndex}" }

  if (Test-TVSValidPresetFile -PresetPath $presetPath) {
    Write-TVSCharacterSyncLog -Severity "INFO" -Message "${logName}: Importing from workdir to game" -LogPath $LogPath
    try {
      $lockTime = Get-Date
      if ($OutboundLocks) {
        $OutboundLocks[$lockKey] = $lockTime
      }
      Set-Content -Path $lockPath -Value $lockTime.ToString("o") -ErrorAction SilentlyContinue

      Sync-TVSCharacterWorkDir -Path $SaveFilePath -Expand -Quiet -LogPath $LogPath
    } catch {
      Write-TVSCharacterSyncLog -Severity "ERROR" -Message "${logName}: Import failed: $_" -LogPath $LogPath
    }
  } else {
    Write-TVSCharacterSyncLog -Severity "INFO" -Message "${logName}: Exporting from game to workdir" -LogPath $LogPath
    try {
      Sync-TVSCharacterWorkDir -Path $SaveFilePath -Quiet -LogPath $LogPath
    } catch {
      Write-TVSCharacterSyncLog -Severity "ERROR" -Message "${logName}: Export failed: $_" -LogPath $LogPath
    }
  }
}
