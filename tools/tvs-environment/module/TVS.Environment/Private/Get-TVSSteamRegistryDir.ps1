function Get-TVSSteamRegistryDir {
    # Reads the Steam registry key for TVS (App ID 1906350).
    # Returns the install path if found and valid, otherwise $null.
    # Silently ignores all errors (non-Windows, registry access failure, etc.).
    try {
        $steamKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 1906350'
        if (Test-Path $steamKey) {
            $installDir = (Get-ItemProperty -Path $steamKey -ErrorAction SilentlyContinue).InstallLocation
            if ($installDir -and (Test-Path (Join-Path $installDir 'TheVillainSimulator_Data'))) {
                return $installDir
            }
        }
    }
    catch {
        # Ignore: non-Windows, registry access failure, etc.
    }
    return $null
}
