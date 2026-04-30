function Show-TVSMConfig {
<#
.SYNOPSIS
Displays the fully-resolved TVS environment configuration as a Spectre table.

.DESCRIPTION
Reads the active profile via TVS.Environment and renders each key with its
resolved value and the source that provided it. Keys that are unset are
highlighted in yellow.

.PARAMETER Profile
Named profile to read. Defaults to the active profile in ~/.tvs/config.json.

.PARAMETER Json
Emit the resolved config as JSON to stdout instead of rendering a table.
Useful for scripting and CI.

.EXAMPLE
Show-TVSMConfig
tvsm config show --profile dev
#>
    [CmdletBinding()]
    param(
        [string]$Profile = '',
        [switch]$Json
    )

    $keys = @('gameDir', 'playerDataDir', 'characterWorkDir', 'modWorkDir', 'communityRegistryUrl', 'communityRegistryCacheTtlMinutes')

    $tvsEnv = if ($Profile) {
        Get-TVSEnvironment -Profile $Profile
    } else {
        Get-TVSEnvironment
    }

    if ($Json) {
        $tvsEnv | ConvertTo-Json -Depth 5
        return
    }

    $rows = foreach ($key in $keys) {
        $value = $tvsEnv.$key
        $display = if ([string]::IsNullOrWhiteSpace([string]$value)) { '[grey](not set)[/]' } else { [string]$value }
        [pscustomobject]@{ Key = $key; Value = $display }
    }

    # pluginsDir is derived — add it separately
    $pluginsDisplay = if ([string]::IsNullOrWhiteSpace([string]$tvsEnv.pluginsDir)) { '[grey](derived from gameDir)[/]' } else { [string]$tvsEnv.pluginsDir }
    $rows += [pscustomobject]@{ Key = 'pluginsDir [grey](derived)[/]'; Value = $pluginsDisplay }

    $rows | Format-SpectreTable -Border Rounded -Color Blue -Title '[cyan]TVS Environment Configuration[/]' -AllowMarkup
}
