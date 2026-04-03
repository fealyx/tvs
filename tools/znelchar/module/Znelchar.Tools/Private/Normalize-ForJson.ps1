function Normalize-ForJson {
    param([Parameter(ValueFromPipeline = $true)]$Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $normalized = [ordered]@{}
        foreach ($k in @($Value.Keys | Sort-Object)) {
            $normalized[$k] = Normalize-ForJson -Value $Value[$k]
        }
        return $normalized
    }

    if (($Value -is [System.Collections.IEnumerable]) -and ($Value -isnot [string])) {
        $arr = @()
        foreach ($item in $Value) {
            $arr += ,(Normalize-ForJson -Value $item)
        }
        return $arr
    }

    return $Value
}
