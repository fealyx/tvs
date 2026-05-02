function Export-TVSCharacterPreset {
<#
.SYNOPSIS
Exports one preset slot file to a .znelchar file.

.DESCRIPTION
Reads a presetSlot{n}.txt.tmp file, converts it to valid znelchar JSON,
and writes it to {characterWorkDir}/presets/{name}.znelchar.

.PARAMETER Slot
Zero-based slot index to export. If omitted, uses the slot index
from a SaveFile.es3 lookup by -Name.

.PARAMETER Name
Character name to look up in SaveFile.es3. If both -Slot and -Name
are provided, -Slot takes precedence.

.PARAMETER OutputPath
Directory for .znelchar output. Defaults to
{characterWorkDir}/presets/ from TVS.Environment.

.PARAMETER PresetSlotPath
Direct path to a presetSlot{n}.txt.tmp file. Overrides -Slot/-Name
lookup.
#>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'BySlot', Mandatory = $true)]
        [int]$Slot,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [string]$Name,

        [string]$OutputPath = '',

        [Parameter(ParameterSetName = 'ByPath', Mandatory = $true)]
        [string]$PresetSlotPath
    )

    $env = Get-TVSEnvironment

    if (-not $OutputPath) {
        $OutputPath = Join-Path $env.characterWorkDir 'presets'
    }

    # Resolve slot index and character name
    if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
        # Extract slot number from filename: presetSlot{n}.txt.tmp
        $fileName = Split-Path $PresetSlotPath -Leaf
        if ($fileName -match 'presetSlot(\d+)\.txt\.tmp') {
            $Slot = [int]$Matches[1]
        }
        else {
            throw "PresetSlotPath filename does not match expected pattern 'presetSlot{n}.txt.tmp': $fileName"
        }
        # Read the preset to get the name
        $znelcharJson = ConvertFrom-TVSPresetSlot -Path $PresetSlotPath
        try {
            $data = $znelcharJson | ConvertFrom-Json -Depth 10
            $Name = if ($data.characterName) { $data.characterName } else { "Slot$Slot" }
        }
        catch {
            $Name = "Slot$Slot"
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $slots = Get-TVSSaveCharacterList
        $match = $slots | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
        if (-not $match) {
            throw "Character '$Name' not found in any occupied save slot."
        }
        $Slot = $match.SlotIndex
    }
    # else BySlot: $Slot is already set; look up the name
    if ($PSCmdlet.ParameterSetName -eq 'BySlot' -or $PSCmdlet.ParameterSetName -eq 'ByPath') {
        if (-not $Name) {
            $slots = Get-TVSSaveCharacterList
            $match = $slots | Where-Object { $_.SlotIndex -eq $Slot } | Select-Object -First 1
            $Name = if ($match) { $match.Name } else { "Slot$Slot" }
        }
    }

    # Build preset slot path if not directly provided
    if (-not $PresetSlotPath) {
        $PresetSlotPath = Join-Path $env.playerDataDir "presetSlot${Slot}.txt.tmp"
    }

    if (-not (Test-Path $PresetSlotPath -PathType Leaf)) {
        throw "presetSlot file not found at: $PresetSlotPath"
    }

    $znelcharJson = ConvertFrom-TVSPresetSlot -Path $PresetSlotPath

    if (-not (Test-Path $OutputPath -PathType Container)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    # Sanitize name for filesystem use: strip zero-width and invisible Unicode
    # characters that can leak from game serialization (defense in depth —
    # Read-TVSSaveIndex also strips these at ingestion).
    $safeName = $Name -replace '[\u200B-\u200D\uFEFF\u00A0]', ''
    $safeName = $safeName.Trim()
    if ([string]::IsNullOrEmpty($safeName)) {
        $safeName = "Slot$Slot"
    }

    $outputFile = Join-Path $OutputPath "${safeName}.znelchar"
    Set-Content -Path $outputFile -Value $znelcharJson -Encoding UTF8

    Write-Verbose "Exported slot $Slot ('$Name') to $outputFile"
    return $outputFile
}
