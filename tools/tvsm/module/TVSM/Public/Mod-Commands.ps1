function Get-TVSMModStatus {
<#
.SYNOPSIS
Shows the status of installed mods in the TVS plugins directory.

.DESCRIPTION
Phase 2 feature. Not yet implemented.
#>
    [CmdletBinding()]
    param(
        [string]$Profile = '',
        [switch]$Json
    )

    Write-SpectreHost '[yellow]tvsm mod status is not yet implemented (Phase 2).[/]'
    Write-SpectreHost 'Run [cyan]tvsm config show[/] to verify your environment is configured.'
}

function Install-TVSMMod {
<#
.SYNOPSIS
Installs a mod from the community registry.

.DESCRIPTION
Phase 2 feature. Not yet implemented.
#>
    [CmdletBinding()]
    param(
        [string]$Name,
        [switch]$All,
        [string]$Profile = '',
        [switch]$Yes
    )

    Write-SpectreHost '[yellow]tvsm mod install is not yet implemented (Phase 2).[/]'
}

function Remove-TVSMMod {
<#
.SYNOPSIS
Removes an installed mod.

.DESCRIPTION
Phase 2 feature. Not yet implemented.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [switch]$Yes
    )

    Write-SpectreHost '[yellow]tvsm mod remove is not yet implemented (Phase 2).[/]'
}

function Invoke-TVSMModRollback {
<#
.SYNOPSIS
Restores the plugins directory from the most recent pre-mutation snapshot.

.DESCRIPTION
Phase 2 feature. Not yet implemented.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$SnapshotName = '',
        [switch]$Yes
    )

    Write-SpectreHost '[yellow]tvsm mod rollback is not yet implemented (Phase 2).[/]'
}

function Test-TVSMModEnvironment {
<#
.SYNOPSIS
Verifies the mod environment: BepInEx integrity, TVSLib presence, config manager.

.DESCRIPTION
Phase 2 feature. Not yet implemented.
#>
    [CmdletBinding()]
    param(
        [string]$Profile = '',
        [switch]$Json
    )

    Write-SpectreHost '[yellow]tvsm mod verify is not yet implemented (Phase 2).[/]'
    Write-SpectreHost 'Use [cyan]Test-TVSEnvironment[/] from TVS.Environment to check basic path configuration.'
}

function New-TVSMModSnapshot {
<#
.SYNOPSIS
Manually creates a named rollback snapshot of the current plugins directory.

.DESCRIPTION
Phase 2 feature. Not yet implemented.
#>
    [CmdletBinding()]
    param(
        [string]$Name = ''
    )

    Write-SpectreHost '[yellow]tvsm mod snapshot is not yet implemented (Phase 2).[/]'
}
