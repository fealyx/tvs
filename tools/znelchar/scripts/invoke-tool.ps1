[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('inspect', 'extract', 'pack', 'dump-yaml', 'verify', 'verify-roundtrip')]
    [string]$Tool,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ToolArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSCommandPath
$scriptName = switch ($Tool) {
    'inspect' { 'inspect.ps1' }
    'extract' { 'extract.ps1' }
    'pack' { 'pack.ps1' }
    'dump-yaml' { 'dump-yaml.ps1' }
    'verify' { 'verify-znelchar.ps1' }
    'verify-roundtrip' { 'roundtrip-verify.ps1' }
    default { throw "Unsupported tool: $Tool" }
}

$toolPath = Join-Path $scriptRoot $scriptName
if (-not (Test-Path -LiteralPath $toolPath)) {
    throw "Tool script not found: $toolPath"
}

& $toolPath @ToolArgs
exit $LASTEXITCODE
