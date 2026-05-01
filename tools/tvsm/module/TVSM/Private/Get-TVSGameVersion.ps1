function Get-TVSGameVersion {
<#
.SYNOPSIS
Attempts to read the current game version from the game directory.
Returns $null when the version cannot be determined (silently — callers
treat $null as "version unknown, skip range checks").

Tries, in order:
  1. {gameDir}/*_Data/app.info (standard Unity build artefact — two-line format:
     line 1 = app name, line 2 = version)
  2. {gameDir}/gameversion.txt (simple one-line version string)
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$GameDir
    )

    if (-not (Test-Path -LiteralPath $GameDir)) { return $null }

    # 1. Unity app.info
    $dataFolders = Get-ChildItem -LiteralPath $GameDir -Directory -Filter '*_Data' -ErrorAction SilentlyContinue
    foreach ($df in $dataFolders) {
        $appInfoPath = Join-Path $df.FullName 'app.info'
        if (Test-Path -LiteralPath $appInfoPath) {
            $lines = Get-Content -LiteralPath $appInfoPath -ErrorAction SilentlyContinue
            if ($lines -and $lines.Count -ge 2 -and -not [string]::IsNullOrWhiteSpace($lines[1])) {
                return $lines[1].Trim()
            }
        }
    }

    # 2. Flat version file
    $versionFilePath = Join-Path $GameDir 'gameversion.txt'
    if (Test-Path -LiteralPath $versionFilePath) {
        $ver = (Get-Content -Raw -LiteralPath $versionFilePath -ErrorAction SilentlyContinue).Trim()
        if (-not [string]::IsNullOrEmpty($ver)) { return $ver }
    }

    return $null
}
