#Requires -Module Pester

Describe 'Invoke-TVSMModRollback' {
    BeforeAll {
        # Load the TVSM module from the dev-repo layout
        $repoRoot   = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..')
        $tvsmModule = Join-Path $repoRoot 'tools' 'tvsm' 'module' 'TVSM' 'TVSM.psd1'
        $tvseModule = Join-Path $repoRoot 'tools' 'tvs-environment' 'module' 'TVS.Environment'

        # Inject TVS.Environment onto PSModulePath so TVSM can find it
        if (Test-Path -LiteralPath $tvseModule) {
            $parentDir = Split-Path -Parent $tvseModule
            $env:PSModulePath = $parentDir + [IO.Path]::PathSeparator + $env:PSModulePath
        }
        Import-Module $tvsmModule -Force -ErrorAction Stop
    }

    BeforeEach {
        # Default profile data used by most tests
        $script:profileData = @{
            schemaVersion  = 1
            name           = 'default'
            bepInExVersion = '5.4.23.2'
            mods           = @{
                TVSLib = @{ version = '1.2.3'; enabled = $true; installLayout = 'plugins-dll' }
            }
            snapshots      = @(
                @{
                    id             = '2026-04-30T12:00:00.0000000+00:00'
                    label          = 'before-install-SomeMod'
                    bepInExVersion = '5.4.23.2'
                    mods           = @{
                        TVSLib = @{ version = '1.1.0'; enabled = $true; installLayout = 'plugins-dll' }
                    }
                }
            )
        }

        # Default environment
        Mock Get-TVSEnvironment { [pscustomobject]@{
            modWorkDir = 'C:\fake\modWorkDir'
            gameDir    = 'C:\fake\gameDir'
        }} -ModuleName TVSM

        Mock Get-TVSActiveProfileName { 'default' } -ModuleName TVSM
        Mock Read-TVSModProfile       { $script:profileData } -ModuleName TVSM
        Mock Write-TVSModProfile      {} -ModuleName TVSM
        Mock Invoke-TVSMModApply      {} -ModuleName TVSM
        Mock Write-SpectreHost        {} -ModuleName TVSM
    }

    Context 'Happy path' {
        It 'Restores bepInExVersion and mods from the first snapshot' {
            Invoke-TVSMModRollback -Yes

            Assert-MockCalled Write-TVSModProfile -ModuleName TVSM -Times 1 -ParameterFilter {
                $ProfileData['bepInExVersion'] -eq '5.4.23.2' -and
                $ProfileData['mods']['TVSLib']['version'] -eq '1.1.0'
            }
        }

        It 'Pops the consumed snapshot from the array' {
            Invoke-TVSMModRollback -Yes

            Assert-MockCalled Write-TVSModProfile -ModuleName TVSM -Times 1 -ParameterFilter {
                @($ProfileData['snapshots']).Count -eq 0
            }
        }

        It 'Calls Invoke-TVSMModApply after writing the restored profile' {
            Invoke-TVSMModRollback -Yes

            Assert-MockCalled Invoke-TVSMModApply -ModuleName TVSM -Times 1
        }

        It 'Passes the profile name to Invoke-TVSMModApply' {
            Invoke-TVSMModRollback -Yes

            Assert-MockCalled Invoke-TVSMModApply -ModuleName TVSM -Times 1 -ParameterFilter {
                $Profile -eq 'default'
            }
        }
    }

    Context 'Multiple snapshots' {
        BeforeEach {
            $script:profileData['snapshots'] = @(
                @{ id = '2026-05-01T10:00:00.0000000+00:00'; label = 'snap2';
                   bepInExVersion = '5.4.23.2'; mods = @{ TVSLib = @{ version = '1.2.0' } } },
                @{ id = '2026-04-30T12:00:00.0000000+00:00'; label = 'snap1';
                   bepInExVersion = '5.4.22.0'; mods = @{ TVSLib = @{ version = '1.1.0' } } }
            )
        }

        It 'Pops only the first (most recent) snapshot' {
            Invoke-TVSMModRollback -Yes

            Assert-MockCalled Write-TVSModProfile -ModuleName TVSM -Times 1 -ParameterFilter {
                # After pop, one snapshot should remain
                @($ProfileData['snapshots']).Count -eq 1 -and
                $ProfileData['snapshots'][0]['label'] -eq 'snap1'
            }
        }

        It 'Restores state from the most recent snapshot, not an older one' {
            Invoke-TVSMModRollback -Yes

            Assert-MockCalled Write-TVSModProfile -ModuleName TVSM -Times 1 -ParameterFilter {
                $ProfileData['mods']['TVSLib']['version'] -eq '1.2.0'
            }
        }
    }

    Context 'Error cases' {
        It 'Throws when profile has no snapshots' {
            $script:profileData['snapshots'] = @()

            { Invoke-TVSMModRollback -Yes } | Should -Throw -ErrorId '*'
        }

        It 'Throws when snapshots key is missing entirely' {
            $script:profileData.Remove('snapshots')

            { Invoke-TVSMModRollback -Yes } | Should -Throw
        }

        It 'Throws when profile is not found' {
            Mock Read-TVSModProfile { $null } -ModuleName TVSM

            { Invoke-TVSMModRollback -Yes } | Should -Throw
        }
    }

    Context 'Dev links isolation' {
        It 'Does not call Write-TVSDevLinks (dev links are untouched by rollback)' {
            Mock Write-TVSDevLinks {} -ModuleName TVSM

            Invoke-TVSMModRollback -Yes

            Assert-MockCalled Write-TVSDevLinks -ModuleName TVSM -Times 0
        }
    }
}
