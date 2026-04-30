function Resolve-TVSProfileKey {
    <#
    .SYNOPSIS
    Resolves a single TVS profile key by walking the 7-level priority chain defined in ADR-002.

    .DESCRIPTION
    Priority order (highest to lowest):
      1. ExplicitValue parameter — caller-supplied override
      2. Nearest-ancestor .tvs-config.json — local project overlay
      3. ~/.tvs/config.json active/named profile — user profile
      4. Legacy .env (TVS_* keys only) — read-only compatibility shim
      5. Legacy GameDir.props — read-only shim, gameDir key only
      6. Steam registry uninstall key — auto-detect, gameDir key only
      7. $null — not configured

    .PARAMETER Key
    Canonical profile key name (e.g. 'gameDir', 'characterWorkDir').

    .PARAMETER Profile
    Named profile to use from ~/.tvs/config.json. Defaults to the file's activeProfile.

    .PARAMETER ExplicitValue
    Caller-supplied value that bypasses all other resolution (priority 1).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [string]$Profile = '',
        [string]$ExplicitValue = ''
    )

    # Level 1: Explicit caller-supplied value
    if (-not [string]::IsNullOrWhiteSpace($ExplicitValue)) {
        return $ExplicitValue
    }

    # Level 2: Nearest-ancestor .tvs-config.json
    $localConfig = Find-TVSLocalConfig
    if ($localConfig -and $localConfig.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace([string]$localConfig[$Key])) {
        return [string]$localConfig[$Key]
    }

    # Level 3: ~/.tvs/config.json user profile
    $userProfile = Read-TVSProfile -Profile $Profile
    if ($userProfile -and $userProfile.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace([string]$userProfile[$Key])) {
        return [string]$userProfile[$Key]
    }

    # Level 4: Legacy .env (TVS_* keys; gameDir and playerDataDir only)
    $legacyEnv = Read-TVSLegacyDotEnv
    if ($legacyEnv -and $legacyEnv.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace([string]$legacyEnv[$Key])) {
        return [string]$legacyEnv[$Key]
    }

    # Levels 5 and 6 apply to gameDir only
    if ($Key -eq 'gameDir') {
        # Level 5: Legacy GameDir.props
        $legacyProps = Read-TVSLegacyGameDirProps
        if ($legacyProps -and $legacyProps.ContainsKey('gameDir') -and -not [string]::IsNullOrWhiteSpace([string]$legacyProps['gameDir'])) {
            return [string]$legacyProps['gameDir']
        }

        # Level 6: Steam registry auto-detect
        $steamDir = Get-TVSSteamRegistryDir
        if (-not [string]::IsNullOrWhiteSpace([string]$steamDir)) {
            return [string]$steamDir
        }
    }

    # Level 7: Not configured
    return $null
}
