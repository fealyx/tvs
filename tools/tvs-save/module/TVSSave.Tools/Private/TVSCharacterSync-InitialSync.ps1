function Invoke-TVSCharacterInitialSync {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$SaveFilePath,

    [Parameter(Mandatory = $true)]
    [string]$CharacterWorkDir,

    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [Parameter(Mandatory = $false)]
    [hashtable]$OutboundLocks
  )

  Write-TVSCharacterSyncLog -Severity "INFO" -Message "Starting initial sync scan" -LogPath $LogPath

  $saveState = Get-TVSCharacterState -SaveFilePath $SaveFilePath
  if (-not $saveState) {
    Write-TVSCharacterSyncLog -Severity "ERROR" -Message "Failed to read SaveFile.es3 for initial sync" -LogPath $LogPath
    return
  }

  for ($slot = 1; $slot -le 3; $slot++) {
    $slotOccupied = Test-TVSCharacterSlotOccupied -SaveState $saveState -SlotIndex $slot

    if (-not $slotOccupied) {
      $presetDir = Join-Path $CharacterWorkDir "Character$slot"
      if (Test-Path $presetDir) {
        Write-TVSCharacterSyncLog -Severity "INFO" -Message "Slot $slot`: Character not found in save, removing stale preset directory" -LogPath $LogPath
        Remove-TVSCharacterPresetDirectory -PresetDirectory $presetDir -LogPath $LogPath
      }
      continue
    }

    $characterName = Get-TVSCharacterName -SaveState $saveState -SlotIndex $slot
    $logName = if ($characterName) { $characterName } else { "Slot $slot" }

    Write-TVSCharacterSyncLog -Severity "INFO" -Message "$logName`: Performing initial sync" -LogPath $LogPath
    try {
      Invoke-TVSCharacterSync -SlotIndex $slot -SaveFilePath $SaveFilePath -CharacterWorkDir $CharacterWorkDir -LogPath $LogPath -OutboundLocks $OutboundLocks
    } catch {
      Write-TVSCharacterSyncLog -Severity "ERROR" -Message "$logName`: Initial sync failed: $_" -LogPath $LogPath
    }
  }

  Write-TVSCharacterSyncLog -Severity "INFO" -Message "Initial sync scan completed" -LogPath $LogPath
}
