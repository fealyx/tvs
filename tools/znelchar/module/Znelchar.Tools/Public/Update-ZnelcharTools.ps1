function Update-ZnelcharTools {
<#!
.SYNOPSIS
Checks for and applies znelchar distribution updates from a release manifest.
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [ValidateSet('check', 'install', 'verify')]
        [string]$Operation = 'check',

        [ValidateSet('module', 'core', 'portable')]
        [string]$Variant = 'core',

        [string]$InstallPath,
        [string]$ManifestPath,
        [string]$ManifestUrl,
        [string]$TargetVersion,
        [string]$AssetDirectory,
        [switch]$Force,
        [switch]$SkipChecksum
    )

    function Read-ReleaseManifest {
        param(
            [string]$Path,
            [string]$Url
        )

        if (-not [string]::IsNullOrWhiteSpace($Path)) {
            $resolvedPath = Resolve-UserPath -Path $Path
            if (-not (Test-Path -LiteralPath $resolvedPath)) {
                throw "Manifest file not found: $resolvedPath"
            }
            Write-Stage -Prefix 'update' -Message "Loading manifest from file: $resolvedPath"
            return @{
                Manifest = (Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json -AsHashtable -Depth 30)
                Source = $resolvedPath
                SourceType = 'file'
                SourceDirectory = [System.IO.Path]::GetDirectoryName($resolvedPath)
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($Url)) {
            Write-Stage -Prefix 'update' -Message "Loading manifest from URL: $Url"
            return @{
                Manifest = (Invoke-RestMethod -Uri $Url -Method Get -ErrorAction Stop | ConvertTo-Json -Depth 30 | ConvertFrom-Json -AsHashtable -Depth 30)
                Source = $Url
                SourceType = 'url'
                SourceDirectory = $null
            }
        }

        $toolRoot = Get-ZnelcharToolRoot
        $defaultManifestPath = Join-Path $toolRoot 'dist/znelchar-release-manifest.json'
        if (Test-Path -LiteralPath $defaultManifestPath) {
            Write-Stage -Prefix 'update' -Message "Loading manifest from default path: $defaultManifestPath"
            return @{
                Manifest = (Get-Content -Raw -LiteralPath $defaultManifestPath | ConvertFrom-Json -AsHashtable -Depth 30)
                Source = $defaultManifestPath
                SourceType = 'file'
                SourceDirectory = [System.IO.Path]::GetDirectoryName($defaultManifestPath)
            }
        }

        throw 'No manifest source was provided. Use -ManifestPath or -ManifestUrl.'
    }

    function Get-VariantArtifact {
        param(
            [hashtable]$Manifest,
            [string]$SelectedVariant,
            [string]$DesiredVersion
        )

        if (-not $Manifest.ContainsKey('toolVersion')) {
            throw 'Manifest is missing toolVersion.'
        }

        if (-not $Manifest.ContainsKey('artifacts')) {
            throw 'Manifest is missing artifacts.'
        }

        if (-not [string]::IsNullOrWhiteSpace($DesiredVersion) -and $Manifest.toolVersion -ne $DesiredVersion) {
            throw "Manifest version '$($Manifest.toolVersion)' does not match -TargetVersion '$DesiredVersion'."
        }

        $artifact = @($Manifest.artifacts | Where-Object { $_.variant -eq $SelectedVariant } | Select-Object -First 1)
        if ($artifact.Count -eq 0) {
            throw "No artifact for variant '$SelectedVariant' in release manifest."
        }

        return $artifact[0]
    }

    function Read-InstallState {
        param([string]$ResolvedInstallPath)

        $statePath = Join-Path $ResolvedInstallPath '.znelchar-install.json'
        if (-not (Test-Path -LiteralPath $statePath)) {
            return $null
        }

        return (Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json -AsHashtable -Depth 20)
    }

    function Write-InstallState {
        param(
            [string]$ResolvedInstallPath,
            [string]$SelectedVariant,
            [string]$Version,
            [string]$ArtifactFileName,
            [string]$ManifestSource
        )

        $state = [ordered]@{
            toolName = 'znelchar'
            variant = $SelectedVariant
            version = $Version
            artifactFileName = $ArtifactFileName
            installedAtUtc = [DateTime]::UtcNow.ToString('o')
            manifestSource = $ManifestSource
        }

        $statePath = Join-Path $ResolvedInstallPath '.znelchar-install.json'
        $stateJson = $state | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($statePath, $stateJson, [System.Text.UTF8Encoding]::new($false))
        return $statePath
    }

    function Resolve-ArchivePath {
        param(
            [hashtable]$Artifact,
            [string]$LocalAssetDirectory,
            [string]$ManifestSourceType,
            [string]$ManifestSourceDirectory
        )

        if (-not [string]::IsNullOrWhiteSpace($LocalAssetDirectory)) {
            $resolvedAssetDirectory = Resolve-UserPath -Path $LocalAssetDirectory
            $candidate = Join-Path $resolvedAssetDirectory $Artifact.fileName
            if (-not (Test-Path -LiteralPath $candidate)) {
                throw "Artifact not found in -AssetDirectory: $candidate"
            }
            return @{ ArchivePath = $candidate; IsTemporary = $false }
        }

        if ($ManifestSourceType -eq 'file' -and -not [string]::IsNullOrWhiteSpace($ManifestSourceDirectory)) {
            $sibling = Join-Path $ManifestSourceDirectory $Artifact.fileName
            if (Test-Path -LiteralPath $sibling) {
                return @{ ArchivePath = $sibling; IsTemporary = $false }
            }
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$Artifact.downloadUrl)) {
            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N') + '-' + $Artifact.fileName)
            Write-Stage -Prefix 'update' -Message "Downloading artifact from $($Artifact.downloadUrl)"
            Invoke-WebRequest -Uri $Artifact.downloadUrl -OutFile $tempFile -ErrorAction Stop
            return @{ ArchivePath = $tempFile; IsTemporary = $true }
        }

        throw 'Unable to resolve artifact archive path. Provide -AssetDirectory, or ensure downloadUrl exists in the manifest.'
    }

    function Assert-Checksum {
        param(
            [string]$ArchivePath,
            [string]$ExpectedSha,
            [switch]$Bypass
        )

        if ($Bypass) {
            return
        }

        if ([string]::IsNullOrWhiteSpace($ExpectedSha)) {
            throw 'Manifest artifact does not include sha256 and checksum verification was not skipped.'
        }

        $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $ArchivePath).Hash.ToLowerInvariant()
        if ($actual -ne ([string]$ExpectedSha).ToLowerInvariant()) {
            throw "Checksum mismatch for archive '$ArchivePath'."
        }
    }

    function Get-PayloadDirectoryName {
        param([string]$SelectedVariant)

        if ($SelectedVariant -eq 'module') {
            return 'Znelchar.Tools'
        }

        return 'znelchar-tools'
    }

    function Install-ArchivePayload {
        param(
            [string]$ArchivePath,
            [string]$DestinationPath,
            [string]$SelectedVariant,
            [switch]$AllowOverwrite,
            [string]$Version,
            [string]$ArtifactFileName,
            [string]$ManifestSource
        )

        $resolvedDestinationPath = Resolve-UserPath -Path $DestinationPath
        $destinationParent = Split-Path -Parent $resolvedDestinationPath
        if (-not [string]::IsNullOrWhiteSpace($destinationParent) -and -not (Test-Path -LiteralPath $destinationParent)) {
            New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        }

        $destinationExisted = Test-Path -LiteralPath $resolvedDestinationPath
        if ($destinationExisted -and -not $AllowOverwrite) {
            throw "InstallPath already exists. Use -Force to overwrite: $resolvedDestinationPath"
        }

        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
        $extractRoot = Join-Path $tempRoot 'extract'
        $backupPath = "$resolvedDestinationPath.backup.$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))"
        $destinationBackedUp = $false
        $statePath = $null

        try {
            New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
            Expand-Archive -LiteralPath $ArchivePath -DestinationPath $extractRoot -Force

            $payloadDirectoryName = Get-PayloadDirectoryName -SelectedVariant $SelectedVariant
            $payloadDirectory = Join-Path $extractRoot $payloadDirectoryName
            if (-not (Test-Path -LiteralPath $payloadDirectory)) {
                throw "Expected payload directory not found in archive: $payloadDirectoryName"
            }

            if (Test-Path -LiteralPath $resolvedDestinationPath) {
                Move-Item -LiteralPath $resolvedDestinationPath -Destination $backupPath -Force
                $destinationBackedUp = $true
            }

            Copy-Item -LiteralPath $payloadDirectory -Destination $resolvedDestinationPath -Recurse -Force
            $statePath = Write-InstallState -ResolvedInstallPath $resolvedDestinationPath -SelectedVariant $SelectedVariant -Version $Version -ArtifactFileName $ArtifactFileName -ManifestSource $ManifestSource

            if ($destinationBackedUp -and (Test-Path -LiteralPath $backupPath)) {
                Remove-Item -LiteralPath $backupPath -Recurse -Force
            }

            return [ordered]@{
                installPath = $resolvedDestinationPath
                stateFile = $statePath
            }
        }
        catch {
            if ($destinationBackedUp -and (Test-Path -LiteralPath $backupPath)) {
                if (Test-Path -LiteralPath $resolvedDestinationPath) {
                    Remove-Item -LiteralPath $resolvedDestinationPath -Recurse -Force
                }
                Move-Item -LiteralPath $backupPath -Destination $resolvedDestinationPath -Force
            }
            elseif (-not $destinationExisted -and (Test-Path -LiteralPath $resolvedDestinationPath)) {
                # Clean up a partial install directory only when it did not exist before this install attempt.
                Remove-Item -LiteralPath $resolvedDestinationPath -Recurse -Force
            }

            throw
        }
        finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }

    function Verify-Installation {
        param(
            [string]$DestinationPath,
            [string]$SelectedVariant,
            [string]$ExpectedVersion
        )

        $resolvedDestinationPath = Resolve-UserPath -Path $DestinationPath
        $checks = [ordered]@{}

        $checks.installPathExists = Test-Path -LiteralPath $resolvedDestinationPath
        $checks.stateFileExists = Test-Path -LiteralPath (Join-Path $resolvedDestinationPath '.znelchar-install.json')

        if ($SelectedVariant -eq 'module') {
            $checks.expectedManifestExists = Test-Path -LiteralPath (Join-Path $resolvedDestinationPath 'Znelchar.Tools.psd1')
        }
        else {
            $checks.expectedScriptsDirExists = Test-Path -LiteralPath (Join-Path $resolvedDestinationPath 'scripts')
            $checks.expectedSchemasDirExists = Test-Path -LiteralPath (Join-Path $resolvedDestinationPath 'schemas')
        }

        $state = Read-InstallState -ResolvedInstallPath $resolvedDestinationPath
        $checks.stateVariantMatches = $false
        $checks.stateVersionMatches = $false
        if ($null -ne $state) {
            $checks.stateVariantMatches = (($state.variant) -eq $SelectedVariant)
            $checks.stateVersionMatches = (($state.version) -eq $ExpectedVersion)
        }

        $verified = $true
        foreach ($value in $checks.Values) {
            if (-not $value) {
                $verified = $false
                break
            }
        }

        return [ordered]@{
            verified = $verified
            checks = $checks
            state = $state
            installPath = $resolvedDestinationPath
        }
    }

    $manifestEnvelope = Read-ReleaseManifest -Path $ManifestPath -Url $ManifestUrl
    $manifest = $manifestEnvelope.Manifest
    $artifact = Get-VariantArtifact -Manifest $manifest -SelectedVariant $Variant -DesiredVersion $TargetVersion

    $currentVersion = $null
    if (-not [string]::IsNullOrWhiteSpace($InstallPath)) {
        $resolvedInstallPath = Resolve-UserPath -Path $InstallPath
        $state = Read-InstallState -ResolvedInstallPath $resolvedInstallPath
        if ($null -ne $state -and $state.ContainsKey('version')) {
            $currentVersion = [string]$state.version
        }
    }

    if ($Operation -eq 'check') {
        return [ordered]@{
            operation = 'check'
            variant = $Variant
            manifestSource = $manifestEnvelope.Source
            currentVersion = $currentVersion
            latestVersion = [string]$manifest.toolVersion
            targetVersion = if ([string]::IsNullOrWhiteSpace($TargetVersion)) { [string]$manifest.toolVersion } else { $TargetVersion }
            updateAvailable = ($currentVersion -ne [string]$manifest.toolVersion)
            artifact = $artifact
        }
    }

    if ([string]::IsNullOrWhiteSpace($InstallPath)) {
        throw '-InstallPath is required for install and verify operations.'
    }

    if ($Operation -eq 'install') {
        if (-not $PSCmdlet.ShouldProcess($InstallPath, "Install $Variant update")) {
            return
        }

        $archiveInfo = Resolve-ArchivePath -Artifact $artifact -LocalAssetDirectory $AssetDirectory -ManifestSourceType $manifestEnvelope.SourceType -ManifestSourceDirectory $manifestEnvelope.SourceDirectory
        try {
            Assert-Checksum -ArchivePath $archiveInfo.ArchivePath -ExpectedSha ([string]$artifact.sha256) -Bypass:$SkipChecksum
            $installResult = Install-ArchivePayload -ArchivePath $archiveInfo.ArchivePath -DestinationPath $InstallPath -SelectedVariant $Variant -AllowOverwrite:$Force -Version ([string]$manifest.toolVersion) -ArtifactFileName ([string]$artifact.fileName) -ManifestSource $manifestEnvelope.Source
            $verification = Verify-Installation -DestinationPath $InstallPath -SelectedVariant $Variant -ExpectedVersion ([string]$manifest.toolVersion)

            return [ordered]@{
                operation = 'install'
                variant = $Variant
                manifestSource = $manifestEnvelope.Source
                installedVersion = [string]$manifest.toolVersion
                archive = [string]$artifact.fileName
                install = $installResult
                verification = $verification
            }
        }
        finally {
            if ($archiveInfo.IsTemporary -and (Test-Path -LiteralPath $archiveInfo.ArchivePath)) {
                Remove-Item -LiteralPath $archiveInfo.ArchivePath -Force
            }
        }
    }

    if ($Operation -eq 'verify') {
        return [ordered]@{
            operation = 'verify'
            variant = $Variant
            manifestSource = $manifestEnvelope.Source
            expectedVersion = [string]$manifest.toolVersion
            verification = Verify-Installation -DestinationPath $InstallPath -SelectedVariant $Variant -ExpectedVersion ([string]$manifest.toolVersion)
        }
    }
}
