function Write-TVSSaveIndex {
<#
.SYNOPSIS
Writes an updated SavedPresetNames array back to SaveFile.es3, preserving
all other top-level keys untouched (opaque passthrough).

.DESCRIPTION
Takes the OpaqueKeys from a prior Read-TVSSaveIndex call and a hashtable
of slot-name mappings. Updates only the SavedPresetNames.value array
and writes the complete object back as JSON. Assumes the caller has
already validated that the game is not running.

.PARAMETER Path
Path to SaveFile.es3. Defaults to playerDataDir from TVS.Environment.

.PARAMETER OpaqueKeys
The ordered hashtable of all top-level keys from Read-TVSSaveIndex.

.PARAMETER SlotNames
Hashtable mapping slot index (int) to character name (string).
Slots not present in the hashtable are left as-is in the original array.
Set a slot to $null or '' to clear it.
#>
    [CmdletBinding()]
    param(
        [string]$Path = '',
        [hashtable]$OpaqueKeys,
        [hashtable]$SlotNames
    )

    if (-not $Path) {
        $env = Get-TVSEnvironment
        $Path = Join-Path $env.playerDataDir 'SaveFile.es3'
    }

    if (-not $OpaqueKeys) {
        throw 'OpaqueKeys is required. Use Read-TVSSaveIndex to obtain it.'
    }

    # Clone the opaque keys so we don't mutate the caller's hashtable
    $output = [ordered]@{}
    foreach ($key in $OpaqueKeys.Keys) {
        $output[$key] = $OpaqueKeys[$key]
    }

    # Update SavedPresetNames if it exists, otherwise create it
    $values = @()
    if ($output.ContainsKey('SavedPresetNames') -and $output['SavedPresetNames'] -is [hashtable]) {
        $existing = $output['SavedPresetNames']
        if ($existing.ContainsKey('value') -and $existing['value'] -is [array]) {
            $values = [System.Collections.ArrayList]::new($existing['value'])
        }
    }

    if ($SlotNames) {
        foreach ($kvp in $SlotNames.GetEnumerator()) {
            $index = [int]$kvp.Key
            $name = $kvp.Value

            # Extend array if needed
            while ($values.Count -le $index) {
                [void]$values.Add($null)
            }

            $values[$index] = if ([string]::IsNullOrEmpty($name)) { $null } else { $name }
        }
    }

    $output['SavedPresetNames'] = @{
        '__type' = $OpaqueKeys['SavedPresetNames']['__type']
        'value'  = [array]$values
    }

    $json = $output | ConvertTo-Json -Depth 100 -Compress
    Set-Content -Path $Path -Value $json -Encoding UTF8 -NoNewline
}
