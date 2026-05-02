function Import-TVSCharacterPreset {
<#
.SYNOPSIS
Imports a .znelchar file back into a presetSlot{n}.txt.tmp save file.

.DESCRIPTION
Reads a .znelchar file from {characterWorkDir}/presets/, converts it
to the presetSlot wrapper format, and writes it to the player data
directory. Requires -Force as a safety guard against overwriting
live save data.

.PARAMETER Name
Character name (matches the .znelchar filename without extension).

.PARAMETER Slot
Zero-based slot index to write to. If omitted, looks up the slot
by character name in SaveFile.es3.

.PARAMETER SourcePath
Direct path to the .znelchar file. Overrides -Name lookup.

.PARAMETER Force
Required safety switch. Must be explicitly provided to confirm
the intent to write into the live player data directory.
#>
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess = $true)]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByPath', Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(ParameterSetName = 'ByName')]
        [Parameter(ParameterSetName = 'ByPath')]
        [int]$Slot = -1,

        [Parameter(Mandatory = $true)]
        [switch]$Force
    )

    if (-not $Force) {
        throw '-Force is required to import a character preset into the live player data directory. Ensure the game is not running.'
    }

    $env = Get-TVSEnvironment

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $SourcePath = Join-Path $env.characterWorkDir 'presets' "${Name}.znelchar"
    }

    if (-not (Test-Path $SourcePath -PathType Leaf)) {
        throw ".znelchar file not found at: $SourcePath"
    }

    $znelcharJson = Get-Content -Path $SourcePath -Raw -Encoding UTF8

    # Validate it's valid znelchar JSON
    try {
        $null = $znelcharJson | ConvertFrom-Json -Depth 10
    }
    catch {
        throw "Source file at '$SourcePath' is not valid JSON: $_"
    }

    # Resolve slot index
    if ($Slot -lt 0) {
        # Try to extract name from filename
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($SourcePath)
        $slots = Get-TVSSaveCharacterList
        $match = $slots | Where-Object { $_.Name -eq $baseName } | Select-Object -First 1
        if ($match) {
            $Slot = $match.SlotIndex
        }
        else {
            throw "Could not determine slot index. Provide -Slot explicitly, or ensure a character named '$baseName' exists in SaveFile.es3."
        }
    }

    $presetPath = Join-Path $env.playerDataDir "presetSlot${Slot}.txt.tmp"

    if ($PSCmdlet.ShouldProcess($presetPath, "Write znelchar character data to preset slot $Slot")) {
        ConvertTo-TVSPresetSlot -ZnelcharJson $znelcharJson -OutputPath $presetPath
        Write-Verbose "Imported '$SourcePath' to $presetPath"
        return $presetPath
    }
}
