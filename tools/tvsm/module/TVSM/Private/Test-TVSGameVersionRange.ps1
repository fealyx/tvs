function Test-TVSGameVersionRange {
<#
.SYNOPSIS
Tests whether a game version satisfies a version range string.
Returns $true if either parameter is null/empty (no constraint — caller proceeds).

Supports standard semver-style range operators: >=, >, <=, <, =, and bare version
(exact match). Multiple constraints separated by whitespace are AND-ed together.

Examples:
  '>=0.45'         — game must be 0.45 or newer
  '>=0.45 <1.0'   — game must be 0.45 up to but not including 1.0
  '=0.47.3'        — game must be exactly 0.47.3
#>
    [CmdletBinding()]
    param(
        [string]$GameVersion,
        [string]$Range
    )

    if ([string]::IsNullOrWhiteSpace($GameVersion) -or [string]::IsNullOrWhiteSpace($Range)) {
        return $true
    }

    $gv = $null
    try { $gv = [version]$GameVersion } catch { return $true }

    foreach ($part in ($Range.Trim() -split '\s+')) {
        if ([string]::IsNullOrWhiteSpace($part)) { continue }

        if ($part -match '^>=(.+)$') {
            try { if ($gv -lt [version]$Matches[1]) { return $false } } catch {}
        } elseif ($part -match '^>(.+)$') {
            try { if ($gv -le [version]$Matches[1]) { return $false } } catch {}
        } elseif ($part -match '^<=(.+)$') {
            try { if ($gv -gt [version]$Matches[1]) { return $false } } catch {}
        } elseif ($part -match '^<(.+)$') {
            try { if ($gv -ge [version]$Matches[1]) { return $false } } catch {}
        } elseif ($part -match '^=(.+)$') {
            try { if ($gv -ne [version]$Matches[1]) { return $false } } catch {}
        } elseif ($part -match '^(\d.*)$') {
            # Bare version — treat as exact match
            try { if ($gv -ne [version]$Matches[1]) { return $false } } catch {}
        }
    }

    return $true
}
