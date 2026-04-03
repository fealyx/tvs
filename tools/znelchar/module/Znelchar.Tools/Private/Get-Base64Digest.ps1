function Get-Base64Digest {
    param([Parameter(Mandatory = $true)][string]$Base64)

    $transform = [System.Security.Cryptography.FromBase64Transform]::new([System.Security.Cryptography.FromBase64TransformMode]::IgnoreWhiteSpaces)
    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash([System.Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        $pending = ''
        $decodedBytes = 0L
        $chunkChars = 32768

        for ($i = 0; $i -lt $Base64.Length; $i += $chunkChars) {
            $size = [Math]::Min($chunkChars, $Base64.Length - $i)
            $pending += $Base64.Substring($i, $size)

            $usableLength = $pending.Length - ($pending.Length % 4)
            if ($usableLength -gt 0) {
                $chunk = $pending.Substring(0, $usableLength)
                $pending = $pending.Substring($usableLength)

                $inputBytes = [System.Text.Encoding]::ASCII.GetBytes($chunk)
                $outputBuffer = New-Object byte[] $inputBytes.Length
                $written = $transform.TransformBlock($inputBytes, 0, $inputBytes.Length, $outputBuffer, 0)
                if ($written -gt 0) {
                    $hash.AppendData($outputBuffer, 0, $written)
                    $decodedBytes += $written
                }
            }
        }

        $finalInput = [System.Text.Encoding]::ASCII.GetBytes($pending)
        $finalBytes = $transform.TransformFinalBlock($finalInput, 0, $finalInput.Length)
        if ($finalBytes.Length -gt 0) {
            $hash.AppendData($finalBytes, 0, $finalBytes.Length)
            $decodedBytes += $finalBytes.Length
        }

        return [ordered]@{
            sha256 = [Convert]::ToHexString($hash.GetHashAndReset())
            decodedBytes = $decodedBytes
            base64Length = [int64]$Base64.Length
        }
    }
    finally {
        $transform.Dispose()
        $hash.Dispose()
    }
}
