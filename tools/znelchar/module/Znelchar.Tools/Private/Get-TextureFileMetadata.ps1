function Get-TextureFileMetadata {
    param([Parameter(Mandatory = $true)][string]$Path)

    $info = Get-Item -LiteralPath $Path
    $sha256 = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash
    return [ordered]@{
        fileSize = [int64]$info.Length
        sha256 = $sha256
    }
}
