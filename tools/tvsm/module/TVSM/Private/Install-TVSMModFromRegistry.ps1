function Install-TVSMModFromRegistry {
<#
.SYNOPSIS
Downloads a specific mod version from the community registry, verifies its SHA-256
hash, extracts it into the mod store, and writes a tvsm-meta.json metadata file.

.PARAMETER ModWorkDir
Mod working directory (store parent).

.PARAMETER ModName
The registry name of the mod (e.g. 'BepInEx', 'TVSLib').

.PARAMETER VersionEntry
The version object from the registry (must have: version, url, sha256, installLayout).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ModWorkDir,
        [Parameter(Mandatory)][string]$ModName,
        [Parameter(Mandatory)][object]$VersionEntry
    )

    $storePath = Join-Path $ModWorkDir 'store' $ModName $VersionEntry.version

    if (-not (Test-Path -LiteralPath $storePath)) {
        New-Item -ItemType Directory -Path $storePath -Force | Out-Null
    }

    $tempFile = [System.IO.Path]::GetTempFileName() + '.zip'
    try {
        Write-SpectreHost "[cyan]  Downloading:[/] $ModName $($VersionEntry.version)..."
        Invoke-WebRequest -Uri $VersionEntry.url -OutFile $tempFile -UseBasicParsing -ErrorAction Stop

        # SHA-256 verification
        if (-not [string]::IsNullOrEmpty($VersionEntry.sha256)) {
            $actual   = (Get-FileHash -Path $tempFile -Algorithm SHA256).Hash.ToLower()
            $expected = $VersionEntry.sha256.ToLower().TrimStart('sha256:')
            if ($actual -ne $expected) {
                Remove-Item -LiteralPath $storePath -Recurse -Force -ErrorAction SilentlyContinue
                throw "SHA-256 mismatch for $ModName $($VersionEntry.version). Expected: $expected, got: $actual"
            }
        }

        Expand-Archive -LiteralPath $tempFile -DestinationPath $storePath -Force

        # Write metadata alongside the extracted files
        $meta = [ordered]@{
            name          = $ModName
            version       = $VersionEntry.version
            installLayout = $VersionEntry.installLayout
            installedAt   = [DateTimeOffset]::UtcNow.ToString('o')
            url           = $VersionEntry.url
            sha256        = $VersionEntry.sha256 ?? ''
        }
        $metaPath = Join-Path $storePath 'tvsm-meta.json'
        [System.IO.File]::WriteAllText($metaPath, ($meta | ConvertTo-Json -Depth 5),
            [System.Text.UTF8Encoding]::new($false))

        Write-SpectreHost "[green]  ✓ Stored:[/] $ModName $($VersionEntry.version)"
    } finally {
        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}
