function Initialize-TVSEnvironment {
<#
.SYNOPSIS
Interactive first-run wizard that populates the TVS user profile.

.DESCRIPTION
Prompts for the key environment paths and writes them to ~/.tvs/config.json.
Pre-populates each prompt with the currently resolved value (if any), so
re-running this command after partial setup preserves existing entries.

NOTE: This is the minimal Read-Host implementation for Phase 0.
For a richer TUI experience, use `tvsm config init` (Phase 1).

.EXAMPLE
Initialize-TVSEnvironment
#>
    [CmdletBinding()]
    param()

    Write-Host ''
    Write-Host 'TVS Environment Setup' -ForegroundColor Cyan
    Write-Host '=====================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Configures your TVS tools profile at ~/.tvs/config.json.' -ForegroundColor Gray
    Write-Host 'Press Enter to keep the current value shown in [brackets].' -ForegroundColor Gray
    Write-Host ''

    $prompts = @(
        [pscustomobject]@{ Key = 'gameDir';          Label = 'Game directory';             ValidateGame = $true  },
        [pscustomobject]@{ Key = 'playerDataDir';    Label = 'Player data directory';      ValidateGame = $false },
        [pscustomobject]@{ Key = 'characterWorkDir'; Label = 'Character working directory'; ValidateGame = $false },
        [pscustomobject]@{ Key = 'modWorkDir';       Label = 'Mod working directory';       ValidateGame = $false }
    )

    foreach ($entry in $prompts) {
        $current = Resolve-TVSProfileKey -Key $entry.Key

        while ($true) {
            $promptText = $entry.Label
            if (-not [string]::IsNullOrWhiteSpace($current)) { $promptText += " [$current]" }
            $input = Read-Host $promptText

            $value = if ([string]::IsNullOrWhiteSpace($input)) { $current } else { $input }

            if ([string]::IsNullOrWhiteSpace($value)) {
                Write-Host '  (skipped)' -ForegroundColor Gray
                break
            }

            if ($entry.ValidateGame) {
                $dataDir = Join-Path $value 'TheVillainSimulator_Data'
                if (-not (Test-Path -LiteralPath $dataDir)) {
                    Write-Host "  Directory does not appear to be a valid TVS install (TheVillainSimulator_Data not found)." -ForegroundColor Yellow
                    $retry = Read-Host '  Re-enter? [Y/n]'
                    if ($retry -ne 'n' -and $retry -ne 'N') { continue }
                }
            }

            Set-TVSEnvironmentValue -Key $entry.Key -Value $value
            Write-Host "  Saved: $($entry.Key) = $value" -ForegroundColor Green
            break
        }
    }

    Write-Host ''
    Write-Host 'Setup complete. Run Get-TVSEnvironment to review your configuration.' -ForegroundColor Green
}
