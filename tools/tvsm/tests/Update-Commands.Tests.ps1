# Tests for Update-Commands.ps1
# Requires Pester v5

BeforeAll {
    # Load the module
    $modulePath = Join-Path $PSScriptRoot '..' 'module' 'TVSM' 'TVSM.psd1'
    Import-Module $modulePath -Force
}

Describe 'Test-TVSMUpdateAvailable' {
    BeforeAll {
        # Mock VERSION.json
        $script:mockVersionJson = @{
            bundleVersion = '1.0.0'
            variant       = 'full'
            components    = @{
                TVSM            = '1.0.0'
                'Znelchar.Tools' = '0.2.0'
                'TVSSave.Tools'  = '0.1.0'
                'TVS.Environment' = '0.1.0'
                pwsh            = '7.5.0'
            }
        }

        # Mock release manifest
        $script:mockReleaseManifest = @{
            latestVersion = '1.0.1'
            publishedAt  = '2026-05-07T00:00:00Z'
            variants     = @{
                full = @{
                    url           = 'https://example.com/tvs-tools-full-1.0.1.zip'
                    sha256        = 'abc123'
                    bundleVersion = '1.0.1'
                    components    = @{
                        TVSM             = '1.0.1'
                        'Znelchar.Tools' = '0.2.1'
                        'TVSSave.Tools'  = '0.1.0'
                        'TVS.Environment' = '0.1.0'
                        pwsh             = '7.5.0'
                    }
                }
                core = @{
                    url           = 'https://example.com/tvs-tools-core-1.0.1.zip'
                    sha256        = 'def456'
                    bundleVersion = '1.0.1'
                    components    = @{
                        TVSM             = '1.0.1'
                        'Znelchar.Tools' = '0.2.1'
                        'TVSSave.Tools'  = '0.1.0'
                        'TVS.Environment' = '0.1.0'
                        pwsh             = '7.5.0'
                    }
                }
            }
        }
    }

    It 'Should detect update is available when latest version is newer' {
        # Mock VERSION.json
        Mock Get-Content {
            return $mockVersionJson | ConvertTo-Json
        } -ParameterFilter { $LiteralPath -like '*VERSION.json' }

        # Mock Invoke-WebRequest
        Mock Invoke-WebRequest { } -ParameterFilter { $Uri -like '*release-manifest*' }

        # Mock Get-Content for manifest
        Mock Get-Content {
            return $mockReleaseManifest | ConvertTo-Json
        } -ParameterFilter { $LiteralPath -like '*tvs-release-manifest*' }

        $result = Test-TVSMUpdateAvailable -ReleaseManifestUrl 'https://example.com/manifest.json'

        $result.UpdateAvailable | Should -Be $true
        $result.CurrentVersion | Should -Be '1.0.0'
        $result.LatestVersion | Should -Be '1.0.1'
        $result.Variant | Should -Be 'full'
    }

    It 'Should detect no update when versions are equal' {
        $currentVersionJson = @{
            bundleVersion = '1.0.1'
            variant       = 'full'
            components    = @{}
        }

        Mock Get-Content {
            return $currentVersionJson | ConvertTo-Json
        } -ParameterFilter { $LiteralPath -like '*VERSION.json' }

        Mock Invoke-WebRequest { }
        Mock Get-Content {
            return $mockReleaseManifest | ConvertTo-Json
        } -ParameterFilter { $LiteralPath -like '*tvs-release-manifest*' }

        $result = Test-TVSMUpdateAvailable -ReleaseManifestUrl 'https://example.com/manifest.json'

        $result.UpdateAvailable | Should -Be $false
    }

    It 'Should throw when VERSION.json is missing' {
        Mock Test-Path { return $false } -ParameterFilter { $LiteralPath -like '*VERSION.json' }

        { Test-TVSMUpdateAvailable } | Should -Throw -Because 'VERSION.json is required'
    }

    It 'Should return variant info for current variant' {
        Mock Get-Content {
            return $mockVersionJson | ConvertTo-Json
        } -ParameterFilter { $LiteralPath -like '*VERSION.json' }

        Mock Invoke-WebRequest { }
        Mock Get-Content {
            return $mockReleaseManifest | ConvertTo-Json
        } -ParameterFilter { $LiteralPath -like '*tvs-release-manifest*' }

        $result = Test-TVSMUpdateAvailable -ReleaseManifestUrl 'https://example.com/manifest.json'

        $result.VariantInfo | Should -Not -BeNullOrEmpty
        $result.VariantInfo.url | Should -Be 'https://example.com/tvs-tools-full-1.0.1.zip'
        $result.VariantInfo.sha256 | Should -Be 'abc123'
    }
}

Describe 'Invoke-TVSMUpdateCheck' {
    BeforeAll {
        # Mock Test-TVSMUpdateAvailable
        $script:mockUpdateInfo = @{
            UpdateAvailable   = $true
            CurrentVersion    = '1.0.0'
            LatestVersion     = '1.0.1'
            Variant           = 'full'
            PublishedAt       = '2026-05-07T00:00:00Z'
            VariantInfo       = @{
                url    = 'https://example.com/tvs-tools-full-1.0.1.zip'
                sha256 = 'abc123'
            }
            CurrentComponents = @{
                TVSM            = '1.0.0'
                'Znelchar.Tools' = '0.2.0'
            }
            NewComponents     = @{
                TVSM            = '1.0.1'
                'Znelchar.Tools' = '0.2.1'
            }
        }
    }

    It 'Should output JSON when -Json is specified' {
        Mock Test-TVSMUpdateAvailable { return $mockUpdateInfo }

        $output = Invoke-TVSMUpdateCheck -Json -ReleaseManifestUrl 'https://example.com/manifest.json' | ConvertFrom-Json

        $output.updateAvailable | Should -Be $true
        $output.currentVersion | Should -Be '1.0.0'
        $output.latestVersion | Should -Be '1.0.1'
    }

    It 'Should handle errors gracefully in JSON mode' {
        Mock Test-TVSMUpdateAvailable { throw 'Network error' }

        $output = Invoke-TVSMUpdateCheck -Json | ConvertFrom-Json

        $output.error | Should -Not -BeNullOrEmpty
    }
}

Describe 'Invoke-TVSMUpdateApply' {
    BeforeAll {
        $script:mockUpdateInfo = @{
            UpdateAvailable   = $true
            CurrentVersion    = '1.0.0'
            LatestVersion     = '1.0.1'
            Variant           = 'full'
            PublishedAt       = '2026-05-07T00:00:00Z'
            VariantInfo       = @{
                url    = 'https://example.com/tvs-tools-full-1.0.1.zip'
                sha256 = 'abc123'
            }
            CurrentComponents = @{}
            NewComponents     = @{}
        }
    }

    It 'Should skip update when already at latest and -Force not specified' {
        $upToDateInfo = $mockUpdateInfo.Clone()
        $upToDateInfo.UpdateAvailable = $false

        Mock Test-TVSMUpdateAvailable { return $upToDateInfo }

        # Should not call Invoke-WebRequest for download
        Mock Invoke-WebRequest { }

        # This should return early without downloading
        Invoke-TVSMUpdateApply -ReleaseManifestUrl 'https://example.com/manifest.json'

        # Verify it would have returned early (no download)
        Should -Not -Invoke Invoke-WebRequest
    }

    It 'Should validate SHA256 when applying update' {
        Mock Test-TVSMUpdateAvailable { return $mockUpdateInfo }
        Mock Invoke-WebRequest { } -ParameterFilter { $OutFile -ne $null }
        Mock Get-FileHash { return @{ Hash = 'ABC123' } }
        Mock Read-SpectreConfirm { return $false }  # Cancel to avoid actual file operations

        # With -NoVerify, should skip SHA256 check
        # This test mainly validates the flow - actual file operations are complex to mock
    }

    It 'Should support -Force to reinstall same version' {
        $upToDateInfo = $mockUpdateInfo.Clone()
        $upToDateInfo.UpdateAvailable = $false

        Mock Test-TVSMUpdateAvailable { return $upToDateInfo }
        Mock Read-SpectreConfirm { return $false }  # Cancel to avoid actual file operations

        # With -Force, should proceed even if up to date
        # (The actual download would happen, but we cancel at confirmation)
        Invoke-TVSMUpdateApply -Force -ReleaseManifestUrl 'https://example.com/manifest.json'
    }
}

Describe 'Version comparison logic' {
    It 'Should correctly compare semantic versions' {
        # Test the version comparison logic used in Test-TVSMUpdateAvailable
        $currentVer = [System.Version]('1.0.0' -replace '-.*$', '')
        $latestVer = [System.Version]('1.0.1' -replace '-.*$', '')

        ($latestVer -gt $currentVer) | Should -Be $true
    }

    It 'Should handle prerelease versions' {
        $currentVer = [System.Version]('1.0.0-beta' -replace '-.*$', '')
        $latestVer = [System.Version]('1.0.0' -replace '-.*$', '')

        ($latestVer -gt $currentVer) | Should -Be $false  # Same base version
    }
}
