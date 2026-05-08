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
  tvsm mod apply [--profile <name>] [--force]
  tvsm mod remove <name> [--yes]
  tvsm mod update [<name>]
  tvsm mod rollback [--yes]
  tvsm mod verify [--json]
  tvsm mod snapshot [<name>]
  tvsm mod profile list [--json]
  tvsm mod profile switch <name>
  tvsm mod profile new <name>
  tvsm mod store list [--json]
  tvsm mod store prune [--yes]
  tvsm mod dev link <name> --src <path> [--layout <value>] [--note <text>]
  tvsm mod dev unlink <name>
  tvsm mod dev list [--json]
  tvsm save list [<path>] [--json]
  tvsm save export [--slot <n> | --name <name> | --all] [<outputPath>]
  tvsm save import --name <name> [--slot <n>] --force
  tvsm save expand --name <name>
  tvsm save compress --name <name> [--force]
  tvsm save watch [<path>] [--expand]
  tvsm update check [--json] [--pre-release]
  tvsm update apply [--force] [--no-verify] [--pre-release]
  tvsm version [--json]
  tvsm help

Run tvsm with no arguments for an interactive menu.

.PARAMETER Experimental
    Enables experimental features, including Save Tools (tvsm save * commands).
    Without this flag, save tools are hidden from the command surface.
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
    [switch]$Force,
    [string]$Src    = '',
    [string]$Layout = 'plugins-dll',
    [string]$Note   = '',
    [switch]$Help,
    [switch]$Experimental,
    [switch]$NoVerify,
    [switch]$PreRelease
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

# Dev-repo layout: tvs-save module sits at ../tvs-save/module
# relative to this script (tools/tvsm/ -> tools/tvs-save/module/).
# Only add to PSModulePath when -Experimental is set.
if ($Experimental) {
    $devTVSSavePath = Join-Path $PSScriptRoot '..' 'tvs-save' 'module'
    if (Test-Path -LiteralPath $devTVSSavePath) {
        $env:PSModulePath = (Resolve-Path $devTVSSavePath).Path + [IO.Path]::PathSeparator + $env:PSModulePath
    }
}

# Dev-repo layout: znelchar module sits at ../znelchar/module
# relative to this script (tools/tvsm/ -> tools/znelchar/module/).
$devZnelcharPath = Join-Path $PSScriptRoot '..' 'znelchar' 'module'
if (Test-Path -LiteralPath $devZnelcharPath) {
    $env:PSModulePath = (Resolve-Path $devZnelcharPath).Path + [IO.Path]::PathSeparator + $env:PSModulePath
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

# Conditionally import TVSSave.Tools when -Experimental is set
if ($Experimental) {
    $tvssaveModulePath = Join-Path $PSScriptRoot '..' 'tvs-save' 'module' 'TVSSave.Tools' 'TVSSave.Tools.psd1'
    if (Test-Path -LiteralPath $tvssaveModulePath) {
        Import-Module $tvssaveModulePath -Force -ErrorAction Stop
    } else {
        Write-Warning "TVSSave.Tools module not found at: $tvssaveModulePath"
    }
}

# --no-ansi: tell PwshSpectreConsole to suppress ANSI codes
if ($NoAnsi) {
    $env:NO_COLOR = '1'
}

# ---------------------------------------------------------------------------
# Interactive menu (no args)
# ---------------------------------------------------------------------------
function Invoke-InteractiveMenu {
    $choices = @(
        'config show    — display current environment configuration',
        'config init    — interactive first-run setup wizard',
        'mod apply      — (re-)establish junctions after a game update',
        'mod status     — show installed mods and junction health',
        'mod install    — install mods from the community registry',
        'mod update     — update installed mods to latest versions',
        'mod rollback   — revert profile to previous snapshot',
        'mod verify     — check BepInEx integrity and junction health',
        'update check   — check for TVSM updates',
        'update apply   — apply TVSM updates',
        'version        — show component versions',
        'exit'
    )

    # Only show save tools in interactive menu when -Experimental is set
    if ($Experimental) {
        $choices = $choices[0..($choices.Count - 2)]  # Remove 'exit' temporarily
        $choices += @(
            'save list      — list occupied character slots',
            'save export    — export character presets to .znelchar',
            'save import    — import .znelchar back to save slot',
            'save expand    — expand .znelchar to multi-file format',
            'save compress  — compress expanded directory to .znelchar',
            'save watch     — watch saves and auto-sync characters'
        )
        $choices += 'exit'
    }

    while ($true) {
        $selection = Read-SpectreSelection -Title '[cyan bold]TVS Manager[/]' -Choices $choices -Color Blue

        switch -Wildcard ($selection) {
            'config show*'   { Show-TVSMConfig -Json:$Json -Profile:$Profile }
            'config init*'   { Invoke-TVSMConfigInit -Profile:$Profile }
            'mod apply*'     { Invoke-TVSMModApply @profileArg }
            'mod status*'    { Get-TVSMModStatus -Json:$Json @profileArg }
            'mod install*'   {
                $modName = Read-SpectreText -Message 'Mod name [grey](leave blank for --all)[/]:'
                if ([string]::IsNullOrEmpty($modName)) {
                    Install-TVSMMod -All @profileArg
                } else {
                    Install-TVSMMod -Name $modName @profileArg
                }
            }
            'mod update*'    { Update-TVSMMod }
            'mod rollback*'  { Invoke-TVSMModRollback @profileArg }
            'mod verify*'    { Test-TVSMModEnvironment -Json:$Json @profileArg }
            'update check*'  { Invoke-TVSMUpdateCheck }
            'update apply*' { Invoke-TVSMUpdateApply }
            'save list*'     { Get-TVSSaveList }
            'save export*'   { Export-TVSSavePreset -All }
            'save import*'   {
                $modName = Read-SpectreText -Message 'Character name:'
                if ($modName) { Import-TVSSavePreset -Name $modName -Force }
            }
            'save expand*'   {
                $modName = Read-SpectreText -Message 'Character name:'
                if ($modName) { Expand-TVSSavePreset -Name $modName }
            }
            'save compress*' {
                $modName = Read-SpectreText -Message 'Character name:'
                if ($modName) { Compress-TVSSavePreset -Name $modName }
            }
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
            'apply'    { Invoke-TVSMModApply -Force:$Force @profileArg }
            'status'   { Get-TVSMModStatus -Json:$Json @profileArg }
            'install'  { Install-TVSMMod -Name:$Arg1 -All:$All -Yes:$Yes @profileArg }
            'update'   { Update-TVSMMod -Name:$Arg1 -Yes:$Yes }
            'remove'   { Remove-TVSMMod -Name:$Arg1 -Yes:$Yes }
            'rollback' { Invoke-TVSMModRollback -Yes:$Yes @profileArg }
            'verify'   { Test-TVSMModEnvironment -Json:$Json @profileArg }
            'snapshot' { New-TVSMModSnapshot -Name:$Arg1 }
            'profile'  {
                switch ($Arg1) {
                    'list'   { Get-TVSMModProfileList -Json:$Json }
                    'switch' {
                        if (-not $Arg2) { Write-SpectreHost '[yellow]Usage: tvsm mod profile switch <name>[/]'; exit 1 }
                        Switch-TVSMModProfile -Name:$Arg2
                    }
                    'new'    {
                        if (-not $Arg2) { Write-SpectreHost '[yellow]Usage: tvsm mod profile new <name>[/]'; exit 1 }
                        New-TVSMModProfile -Name:$Arg2
                    }
                    default  {
                        Write-SpectreHost "[yellow]Unknown profile command: '$Arg1'[/]"
                        Write-SpectreHost 'Available: [cyan]list[/], [cyan]switch[/], [cyan]new[/]'
                        exit 1
                    }
                }
            }
            'store' {
                switch ($Arg1) {
                    'list'  { Get-TVSMModStoreList -Json:$Json }
                    'prune' { Invoke-TVSMModStorePrune -Yes:$Yes }
                    default {
                        Write-SpectreHost "[yellow]Unknown store command: '$Arg1'[/]"
                        Write-SpectreHost 'Available: [cyan]list[/], [cyan]prune[/]'
                        exit 1
                    }
                }
            }
            'dev' {
                switch ($Arg1) {
                    'link' {
                        if (-not $Arg2) { Write-SpectreHost '[yellow]Usage: tvsm mod dev link <name> --src <path>[/]'; exit 1 }
                        if (-not $Src)  { Write-SpectreHost '[yellow]--src is required for dev link[/]'; exit 1 }
                        $devLinkArgs = @{ Name = $Arg2; Src = $Src; Layout = $Layout }
                        if ($Note) { $devLinkArgs['Note'] = $Note }
                        Add-TVSMDevLink @devLinkArgs
                    }
                    'unlink' {
                        if (-not $Arg2) { Write-SpectreHost '[yellow]Usage: tvsm mod dev unlink <name>[/]'; exit 1 }
                        Remove-TVSMDevLink -Name:$Arg2
                    }
                    'list'   { Get-TVSMDevLinkList -Json:$Json }
                    default  {
                        Write-SpectreHost "[yellow]Unknown dev command: '$Arg1'[/]"
                        Write-SpectreHost 'Available: [cyan]link[/], [cyan]unlink[/], [cyan]list[/]'
                        exit 1
                    }
                }
            }
            default {
                Write-SpectreHost "[yellow]Unknown mod command: '$Verb'[/]"
                Write-SpectreHost 'Available: [cyan]apply[/], [cyan]status[/], [cyan]install[/], [cyan]update[/], [cyan]remove[/], [cyan]rollback[/], [cyan]verify[/], [cyan]snapshot[/], [cyan]profile[/], [cyan]store[/], [cyan]dev[/]'
                exit 1
            }
        }
    }

    'save' {
        if (-not $Experimental) {
            Write-Host "Save tools are experimental. Use -Experimental flag to enable." -ForegroundColor Yellow
            exit 1
        }
        switch ($Verb) {
            'list'   { Get-TVSSaveList -Path:$Arg1 -Json:$Json }
            'export' {
                $exportArgs = @{}
                if ($Arg1 -eq '--all' -or $All) {
                    $exportArgs['All'] = $true
                } elseif ($Arg1 -match '^\d+$') {
                    $exportArgs['Slot'] = [int]$Arg1
                } elseif ($Arg1) {
                    $exportArgs['Name'] = $Arg1
                } else {
                    $exportArgs['All'] = $true
                }
                if ($Arg2) { $exportArgs['OutputPath'] = $Arg2 }
                Export-TVSSavePreset @exportArgs
            }
            'import' {
                if (-not $Arg1) {
                    Write-SpectreHost '[yellow]Usage: tvsm save import --name <name> [--slot <n>] --force[/]'
                    exit 1
                }
                $importArgs = @{ Name = $Arg1; Force = $true }
                if ($Arg2 -match '^\d+$') { $importArgs['Slot'] = [int]$Arg2 }
                Import-TVSSavePreset @importArgs
            }
            'expand' {
                if (-not $Arg1) {
                    Write-SpectreHost '[yellow]Usage: tvsm save expand --name <name>[/]'
                    exit 1
                }
                Expand-TVSSavePreset -Name $Arg1
            }
            'compress' {
                if (-not $Arg1) {
                    Write-SpectreHost '[yellow]Usage: tvsm save compress --name <name> [--force][/]'
                    exit 1
                }
                Compress-TVSSavePreset -Name $Arg1 -Force:$Force
            }
            'watch'  { Watch-TVSSave -Path:$Arg1 -Expand:$Expand @profileArg }
            default {
                Write-SpectreHost "[yellow]Unknown save command: '$Verb'[/]"
                Write-SpectreHost 'Available: [cyan]list[/], [cyan]export[/], [cyan]import[/], [cyan]expand[/], [cyan]compress[/], [cyan]watch[/]'
                exit 1
            }
        }
    }

    'update' {
        switch ($Verb) {
            'check' {
                Invoke-TVSMUpdateCheck -Json:$Json -PreRelease:$PreRelease
            }
            'apply' {
                Invoke-TVSMUpdateApply -Force:$Force -NoVerify:$NoVerify -PreRelease:$PreRelease
            }
            default {
                Write-SpectreHost "[yellow]Unknown update command: '$Verb'[/]"
                Write-SpectreHost 'Available: [cyan]check[/], [cyan]apply[/]'
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
