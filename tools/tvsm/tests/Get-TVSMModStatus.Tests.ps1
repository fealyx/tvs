#Requires -Module Pester

Describe 'Get-TVSMModStatus' {
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
        $script:profileData = @{
            schemaVersion  = 1
            name           = 'default'
            bepInExVersion = '5.4.23.2'
            mods           = @{
                TVSLib = @{ version = '1.2.3'; enabled = $true; installLayout = 'plugins-dll' }
            }
            snapshots = @()
        }

        $script:devLinks = @{ schemaVersion = 1; links = @{} }

        Mock Get-TVSEnvironment { [pscustomobject]@{
            modWorkDir = 'C:\fake\modWorkDir'
            gameDir    = 'C:\fake\gameDir'
        }} -ModuleName TVSM

        Mock Get-TVSActiveProfileName { 'default' } -ModuleName TVSM
        Mock Read-TVSModProfile       { $script:profileData } -ModuleName TVSM
        Mock Read-TVSDevLinks         { $script:devLinks } -ModuleName TVSM
        Mock Get-TVSGameVersion       { '0.47.3' } -ModuleName TVSM
        Mock Test-Path                { $false } -ModuleName TVSM  # Default: paths don't exist
        Mock Get-Item                 {} -ModuleName TVSM
        Mock Write-SpectreHost        {} -ModuleName TVSM
        Mock Format-SpectreTable      {} -ModuleName TVSM
    }

    Context 'JSON output' {
        It 'Returns valid JSON with profile name and mod list' {
            # Make store path checks return true so mods appear healthy
            Mock Test-Path { $true } -ModuleName TVSM

            # plugins path exists as a junction
            $fakeJunction = [pscustomobject]@{ LinkType = 'Junction'; Target = 'C:\fake\staging' }
            Mock Get-Item { $fakeJunction } -ModuleName TVSM

            $result = Get-TVSMModStatus -Json | ConvertFrom-Json
            $result.profile | Should -Be 'default'
            $result.mods    | Should -Not -BeNullOrEmpty
        }

        It 'Includes wipeDetected: false when junctions are present' {
            Mock Test-Path { $true } -ModuleName TVSM
            $fakeJunction = [pscustomobject]@{ LinkType = 'Junction'; Target = 'C:\fake\staging' }
            Mock Get-Item { $fakeJunction } -ModuleName TVSM

            $result = Get-TVSMModStatus -Json | ConvertFrom-Json
            $result.wipeDetected | Should -Be $false
        }

        It 'Reports wipeDetected: true when BepInEx dir exists but plugins junction is missing' {
            # BepInEx dir exists, plugins path does not, so wipe is detected
            Mock Test-Path {
                param([string]$LiteralPath)
                if ($LiteralPath -like '*BepInEx' -and $LiteralPath -notlike '*plugins*') { return $true }
                return $false
            } -ModuleName TVSM

            $result = Get-TVSMModStatus -Json | ConvertFrom-Json
            $result.wipeDetected | Should -Be $true
        }
    }

    Context 'Version range tags' {
        It 'Tags mod with [OUTDATED RANGE] when game version is outside declared range' {
            $script:profileData['mods']['TVSLib']['gameVersionRange'] = '>=0.50'
            # Game version is 0.47.3 which is < 0.50, so should be outdated

            Mock Test-Path { $true } -ModuleName TVSM
            $fakeJunction = [pscustomobject]@{ LinkType = 'Junction'; Target = 'C:\fake\staging' }
            Mock Get-Item { $fakeJunction } -ModuleName TVSM

            $result = Get-TVSMModStatus -Json | ConvertFrom-Json
            $tvslibRow = $result.mods | Where-Object { $_.name -eq 'TVSLib' }
            $tvslibRow | Should -Not -BeNullOrEmpty
            $tvslibRow.tag | Should -Be '[OUTDATED RANGE]'
        }

        It 'Does not tag mod when game version satisfies range' {
            $script:profileData['mods']['TVSLib']['gameVersionRange'] = '>=0.45'
            # Game version is 0.47.3 which satisfies >=0.45

            Mock Test-Path { $true } -ModuleName TVSM
            $fakeJunction = [pscustomobject]@{ LinkType = 'Junction'; Target = 'C:\fake\staging' }
            Mock Get-Item { $fakeJunction } -ModuleName TVSM

            $result = Get-TVSMModStatus -Json | ConvertFrom-Json
            $tvslibRow = $result.mods | Where-Object { $_.name -eq 'TVSLib' }
            $tvslibRow.tag | Should -BeNullOrEmpty
        }

        It 'Tags mod with [VERSION UNKNOWN] when game version cannot be determined' {
            $script:profileData['mods']['TVSLib']['gameVersionRange'] = '>=0.45'
            Mock Get-TVSGameVersion { $null } -ModuleName TVSM

            $result = Get-TVSMModStatus -Json | ConvertFrom-Json
            $tvslibRow = $result.mods | Where-Object { $_.name -eq 'TVSLib' }
            $tvslibRow.tag | Should -Be '[VERSION UNKNOWN]'
        }
    }

    Context 'Dev links' {
        BeforeEach {
            $script:devLinks = @{
                schemaVersion = 1
                links = @{
                    MyMod = @{ src = 'C:\dev\MyMod\build'; installLayout = 'plugins-dll' }
                }
            }
        }

        It 'Includes dev link row tagged [DEV]' {
            Mock Test-Path { $true } -ModuleName TVSM
            $fakeJunction = [pscustomobject]@{ LinkType = 'Junction'; Target = 'C:\fake\staging' }
            Mock Get-Item { $fakeJunction } -ModuleName TVSM

            $result = Get-TVSMModStatus -Json | ConvertFrom-Json
            $devRow = $result.mods | Where-Object { $_.name -eq 'MyMod' }
            $devRow            | Should -Not -BeNullOrEmpty
            $devRow.tag        | Should -Be '[DEV]'
            $devRow.version    | Should -Be '[DEV]'
        }
    }

    Context 'Empty / no profile' {
        It 'Writes a no-mods message when profile is null' {
            Mock Read-TVSModProfile { $null } -ModuleName TVSM

            { Get-TVSMModStatus } | Should -Not -Throw
            Assert-MockCalled Write-SpectreHost -ModuleName TVSM -Times 1 -ParameterFilter {
                $Object -like '*No mods installed*'
            }
        }
    }
}
