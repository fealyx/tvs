function Get-TextureMap {
    param([Parameter(Mandatory = $true)][hashtable]$Outer)

    $map = @{}
    $textures = @()
    if ($Outer.ContainsKey('_textureDatas') -and $null -ne $Outer['_textureDatas']) {
        $textures = @($Outer['_textureDatas'])
    }

    foreach ($t in $textures) {
        $name = if ($t.ContainsKey('_textureName')) { [string]$t['_textureName'] } else { '' }
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw 'Found a texture entry with missing _textureName'
        }
        if ($map.ContainsKey($name)) {
            throw "Duplicate texture name found: $name"
        }

        $b64 = if ($t.ContainsKey('_textureData') -and $null -ne $t['_textureData']) { [string]$t['_textureData'] } else { '' }
        $digest = Get-Base64Digest -Base64 $b64
        $map[$name] = [ordered]@{
            textureName = $name
            sha256 = $digest.sha256
            decodedBytes = $digest.decodedBytes
            base64Length = $digest.base64Length
        }
    }

    return $map
}
