function Get-TVSSaveCharacterList {
<#
.SYNOPSIS
Lists occupied character slots from SaveFile.es3.

.DESCRIPTION
Reads the player's SaveFile.es3 (via TVS.Environment playerDataDir)
and returns an array of occupied character slots with their index
and character name.

.PARAMETER Path
Path to SaveFile.es3. Defaults to playerDataDir from TVS.Environment.

.OUTPUTS
Hashtable array with SlotIndex (int) and Name (string) for each
occupied slot.
#>
    [CmdletBinding()]
    param(
        [string]$Path = ''
    )

    $index = Read-TVSSaveIndex -Path $Path
    return $index.Slots
}
