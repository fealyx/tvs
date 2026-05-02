<#
.SYNOPSIS
    Closes a git worktree: writes a final session handoff, optionally pushes
    the branch, removes the root from tvs.code-workspace, and removes the
    linked worktree directory.

.DESCRIPTION
    Safe teardown companion to new-worktree.ps1. The branch is NOT deleted —
    it remains in git history for PR creation or future reference.

.PARAMETER WorktreePath
    Path to the linked worktree to close.
    Defaults to the current directory if it is a linked worktree.

.PARAMETER Push
    If specified, runs: git push -u origin <branch> before removing the worktree.

.PARAMETER Force
    Skip confirmation prompt and bypass "git worktree remove" safety check for
    unclean worktrees. Use with care.

.EXAMPLE
    ./common/scripts/close-worktree.ps1 -WorktreePath worktrees/tvs-tvsm-save-tools

.EXAMPLE
    ./common/scripts/close-worktree.ps1 -WorktreePath worktrees/tvs-tvsm-save-tools -Push -Force
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $WorktreePath,

    [switch] $Push,

    [switch] $Force
)

$ErrorActionPreference = 'Stop'

# Default to current directory
if (-not $WorktreePath) {
    $WorktreePath = $PWD.Path
}
$WorktreePath = [System.IO.Path]::GetFullPath($WorktreePath)

# Resolve repo root — walk up until we find rush.json in a parent that is NOT
# the worktree itself (the main worktree contains rush.json; linked worktrees
# also have a copy via git).  We use the .git file (not directory) to detect a
# linked worktree and find the main worktree's gitdir.
$gitFile = Join-Path $WorktreePath '.git'
if (-not (Test-Path $gitFile -PathType Leaf)) {
    throw "Cannot determine git worktree root. Expected a .git file at: $gitFile"
}

# The .git file in a linked worktree looks like: "gitdir: /path/to/main/.git/worktrees/name"
$gitContent = Get-Content -LiteralPath $gitFile -Raw
if ($gitContent -notmatch 'gitdir:\s*(.+)') {
    throw ".git file does not contain a gitdir reference. Is '$WorktreePath' a linked worktree?"
}
$gitdirPath = $Matches[1].Trim()
# $gitdirPath = {repo}/.git/worktrees/{name}
# Navigate ../../.. to reach: worktrees -> .git -> repo root
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $gitdirPath '../../..'))

if (-not (Test-Path (Join-Path $repoRoot 'rush.json'))) {
    throw "Could not resolve main worktree root (expected rush.json at: $repoRoot)"
}

# Determine branch name
$branch = (& git -C $WorktreePath rev-parse --abbrev-ref HEAD 2>$null).Trim()
if (-not $branch -or $branch -eq 'HEAD') {
    Write-Warning "Could not determine branch name for worktree at $WorktreePath."
    $branch = '<unknown>'
}

Write-Host ""
Write-Host "Closing worktree" -ForegroundColor Cyan
Write-Host "  Path   : $WorktreePath"
Write-Host "  Branch : $branch"
Write-Host ""

# --- Confirmation ---
if (-not $Force -and -not $PSCmdlet.ShouldProcess($WorktreePath, "close worktree (removes directory, branch preserved)")) {
    Write-Host "Aborted." -ForegroundColor Yellow
    return
}

# --- Write final session handoff ---
$handoffDir  = Join-Path $WorktreePath 'temp/ai'
$handoffPath = Join-Path $handoffDir 'session-handoff.latest.json'
if (Test-Path $handoffPath) {
    $existing = Get-Content -Raw -LiteralPath $handoffPath | ConvertFrom-Json -AsHashtable -Depth 20
    if (-not $existing.ContainsKey('_meta')) { $existing['_meta'] = @{} }
    $existing['_meta']['closed_at']    = (Get-Date -Format 'o')
    $existing['_meta']['close_status'] = 'worktree removed'
    $existing | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $handoffPath -Encoding utf8NoBOM
    Write-Host "  Session handoff updated: $handoffPath" -ForegroundColor Green
} else {
    Write-Warning "No session handoff found at $handoffPath — skipping update."
}

# --- Optional push ---
if ($Push) {
    Write-Host "  Pushing branch $branch..." -ForegroundColor Cyan
    & git -C $WorktreePath push -u origin $branch
    if ($LASTEXITCODE -ne 0) { throw "git push failed (exit $LASTEXITCODE)." }
    Write-Host "  Pushed." -ForegroundColor Green
}

# --- Remove from tvs.code-workspace ---
$workspaceFile = Join-Path $repoRoot 'tvs.code-workspace'
if (Test-Path $workspaceFile) {
    $ws = Get-Content -Raw -LiteralPath $workspaceFile | ConvertFrom-Json -AsHashtable -Depth 10
    if ($ws.ContainsKey('folders')) {
        $relPath  = [System.IO.Path]::GetRelativePath($repoRoot, $WorktreePath).Replace('\','/')
        $filtered = @($ws['folders'] | Where-Object { $_.path -ne $relPath })
        if ($filtered.Count -lt $ws['folders'].Count) {
            $ws['folders'] = $filtered
            $ws | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $workspaceFile -Encoding utf8NoBOM
            Write-Host "  Removed root from tvs.code-workspace." -ForegroundColor Green
        } else {
            Write-Host "  Root not found in tvs.code-workspace — nothing to remove." -ForegroundColor Yellow
        }
    }
} else {
    Write-Warning "tvs.code-workspace not found at $workspaceFile — skipping workspace update."
}

# --- git worktree remove ---
$removeArgs = @('worktree', 'remove', $WorktreePath)
if ($Force) { $removeArgs += '--force' }
& git -C $repoRoot @removeArgs
if ($LASTEXITCODE -ne 0) { throw "git worktree remove failed (exit $LASTEXITCODE). Use -Force to override dirty-worktree check." }
Write-Host "  Worktree directory removed." -ForegroundColor Green

# --- Done ---
Write-Host ""
Write-Host "Worktree closed." -ForegroundColor Green
Write-Host "Branch '$branch' is preserved in git history."
Write-Host ""
Write-Host "Next steps (if ready to merge):"
Write-Host "  1. Open a PR from '$branch' into main."
Write-Host "  2. After merging, delete the remote branch via GitHub or:"
Write-Host "     git push origin --delete '$branch'"
Write-Host "  3. Delete the local branch:"
Write-Host "     git branch -d '$branch'"
Write-Host ""
Write-Host "Reload VS Code workspace to reflect the removed root:"
Write-Host "  File > Open Workspace from File > tvs.code-workspace"
Write-Host ""
