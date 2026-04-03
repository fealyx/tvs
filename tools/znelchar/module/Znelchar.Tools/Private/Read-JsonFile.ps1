function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = (Resolve-Path $Path).Path
    $raw = [System.IO.File]::ReadAllText($resolved, [System.Text.UTF8Encoding]::new($false))
    return ($raw | ConvertFrom-Json -AsHashtable -Depth 100)
}
