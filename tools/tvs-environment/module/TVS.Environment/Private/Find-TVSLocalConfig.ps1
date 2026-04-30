function Find-TVSLocalConfig {
    $current = $PWD.Path

    while ($true) {
        $candidate = Join-Path $current '.tvs-config.json'
        if (Test-Path -LiteralPath $candidate) {
            try {
                return Get-Content -Raw -LiteralPath $candidate | ConvertFrom-Json -AsHashtable -Depth 20
            }
            catch {
                # Ignore parse errors; continue walking up
            }
        }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
    }

    return $null
}
