function Get-TVSCommunityRegistry {
<#
.SYNOPSIS
Fetches the community mod registry from communityRegistryUrl, caching the result
at {modWorkDir}/.registry-cache.json with the TTL from communityRegistryCacheTtlMinutes
(default: 60). Returns cached data when offline and cache is available.

.PARAMETER ModWorkDir
Mod working directory. Used for cache file location. If omitted, resolved from TVSEnvironment.

.PARAMETER ForceRefresh
Bypass cache TTL and always fetch fresh data.
#>
    [CmdletBinding()]
    param(
        [string]$ModWorkDir = '',
        [switch]$ForceRefresh
    )

    $tvse = Get-TVSEnvironment
    if ([string]::IsNullOrEmpty($ModWorkDir)) {
        $ModWorkDir = $tvse.modWorkDir
    }
    $registryUrl = $tvse.communityRegistryUrl
    $cacheTtlMinutes = if ($tvse.communityRegistryCacheTtlMinutes) {
        [int]$tvse.communityRegistryCacheTtlMinutes
    } else { 60 }

    if ([string]::IsNullOrEmpty($registryUrl)) {
        throw "communityRegistryUrl is not configured. Run 'tvsm config set communityRegistryUrl <url>'."
    }

    $cachePath = Join-Path $ModWorkDir '.registry-cache.json'

    # Return cached copy if within TTL
    if (-not $ForceRefresh -and (Test-Path -LiteralPath $cachePath)) {
        try {
            $cache = Get-Content -Raw -LiteralPath $cachePath | ConvertFrom-Json
            if ($cache.cachedAt) {
                $age = ([DateTimeOffset]::UtcNow - [DateTimeOffset]::Parse($cache.cachedAt)).TotalMinutes
                if ($age -lt $cacheTtlMinutes) {
                    return $cache
                }
            }
        } catch {
            # Corrupted cache — fall through to fetch
        }
    }

    # Fetch fresh
    try {
        $data = Invoke-RestMethod -Uri $registryUrl -UseBasicParsing -ErrorAction Stop

        # Annotate with cache timestamp
        $data | Add-Member -NotePropertyName 'cachedAt' `
            -NotePropertyValue ([DateTimeOffset]::UtcNow.ToString('o')) -Force

        if ($ModWorkDir -and (Test-Path -LiteralPath $ModWorkDir)) {
            $json = $data | ConvertTo-Json -Depth 20
            [System.IO.File]::WriteAllText($cachePath, $json, [System.Text.UTF8Encoding]::new($false))
        }

        return $data
    } catch {
        if (Test-Path -LiteralPath $cachePath) {
            Write-Warning "[tvsm] Could not fetch registry ($_). Using cached version."
            return Get-Content -Raw -LiteralPath $cachePath | ConvertFrom-Json
        }
        throw "Failed to fetch community registry from '$registryUrl' and no local cache is available: $_"
    }
}
