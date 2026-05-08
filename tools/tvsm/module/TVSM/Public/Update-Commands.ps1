# ---------------------------------------------------------------------------
# Update Commands — tvsm update check / tvsm update apply
# ---------------------------------------------------------------------------

# GitHub repository for API queries
$script:TVSMRepoOwner = 'fealyx'
$script:TVSMRepoName = 'tvs'
$script:TVSMTagPrefix = 'tvs-tools/v'  # Tag format: tvs-tools/v0.1.0

# ---------------------------------------------------------------------------
# Get-TVSMReleaseFromApi (private)
# ---------------------------------------------------------------------------
function Get-TVSMReleaseFromApi {
<#
.SYNOPSIS
    Queries the GitHub API to find the latest tvs-tools release.

.DESCRIPTION
    Queries the GitHub Releases API to find releases matching the tvs-tools/v* tag format.
    Can optionally include pre-releases in the search results.

.PARAMETER IncludePreRelease
    When set, includes pre-release versions in the search. Otherwise only stable releases.

.EXAMPLE
    $release = Get-TVSMReleaseFromApi
    $preRelease = Get-TVSMReleaseFromApi -IncludePreRelease
#>
    [CmdletBinding()]
    param(
        [bool]$IncludePreRelease = $false
    )

    $apiUrl = "https://api.github.com/repos/$($script:TVSMRepoOwner)/$($script:TVSMRepoName)/releases?per_page=100"
    
    try {
        Write-SpectreHost "[grey]Querying GitHub API for releases...[/]"
        $headers = @{ 'User-Agent' = 'TVSM' }
        
        # Add GitHub token if available for higher rate limits
        if ($env:GITHUB_TOKEN) {
            $headers['Authorization'] = "token $env:GITHUB_TOKEN"
        }
        
        $releases = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
        
        # Filter for tvs-tools/v* tags
        $tvsReleases = $releases | Where-Object { $_.tag_name -match "^$($script:TVSMTagPrefix.Replace('.', '\.'))\d+\.\d+\.\d+" }
        
        # Filter pre-releases unless flag is set
        if (-not $IncludePreRelease) {
            $tvsReleases = $tvsReleases | Where-Object { $_.prerelease -eq $false }
        }
        
        # Return the latest (most recent by published_at)
        $latest = $tvsReleases | Sort-Object -Property published_at -Descending | Select-Object -First 1
        
        if (-not $latest) {
            throw "No tvs-tools releases found. Ensure releases exist with tags matching '$($script:TVSMTagPrefix)*'."
        }
        
        return $latest
    } catch {
        throw "Failed to query GitHub API: $_"
    }
}

# ---------------------------------------------------------------------------
# Get-TVSMReleaseManifest (private)
# ---------------------------------------------------------------------------
function Get-TVSMReleaseManifest {
<#
.SYNOPSIS
    Downloads the release manifest from a GitHub release asset.

.DESCRIPTION
    Finds the tvs-tools-release-manifest.json asset in the specified release
    and downloads it for version comparison.

.PARAMETER Release
    The release object returned by Get-TVSMReleaseFromApi.

.EXAMPLE
    $release = Get-TVSMReleaseFromApi
    $manifest = Get-TVSMReleaseManifest -Release $release
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Release
    )

    $manifestAsset = $Release.assets | Where-Object { $_.name -eq 'tvs-tools-release-manifest.json' } | Select-Object -First 1
    
    if (-not $manifestAsset) {
        throw "Release '$($Release.tag_name)' does not contain tvs-tools-release-manifest.json asset."
    }
    
    $tempManifest = Join-Path $env:TEMP "tvs-release-manifest-$([guid]::NewGuid()).json"
    try {
        Write-SpectreHost "[grey]Downloading release manifest from $($manifestAsset.browser_download_url)...[/]"
        Invoke-WebRequest -Uri $manifestAsset.browser_download_url -OutFile $tempManifest -ErrorAction Stop
        $manifest = Get-Content -LiteralPath $tempManifest -Raw | ConvertFrom-Json
        return $manifest
    } catch {
        throw "Failed to download release manifest: $_"
    } finally {
        if (Test-Path -LiteralPath $tempManifest) {
            Remove-Item -LiteralPath $tempManifest -Force -ErrorAction SilentlyContinue
        }
    }
}

# ---------------------------------------------------------------------------
# Test-TVSMUpdateAvailable (private)
# ---------------------------------------------------------------------------
function Test-TVSMUpdateAvailable {
<#
.SYNOPSIS
    Checks for available updates using the GitHub API.

.DESCRIPTION
    Queries the GitHub API to find the latest tvs-tools release and compares
    the current bundle version against the available version.
    Returns a hashtable with update availability and version details.

.PARAMETER IncludePreRelease
    When set, includes pre-release versions in the update check.

.EXAMPLE
    $updateInfo = Test-TVSMUpdateAvailable
    if ($updateInfo.UpdateAvailable) { ... }

.EXAMPLE
    $updateInfo = Test-TVSMUpdateAvailable -IncludePreRelease $true
#>
    [CmdletBinding()]
    param(
        [bool]$IncludePreRelease = $false
    )

    # Read current VERSION.json from the bundle
    $versionJsonPath = Join-Path $script:TVSMModuleRoot '..' '..' 'VERSION.json'
    if (-not (Test-Path -LiteralPath $versionJsonPath)) {
        throw "VERSION.json not found at: $versionJsonPath. This does not appear to be a unified bundle installation."
    }

    $currentVersion = Get-Content -LiteralPath $versionJsonPath -Raw | ConvertFrom-Json
    $currentBundleVersion = $currentVersion.bundleVersion
    $currentVariant = $currentVersion.variant

    if ([string]::IsNullOrEmpty($currentBundleVersion)) {
        throw "Invalid VERSION.json: bundleVersion is missing or empty."
    }

    if ([string]::IsNullOrEmpty($currentVariant)) {
        throw "Invalid VERSION.json: variant is missing or empty."
    }

    # Get latest release from GitHub API
    $latestRelease = Get-TVSMReleaseFromApi -IncludePreRelease:$IncludePreRelease
    $manifest = Get-TVSMReleaseManifest -Release $latestRelease

    $latestVersion = $manifest.latestVersion
    if ([string]::IsNullOrEmpty($latestVersion)) {
        throw "Invalid release manifest: latestVersion is missing."
    }

    # Compare versions using [System.Version] for proper semantic version comparison
    try {
        $currentVer = [System.Version]($currentBundleVersion -replace '-.*$', '')  # Strip prerelease
        $latestVer = [System.Version]($latestVersion -replace '-.*$', '')
        $updateAvailable = $latestVer -gt $currentVer
    } catch {
        # Fallback to string comparison if version parsing fails
        $updateAvailable = $latestVersion -ne $currentBundleVersion
    }

    # Get variant-specific info
    $variantInfo = $null
    if ($manifest.variants -and $manifest.variants.$currentVariant) {
        $variantInfo = $manifest.variants.$currentVariant
    }

    return [ordered]@{
        UpdateAvailable    = $updateAvailable
        CurrentVersion     = $currentBundleVersion
        LatestVersion      = $latestVersion
        Variant            = $currentVariant
        PublishedAt        = $manifest.publishedAt
        VariantInfo        = $variantInfo
        Manifest           = $manifest
        CurrentComponents  = $currentVersion.components
        NewComponents      = if ($variantInfo) { $variantInfo.components } else { $null }
        IsPreRelease       = $latestRelease.prerelease
        ReleaseTag         = $latestRelease.tag_name
    }
}

# ---------------------------------------------------------------------------
# Invoke-TVSMUpdateCheck (public, exported)
# ---------------------------------------------------------------------------
function Invoke-TVSMUpdateCheck {
<#
.SYNOPSIS
    Checks if a newer TVSM bundle version is available.

.DESCRIPTION
    Queries the GitHub API to find the latest tvs-tools release and displays
    a comparison table showing the current and available versions using
    PwshSpectreConsole formatting.

.PARAMETER Json
    Emit output as JSON to stdout.

.PARAMETER PreRelease
    Include pre-release versions in the update check.

.EXAMPLE
    Invoke-TVSMUpdateCheck
    tvsm update check

.EXAMPLE
    Invoke-TVSMUpdateCheck -PreRelease
    tvsm update check --pre-release

.EXAMPLE
    Invoke-TVSMUpdateCheck -Json
#>
    [CmdletBinding()]
    param(
        [switch]$Json,
        [bool]$PreRelease = $false
    )

    try {
        $updateInfo = Test-TVSMUpdateAvailable -IncludePreRelease:$PreRelease
    } catch {
        if ($Json) {
            @{ error = $_.Exception.Message } | ConvertTo-Json | Write-Output
        } else {
            Write-SpectreHost "[red]Error checking for updates: $($_.Exception.Message)[/]"
        }
        return
    }

    if ($Json) {
        $output = [ordered]@{
            updateAvailable = $updateInfo.UpdateAvailable
            currentVersion  = $updateInfo.CurrentVersion
            latestVersion   = $updateInfo.LatestVersion
            variant         = $updateInfo.Variant
            publishedAt     = $updateInfo.PublishedAt
            isPreRelease   = $updateInfo.IsPreRelease
            releaseTag      = $updateInfo.ReleaseTag
        }
        $output | ConvertTo-Json -Depth 5 | Write-Output
        return
    }

    # Display using Spectre Console
    Write-SpectreHost ""
    Write-SpectreHost "[bold cyan]TVSM Update Check[/]"

    # Summary panel
    $statusColor = if ($updateInfo.UpdateAvailable) { "green" } else { "yellow" }
    $statusText = if ($updateInfo.UpdateAvailable) { "Update Available" } else { "Up to Date" }

    Write-SpectreHost "[$statusColor]Status: $statusText[/]"
    Write-SpectreHost "[grey]Current version:[/] $($updateInfo.CurrentVersion)"
    Write-SpectreHost "[grey]Latest version: [/] $($updateInfo.LatestVersion)"
    Write-SpectreHost "[grey]Variant:        [/] $($updateInfo.Variant)"
    if ($updateInfo.IsPreRelease) {
        Write-SpectreHost "[grey]Pre-release:    [/] [yellow]Yes[/]"
    }
    if ($updateInfo.PublishedAt) {
        Write-SpectreHost "[grey]Published:      [/] $($updateInfo.PublishedAt)"
    }
    Write-SpectreHost ""

    # Component version comparison table
    if ($updateInfo.CurrentComponents -and $updateInfo.NewComponents) {
        $rows = @()
        foreach ($comp in $updateInfo.CurrentComponents.PSObject.Properties) {
            $compName = $comp.Name
            $currentVer = $comp.Value
            $newVer = if ($updateInfo.NewComponents.$compName) { $updateInfo.NewComponents.$compName } else { '(unchanged)' }

            $changeIcon = if ($newVer -ne $currentVer -and $newVer -ne '(unchanged)') { '[green]↑[/]' } else { '[grey]—[/]' }

            $rows += [pscustomobject]@{
                Component = $compName
                Current   = $currentVer
                New       = $newVer
                Change    = $changeIcon
            }
        }

        $rows | Format-SpectreTable -Border Rounded -Color Blue -Title '[cyan]Component Versions[/]'
        Write-SpectreHost ""
    }

    if ($updateInfo.UpdateAvailable) {
        Write-SpectreHost "[green]Run 'tvsm update apply' to update to version $($updateInfo.LatestVersion).[/]"
        if ($updateInfo.IsPreRelease) {
            Write-SpectreHost "[yellow]Note: This is a pre-release version. Use 'tvsm update apply --pre-release' to install.[/]"
        }
    } else {
        Write-SpectreHost "[yellow]You are already running the latest version.[/]"
    }
}

# ---------------------------------------------------------------------------
# Invoke-TVSMUpdateApply (public, exported)
# ---------------------------------------------------------------------------
function Invoke-TVSMUpdateApply {
<#
.SYNOPSIS
    Downloads and applies the latest TVSM bundle update atomically.

.DESCRIPTION
    Performs an atomic update of the TVSM unified bundle:
    1. Checks for updates (optionally including pre-releases)
    2. Downloads the appropriate variant (-full or -core)
    3. Validates SHA256 checksum
    4. Performs atomic swap (safe overwrite pattern)

.PARAMETER Force
    Apply update even if already at the latest version.

.PARAMETER NoVerify
    Skip SHA256 validation (not recommended).

.PARAMETER PreRelease
    Include pre-release versions in the update check.

.EXAMPLE
    Invoke-TVSMUpdateApply
    tvsm update apply

.EXAMPLE
    Invoke-TVSMUpdateApply -PreRelease
    tvsm update apply --pre-release

.EXAMPLE
    Invoke-TVSMUpdateApply -Force
#>
    [CmdletBinding()]
    param(
        [switch]$Force,
        [switch]$NoVerify,
        [bool]$PreRelease = $false
    )

    $isWindows = $IsWindows -or ($PSVersionTable.PSVersion.Major -le 5)  # Fallback detection

    Write-SpectreHost ""
    Write-SpectreHost "[bold cyan]TVSM Update Apply[/]"
    Write-SpectreHost ""

    # Step 1: Check for updates
    try {
        $updateInfo = Test-TVSMUpdateAvailable -IncludePreRelease:$PreRelease
    } catch {
        Write-SpectreHost "[red]Error checking for updates: $($_.Exception.Message)[/]"
        return
    }

    if (-not $updateInfo.UpdateAvailable -and -not $Force) {
        Write-SpectreHost "[yellow]Already at the latest version ($($updateInfo.CurrentVersion)).[/]"
        Write-SpectreHost "[grey]Use -Force to reinstall anyway.[/]"
        return
    }

    if (-not $updateInfo.VariantInfo) {
        Write-SpectreHost "[red]No download information found for variant: $($updateInfo.Variant)[/]"
        return
    }

    $downloadUrl = $updateInfo.VariantInfo.url
    $expectedSha256 = $updateInfo.VariantInfo.sha256
    $targetVersion = $updateInfo.LatestVersion

    Write-SpectreHost "[grey]Current version:[/] $($updateInfo.CurrentVersion)"
    Write-SpectreHost "[grey]Target version: [/] $targetVersion"
    Write-SpectreHost "[grey]Variant:        [/] $($updateInfo.Variant)"
    if ($updateInfo.IsPreRelease) {
        Write-SpectreHost "[grey]Pre-release:    [/] [yellow]Yes[/]"
    }
    Write-SpectreHost "[grey]Download URL:   [/] $downloadUrl"
    Write-SpectreHost ""

    # Confirm with user
    $confirm = Read-SpectreConfirm -Message "Proceed with update to $targetVersion?" -DefaultAnswer $true
    if (-not $confirm) {
        Write-SpectreHost "[yellow]Update cancelled.[/]"
        return
    }

    # Step 2: Set up paths
    $bundleRoot = Resolve-Path (Join-Path $script:TVSMModuleRoot '..' '..')
    $tempDir = Join-Path $env:TEMP "tvs-update-$([guid]::NewGuid())"
    $downloadPath = Join-Path $tempDir "tvs-tools-$($updateInfo.Variant)-$targetVersion.zip"
    $extractDir = Join-Path $tempDir "extracted"

    try {
        # Create temp directory
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

        # Step 3: Download
        Write-SpectreHost "[cyan]Downloading update...[/]"
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -ErrorAction Stop
        } catch {
            throw "Download failed: $_"
        }
        Write-SpectreHost "[green]✓ Download complete[/]"

        # Step 4: SHA256 validation
        if (-not $NoVerify) {
            Write-SpectreHost "[cyan]Validating SHA256 checksum...[/]"
            $actualSha256 = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash.ToLower()
            $expectedSha256 = $expectedSha256.ToLower()

            if ($actualSha256 -ne $expectedSha256) {
                throw "SHA256 validation failed!`nExpected: $expectedSha256`nActual:   $actualSha256"
            }
            Write-SpectreHost "[green]✓ Checksum valid[/]"
        } else {
            Write-SpectreHost "[yellow]⚠ SHA256 validation skipped[/]"
        }

        # Step 5: Extract
        Write-SpectreHost "[cyan]Extracting update...[/]"
        Microsoft.PowerShell.Archive\Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractDir -Force
        Write-SpectreHost "[green]✓ Extraction complete[/]"

        # Step 6: Atomic swap
        Write-SpectreHost "[cyan]Applying update...[/]"

        if ($isWindows) {
            # Windows: rename current to .old, extract new, verify, delete .old
            $oldDir = "$bundleRoot.old"

            # Remove any existing .old directory
            if (Test-Path -LiteralPath $oldDir) {
                Remove-Item -LiteralPath $oldDir -Recurse -Force -ErrorAction Stop
            }

            # Rename current to .old
            Rename-Item -LiteralPath $bundleRoot -NewName (Split-Path -Leaf $oldDir) -ErrorAction Stop

            try {
                # Move extracted content to bundle root
                Move-Item -LiteralPath $extractDir -Destination $bundleRoot -ErrorAction Stop

                # Verify critical files exist
                $criticalFiles = @('tvsm.ps1', 'VERSION.json')
                foreach ($file in $criticalFiles) {
                    if (-not (Test-Path (Join-Path $bundleRoot $file))) {
                        throw "Critical file missing after update: $file"
                    }
                }

                # Success - remove .old
                if (Test-Path -LiteralPath $oldDir) {
                    Remove-Item -LiteralPath $oldDir -Recurse -Force -ErrorAction Stop
                }
                Write-SpectreHost "[green]✓ Update applied successfully[/]"
            } catch {
                # Rollback on failure
                Write-SpectreHost "[yellow]Update failed, rolling back...[/]"
                if (Test-Path -LiteralPath $bundleRoot) {
                    Remove-Item -LiteralPath $bundleRoot -Recurse -Force -ErrorAction SilentlyContinue
                }
                Rename-Item -LiteralPath $oldDir -NewName (Split-Path -Leaf $bundleRoot) -ErrorAction Stop
                throw "Update failed and was rolled back: $_"
            }
        } else {
            # Linux: extract to temp, rename atomically
            # On Linux, we can use a more atomic approach with rename
            $oldDir = "$bundleRoot.old"

            # Remove any existing .old directory
            if (Test-Path -LiteralPath $oldDir) {
                Remove-Item -LiteralPath $oldDir -Recurse -Force -ErrorAction Stop
            }

            # Move current to .old, then move new to current
            Move-Item -LiteralPath $bundleRoot -Destination $oldDir -ErrorAction Stop

            try {
                Move-Item -LiteralPath $extractDir -Destination $bundleRoot -ErrorAction Stop

                # Verify critical files exist
                $criticalFiles = @('tvsm.ps1', 'VERSION.json')
                foreach ($file in $criticalFiles) {
                    if (-not (Test-Path (Join-Path $bundleRoot $file))) {
                        throw "Critical file missing after update: $file"
                    }
                }

                # Success - remove .old
                if (Test-Path -LiteralPath $oldDir) {
                    Remove-Item -LiteralPath $oldDir -Recurse -Force -ErrorAction Stop
                }
                Write-SpectreHost "[green]✓ Update applied successfully[/]"
            } catch {
                # Rollback on failure
                Write-SpectreHost "[yellow]Update failed, rolling back...[/]"
                if (Test-Path -LiteralPath $bundleRoot) {
                    Remove-Item -LiteralPath $bundleRoot -Recurse -Force -ErrorAction SilentlyContinue
                }
                Move-Item -LiteralPath $oldDir -Destination $bundleRoot -ErrorAction Stop
                throw "Update failed and was rolled back: $_"
            }
        }

        Write-SpectreHost ""
        Write-SpectreHost "[bold green]Update complete! TVSM is now at version $targetVersion.[/]"
        Write-SpectreHost "[grey]Please restart tvsm for the changes to take effect.[/]"

    } catch {
        Write-SpectreHost ""
        Write-SpectreHost "[red]Update failed: $($_.Exception.Message)[/]"
        throw
    } finally {
        # Cleanup temp directory
        if (Test-Path -LiteralPath $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
