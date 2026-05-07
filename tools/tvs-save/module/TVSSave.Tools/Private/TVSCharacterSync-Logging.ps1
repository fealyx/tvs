function Write-TVSCharacterSyncLog {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("INFO", "WARN", "ERROR")]
    [string]$Severity,

    [Parameter(Mandatory = $true)]
    [string]$Message,

    [Parameter(Mandatory = $false)]
    [string]$LogPath
  )

  $timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ").ToString()
  $logEntry = "$timestamp [$Severity] $Message"

  if ($LogPath) {
    try {
      Add-Content -Path $LogPath -Value $logEntry -ErrorAction Stop
    } catch {
      Write-Host $logEntry
    }
  } else {
    Write-Host $logEntry
  }
}
