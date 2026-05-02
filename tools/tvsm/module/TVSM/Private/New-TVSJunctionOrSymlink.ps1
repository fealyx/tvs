function New-TVSJunctionOrSymlink {
<#
.SYNOPSIS
Creates a directory junction (Windows) or symbolic link (Linux/macOS) at Path pointing to Target.
Removes any existing item at Path first, preserving the target's contents.

.PARAMETER Path
The path at which to create the junction or symlink.

.PARAMETER Target
The target directory the link should point to.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Target
    )

    # Ensure target exists — caller must guarantee this
    if (-not (Test-Path -LiteralPath $Target)) {
        throw "Junction target does not exist: $Target"
    }

    # Remove any existing item at the link path without touching the target
    if (Test-Path -LiteralPath $Path) {
        $existing = Get-Item -LiteralPath $Path -Force
        if ($existing.LinkType) {
            # It's a link — delete just the link node, not its contents
            $existing.Delete()
        } else {
            # It's a real directory — remove it
            Remove-Item -LiteralPath $Path -Recurse -Force
        }
    }

    # Ensure the parent directory exists
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if ($IsWindows) {
        New-Item -ItemType Junction -Path $Path -Value $Target | Out-Null
    } else {
        New-Item -ItemType SymbolicLink -Path $Path -Value $Target | Out-Null
    }
}
