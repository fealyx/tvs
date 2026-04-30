#Requires -Module Pester

BeforeAll {
    $modulePsd1 = Resolve-Path (Join-Path $PSScriptRoot '../module/TVS.Environment/TVS.Environment.psd1')
    Import-Module $modulePsd1.Path -Force
}

Describe 'Resolve-TVSProfileKey priority chain' {
    InModuleScope 'TVS.Environment' {

        BeforeAll {
            # Baseline: every helper returns null / empty so tests start from a clean slate.
            # Individual Context blocks override only what they need.
            Mock Find-TVSLocalConfig      { $null }
            Mock Read-TVSProfile          { @{} }
            Mock Read-TVSLegacyDotEnv     { @{} }
            Mock Read-TVSLegacyGameDirProps { $null }
            Mock Get-TVSSteamRegistryDir  { $null }
        }

        # -----------------------------------------------------------------------
        Context 'Level 7 – null fallback' {

            It 'returns $null when no source provides the key' {
                Resolve-TVSProfileKey -Key 'gameDir' | Should -BeNullOrEmpty
            }

            It 'returns $null for a non-gameDir key when no source provides it' {
                Resolve-TVSProfileKey -Key 'characterWorkDir' | Should -BeNullOrEmpty
            }

            It 'returns $null for playerDataDir when nothing is configured' {
                Resolve-TVSProfileKey -Key 'playerDataDir' | Should -BeNullOrEmpty
            }
        }

        # -----------------------------------------------------------------------
        Context 'Level 1 – ExplicitValue takes precedence over all sources' {

            BeforeAll {
                Mock Find-TVSLocalConfig  { @{ gameDir = 'C:\Local' } }
                Mock Read-TVSProfile      { @{ gameDir = 'C:\Profile' } }
                Mock Read-TVSLegacyDotEnv { @{ gameDir = 'C:\Env' } }
                Mock Read-TVSLegacyGameDirProps { @{ gameDir = 'C:\Props' } }
                Mock Get-TVSSteamRegistryDir { 'C:\Steam\TVS' }
            }

            It 'returns the explicit value when all other sources are also populated' {
                Resolve-TVSProfileKey -Key 'gameDir' -ExplicitValue 'D:\Explicit' |
                    Should -Be 'D:\Explicit'
            }

            It 'explicit value is returned even when local config has the key' {
                Resolve-TVSProfileKey -Key 'gameDir' -ExplicitValue 'D:\Override' |
                    Should -Be 'D:\Override'
            }
        }

        # -----------------------------------------------------------------------
        Context 'Level 2 – local .tvs-config.json' {

            It 'returns the local config value when present' {
                Mock Find-TVSLocalConfig { @{ gameDir = 'C:\Local' } }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Local'
            }

            It 'local config takes precedence over user profile' {
                Mock Find-TVSLocalConfig { @{ gameDir = 'C:\Local' } }
                Mock Read-TVSProfile     { @{ gameDir = 'C:\Profile' } }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Local'
            }

            It 'local config takes precedence over legacy .env' {
                Mock Find-TVSLocalConfig  { @{ gameDir = 'C:\Local' } }
                Mock Read-TVSLegacyDotEnv { @{ gameDir = 'C:\Env' } }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Local'
            }

            It 'falls through when local config does not contain the requested key' {
                Mock Find-TVSLocalConfig { @{ modWorkDir = 'C:\LocalMods' } }
                Mock Read-TVSProfile     { @{ gameDir = 'C:\Profile' } }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Profile'
            }

            It 'falls through when local config value is empty string' {
                Mock Find-TVSLocalConfig { @{ gameDir = '' } }
                Mock Read-TVSProfile     { @{ gameDir = 'C:\Profile' } }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Profile'
            }
        }

        # -----------------------------------------------------------------------
        Context 'Level 3 – user profile (~/.tvs/config.json)' {

            It 'returns user profile value when present' {
                Mock Read-TVSProfile { @{ characterWorkDir = 'D:\Chars' } }
                Resolve-TVSProfileKey -Key 'characterWorkDir' | Should -Be 'D:\Chars'
            }

            It 'user profile takes precedence over legacy .env' {
                Mock Read-TVSProfile      { @{ gameDir = 'C:\Profile' } }
                Mock Read-TVSLegacyDotEnv { @{ gameDir = 'C:\Env' } }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Profile'
            }

            It 'user profile takes precedence over GameDir.props' {
                Mock Read-TVSProfile           { @{ gameDir = 'C:\Profile' } }
                Mock Read-TVSLegacyGameDirProps { @{ gameDir = 'C:\Props' } }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Profile'
            }

            It 'user profile takes precedence over Steam registry' {
                Mock Read-TVSProfile        { @{ gameDir = 'C:\Profile' } }
                Mock Get-TVSSteamRegistryDir { 'C:\Steam\TVS' }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Profile'
            }

            It 'falls through when profile value is whitespace' {
                Mock Read-TVSProfile      { @{ gameDir = '   ' } }
                Mock Read-TVSLegacyDotEnv { @{ gameDir = 'C:\Env' } }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Env'
            }
        }

        # -----------------------------------------------------------------------
        Context 'Level 4 – legacy .env (read-only shim)' {

            It 'returns .env value for gameDir when profile is empty' {
                Mock Read-TVSLegacyDotEnv { @{ gameDir = 'C:\Env' } }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Env'
            }

            It 'returns .env value for playerDataDir' {
                Mock Read-TVSLegacyDotEnv { @{ playerDataDir = 'C:\AppData\TVS' } }
                Resolve-TVSProfileKey -Key 'playerDataDir' | Should -Be 'C:\AppData\TVS'
            }

            It '.env takes precedence over GameDir.props for gameDir' {
                Mock Read-TVSLegacyDotEnv     { @{ gameDir = 'C:\Env' } }
                Mock Read-TVSLegacyGameDirProps { @{ gameDir = 'C:\Props' } }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Env'
            }

            It '.env takes precedence over Steam registry for gameDir' {
                Mock Read-TVSLegacyDotEnv   { @{ gameDir = 'C:\Env' } }
                Mock Get-TVSSteamRegistryDir { 'C:\Steam\TVS' }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Env'
            }
        }

        # -----------------------------------------------------------------------
        Context 'Level 5 – legacy GameDir.props (gameDir only)' {

            It 'returns GameDir.props value for gameDir' {
                Mock Read-TVSLegacyGameDirProps { @{ gameDir = 'C:\Props' } }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Props'
            }

            It 'GameDir.props does NOT apply to characterWorkDir' {
                Mock Read-TVSLegacyGameDirProps { @{ gameDir = 'C:\Props' } }
                Resolve-TVSProfileKey -Key 'characterWorkDir' | Should -BeNullOrEmpty
            }

            It 'GameDir.props does NOT apply to playerDataDir' {
                Mock Read-TVSLegacyGameDirProps { @{ gameDir = 'C:\Props' } }
                Resolve-TVSProfileKey -Key 'playerDataDir' | Should -BeNullOrEmpty
            }

            It 'GameDir.props does NOT apply to modWorkDir' {
                Mock Read-TVSLegacyGameDirProps { @{ gameDir = 'C:\Props' } }
                Resolve-TVSProfileKey -Key 'modWorkDir' | Should -BeNullOrEmpty
            }

            It 'GameDir.props takes precedence over Steam registry' {
                Mock Read-TVSLegacyGameDirProps { @{ gameDir = 'C:\Props' } }
                Mock Get-TVSSteamRegistryDir    { 'C:\Steam\TVS' }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Props'
            }
        }

        # -----------------------------------------------------------------------
        Context 'Level 6 – Steam registry (gameDir only)' {

            It 'returns Steam registry path for gameDir' {
                Mock Get-TVSSteamRegistryDir { 'C:\Steam\TVS' }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Steam\TVS'
            }

            It 'Steam registry does NOT apply to playerDataDir' {
                Mock Get-TVSSteamRegistryDir { 'C:\Steam\TVS' }
                Resolve-TVSProfileKey -Key 'playerDataDir' | Should -BeNullOrEmpty
            }

            It 'Steam registry does NOT apply to characterWorkDir' {
                Mock Get-TVSSteamRegistryDir { 'C:\Steam\TVS' }
                Resolve-TVSProfileKey -Key 'characterWorkDir' | Should -BeNullOrEmpty
            }

            It 'Steam registry does NOT apply to modWorkDir' {
                Mock Get-TVSSteamRegistryDir { 'C:\Steam\TVS' }
                Resolve-TVSProfileKey -Key 'modWorkDir' | Should -BeNullOrEmpty
            }
        }

        # -----------------------------------------------------------------------
        Context 'Profile parameter pass-through' {

            It 'passes the Profile parameter to Read-TVSProfile' {
                Mock Read-TVSProfile { @{ gameDir = 'C:\DevGame' } }
                Resolve-TVSProfileKey -Key 'gameDir' -Profile 'dev' | Should -Be 'C:\DevGame'
                Should -Invoke Read-TVSProfile -ParameterFilter { $Profile -eq 'dev' } -Times 1
            }

            It 'does not pass Profile to the gameDir-only legacy sources' {
                # GameDir.props and registry have no concept of profiles; they are always called without filtering
                Mock Read-TVSLegacyGameDirProps { @{ gameDir = 'C:\Props' } }
                $result = Resolve-TVSProfileKey -Key 'gameDir' -Profile 'dev'
                $result | Should -Be 'C:\Props'
            }
        }

        # -----------------------------------------------------------------------
        Context 'Priority chain completeness' {

            It 'walks all levels when each level is empty until one provides a value' {
                # Only the registry has a value — verifies the full chain is walked for gameDir
                Mock Get-TVSSteamRegistryDir { 'C:\Steam\TVS' }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Steam\TVS'
            }

            It 'stops at the first populated level and does not call lower-priority helpers' {
                Mock Find-TVSLocalConfig { @{ gameDir = 'C:\Local' } }
                Resolve-TVSProfileKey -Key 'gameDir' | Should -Be 'C:\Local'
                Should -Invoke Read-TVSProfile          -Times 0
                Should -Invoke Read-TVSLegacyDotEnv     -Times 0
                Should -Invoke Read-TVSLegacyGameDirProps -Times 0
                Should -Invoke Get-TVSSteamRegistryDir  -Times 0
            }
        }
    }
}
