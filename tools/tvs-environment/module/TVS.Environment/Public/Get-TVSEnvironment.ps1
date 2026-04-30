function Get-TVSEnvironment {
<#
.SYNOPSIS
Returns the resolved TVS environment profile for the current user and context.

.DESCRIPTION
Resolves all canonical profile keys using the 7-level priority chain (ADR-002).
Returns a PSCustomObject with all keys and a derived pluginsDir convenience property.

.PARAMETER Profile
Named profile to activate. Overrides the activeProfile setting in ~/.tvs/config.json.

.PARAMETER Key
When specified, returns the resolved scalar value for that key only instead of the
full environment object.

.EXAMPLE
$env = Get-TVSEnvironment
$env.gameDir

Get-TVSEnvironment -Key characterWorkDir

Get-TVSEnvironment -Profile dev
#>
    [CmdletBinding()]
    param(
        [string]$Profile = '',
        [string]$Key = ''
    )

    $canonicalKeys = @(
        'gameDir',
        'playerDataDir',
        'characterWorkDir',
        'modWorkDir',
        'communityRegistryUrl',
        'communityRegistryCacheTtlMinutes'
    )

    if (-not [string]::IsNullOrEmpty($Key)) {
        if ($canonicalKeys -notcontains $Key) {
            throw "Unknown profile key: '$Key'. Valid keys: $($canonicalKeys -join ', ')"
        }
        return Resolve-TVSProfileKey -Key $Key -Profile $Profile
    }

    $resolved = @{}
    foreach ($k in $canonicalKeys) {
        $resolved[$k] = Resolve-TVSProfileKey -Key $k -Profile $Profile
    }

    $pluginsDir = if ($resolved['gameDir']) {
        Join-Path $resolved['gameDir'] 'BepInEx' 'plugins'
    }
    else { $null }

    return [pscustomobject]@{
        gameDir                      = $resolved['gameDir']
        playerDataDir                = $resolved['playerDataDir']
        characterWorkDir             = $resolved['characterWorkDir']
        modWorkDir                   = $resolved['modWorkDir']
        communityRegistryUrl         = $resolved['communityRegistryUrl']
        communityRegistryCacheTtlMinutes = $resolved['communityRegistryCacheTtlMinutes']
        pluginsDir                   = $pluginsDir
    }
}
