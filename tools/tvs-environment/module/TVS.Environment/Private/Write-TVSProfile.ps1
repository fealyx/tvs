function Write-TVSProfile {
    param(
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value,
        [string]$Profile = 'default'
    )

    $profilePath = Join-Path $HOME '.tvs' 'config.json'
    $dir = Split-Path -Parent $profilePath

    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $config = $null
    if (Test-Path -LiteralPath $profilePath) {
        $config = Get-Content -Raw -LiteralPath $profilePath | ConvertFrom-Json -AsHashtable -Depth 20
    }

    if (-not $config) {
        $config = [ordered]@{
            schemaVersion = 1
            activeProfile = 'default'
            profiles      = [ordered]@{ default = [ordered]@{} }
        }
    }

    if (-not $config.ContainsKey('profiles')) {
        $config['profiles'] = [ordered]@{}
    }
    if (-not $config['profiles'].ContainsKey($Profile)) {
        $config['profiles'][$Profile] = [ordered]@{}
    }

    $config['profiles'][$Profile][$Key] = $Value

    $json = $config | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($profilePath, $json, [System.Text.UTF8Encoding]::new($false))
}
