function Get-ImageFormatInfoFromBytes {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)

    if ($Bytes.Length -ge 8 -and
        $Bytes[0] -eq 0x89 -and $Bytes[1] -eq 0x50 -and $Bytes[2] -eq 0x4E -and $Bytes[3] -eq 0x47 -and
        $Bytes[4] -eq 0x0D -and $Bytes[5] -eq 0x0A -and $Bytes[6] -eq 0x1A -and $Bytes[7] -eq 0x0A) {
        return [ordered]@{ extension = '.png'; mimeType = 'image/png' }
    }

    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xD8 -and $Bytes[2] -eq 0xFF) {
        return [ordered]@{ extension = '.jpg'; mimeType = 'image/jpeg' }
    }

    if ($Bytes.Length -ge 6) {
        $gif87 = ($Bytes[0] -eq 0x47 -and $Bytes[1] -eq 0x49 -and $Bytes[2] -eq 0x46 -and $Bytes[3] -eq 0x38 -and $Bytes[4] -eq 0x37 -and $Bytes[5] -eq 0x61)
        $gif89 = ($Bytes[0] -eq 0x47 -and $Bytes[1] -eq 0x49 -and $Bytes[2] -eq 0x46 -and $Bytes[3] -eq 0x38 -and $Bytes[4] -eq 0x39 -and $Bytes[5] -eq 0x61)
        if ($gif87 -or $gif89) {
            return [ordered]@{ extension = '.gif'; mimeType = 'image/gif' }
        }
    }

    if ($Bytes.Length -ge 12 -and
        $Bytes[0] -eq 0x52 -and $Bytes[1] -eq 0x49 -and $Bytes[2] -eq 0x46 -and $Bytes[3] -eq 0x46 -and
        $Bytes[8] -eq 0x57 -and $Bytes[9] -eq 0x45 -and $Bytes[10] -eq 0x42 -and $Bytes[11] -eq 0x50) {
        return [ordered]@{ extension = '.webp'; mimeType = 'image/webp' }
    }

    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0x42 -and $Bytes[1] -eq 0x4D) {
        return [ordered]@{ extension = '.bmp'; mimeType = 'image/bmp' }
    }

    if ($Bytes.Length -ge 4) {
        $littleEndianTiff = ($Bytes[0] -eq 0x49 -and $Bytes[1] -eq 0x49 -and $Bytes[2] -eq 0x2A -and $Bytes[3] -eq 0x00)
        $bigEndianTiff = ($Bytes[0] -eq 0x4D -and $Bytes[1] -eq 0x4D -and $Bytes[2] -eq 0x00 -and $Bytes[3] -eq 0x2A)
        if ($littleEndianTiff -or $bigEndianTiff) {
            return [ordered]@{ extension = '.tiff'; mimeType = 'image/tiff' }
        }
    }

    if ($Bytes.Length -ge 4 -and $Bytes[0] -eq 0x00 -and $Bytes[1] -eq 0x00 -and $Bytes[2] -eq 0x01 -and $Bytes[3] -eq 0x00) {
        return [ordered]@{ extension = '.ico'; mimeType = 'image/x-icon' }
    }

    return [ordered]@{ extension = '.bin'; mimeType = 'application/octet-stream' }
}
