function Add-TVSMDevLink {
<#
.SYNOPSIS
Registers a local build output directory as a dev link overlay for a mod.
The source path is resolved to an absolute path at link time so apply works
from any working directory. Run tvsm mod apply after linking to activate.

.PARAMETER Name
Mod name (used as the junction name in staging).

.PARAMETER Src
Path to the directory containing the build output. Relative paths are resolved
against the current working directory.

.PARAMETER Layout
installLayout that determines where the source is placed in staging.
Defaults to 'plugins-dll'. Valid values: plugins-dll, plugins-dir,
patchers-dll, config-only, gameroot-overlay.

.PARAMETER Note
Optional freeform annotation shown in tvsm mod dev list.

.EXAMPLE
tvsm mod dev link MyMod --src ./mods/csharp/MyMod/bin/Debug/net6.0
tvsm mod dev link ItemPack --src ./items/ItemPack/build --layout gameroot-overlay
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Src,
        [string]$Layout = 'plugins-dll',
        [string]$Note   = ''
    )

    $validLayouts = @('plugins-dll', 'plugins-dir', 'patchers-dll', 'config-only', 'gameroot-overlay')
    if ($validLayouts -notcontains $Layout) {
        throw "Invalid installLayout '$Layout'. Valid values: $($validLayouts -join ', ')"
    }

    $modWorkDir = (Get-TVSEnvironment).modWorkDir
    if ([string]::IsNullOrEmpty($modWorkDir)) { throw "modWorkDir is not configured." }

    # Resolve src to absolute path at link time
    $resolvedSrc = if ([System.IO.Path]::IsPathRooted($Src)) {
        $Src
    } else {
        (Resolve-Path -LiteralPath $Src -ErrorAction Stop).Path
    }

    if (-not (Test-Path -LiteralPath $resolvedSrc)) {
        throw "Source path does not exist: $resolvedSrc"
    }

    $devLinks = Read-TVSDevLinks -ModWorkDir $modWorkDir
    if (-not $devLinks['links']) { $devLinks['links'] = @{} }

    $entry = [ordered]@{
        src           = $resolvedSrc
        installLayout = $Layout
        linkedAt      = [DateTimeOffset]::UtcNow.ToString('o')
    }
    if (-not [string]::IsNullOrEmpty($Note)) { $entry['note'] = $Note }

    $devLinks['links'][$Name] = $entry
    Write-TVSDevLinks -ModWorkDir $modWorkDir -DevLinks $devLinks

    Write-SpectreHost "[green]✓ Dev link registered:[/] $Name → $resolvedSrc"
    Write-SpectreHost "Run [cyan]tvsm mod apply[/] to activate the link in staging."
}

function Remove-TVSMDevLink {
<#
.SYNOPSIS
Removes a dev link registration. Run tvsm mod apply after unlinking to
remove the junction from staging and fall back to the store version if present.

.PARAMETER Name
Name of the dev link to remove.

.EXAMPLE
tvsm mod dev unlink MyMod
#>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    $modWorkDir = (Get-TVSEnvironment).modWorkDir
    if ([string]::IsNullOrEmpty($modWorkDir)) { throw "modWorkDir is not configured." }

    $devLinks = Read-TVSDevLinks -ModWorkDir $modWorkDir
    if (-not $devLinks['links'] -or -not $devLinks['links'].ContainsKey($Name)) {
        throw "Dev link '$Name' not found."
    }

    $devLinks['links'].Remove($Name)
    Write-TVSDevLinks -ModWorkDir $modWorkDir -DevLinks $devLinks

    Write-SpectreHost "[green]✓ Dev link removed:[/] $Name"
    Write-SpectreHost "Run [cyan]tvsm mod apply[/] to update staging."
}

function Get-TVSMDevLinkList {
<#
.SYNOPSIS
Displays all registered dev links with their source paths, layouts, and status.

.PARAMETER Json
Emit structured JSON instead of the Spectre table.

.EXAMPLE
tvsm mod dev list
#>
    [CmdletBinding()]
    param([switch]$Json)

    $modWorkDir = (Get-TVSEnvironment).modWorkDir
    if ([string]::IsNullOrEmpty($modWorkDir)) { throw "modWorkDir is not configured." }

    $devLinks = Read-TVSDevLinks -ModWorkDir $modWorkDir
    $links    = $devLinks['links'] ?? @{}

    if ($Json) { $links | ConvertTo-Json -Depth 10; return }

    if ($links.Count -eq 0) {
        Write-SpectreHost '[grey]No dev links configured. Run [cyan]tvsm mod dev link <name> --src <path>[/] to add one.[/]'
        return
    }

    $rows = foreach ($key in $links.Keys) {
        $link      = $links[$key]
        $srcExists = Test-Path -LiteralPath $link['src']
        $status    = if ($srcExists) { '[green]✓[/]' } else { '[red]✗ missing[/]' }
        [pscustomobject]@{
            Status = $status
            Name   = $key
            Source = $link['src']
            Layout = $link['installLayout'] ?? 'plugins-dll'
            Note   = $link['note'] ?? ''
        }
    }

    $rows | Format-SpectreTable -Border Rounded -Color Cyan `
        -Title '[cyan]Dev Links[/]' -AllowMarkup
}
