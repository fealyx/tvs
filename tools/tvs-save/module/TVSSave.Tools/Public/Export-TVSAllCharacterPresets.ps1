function Export-TVSAllCharacterPresets {
<#
.SYNOPSIS
Exports all occupied preset slot files to .znelchar files.

.DESCRIPTION
Iterates all occupied character slots detected in SaveFile.es3 and
calls Export-TVSCharacterPreset for each one.

.PARAMETER OutputPath
Directory for .znelchar output. Defaults to
{characterWorkDir}/presets/ from TVS.Environment.

.OUTPUTS
Array of output file paths.
#>
    [CmdletBinding()]
    param(
        [string]$OutputPath = ''
    )

    $env = Get-TVSEnvironment

    if (-not $OutputPath) {
        $OutputPath = Join-Path $env.characterWorkDir 'presets'
    }

    if (-not (Test-Path $OutputPath -PathType Container)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $slots = Get-TVSSaveCharacterList
    $results = @()

    foreach ($slot in $slots) {
        $presetPath = Join-Path $env.playerDataDir "presetSlot$($slot.SlotIndex).txt.tmp"
        if (Test-Path $presetPath -PathType Leaf) {
            $outputFile = Export-TVSCharacterPreset -Slot $slot.SlotIndex -OutputPath $OutputPath
            $results += $outputFile
        }
        else {
            Write-Warning "presetSlot$($slot.SlotIndex).txt.tmp not found for character '$($slot.Name)'; skipping."
        }
    }

    return $results
}
