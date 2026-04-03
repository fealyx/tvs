function Format-BytesPerSecond {
    param(
        [int64]$Bytes,
        [double]$Seconds
    )

    if ($Seconds -le 0) {
        return 'n/a'
    }

    return ('{0:N2} MB/s' -f (($Bytes / 1MB) / $Seconds))
}
