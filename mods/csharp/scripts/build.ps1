param(
  [string]$Configuration = 'Release',
  [switch]$Rebuild,
  [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if (-not $dotnet) {
  throw 'dotnet SDK is not installed or not on PATH. Install a recent .NET SDK to build the mods workspace.'
}

$solutionPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Mods.sln'

$arguments = @()
if ($Clean) {
  $arguments += 'clean'
} else {
  $arguments += 'build'
}

$arguments += $solutionPath
$arguments += '--configuration'
$arguments += $Configuration

if ($Rebuild) {
  $arguments += '--no-incremental'
}

& $dotnet.Source @arguments
exit $LASTEXITCODE
