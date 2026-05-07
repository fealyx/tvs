#Requires -Module Pester

Describe 'Get-TVSSaveCharacterList' {
    BeforeAll {
        $repoRoot      = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..')
        $tvsSaveModule = Join-Path $repoRoot 'tools' 'tvs-save' 'module' 'TVSSave.Tools' 'TVSSave.Tools.psd1'
        $tvseModule    = Join-Path $repoRoot 'tools' 'tvs-environment' 'module' 'TVS.Environment'
        $znelcharModule = Join-Path $repoRoot 'tools' 'znelchar' 'module' 'Znelchar.Tools'

        if (Test-Path -LiteralPath $tvseModule) {
            $parentDir = Split-Path -Parent $tvseModule
            $env:PSModulePath = $parentDir + [IO.Path]::PathSeparator + $env:PSModulePath
        }
        if (Test-Path -LiteralPath $znelcharModule) {
            $parentDir = Split-Path -Parent $znelcharModule
            $env:PSModulePath = $parentDir + [IO.Path]::PathSeparator + $env:PSModulePath
        }
        Import-Module $tvsSaveModule -Force -ErrorAction Stop
    }

    BeforeEach {
        $script:testDir = Join-Path ([System.IO.Path]::GetTempPath()) "tvs-save-test-$(Get-Random)"
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null

        Mock Get-TVSEnvironment {
            [pscustomobject]@{
                playerDataDir    = $script:testDir
                characterWorkDir = $script:testDir
            }
        } -ModuleName TVSSave.Tools
    }

    AfterEach {
        if (Test-Path $script:testDir) {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    function New-MockSaveFile {
        param([array]$Names)

        $values = @()
        foreach ($name in $Names) {
            $values += if ($name) { $name.ToString() } else { $null }
        }

        $saveData = [ordered]@{
            SavedPresetNames = @{
                '__type' = "System.Collections.Generic.List`1[[System.String, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]], mscorlib"
                'value'  = $values
            }
            SomeOtherKey = @{
                '__type' = 'Some.Type, Assembly'
                'value'  = @{ nested = 'data' }
            }
        }

        $json = $saveData | ConvertTo-Json -Depth 10 -Compress
        $savePath = Join-Path $script:testDir 'SaveFile.es3'
        Set-Content -Path $savePath -Value $json -Encoding UTF8

        return $savePath
    }

    Context 'Occupied and empty slots' {
        It 'Returns only occupied slots' {
            New-MockSaveFile -Names @('Snowball', 'Kimmy', $null, $null, 'Zephyr')

            $result = Get-TVSSaveCharacterList

            $result.Count | Should -Be 3
            $result[0].SlotIndex | Should -Be 0
            $result[0].Name      | Should -Be 'Snowball'
            $result[1].SlotIndex | Should -Be 1
            $result[1].Name      | Should -Be 'Kimmy'
            $result[2].SlotIndex | Should -Be 4
            $result[2].Name      | Should -Be 'Zephyr'
        }

        It 'Returns empty array when all slots are null' {
            New-MockSaveFile -Names @($null, $null, $null)

            $result = Get-TVSSaveCharacterList

            $result.Count | Should -Be 0
        }

        It 'Returns empty array when SavedPresetNames.value is empty' {
            New-MockSaveFile -Names @()

            $result = Get-TVSSaveCharacterList

            $result.Count | Should -Be 0
        }
    }

    Context 'Single character' {
        It 'Returns one entry for a single character' {
            New-MockSaveFile -Names @($null, $null, 'LoneWolf')

            $result = Get-TVSSaveCharacterList

            $result.Count      | Should -Be 1
            $result[0].SlotIndex | Should -Be 2
            $result[0].Name      | Should -Be 'LoneWolf'
        }
    }

    Context 'Many slots (sparse)' {
        It 'Handles a large sparse array' {
            $names = @($null) * 50
            $names[7]  = 'Alpha'
            $names[23] = 'Beta'
            $names[42] = 'Gamma'

            New-MockSaveFile -Names $names

            $result = Get-TVSSaveCharacterList

            $result.Count | Should -Be 3
            ($result | Where-Object { $_.SlotIndex -eq 7 }).Name  | Should -Be 'Alpha'
            ($result | Where-Object { $_.SlotIndex -eq 23 }).Name | Should -Be 'Beta'
            ($result | Where-Object { $_.SlotIndex -eq 42 }).Name | Should -Be 'Gamma'
        }
    }

    Context 'Opaque keys preservation' {
        It 'Returns OpaqueKeys containing all top-level keys' {
            New-MockSaveFile -Names @('TestChar')

            # Read-TVSSaveIndex returns both Slots and OpaqueKeys
            Mock Get-TVSSaveCharacterList {
                $index = Read-TVSSaveIndex
                return $index.Slots
            } -ModuleName TVSSave.Tools

            $rawIndex = Read-TVSSaveIndex -Path (Join-Path $script:testDir 'SaveFile.es3')

            $rawIndex.OpaqueKeys.ContainsKey('SavedPresetNames') | Should -Be $true
            $rawIndex.OpaqueKeys.ContainsKey('SomeOtherKey')    | Should -Be $true
            $rawIndex.OpaqueKeys['SomeOtherKey']['__type']      | Should -Be 'Some.Type, Assembly'
        }
    }

    Context 'Error handling' {
        It 'Throws when SaveFile.es3 does not exist' {
            { Read-TVSSaveIndex -Path (Join-Path $script:testDir 'nonexistent') } | Should -Throw
        }
    }
}
