function Resolve-PathOrNull {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    return (Resolve-Path $Path).Path
}
