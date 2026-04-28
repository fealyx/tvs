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
        [object]$Opinions,

        [hashtable]$IdToNameDict = $null
    )

    $result = [ordered]@{}
    if ($null -eq $Opinions) {
        return $result
    }

    foreach ($item in @($Opinions)) {
        if ($null -eq $item) {
            continue
        }

        $id = if ($item -is [hashtable]) { $item['_name'] } else { $item._name }
        if ($null -eq $id) {
            continue
        }

        # Use display name as key if dictionary provided, otherwise use ID
        $keyName = if ($IdToNameDict) {
            $IdToNameDict[[string]$id]
        } else {
            [string]$id
        }

        $entry = @{}
        # Always include the ID for roundtrip integrity
        if ($IdToNameDict) {
            $entry['id'] = $id
        }

        $properties = if ($item -is [hashtable]) { $item.Keys } else { $item.PSObject.Properties.Name }
        foreach ($property in $properties) {
            if ($property -ne '_name') {
                # Strip _ prefix from property names
                $cleanProp = if ($property -match '^_(.+)$') { $matches[1] } else { $property }
                $entry[$cleanProp] = if ($item -is [hashtable]) { $item[$property] } else { $item.$property }
            }
        }

        $result[$keyName] = $entry
    }

    return $result
}

function Convert-OpinionsMapToList {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Opinions,

        [hashtable]$NameToIdDict = $null
    )

    if ($null -eq $Opinions) {
        return ,@()
    }

    if ($Opinions -is [System.Collections.IList]) {
        return ,@($Opinions)
    }

    $result = @()
    foreach ($key in $Opinions.Keys) {
        # If dictionary provided, try to get ID from value.id, otherwise look up by display name
        $id = if ($NameToIdDict) {
            $value = $Opinions[$key]
            if ($value -is [System.Collections.IDictionary] -and $value.Contains('id')) {
                $value['id']
            } else {
                # Fallback: lookup by display name
                $NameToIdDict[[string]$key]
            }
        } else {
            [int]$key
        }

        $entry = @{
            _name = [int]$id
        }

        $value = $Opinions[$key]
        if ($value -is [System.Collections.IDictionary]) {
            foreach ($property in $value.Keys) {
                # Skip the 'id' field as we've already used it for _name
                if ($property -ne 'id') {
                    # Restore _ prefix to property names (unless already prefixed)
                    $prefixedProp = if ($property -match '^_') { $property } else { "_$property" }
                    $entry[$prefixedProp] = $value[$property]
                }
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
        [object]$Traits,

        [hashtable]$IdToNameDict = $null
    )

    $result = [ordered]@{}
    if ($null -eq $Traits) {
        return $result
    }

    foreach ($item in @($Traits)) {
        if ($null -eq $item) {
            continue
        }

        $id = if ($item -is [hashtable]) { $item['_name'] } else { $item._name }
        $active = if ($item -is [hashtable]) { $item['_active'] } else { $item._active }
        if ($null -ne $id) {
            # Use display name as key if dictionary provided, otherwise use ID
            $keyName = if ($IdToNameDict) {
                $IdToNameDict[[string]$id]
            } else {
                [string]$id
            }

            # Store as nested object with id and active when using display names
            $value = if ($IdToNameDict) {
                @{
                    id = $id
                    active = [bool]$active
                }
            } else {
                [bool]$active
            }

            $result[$keyName] = $value
        }
    }

    return $result
}

function Convert-TraitsMapToList {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Traits,

        [hashtable]$NameToIdDict = $null
    )

    if ($null -eq $Traits) {
        return ,@()
    }

    if ($Traits -is [System.Collections.IList]) {
        return ,@($Traits)
    }

    $result = @()
    foreach ($key in $Traits.Keys) {
        $value = $Traits[$key]

        # If dictionary provided and value is a hashtable with id, use that
        $id = if ($NameToIdDict) {
            if ($value -is [System.Collections.IDictionary] -and $value.Contains('id')) {
                $value['id']
            } else {
                # Fallback: lookup by display name
                $NameToIdDict[[string]$key]
            }
        } else {
            [int]$key
        }

        # Extract active state
        $active = if ($value -is [System.Collections.IDictionary] -and $value.Contains('active')) {
            [bool]$value['active']
        } else {
            [bool]$value
        }

        $result += @{
            _name = [int]$id
            _active = $active
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
