function Read-TVSProfile {
    param(
        [string]$Profile = ''
    )

    $profilePath = Join-Path $HOME '.tvs' 'config.json'

    if (-not (Test-Path -LiteralPath $profilePath)) {
        $dir = Split-Path -Parent $profilePath
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $default = [ordered]@{
            schemaVersion = 1
            activeProfile = 'default'
            profiles      = [ordered]@{ default = [ordered]@{} }
        }
        $json = $default | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($profilePath, $json, [System.Text.UTF8Encoding]::new($false))
        return @{}
    }

    $config = Get-Content -Raw -LiteralPath $profilePath | ConvertFrom-Json -AsHashtable -Depth 20

    $activeProfileName = if (-not [string]::IsNullOrEmpty($Profile)) {
        $Profile
    }
    else {
        $config['activeProfile'] ?? 'default'
    }
    if ([string]::IsNullOrEmpty($activeProfileName)) { $activeProfileName = 'default' }

    $activeProfileData = $null
    if ($config['profiles'] -and $config['profiles'].ContainsKey($activeProfileName)) {
        $activeProfileData = $config['profiles'][$activeProfileName]
    }

    # Named profile keys take precedence; missing keys fall through to default profile
    if ($activeProfileName -ne 'default' -and $config['profiles'] -and $config['profiles'].ContainsKey('default')) {
        $defaultData = $config['profiles']['default']
        $merged = @{}
        foreach ($key in $defaultData.Keys) { $merged[$key] = $defaultData[$key] }
        if ($activeProfileData) {
            foreach ($key in $activeProfileData.Keys) { $merged[$key] = $activeProfileData[$key] }
        }
        return $merged
    }

    return if ($activeProfileData) { $activeProfileData } else { @{} }
}
