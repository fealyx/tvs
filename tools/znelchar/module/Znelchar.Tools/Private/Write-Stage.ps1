function Write-Stage {
    param(
        [Parameter(Mandatory = $true)][string]$Prefix,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Write-Host ("[{0}] {1}" -f $Prefix, $Message)
}
