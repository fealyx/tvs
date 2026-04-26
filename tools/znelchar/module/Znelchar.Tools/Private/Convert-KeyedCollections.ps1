function Convert-BlendshapeListToMap {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Blendshapes
    )

    $result = [ordered]@{}
    if ($null -eq $Blendshapes) {
        return $result
    }

    foreach ($item in @($Blendshapes)) {
        if ($null -eq $item) {
            continue
        }

        $name = if ($item -is [hashtable]) { $item['name'] } else { $item.name }
        $value = if ($item -is [hashtable]) { $item['value'] } else { $item.value }
        if ($null -ne $name) {
            $result[[string]$name] = $value
        }
    }

    return $result
}

function Convert-BlendshapeMapToList {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Blendshapes
    )

    if ($null -eq $Blendshapes) {
        return ,@()
    }

    if ($Blendshapes -is [System.Collections.IList]) {
        return ,@($Blendshapes)
    }

    $result = @()
    foreach ($key in $Blendshapes.Keys) {
        $result += @{
            name = $key
            value = $Blendshapes[$key]
        }
    }

    return ,$result
}

function Convert-OpinionsListToMap {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Opinions
    )

    $result = [ordered]@{}
    if ($null -eq $Opinions) {
        return $result
    }

    foreach ($item in @($Opinions)) {
        if ($null -eq $item) {
            continue
        }

        $name = if ($item -is [hashtable]) { $item['_name'] } else { $item._name }
        if ($null -eq $name) {
            continue
        }

        $entry = @{}
        $properties = if ($item -is [hashtable]) { $item.Keys } else { $item.PSObject.Properties.Name }
        foreach ($property in $properties) {
            if ($property -ne '_name') {
                $entry[$property] = if ($item -is [hashtable]) { $item[$property] } else { $item.$property }
            }
        }

        $result[[string]$name] = $entry
    }

    return $result
}

function Convert-OpinionsMapToList {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Opinions
    )

    if ($null -eq $Opinions) {
        return ,@()
    }

    if ($Opinions -is [System.Collections.IList]) {
        return ,@($Opinions)
    }

    $result = @()
    foreach ($key in $Opinions.Keys) {
        $entry = @{
            _name = [int]$key
        }

        $value = $Opinions[$key]
        if ($value -is [System.Collections.IDictionary]) {
            foreach ($property in $value.Keys) {
                $entry[$property] = $value[$property]
            }
        }

        $result += $entry
    }

    return ,$result
}

function Convert-TraitsListToMap {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Traits
    )

    $result = [ordered]@{}
    if ($null -eq $Traits) {
        return $result
    }

    foreach ($item in @($Traits)) {
        if ($null -eq $item) {
            continue
        }

        $name = if ($item -is [hashtable]) { $item['_name'] } else { $item._name }
        $active = if ($item -is [hashtable]) { $item['_active'] } else { $item._active }
        if ($null -ne $name) {
            $result[[string]$name] = [bool]$active
        }
    }

    return $result
}

function Convert-TraitsMapToList {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Traits
    )

    if ($null -eq $Traits) {
        return ,@()
    }

    if ($Traits -is [System.Collections.IList]) {
        return ,@($Traits)
    }

    $result = @()
    foreach ($key in $Traits.Keys) {
        $result += @{
            _name = [int]$key
            _active = [bool]$Traits[$key]
        }
    }

    return ,$result
}

function Convert-NestedBlendshapeListsToMaps {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in ($InputObject.Keys | Sort-Object)) {
            $value = $InputObject[$key]
            if ([string]$key -eq 'blendshapes' -and $value -is [array]) {
                $result[$key] = Convert-BlendshapeListToMap -Blendshapes $value
            } else {
                $result[$key] = Convert-NestedBlendshapeListsToMaps -InputObject $value
            }
        }
        return $result
    }

    if ($InputObject -is [pscustomobject]) {
        $asHash = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $asHash[$property.Name] = $property.Value
        }
        return Convert-NestedBlendshapeListsToMaps -InputObject $asHash
    }

    if ($InputObject -is [System.Collections.IList] -and $InputObject -isnot [string]) {
        $result = @()
        foreach ($item in $InputObject) {
            $result += ,(Convert-NestedBlendshapeListsToMaps -InputObject $item)
        }
        return ,$result
    }

    return $InputObject
}

function Convert-NestedBlendshapeMapsToLists {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = @{}
        foreach ($key in ($InputObject.Keys | Sort-Object)) {
            $value = $InputObject[$key]
            if ([string]$key -eq 'blendshapes' -and $value -is [System.Collections.IDictionary]) {
                $result[$key] = Convert-BlendshapeMapToList -Blendshapes $value
            } else {
                $result[$key] = Convert-NestedBlendshapeMapsToLists -InputObject $value
            }
        }
        return $result
    }

    if ($InputObject -is [pscustomobject]) {
        $asHash = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $asHash[$property.Name] = $property.Value
        }
        return Convert-NestedBlendshapeMapsToLists -InputObject $asHash
    }

    if ($InputObject -is [System.Collections.IList] -and $InputObject -isnot [string]) {
        $result = @()
        foreach ($item in $InputObject) {
            $result += ,(Convert-NestedBlendshapeMapsToLists -InputObject $item)
        }
        return ,$result
    }

    return $InputObject
}
