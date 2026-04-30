function Set-TVSEnvironmentValue {
<#
.SYNOPSIS
Writes a key-value pair to the TVS user profile at ~/.tvs/config.json.

.PARAMETER Key
The canonical profile key to set. Must be one of the recognised key names.

.PARAMETER Value
The value to store. Pass an empty string to clear a key.

.PARAMETER Profile
The named profile to write to. Defaults to 'default'.

.EXAMPLE
Set-TVSEnvironmentValue -Key gameDir -Value 'C:\Steam\steamapps\common\The Villain Simulator'
Set-TVSEnvironmentValue -Key characterWorkDir -Value 'D:\TVS\Characters' -Profile dev
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value,
        [string]$Profile = 'default'
    )

    $validKeys = @(
        'gameDir',
        'playerDataDir',
        'characterWorkDir',
        'modWorkDir',
        'communityRegistryUrl',
        'communityRegistryCacheTtlMinutes'
    )

    if ($validKeys -notcontains $Key) {
        throw "Unknown profile key: '$Key'. Valid keys: $($validKeys -join ', ')"
    }

    if (-not $PSCmdlet.ShouldProcess("~/.tvs/config.json", "Set '$Key' in profile '$Profile'")) {
        return
    }

    Write-TVSProfile -Key $Key -Value $Value -Profile $Profile
}
