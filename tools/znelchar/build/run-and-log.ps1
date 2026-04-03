#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$outputLog = Join-Path $PSScriptRoot 'build-execution.log'
$startTime = Get-Date

try {
    "=== Build Execution Log ===" | Out-File -LiteralPath $outputLog
    "Started: {0:o}" -f $startTime | Out-File -LiteralPath $outputLog -Append
    "" | Out-File -LiteralPath $outputLog -Append
    
    $packagePath = Join-Path $PSScriptRoot 'package.ps1'
    "Invoking: $packagePath" | Out-File -LiteralPath $outputLog -Append
    "Arguments: -CreateModule -CreatePortable:`$false" | Out-File -LiteralPath $outputLog -Append
    "" | Out-File -LiteralPath $outputLog -Append
    
    & $packagePath -CreateModule -CreatePortable:$false 2>&1 | Out-File -LiteralPath $outputLog -Append
    
    $exitCode = $LASTEXITCODE
    "" | Out-File -LiteralPath $outputLog -Append
    "Exit Code: $exitCode" | Out-File -LiteralPath $outputLog -Append
    "Completed: {0:o}" -f (Get-Date) | Out-File -LiteralPath $outputLog -Append
}
catch {
    "ERROR: {0}" -f $_.Exception.Message | Out-File -LiteralPath $outputLog -Append
    "Stack: {0}" -f $_.ScriptStackTrace | Out-File -LiteralPath $outputLog -Append
    exit 1
}

"Wrote log to: $outputLog"
exit 0
