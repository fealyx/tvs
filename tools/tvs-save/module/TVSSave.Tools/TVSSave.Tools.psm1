$moduleRoot = $PSScriptRoot

# Optional TVS.Environment integration
# Detect if TVS.Environment is available and load defaults
$script:TVSEnvironmentAvailable = $false
$script:DefaultPlayerDataDir = $null
$script:DefaultCharacterWorkDir = $null

try {
  $envModule = Get-Module -Name 'TVS.Environment' -ListAvailable | Select-Object -First 1
  if ($envModule) {
    Import-Module $envModule.Path -ErrorAction Stop
    $env = Get-TVSEnvironment -ErrorAction Stop
    $script:DefaultPlayerDataDir = $env.playerDataDir
    $script:DefaultCharacterWorkDir = $env.characterWorkDir
    $script:TVSEnvironmentAvailable = $true
  }
} catch {
  # TVS.Environment not available, use standalone mode
  $script:TVSEnvironmentAvailable = $false
}

$privateFunctions = @(
  'TVSSave-Helpers',
  'TVSCharacterSync-Logging',
  'TVSCharacterSync-State',
  'TVSCharacterSync-Validation',
  'TVSCharacterSync-Sync',
  'TVSCharacterSync-Watcher',
  'TVSCharacterSync-InitialSync'
)

foreach ($func in $privateFunctions) {
  $path = Join-Path $moduleRoot "Private/$func.ps1"
  if (Test-Path $path) {
    . $path
  }
}

$publicFunctions = @(
  'Compress-TVSCharacterPreset',
  'ConvertFrom-TVSPresetSlot',
  'ConvertTo-TVSPresetSlot',
  'Expand-TVSCharacterPreset',
  'Export-TVSAllCharacterPresets',
  'Export-TVSCharacterPreset',
  'Get-TVSSaveCharacterList',
  'Import-TVSCharacterPreset',
  'Sync-TVSCharacterWorkDir',
  'Watch-TVSCharacterSync',
  'Stop-TVSCharacterSync'
)

foreach ($func in $publicFunctions) {
  $path = Join-Path $moduleRoot "Public/$func.ps1"
  if (Test-Path $path) {
    . $path
  }
}
