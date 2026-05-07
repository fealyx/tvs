function Test-TVSValidPresetFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$PresetPath
  )

  if (-not (Test-Path $PresetPath)) {
    return $false
  }

  $item = Get-Item $PresetPath
  if ($item.PSIsContainer -or $item.Length -eq 0) {
    return $false
  }

  try {
    $content = Get-Content -Path $PresetPath -Raw -ErrorAction Stop
    if ($content -match '^\s*\{\s*\"\s*\}\s*$') {
      return $false
    }
    $null = $content | ConvertFrom-Json -ErrorAction Stop
    return $true
  } catch {
    return $false
  }
}

function Remove-TVSCharacterPresetDirectory {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$PresetDirectory,

    [Parameter(Mandatory = $true)]
    [string]$LogPath
  )

  if (Test-Path $PresetDirectory) {
    try {
      Remove-Item -Path $PresetDirectory -Recurse -Force -ErrorAction Stop
      Write-TVSCharacterSyncLog -Severity "INFO" -Message "Removed preset directory: $PresetDirectory" -LogPath $LogPath
    } catch {
      Write-TVSCharacterSyncLog -Severity "ERROR" -Message "Failed to remove preset directory '$PresetDirectory': $_" -LogPath $LogPath
    }
  }
}
