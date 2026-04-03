function Expand-NestedCharacterData {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Character,
        [switch]$WarnOnFailure
    )

    if ($Character.ContainsKey('opinionDataString') -and $Character['opinionDataString'] -is [string]) {
        try {
            $Character['opinionDataString'] = ($Character['opinionDataString'] | ConvertFrom-Json -AsHashtable -Depth 100)
        }
        catch {
            if ($WarnOnFailure) {
                Write-Warning "Failed to parse opinionDataString; keeping original string. $($_.Exception.Message)"
            }
            else {
                Write-Verbose "Failed to parse opinionDataString; keeping original string. $($_.Exception.Message)"
            }
        }
    }

    return $Character
}
