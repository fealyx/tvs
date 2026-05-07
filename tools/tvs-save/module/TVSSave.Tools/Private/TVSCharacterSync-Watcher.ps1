function New-TVSCharacterWatcher {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [System.Collections.Concurrent.ConcurrentQueue[object]]$EventQueue,

    [Parameter(Mandatory = $true)]
    [string]$LogPath
  )

  $watcher = New-Object System.IO.FileSystemWatcher
  $watcher.Path = $Path
  $watcher.Filter = "SaveFile.es3"
  $watcher.IncludeSubdirectories = $false
  $watcher.NotifyFilter = [System.IO.NotifyFilters]'LastWrite'

  $action = {
    param($EventQueue, $LogPath)
    $EventQueue.Enqueue(@{
      Time = Get-Date
      Source = 'FileSystemWatcher'
    })
  }

  $errorAction = {
    param($EventQueue, $LogPath)
    $EventQueue.Enqueue(@{
      Time = Get-Date
      Source = 'FileSystemWatcherError'
      Message = $Event.MessageData
    })
    Write-TVSCharacterSyncLog -Severity "ERROR" -Message "FileSystemWatcher buffer overflow or error detected" -LogPath $LogPath
  }

  $createdEvent = Register-ObjectEvent -InputObject $watcher -EventName Changed -Action { & $action $EventQueue $LogPath }
  $errorEvent = Register-ObjectEvent -InputObject $watcher -EventName Error -Action { & $errorAction $EventQueue $LogPath }

  $watcher.EnableRaisingEvents = $false

  return @{
    Watcher = $watcher
    Events = @($createdEvent, $errorEvent)
  }
}

function Start-TVSCharacterProcessingLoop {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.Collections.Concurrent.ConcurrentQueue[object]]$EventQueue,

    [Parameter(Mandatory = $true)]
    [string]$SaveFilePath,

    [Parameter(Mandatory = $true)]
    [string]$CharacterWorkDir,

    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [Parameter(Mandatory = $true)]
    [hashtable]$OutboundLocks,

    [Parameter(Mandatory = $true)]
    [System.Threading.CancellationTokenSource]$CancellationTokenSource,

    [Parameter(Mandatory = $false)]
    [int]$DebounceMs = 750
  )

  $lastProcessed = Get-Date
  $debounce = [TimeSpan]::FromMilliseconds($DebounceMs)

  while (-not $CancellationTokenSource.Token.IsCancellationRequested) {
    Start-Sleep -Milliseconds 100

    $eventData = $null
    if ($EventQueue.TryDequeue([ref]$eventData)) {
      $now = Get-Date
      if ($now - $lastProcessed -lt $debounce) {
        Start-Sleep -Milliseconds ($debounce.TotalMilliseconds - ($now - $lastProcessed).TotalMilliseconds)
      }

      $lastProcessed = Get-Date

      if ($eventData.Source -eq 'FileSystemWatcherError') {
        Write-TVSCharacterSyncLog -Severity "WARN" -Message "Handling FileSystemWatcher error, performing full resync" -LogPath $LogPath
        Invoke-TVSCharacterInitialSync -SaveFilePath $SaveFilePath -CharacterWorkDir $CharacterWorkDir -LogPath $LogPath -OutboundLocks $OutboundLocks
      } else {
        for ($i = 1; $i -le 3; $i++) {
          try {
            Invoke-TVSCharacterSync -SlotIndex $i -SaveFilePath $SaveFilePath -CharacterWorkDir $CharacterWorkDir -LogPath $LogPath -OutboundLocks $OutboundLocks
            break
          } catch {
            if ($i -eq 3) {
              Write-TVSCharacterSyncLog -Severity "ERROR" -Message "Slot $i sync failed after 3 attempts: $_" -LogPath $LogPath
            }
          }
        }
      }

      while ($EventQueue.TryDequeue([ref]$null)) { }
    }
  }
}
