function Convert-CharacterForPacking {
    param([Parameter(Mandatory = $true)][hashtable]$Character)

    if ($Character.ContainsKey('opinionDataString') -and $null -ne $Character['opinionDataString'] -and $Character['opinionDataString'] -isnot [string]) {
        Write-Verbose 'Encoding characterData.opinionDataString back into a serialized JSON string'
        $Character['opinionDataString'] = ($Character['opinionDataString'] | ConvertTo-Json -Compress -Depth 100)
    }

    return $Character
}
