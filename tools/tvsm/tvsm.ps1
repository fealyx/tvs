#!/usr/bin/env pwsh
<#
.SYNOPSIS
tvsm — TVS Manager entry point.

.DESCRIPTION
Dispatches tvsm subcommands to the TVSM module. Supports:

  tvsm config show [--profile <name>] [--json]
  tvsm config init [--profile <name>]
  tvsm config set <key> <value> [--profile <name>]
  tvsm config get <key> [--profile <name>] [--json]
  tvsm mod status [--json]
  tvsm mod install [<name>] [--all] [--yes]
  tvsm mod remove <name> [--yes]
  tvsm mod rollback [--yes]
  tvsm mod verify [--json]
  tvsm mod snapshot [<name>]
  tvsm save watch [<path>]
  tvsm version [--json]
  tvsm help

Run tvsm with no arguments for an interactive menu.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Noun   = '',
    [Parameter(Position = 1)][string]$Verb   = '',
    [Parameter(Position = 2)][string]$Arg1   = '',
    [Parameter(Position = 3)][string]$Arg2   = '',
    [string]$Profile  = '',
    [switch]$Json,
    [switch]$NoAnsi,
    [switch]$Yes,
    [switch]$All,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Resolve dependency modules before loading TVSM (RequiredModules is validated
# by the manifest loader before psm1 runs, so they must be on PSModulePath).
# ---------------------------------------------------------------------------

# Portable bundle layout: modules/ sits next to tvsm.ps1, containing TVSM/,
# TVS.Environment/, and PwshSpectreConsole/ as sibling folders.
$bundleModulesPath = Join-Path $PSScriptRoot 'modules'
if (Test-Path -LiteralPath $bundleModulesPath) {
    $env:PSModulePath = $bundleModulesPath + [IO.Path]::PathSeparator + $env:PSModulePath
}

# Dev-repo layout: tvs-environment module sits at ../../tvs-environment/module
# relative to this script (tools/tvsm/ -> tools/tvs-environment/module/).
$devTVSEPath = Join-Path $PSScriptRoot '..' 'tvs-environment' 'module'
if (Test-Path -LiteralPath $devTVSEPath) {
    $env:PSModulePath = (Resolve-Path $devTVSEPath).Path + [IO.Path]::PathSeparator + $env:PSModulePath
}

# ---------------------------------------------------------------------------
# UTF-8 encoding — required for Spectre Console Unicode/box-drawing output.
# Save originals and restore in the finally block so the caller's shell
# session is not permanently altered. Skipped under --no-ansi (plain text
# mode has no Unicode rendering requirement).
# ---------------------------------------------------------------------------
$script:_prevOutputEncoding = $null
$script:_prevInputEncoding  = $null

if (-not $NoAnsi -and [Console]::OutputEncoding.CodePage -ne 65001) {
    $script:_prevOutputEncoding = [Console]::OutputEncoding
    $script:_prevInputEncoding  = [Console]::InputEncoding
    $OutputEncoding             = [System.Text.UTF8Encoding]::new()
    [Console]::OutputEncoding   = [System.Text.UTF8Encoding]::new()
    [Console]::InputEncoding    = [System.Text.UTF8Encoding]::new()
    # Signal to PwshSpectreConsole that encoding is already handled — suppress its warning.
    $env:IgnoreSpectreEncoding  = $true
}

# Ensure PwshSpectreConsole is available before the manifest loader validates
# RequiredModules (which fires before TVSM.psm1 runs, so the psm1 auto-install is too late).
if (-not (Get-Module -ListAvailable -Name 'PwshSpectreConsole')) {
    Write-Host '[tvsm] PwshSpectreConsole not found — installing to CurrentUser scope...' -ForegroundColor Cyan
    Install-Module -Name 'PwshSpectreConsole' -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    Write-Host '[tvsm] PwshSpectreConsole installed.' -ForegroundColor Green
}

# Resolve TVSM module path
$tvsmModulePath = Join-Path $PSScriptRoot 'module' 'TVSM' 'TVSM.psd1'
if (-not (Test-Path -LiteralPath $tvsmModulePath)) {
    Write-Error "TVSM module not found at: $tvsmModulePath"
    exit 1
}
Import-Module $tvsmModulePath -Force -ErrorAction Stop

# --no-ansi: tell PwshSpectreConsole to suppress ANSI codes
if ($NoAnsi) {
    $env:NO_COLOR = '1'
}

# ---------------------------------------------------------------------------
# Interactive menu (no args)
# ---------------------------------------------------------------------------
function Invoke-InteractiveMenu {
    $choices = @(
        'config show   — display current environment configuration',
        'config init   — interactive setup wizard',
        'mod status    — show installed mods [[Phase 2]]',
        'mod install   — install a mod [[Phase 2]]',
        'save watch    — watch saves and auto-expand [[Phase 3]]',
        'version       — show component versions',
        'exit'
    )

    while ($true) {
        $selection = Read-SpectreSelection -Title '[cyan bold]TVS Manager[/]' -Choices $choices -Color Blue

        switch -Wildcard ($selection) {
            'config show*'   { Show-TVSMConfig -Json:$Json -Profile:$Profile }
            'config init*'   { Invoke-TVSMConfigInit -Profile:$Profile }
            'mod status*'    { Get-TVSMModStatus -Json:$Json }
            'mod install*'   { Install-TVSMMod }
            'save watch*'    { Watch-TVSSave }
            'version*'       { Get-TVSMVersion -Json:$Json }
            'exit'           { return }
        }

        Write-SpectreHost ''
    }
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
try {

$profileArg = @{}
if ($Profile) { $profileArg['Profile'] = $Profile }

if ($Help -or ($Noun -eq 'help') -or ($Noun -eq '--help') -or ($Noun -eq '-h')) {
    Get-Help $PSCommandPath
    exit 0
}

switch ($Noun) {
    '' {
        Invoke-InteractiveMenu
    }

    'version' {
        Get-TVSMVersion -Json:$Json
    }

    'config' {
        switch ($Verb) {
            'show' {
                Show-TVSMConfig -Json:$Json @profileArg
            }
            'init' {
                Invoke-TVSMConfigInit @profileArg
            }
            'set' {
                if (-not $Arg1 -or -not $Arg2) {
                    Write-Error "Usage: tvsm config set <key> <value>"
                    exit 1
                }
                Set-TVSEnvironmentValue -Key $Arg1 -Value $Arg2 @profileArg
                Write-SpectreHost "[green]Saved:[/] $Arg1 = $Arg2"
            }
            'get' {
                if (-not $Arg1) {
                    Write-Error "Usage: tvsm config get <key>"
                    exit 1
                }
                $val = Get-TVSEnvironment -Key $Arg1 @profileArg
                if ($Json) {
                    [pscustomobject]@{ key = $Arg1; value = $val } | ConvertTo-Json
                } else {
                    Write-SpectreHost "${Arg1}: $val"
                }
            }
            default {
                Write-SpectreHost "[yellow]Unknown config command: '$Verb'[/]"
                Write-SpectreHost 'Available: [cyan]show[/], [cyan]init[/], [cyan]set[/], [cyan]get[/]'
                exit 1
            }
        }
    }

    'mod' {
        switch ($Verb) {
            'status'   { Get-TVSMModStatus -Json:$Json @profileArg }
            'install'  { Install-TVSMMod -Name:$Arg1 -All:$All -Yes:$Yes @profileArg }
            'remove'   { Remove-TVSMMod -Name:$Arg1 -Yes:$Yes }
            'rollback' { Invoke-TVSMModRollback -Yes:$Yes }
            'verify'   { Test-TVSMModEnvironment -Json:$Json @profileArg }
            'snapshot' { New-TVSMModSnapshot -Name:$Arg1 }
            default {
                Write-SpectreHost "[yellow]Unknown mod command: '$Verb'[/]"
                Write-SpectreHost 'Available: [cyan]status[/], [cyan]install[/], [cyan]remove[/], [cyan]rollback[/], [cyan]verify[/], [cyan]snapshot[/]'
                exit 1
            }
        }
    }

    'save' {
        switch ($Verb) {
            'watch' { Watch-TVSSave -Path:$Arg1 @profileArg }
            default {
                Write-SpectreHost "[yellow]Unknown save command: '$Verb'[/]"
                Write-SpectreHost 'Available: [cyan]watch[/]'
                exit 1
            }
        }
    }

    default {
        Write-SpectreHost "[yellow]Unknown command: '$Noun'[/]"
        Write-SpectreHost 'Run [cyan]tvsm help[/] for usage information.'
        exit 1
    }
}

} finally {
    # Restore original console encoding if we swapped it
    if ($null -ne $script:_prevOutputEncoding) {
        [Console]::OutputEncoding = $script:_prevOutputEncoding
        [Console]::InputEncoding  = $script:_prevInputEncoding
    }
}
