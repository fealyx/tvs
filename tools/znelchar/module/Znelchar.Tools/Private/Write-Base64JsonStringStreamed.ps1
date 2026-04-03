function Write-Base64JsonStringStreamed {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][System.IO.TextWriter]$Writer,
        [int64]$VerboseProgressBytes = 16777216
    )

    $inputStream = [System.IO.File]::OpenRead($Path)
    $transform = [System.Security.Cryptography.ToBase64Transform]::new()
    try {
        $inputBlockSize = $transform.InputBlockSize
        $rawBuffer = New-Object byte[] 65535
        $pending = New-Object byte[] 2
        $pendingCount = 0
        $totalRead = 0L
        $nextVerboseAt = $VerboseProgressBytes
        $ascii = [System.Text.Encoding]::ASCII

        $Writer.Write('"')

        while (($read = $inputStream.Read($rawBuffer, 0, $rawBuffer.Length)) -gt 0) {
            $totalRead += $read

            if ($pendingCount -gt 0) {
                $combined = New-Object byte[] ($pendingCount + $read)
                [Array]::Copy($pending, 0, $combined, 0, $pendingCount)
                [Array]::Copy($rawBuffer, 0, $combined, $pendingCount, $read)

                $usableLength = $combined.Length - ($combined.Length % $inputBlockSize)
                if ($usableLength -gt 0) {
                    $outputBuffer = New-Object byte[] ([int]([Math]::Ceiling($usableLength / 3.0) * 4))
                    $written = $transform.TransformBlock($combined, 0, $usableLength, $outputBuffer, 0)
                    if ($written -gt 0) {
                        $Writer.Write($ascii.GetString($outputBuffer, 0, $written))
                    }
                }

                $pendingCount = $combined.Length - $usableLength
                if ($pendingCount -gt 0) {
                    [Array]::Copy($combined, $usableLength, $pending, 0, $pendingCount)
                }
            }
            else {
                $usableLength = $read - ($read % $inputBlockSize)
                if ($usableLength -gt 0) {
                    $outputBuffer = New-Object byte[] ([int]([Math]::Ceiling($usableLength / 3.0) * 4))
                    $written = $transform.TransformBlock($rawBuffer, 0, $usableLength, $outputBuffer, 0)
                    if ($written -gt 0) {
                        $Writer.Write($ascii.GetString($outputBuffer, 0, $written))
                    }
                }

                $pendingCount = $read - $usableLength
                if ($pendingCount -gt 0) {
                    [Array]::Copy($rawBuffer, $usableLength, $pending, 0, $pendingCount)
                }
            }

            if ($VerbosePreference -ne 'SilentlyContinue' -and $totalRead -ge $nextVerboseAt) {
                Write-Verbose ('Streamed {0:N0} bytes from {1}' -f $totalRead, $Path)
                $nextVerboseAt += $VerboseProgressBytes
            }
        }

        $finalInput = New-Object byte[] $pendingCount
        if ($pendingCount -gt 0) {
            [Array]::Copy($pending, 0, $finalInput, 0, $pendingCount)
        }

        $finalBytes = $transform.TransformFinalBlock($finalInput, 0, $finalInput.Length)
        if ($finalBytes.Length -gt 0) {
            $Writer.Write($ascii.GetString($finalBytes, 0, $finalBytes.Length))
        }

        $Writer.Write('"')

        return $totalRead
    }
    finally {
        $inputStream.Dispose()
        $transform.Dispose()
    }
}
