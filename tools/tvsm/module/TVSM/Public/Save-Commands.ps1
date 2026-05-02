function Get-TVSSaveList {
<#
.SYNOPSIS
Lists occupied character slots from SaveFile.es3 as a Spectre table.

.DESCRIPTION
Reads the player's SaveFile.es3 via TVSSave.Tools and renders a
formatted table of occupied slots with index and character name.

.PARAMETER Path
Path to the player data directory. Defaults to playerDataDir from
TVS.Environment.

.PARAMETER Json
Emit structured JSON output instead of the Spectre table.

.EXAMPLE
tvsm save list
tvsm save list --json
#>
    [CmdletBinding()]
    param(
        [string]$Path = '',
        [switch]$Json
    )

    # Ensure TVSSave.Tools is available
    if (-not (Get-Module -ListAvailable -Name 'TVSSave.Tools')) {
        throw "TVSSave.Tools module is not available. Install it from the TVS Tools bundle."
    }
    Import-Module 'TVSSave.Tools' -Global -Force

    $slots = Get-TVSSaveCharacterList -Path $Path

    if ($Json) {
        $slots | ConvertTo-Json -Depth 5
        return
    }

    if ($slots.Count -eq 0) {
        Write-SpectreHost '[yellow]No occupied character slots found.[/]'
        return
    }

    $rows = foreach ($slot in $slots) {
        [pscustomobject]@{
            Slot  = $slot.SlotIndex
            Name  = $slot.Name
        }
    }

    $rows | Format-SpectreTable -Border Rounded -Color Blue `
        -Title '[cyan]Save Slots[/]' -AllowMarkup
}

function Export-TVSSavePreset {
<#
.SYNOPSIS
Exports one or all character preset slots to .znelchar files.

.DESCRIPTION
Delegates to Export-TVSCharacterPreset or Export-TVSAllCharacterPresets
from TVSSave.Tools.

.PARAMETER Slot
Zero-based slot index to export.

.PARAMETER Name
Character name to look up in SaveFile.es3.

.PARAMETER All
Export all occupied slots.

.PARAMETER OutputPath
Directory for .znelchar output. Defaults to
{characterWorkDir}/presets/ from TVS.Environment.

.EXAMPLE
tvsm save export --slot 0
tvsm save export --name Snowball
tvsm save export --all
#>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'BySlot')]
        [int]$Slot = -1,

        [Parameter(ParameterSetName = 'ByName')]
        [string]$Name = '',

        [Parameter(ParameterSetName = 'All')]
        [switch]$All,

        [string]$OutputPath = ''
    )

    if (-not (Get-Module -ListAvailable -Name 'TVSSave.Tools')) {
        throw "TVSSave.Tools module is not available. Install it from the TVS Tools bundle."
    }
    Import-Module 'TVSSave.Tools' -Global -Force

    if ($PSCmdlet.ParameterSetName -eq 'All' -or $All) {
        $results = Export-TVSAllCharacterPresets -OutputPath $OutputPath
        Write-SpectreHost "[green]✓ Exported $($results.Count) character(s)[/]"
        foreach ($r in $results) {
            Write-SpectreHost "  [grey]→[/] $r"
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'BySlot' -and $Slot -ge 0) {
        $result = Export-TVSCharacterPreset -Slot $Slot -OutputPath $OutputPath
        Write-SpectreHost "[green]✓ Exported slot $Slot →[/] $result"
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ByName' -and $Name) {
        $result = Export-TVSCharacterPreset -Name $Name -OutputPath $OutputPath
        Write-SpectreHost "[green]✓ Exported '$Name' →[/] $result"
    }
    else {
        Write-SpectreHost '[yellow]Specify --slot, --name, or --all.[/]'
    }
}

function Import-TVSSavePreset {
<#
.SYNOPSIS
Imports a .znelchar file back into a presetSlot save file.

.DESCRIPTION
Delegates to Import-TVSCharacterPreset from TVSSave.Tools.
Requires --force as a safety guard.

.PARAMETER Name
Character name (matches the .znelchar filename without extension).

.PARAMETER Slot
Zero-based slot index to write to. If omitted, looks up the slot
by character name in SaveFile.es3.

.PARAMETER SourcePath
Direct path to the .znelchar file. Overrides -Name lookup.

.PARAMETER Force
Required safety switch.

.EXAMPLE
tvsm save import --name Snowball --force
tvsm save import --name Snowball --slot 2 --force
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

    if (-not (Get-Module -ListAvailable -Name 'TVSSave.Tools')) {
        throw "TVSSave.Tools module is not available. Install it from the TVS Tools bundle."
    }
    Import-Module 'TVSSave.Tools' -Global -Force

    $importArgs = @{ Force = $true }
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $importArgs['Name'] = $Name
    } else {
        $importArgs['SourcePath'] = $SourcePath
    }
    if ($Slot -ge 0) {
        $importArgs['Slot'] = $Slot
    }

    $result = Import-TVSCharacterPreset @importArgs
    Write-SpectreHost "[green]✓ Imported →[/] $result"
}

function Expand-TVSSavePreset {
<#
.SYNOPSIS
Expands a .znelchar preset file to the multi-file character format.

.DESCRIPTION
Delegates to Expand-TVSCharacterPreset from TVSSave.Tools.

.PARAMETER Name
Character name (matches the .znelchar filename without extension).

.PARAMETER SourcePath
Direct path to the .znelchar file.

.EXAMPLE
tvsm save expand --name Snowball
#>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByPath', Mandatory = $true)]
        [string]$SourcePath
    )

    if (-not (Get-Module -ListAvailable -Name 'TVSSave.Tools')) {
        throw "TVSSave.Tools module is not available. Install it from the TVS Tools bundle."
    }
    Import-Module 'TVSSave.Tools' -Global -Force

    $expandArgs = @{}
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $expandArgs['Name'] = $Name
    } else {
        $expandArgs['SourcePath'] = $SourcePath
    }

    $result = Expand-TVSCharacterPreset @expandArgs
    Write-SpectreHost "[green]✓ Expanded →[/] $result"
}

function Compress-TVSSavePreset {
<#
.SYNOPSIS
Compresses an expanded character directory back to a .znelchar file.

.DESCRIPTION
Delegates to Compress-TVSCharacterPreset from TVSSave.Tools.

.PARAMETER Name
Character name (matches the .znelchar filename without extension).

.PARAMETER SourcePath
Direct path to the expanded directory.

.PARAMETER Force
Overwrite the output .znelchar file if it already exists.

.EXAMPLE
tvsm save compress --name Snowball
tvsm save compress --name Snowball --force
#>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByPath', Mandatory = $true)]
        [string]$SourcePath,

        [switch]$Force
    )

    if (-not (Get-Module -ListAvailable -Name 'TVSSave.Tools')) {
        throw "TVSSave.Tools module is not available. Install it from the TVS Tools bundle."
    }
    Import-Module 'TVSSave.Tools' -Global -Force

    $compressArgs = @{}
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $compressArgs['Name'] = $Name
    } else {
        $compressArgs['SourcePath'] = $SourcePath
    }
    if ($Force) {
        $compressArgs['Force'] = $true
    }

    $result = Compress-TVSCharacterPreset @compressArgs
    Write-SpectreHost "[green]✓ Compressed →[/] $result"
}

function Watch-TVSSave {
<#
.SYNOPSIS
Watches the player data directory for save file changes and syncs
character data to the working directory.

.DESCRIPTION
Delegates to Watch-TVSCharacterSync from TVSSave.Tools. Displays
live Spectre status while watching.

.PARAMETER Path
Path to the player data directory. Defaults to playerDataDir from
TVS.Environment.

.PARAMETER Expand
When present, also auto-expands character data after each export.

.EXAMPLE
tvsm save watch
tvsm save watch --expand
#>
    [CmdletBinding()]
    param(
        [string]$Path = '',
        [string]$Profile = '',
        [switch]$Expand
    )

    if (-not (Get-Module -ListAvailable -Name 'TVSSave.Tools')) {
        throw "TVSSave.Tools module is not available. Install it from the TVS Tools bundle."
    }
    Import-Module 'TVSSave.Tools' -Global -Force

    $env = Get-TVSEnvironment
    $watchPath = if ($Path) { $Path } else { $env.playerDataDir }

    Write-SpectreHost '[cyan]Starting save watcher...[/]'
    Write-SpectreHost "  Watch dir: [grey]$watchPath[/]"
    Write-SpectreHost "  Presets:   [grey]$($env.characterWorkDir)/presets/[/]"
    if ($Expand) {
        Write-SpectreHost '  Auto-expand: [green]enabled[/]'
    }
    Write-SpectreHost ''
    Write-SpectreHost '[grey]Press Ctrl+C to stop.[/]'

    $watcherId = Watch-TVSCharacterSync -Path $watchPath -Expand:$Expand -Quiet

    # Keep the script alive until Ctrl+C
    try {
        while ($true) {
            Start-Sleep -Seconds 1
        }
    }
    finally {
        Stop-TVSCharacterSync -Id $watcherId
        Write-SpectreHost '[grey]Watcher stopped.[/]'
    }
}

function Sync-TVSCharacterWorkDir {
<#
.SYNOPSIS
Syncs game save state into the character work directory using direct file
copies — no base64 encoding/decoding round-trips. Thin orchestrator wrapper
over TVSSave.Tools.

.DESCRIPTION
Delegates to Sync-TVSCharacterWorkDir from TVSSave.Tools. See the
TVSSave.Tools version for full parameter and behaviour documentation.

.PARAMETER PresetSlotPath
Path to the presetSlot{n}.txt.tmp file in the player data directory.

.PARAMETER TextureDir
Path to the SkinPresetTextures directory (source of texture image files).

.PARAMETER WorkDir
Root of the characterWorkDir.

.OUTPUTS
Hashtable with keys PresetDir, CharacterData, TexturesDir, ExportsDir,
and CopiedTextures (array of filenames).

.EXAMPLE
Sync-TVSCharacterWorkDir -PresetSlotPath "$env:playerDataDir/presetSlot0.txt.tmp" `
    -TextureDir "$env:playerDataDir/SkinPresetTextures" `
    -WorkDir "$env:characterWorkDir"
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PresetSlotPath,

        [Parameter(Mandatory = $true)]
        [string]$TextureDir,

        [Parameter(Mandatory = $true)]
        [string]$WorkDir
    )

    # TVSSave.Tools is a RequiredModule of TVSM — already loaded at import time.
    # Lazy import kept as defense-in-depth for any edge case where the module
    # is unloaded between TVSM load and this function call.
    if (-not (Get-Module -Name 'TVSSave.Tools')) {
        if (-not (Get-Module -ListAvailable -Name 'TVSSave.Tools')) {
            throw "TVSSave.Tools module is not available. Install it from the TVS Tools bundle."
        }
        Import-Module 'TVSSave.Tools' -Global -Force
    }

    # Module-qualified call to avoid shadowing the local wrapper
    TVSSave.Tools\Sync-TVSCharacterWorkDir @PSBoundParameters
}
