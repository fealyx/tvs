function Read-TVSLegacyDotEnv {
    # Walk upward from the current working directory to find a .env file.
    # Only TVS_* keys are surfaced; unrelated vars (e.g. UNITY_EDITOR_PATH) are ignored.
    $keyMap = @{
        'TVS_GAME_DIR'        = 'gameDir'
        'TVS_PLAYER_DATA_DIR' = 'playerDataDir'
    }

    $current = $PWD.Path
    $envPath = $null

    while ($true) {
        $candidate = Join-Path $current '.env'
        if (Test-Path -LiteralPath $candidate) {
            $envPath = $candidate
            break
        }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
    }

    if (-not $envPath) { return @{} }

    $result = @{}
    foreach ($line in Get-Content -LiteralPath $envPath) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        $index = $trimmed.IndexOf('=')
        if ($index -le 0) { continue }
        $key   = $trimmed.Substring(0, $index).Trim()
        $value = $trimmed.Substring($index + 1).Trim()
        if ($keyMap.ContainsKey($key)) {
            $result[$keyMap[$key]] = $value
        }
    }

    return $result
}
