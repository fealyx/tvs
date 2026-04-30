function Watch-TVSSave {
<#
.SYNOPSIS
Watches the player data directory for save file changes and auto-expands
embedded character data into characterWorkDir.

.DESCRIPTION
Phase 3 feature. Not yet implemented.

.PARAMETER Path
Path to watch. Defaults to playerDataDir from the TVS.Environment profile.

.PARAMETER Profile
Named profile to use for path resolution.
#>
    [CmdletBinding()]
    param(
        [string]$Path = '',
        [string]$Profile = ''
    )

    Write-SpectreHost '[yellow]tvsm save watch is not yet implemented (Phase 3).[/]'
    Write-SpectreHost 'The save directory will be resolved from [cyan]playerDataDir[/] in your TVS.Environment profile.'
}
