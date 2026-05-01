<#
.SYNOPSIS
    Creates a new git worktree + branch for isolated feature work.

.DESCRIPTION
    Creates a linked worktree at a sibling path, creates a new branch, adds
    the worktree root to tvs.code-workspace, and seeds a starter session
    handoff snapshot in the new worktree.

.PARAMETER Area
    Canonical area name. Determines default WorktreePath and forms the branch name.
    Valid values: tvsm, znelchar, tvs-env, content, mods, infra, deps, docs

.PARAMETER Slug
    Short kebab-case descriptor for this branch (e.g. save-tools, round-trip-fix).

.PARAMETER Type
    Branch type prefix. Default: feature. Valid: feature, fix, chore.

.PARAMETER BaseBranch
    Git ref to branch from. Default: main.

.PARAMETER WorktreePath
    Absolute or relative path for the new worktree directory.
    Default: worktrees/tvs-<area>-<slug> (subdirectory of the repo root, gitignored).

.PARAMETER Purpose
    Optional one-line description seeded into the session handoff snapshot.

.EXAMPLE
    ./common/scripts/new-worktree.ps1 -Area tvsm -Slug save-tools -Purpose "Implement TVSSave.Tools PS module"
    Creates branch feature/tvsm/save-tools in worktrees/tvs-tvsm-save-tools.

.EXAMPLE
    ./common/scripts/new-worktree.ps1 -Area content -Slug guides-restructure -Type chore
    Creates branch chore/content/guides-restructure in worktrees/tvs-content-guides-restructure.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('tvsm','znelchar','tvs-env','content','mods','infra','deps','docs')]
    [string] $Area,

    [Parameter(Mandatory)]
    [string] $Slug,

    [ValidateSet('feature','fix','chore')]
    [string] $Type = 'feature',

    [string] $BaseBranch = 'main',

    [string] $WorktreePath,

    [string] $Purpose = ''
)

$ErrorActionPreference = 'Stop'

# Resolve repo root (script lives in common/scripts/ inside the main worktree)
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

$branchName = "$Type/$Area/$Slug"

if (-not $WorktreePath) {
    $WorktreePath = Join-Path $repoRoot "worktrees/tvs-$Area-$Slug"
}
$WorktreePath = [System.IO.Path]::GetFullPath($WorktreePath)

Write-Host ""
Write-Host "Creating worktree" -ForegroundColor Cyan
Write-Host "  Branch  : $branchName"
Write-Host "  Base    : $BaseBranch"
Write-Host "  Path    : $WorktreePath"
Write-Host ""

# --- git worktree add ---
if ($PSCmdlet.ShouldProcess($WorktreePath, "git worktree add -b $branchName")) {
    & git -C $repoRoot worktree add -b $branchName $WorktreePath $BaseBranch
    if ($LASTEXITCODE -ne 0) { throw "git worktree add failed (exit $LASTEXITCODE)." }
}

# --- Update tvs.code-workspace ---
$workspaceFile = Join-Path $repoRoot 'tvs.code-workspace'
if (Test-Path $workspaceFile) {
    $ws = Get-Content -Raw -LiteralPath $workspaceFile | ConvertFrom-Json -AsHashtable -Depth 10

    # Compute relative path from workspace file location (repo root) to the new worktree
    $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $WorktreePath)
    # Normalise to forward slashes
    $relPath = $relPath.Replace('\','/')

    $newFolder = @{ path = $relPath; name = "tvs-$Area-$Slug" }

    if (-not $ws.ContainsKey('folders')) { $ws['folders'] = @() }
    # Avoid duplicates
    $alreadyPresent = $ws['folders'] | Where-Object { $_.path -eq $relPath }
    if (-not $alreadyPresent) {
        $ws['folders'] += $newFolder
        $ws | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $workspaceFile -Encoding utf8NoBOM
        Write-Host "  tvs.code-workspace updated." -ForegroundColor Green
    } else {
        Write-Host "  tvs.code-workspace already contains this root — skipped." -ForegroundColor Yellow
    }
} else {
    Write-Warning "tvs.code-workspace not found at $workspaceFile — skipping workspace update. Run: cp tvs.code-workspace.template tvs.code-workspace"
}

# --- Seed session handoff snapshot ---
$handoffDir = Join-Path $WorktreePath 'temp/ai'
New-Item -ItemType Directory -Path $handoffDir -Force | Out-Null

$handoff = [ordered]@{
    project_overview = [ordered]@{
        goal             = if ($Purpose) { $Purpose } else { "$Type/$Area/$Slug" }
        current_status   = "Worktree created. Ready to begin work."
        definition_of_done = ""
    }
    decisions = @()
    work_completed = @()
    open_work = @(
        [ordered]@{
            priority = "high"
            task = "Define definition of done for this branch"
            recommended_next_step = "Read the relevant initiative doc and ADRs, then update this handoff."
            blocking_dependencies = ""
        }
    )
    known_issues_and_risks = @()
    validation = [ordered]@{
        commands_run = @()
        test_results = ""
        lint_typecheck_status = ""
        manual_checks = @()
    }
    environment_notes = [ordered]@{
        toolchain_versions = @()
        env_vars_required = @()
        devcontainer_differences = ""
    }
    next_session_bootstrap = [ordered]@{
        first_3_actions = @(
            "Read docs/ai/README.md for context",
            "Read the relevant initiative doc for this area",
            "Review open_work in this handoff and start the highest-priority item"
        )
        quick_win_task = ""
    }
    appendix = [ordered]@{
        important_commands = @(
            "node common/scripts/install-run-rush.js build",
            "node common/scripts/install-run-rush.js install"
        )
        important_paths = @(
            "docs/ai/README.md",
            "docs/ai/AGENT_CONVENTIONS.md"
        )
        glossary = @()
    }
    _meta = [ordered]@{
        branch      = $branchName
        worktree    = $WorktreePath
        created_at  = (Get-Date -Format 'o')
    }
}

$handoffPath = Join-Path $handoffDir 'session-handoff.latest.json'
$handoff | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $handoffPath -Encoding utf8NoBOM
Write-Host "  Session handoff seeded at: $handoffPath" -ForegroundColor Green

# --- Done ---
Write-Host ""
Write-Host "Worktree ready." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Reload VS Code workspace: File > Open Workspace from File > tvs.code-workspace"
Write-Host "     (or open $WorktreePath in a new VS Code window)"
Write-Host "  2. In the new worktree window, run: rush install"
Write-Host "  3. Update $handoffPath with your goals and definition of done."
Write-Host ""
Write-Host "To close this worktree when done:"
Write-Host "  ./common/scripts/close-worktree.ps1 -WorktreePath '$WorktreePath'"
Write-Host ""
