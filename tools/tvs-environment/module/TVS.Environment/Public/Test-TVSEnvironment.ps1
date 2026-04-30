function Test-TVSEnvironment {
<#
.SYNOPSIS
Validates that required TVS profile keys are set and their paths exist on disk.

.DESCRIPTION
Does not throw. Returns a PSCustomObject with Valid, Missing, and InvalidPaths
properties for use in conditional checks.

.PARAMETER RequiredKeys
The profile keys to validate. Defaults to @('gameDir').

.EXAMPLE
$result = Test-TVSEnvironment
if (-not $result.Valid) { Initialize-TVSEnvironment }

Test-TVSEnvironment -RequiredKeys @('gameDir', 'playerDataDir', 'characterWorkDir')
#>
    [CmdletBinding()]
    param(
        [string[]]$RequiredKeys = @('gameDir')
    )

    $validKeys  = @('gameDir', 'playerDataDir', 'characterWorkDir', 'modWorkDir', 'communityRegistryUrl', 'communityRegistryCacheTtlMinutes')
    $pathKeys   = @('gameDir', 'playerDataDir', 'characterWorkDir', 'modWorkDir')

    $missing      = @()
    $invalidPaths = @()

    $tvsEnv = Get-TVSEnvironment

    foreach ($key in $RequiredKeys) {
        if ($validKeys -notcontains $key) {
            throw "Unknown profile key: '$key'. Valid keys: $($validKeys -join ', ')"
        }

        $value = $tvsEnv.$key
        if ([string]::IsNullOrWhiteSpace([string]$value)) {
            $missing += $key
        }
        elseif ($pathKeys -contains $key -and -not (Test-Path -LiteralPath $value)) {
            $invalidPaths += $key
        }
    }

    return [pscustomobject]@{
        Valid        = ($missing.Count -eq 0) -and ($invalidPaths.Count -eq 0)
        Missing      = $missing
        InvalidPaths = $invalidPaths
    }
}
