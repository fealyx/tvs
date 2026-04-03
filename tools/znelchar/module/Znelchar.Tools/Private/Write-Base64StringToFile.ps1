function Write-Base64StringToFile {
    param(
        [Parameter(Mandatory = $true)][string]$Base64,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    $transform = [System.Security.Cryptography.FromBase64Transform]::new([System.Security.Cryptography.FromBase64TransformMode]::IgnoreWhiteSpaces)
    $outputStream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        $pending = ''
        $chunkChars = 32768
        for ($i = 0; $i -lt $Base64.Length; $i += $chunkChars) {
            $size = [Math]::Min($chunkChars, $Base64.Length - $i)
            $pending += $Base64.Substring($i, $size)

            $usableLength = $pending.Length - ($pending.Length % 4)
            if ($usableLength -gt 0) {
                $chunk = $pending.Substring(0, $usableLength)
                $pending = $pending.Substring($usableLength)

                $inputBytes = [System.Text.Encoding]::ASCII.GetBytes($chunk)
                $outputBuffer = New-Object byte[] ($inputBytes.Length)
                $written = $transform.TransformBlock($inputBytes, 0, $inputBytes.Length, $outputBuffer, 0)
                if ($written -gt 0) {
                    $outputStream.Write($outputBuffer, 0, $written)
                }
            }
        }

        if ($pending.Length -gt 0) {
            $finalInput = [System.Text.Encoding]::ASCII.GetBytes($pending)
            $finalBytes = $transform.TransformFinalBlock($finalInput, 0, $finalInput.Length)
            if ($finalBytes.Length -gt 0) {
                $outputStream.Write($finalBytes, 0, $finalBytes.Length)
            }
        }
    }
    finally {
        $outputStream.Dispose()
        $transform.Dispose()
    }
}
