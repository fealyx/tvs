function Read-TVSLegacyGameDirProps {
    # Walk upward from the current working directory looking for mods/csharp/GameDir.props.
    # Only exposes gameDir; other MSBuild properties are not surfaced.
    $current = $PWD.Path

    while ($true) {
        $candidate = Join-Path $current 'mods' 'csharp' 'GameDir.props'
        if (Test-Path -LiteralPath $candidate) {
            try {
                [xml]$propsXml = Get-Content -LiteralPath $candidate
                $gameDir = $propsXml.Project.PropertyGroup.TVSGameDir
                if (-not [string]::IsNullOrWhiteSpace($gameDir)) {
                    return @{ gameDir = $gameDir }
                }
            }
            catch {
                # Ignore parse failures
            }
            break
        }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
    }

    return $null
}
