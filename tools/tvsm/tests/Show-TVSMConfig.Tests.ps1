#Requires -Module Pester

Describe 'Show-TVSMConfig' {
    BeforeAll {
        $repoRoot   = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..')
        $tvsmModule = Join-Path $repoRoot 'tools' 'tvsm' 'module' 'TVSM' 'TVSM.psd1'
        $tvseModule = Join-Path $repoRoot 'tools' 'tvs-environment' 'module' 'TVS.Environment'
        if (Test-Path -LiteralPath $tvseModule) {
            $parentDir = Split-Path -Parent $tvseModule
            $env:PSModulePath = $parentDir + [IO.Path]::PathSeparator + $env:PSModulePath
        }
        Import-Module $tvsmModule -Force -ErrorAction Stop
    }

    BeforeEach {
        $script:fakeEnv = [pscustomobject]@{
            gameDir                      = 'C:\Games\TVS'
            playerDataDir                = 'C:\Games\TVS\playerdata'
            characterWorkDir             = 'C:\work\characters'
            modWorkDir                   = 'C:\work\mods'
            communityRegistryUrl         = 'https://example.com/registry.json'
            communityRegistryCacheTtlMinutes = '60'
            pluginsDir                   = 'C:\Games\TVS\BepInEx\plugins'
        }

        Mock Get-TVSEnvironment  { $script:fakeEnv } -ModuleName TVSM
        Mock Write-SpectreHost   {} -ModuleName TVSM
        Mock Format-SpectreTable {} -ModuleName TVSM
    }

    Context 'JSON output' {
        It 'Returns parseable JSON' {
            $result = Show-TVSMConfig -Json
            { $result | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'JSON output contains all canonical keys' {
            $result = Show-TVSMConfig -Json | ConvertFrom-Json
            $result.gameDir              | Should -Be 'C:\Games\TVS'
            $result.modWorkDir           | Should -Be 'C:\work\mods'
            $result.communityRegistryUrl | Should -Be 'https://example.com/registry.json'
        }
    }

    Context 'Table output — all keys set' {
        It 'Does not throw with fully populated environment' {
            { Show-TVSMConfig } | Should -Not -Throw
        }

        It 'Calls Format-SpectreTable exactly once' {
            Show-TVSMConfig
            Assert-MockCalled Format-SpectreTable -ModuleName TVSM -Times 1
        }
    }

    Context 'Table output — partial keys' {
        BeforeEach {
            $script:fakeEnv = [pscustomobject]@{
                gameDir                      = 'C:\Games\TVS'
                playerDataDir                = $null
                characterWorkDir             = $null
                modWorkDir                   = $null
                communityRegistryUrl         = $null
                communityRegistryCacheTtlMinutes = $null
                pluginsDir                   = $null
            }
        }

        It 'Does not throw when keys are null' {
            { Show-TVSMConfig } | Should -Not -Throw
        }

        It 'Renders table (even with partial data)' {
            Show-TVSMConfig
            Assert-MockCalled Format-SpectreTable -ModuleName TVSM -Times 1
        }
    }

    Context 'Profile parameter forwarding' {
        It 'Passes Profile to Get-TVSEnvironment when specified' {
            Show-TVSMConfig -Profile 'dev'

            Assert-MockCalled Get-TVSEnvironment -ModuleName TVSM -Times 1 -ParameterFilter {
                $Profile -eq 'dev'
            }
        }
    }
}
