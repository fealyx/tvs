function Read-TVSSaveIndex {
<#
.SYNOPSIS
Parses SaveFile.es3 and returns an array of occupied character slots.

.DESCRIPTION
Reads the Easy Save 3 JSON file, extracts the SavedPresetNames array,
and returns a hashtable array of occupied slots (SlotIndex, Name).
All other top-level keys are returned in an OpaqueKeys hashtable for
round-trip preservation via Write-TVSSaveIndex.

.PARAMETER Path
Path to SaveFile.es3. Defaults to playerDataDir from TVS.Environment.

.OUTPUTS
Hashtable with two keys:
  - Slots: @{ SlotIndex = int; Name = string }[]  (occupied only, non-null entries)
  - OpaqueKeys: ordered hashtable of all top-level keys and their values
#>
    [CmdletBinding()]
    param(
        [string]$Path = ''
    )

    if (-not $Path) {
        $env = Get-TVSEnvironment
        $Path = Join-Path $env.playerDataDir 'SaveFile.es3'
    }

    if (-not (Test-Path $Path -PathType Leaf)) {
        throw "SaveFile.es3 not found at: $Path"
    }

    $raw = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable

    $opaqueKeys = [ordered]@{}
    foreach ($key in $raw.Keys) {
        $opaqueKeys[$key] = $raw[$key]
    }

    $slots = @()
    if ($raw.ContainsKey('SavedPresetNames')) {
        $presetNames = $raw['SavedPresetNames']
        if ($presetNames -is [hashtable] -and $presetNames.ContainsKey('value')) {
            $values = $presetNames['value']
            if ($values -is [array]) {
                for ($i = 0; $i -lt $values.Count; $i++) {
                    if ($null -ne $values[$i] -and $values[$i] -is [string] -and $values[$i].Length -gt 0) {
                        $slots += @{ SlotIndex = $i; Name = $values[$i] }
                    }
                }
            }
        }
    }

    return @{
        Slots      = $slots
        OpaqueKeys = $opaqueKeys
    }
}
