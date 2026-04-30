function Invoke-TVSMConfigInit {
<#
.SYNOPSIS
Interactive first-run wizard for TVS environment configuration.

.DESCRIPTION
A richer TUI wrapper around Initialize-TVSEnvironment, using PwshSpectreConsole
prompts. For a minimal Read-Host fallback, call Initialize-TVSEnvironment directly.

.PARAMETER Profile
Named profile to configure. Defaults to the active profile.

.EXAMPLE
Invoke-TVSMConfigInit
tvsm config init --profile dev
#>
    [CmdletBinding()]
    param(
        [string]$Profile = ''
    )

    Write-SpectreHost ''
    Write-SpectreHost '[cyan bold]TVS Environment Setup[/]'
    Write-SpectreHost '[cyan]=====================[/]'
    Write-SpectreHost ''
    Write-SpectreHost '[grey]Configures your TVS tools profile at ~/.tvs/config.json.[/]'
    Write-SpectreHost '[grey]Press Enter to keep the current value shown as the default.[/]'
    Write-SpectreHost ''

    $prompts = @(
        [pscustomobject]@{ Key = 'gameDir';          Label = 'Game directory';              ValidateGame = $true  },
        [pscustomobject]@{ Key = 'playerDataDir';    Label = 'Player data directory';       ValidateGame = $false },
        [pscustomobject]@{ Key = 'characterWorkDir'; Label = 'Character working directory'; ValidateGame = $false },
        [pscustomobject]@{ Key = 'modWorkDir';       Label = 'Mod working directory';       ValidateGame = $false }
    )

    $profileArg = @{}
    if ($Profile) { $profileArg['Profile'] = $Profile }

    foreach ($entry in $prompts) {
        $current = Resolve-TVSProfileKey -Key $entry.Key @profileArg

        $defaultDisplay = if ([string]::IsNullOrWhiteSpace([string]$current)) { '' } else { [string]$current }

        while ($true) {
            $input = Read-SpectreText -Message "$($entry.Label):" -DefaultAnswer $defaultDisplay -AllowEmpty

            $value = if ([string]::IsNullOrWhiteSpace($input)) { $current } else { $input }

            if ([string]::IsNullOrWhiteSpace([string]$value)) {
                Write-SpectreHost '  [grey](skipped)[/]'
                break
            }

            if ($entry.ValidateGame) {
                $dataDir = Join-Path $value 'TheVillainSimulator_Data'
                if (-not (Test-Path -LiteralPath $dataDir)) {
                    Write-SpectreHost '  [yellow]Directory does not appear to be a valid TVS install (TheVillainSimulator_Data not found).[/]'
                    $retry = Read-SpectreConfirm -Message 'Re-enter?' -DefaultAnswer 'y'
                    if ($retry) { continue }
                }
            }

            $setArgs = @{ Key = $entry.Key; Value = $value }
            if ($Profile) { $setArgs['Profile'] = $Profile }
            Set-TVSEnvironmentValue @setArgs
            Write-SpectreHost "  [green]Saved:[/] $($entry.Key) = $value"
            break
        }
    }

    Write-SpectreHost ''
    Write-SpectreHost '[green]Setup complete.[/] Run [cyan]tvsm config show[/] to review your configuration.'
    Write-SpectreHost ''
}
