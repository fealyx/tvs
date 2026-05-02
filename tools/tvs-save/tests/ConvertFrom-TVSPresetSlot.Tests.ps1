#Requires -Module Pester

Describe 'ConvertFrom-TVSPresetSlot' {
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

    Context 'Parsing presetSlot with trailing brace' {
        It 'Correctly extracts valid znelchar JSON from wrapped format' {
            $originalZnelchar = '{"version":"v0.2","isSynth":false,"characterName":"Snowball","blendshapes":[]}'

            # Build the ES3 wrapper: JSON-escape the znelchar, then wrap in { }
            $escaped = $originalZnelchar | ConvertTo-Json -Compress
            $escaped = $escaped.Substring(1, $escaped.Length - 2)  # strip outer quotes
            $wrapped = "{$escaped}"

            $presetPath = Join-Path $script:testDir 'presetSlot0.txt.tmp'
            Set-Content -Path $presetPath -Value $wrapped -Encoding UTF8 -NoNewline

            $result = ConvertFrom-TVSPresetSlot -Path $presetPath

            # Result should be valid JSON
            { $result | ConvertFrom-Json } | Should -Not -Throw

            # Round-trip: parse both and compare
            $original = $originalZnelchar | ConvertFrom-Json
            $parsed   = $result | ConvertFrom-Json

            $parsed.version        | Should -Be $original.version
            $parsed.characterName  | Should -Be 'Snowball'
        }

        It 'Handles empty blendshapes correctly' {
            $originalZnelchar = '{"version":"v0.2","isSynth":false,"characterName":"Test","blendshapes":[]}'
            $escaped = $originalZnelchar | ConvertTo-Json -Compress
            $escaped = $escaped.Substring(1, $escaped.Length - 2)
            $wrapped = "{$escaped}}"

            $presetPath = Join-Path $script:testDir 'presetSlot0.txt.tmp'
            Set-Content -Path $presetPath -Value $wrapped -Encoding UTF8 -NoNewline

            $result = ConvertFrom-TVSPresetSlot -Path $presetPath

            $parsed = $result | ConvertFrom-Json
            $parsed.blendshapes.Count | Should -Be 0
        }
    }

    Context 'Parsing presetSlot without trailing brace' {
        It 'Correctly extracts znelchar when closing brace is missing' {
            $originalZnelchar = '{"version":"v0.2","isSynth":false,"characterName":"Kimmy"}'

            $escaped = $originalZnelchar | ConvertTo-Json -Compress
            $escaped = $escaped.Substring(1, $escaped.Length - 2)
            # No closing brace — matches observed game output
            $wrapped = "{$escaped"

            $presetPath = Join-Path $script:testDir 'presetSlot1.txt.tmp'
            Set-Content -Path $presetPath -Value $wrapped -Encoding UTF8 -NoNewline

            $result = ConvertFrom-TVSPresetSlot -Path $presetPath

            $parsed = $result | ConvertFrom-Json
            $parsed.characterName | Should -Be 'Kimmy'
        }
    }

    Context 'Round-trip via ConvertTo-TVSPresetSlot' {
        It 'Produces valid presetSlot content after export → re-import' {
            $originalZnelchar = '{"version":"v0.2","isSynth":true,"characterName":"Roundtrip","blendshapes":[]}'

            # Write the preset
            $presetPath1 = Join-Path $script:testDir 'presetSlot0.txt.tmp'
            ConvertTo-TVSPresetSlot -ZnelcharJson $originalZnelchar -OutputPath $presetPath1

            # Read it back
            $result = ConvertFrom-TVSPresetSlot -Path $presetPath1

            $original = $originalZnelchar | ConvertFrom-Json
            $parsed   = $result | ConvertFrom-Json

            $parsed.characterName | Should -Be 'Roundtrip'
            $parsed.isSynth       | Should -Be $true
            $parsed.version       | Should -Be 'v0.2'
        }

        It 'Second round-trip is stable' {
            $originalZnelchar = '{"version":"v0.2","characterName":"Stable","isSynth":false}'

            $presetPath1 = Join-Path $script:testDir 'presetSlot0.txt.tmp'
            ConvertTo-TVSPresetSlot -ZnelcharJson $originalZnelchar -OutputPath $presetPath1

            $round1 = ConvertFrom-TVSPresetSlot -Path $presetPath1

            $presetPath2 = Join-Path $script:testDir 'presetSlot1.txt.tmp'
            ConvertTo-TVSPresetSlot -ZnelcharJson $round1 -OutputPath $presetPath2

            $round2 = ConvertFrom-TVSPresetSlot -Path $presetPath2

            $r1obj = $round1 | ConvertFrom-Json
            $r2obj = $round2 | ConvertFrom-Json

            $r2obj.characterName | Should -Be 'Stable'
            $r2obj.version       | Should -Be 'v0.2'
        }
    }

    Context 'Raw mode' {
        It 'Returns raw unescaped string without re-parsing when -Raw is specified' {
            $originalZnelchar = '{"version":"v0.2","characterName":"RawTest"}'

            $escaped = $originalZnelchar | ConvertTo-Json -Compress
            $escaped = $escaped.Substring(1, $escaped.Length - 2)
            $wrapped = "{$escaped}}"

            $presetPath = Join-Path $script:testDir 'presetSlot0.txt.tmp'
            Set-Content -Path $presetPath -Value $wrapped -Encoding UTF8 -NoNewline

            $result = ConvertFrom-TVSPresetSlot -Path $presetPath -Raw

            # Raw result should contain 'RawTest' somewhere
            $result | Should -Match 'RawTest'
        }
    }

    Context 'Error handling' {
        It 'Throws when file does not exist' {
            $badPath = Join-Path $script:testDir 'nonexistent.txt.tmp'
            { ConvertFrom-TVSPresetSlot -Path $badPath } | Should -Throw
        }

        It 'Throws when content is not valid after unescaping' {
            $wrapped = '{not-valid-json-at-all'
            $presetPath = Join-Path $script:testDir 'presetSlot0.txt.tmp'
            Set-Content -Path $presetPath -Value $wrapped -Encoding UTF8 -NoNewline

            { ConvertFrom-TVSPresetSlot -Path $presetPath } | Should -Throw
        }
    }
}
