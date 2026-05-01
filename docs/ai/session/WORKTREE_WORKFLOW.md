# Worktree Workflow

How to use `git worktree` for isolated parallel development in this monorepo — for agents, contributors, and the repo owner.

---

## Mental model

The monorepo has one git history and one `.git` directory, but can have **multiple working directories (worktrees)** checked out to different branches simultaneously. Each worktree is fully independent:

- Separate file tree (so VS Code windows don't step on each other)
- Separate branch (so commits are isolated)
- Separate `temp/` directory (so session handoffs, Rush intermediate files, and build outputs are isolated)

Worktrees share the underlying object store, so switching between them is instant — no re-clone, no duplicate remote.

```
/workspaces/tvs                            ← main worktree  (e.g. main branch)
/workspaces/tvs/worktrees/tvs-tvsm-save-tools  ← linked worktree (feature/tvsm/save-tools)
/workspaces/tvs/worktrees/tvs-content-guides   ← linked worktree (feature/content/guides-restructure)
C:\dev\tvs-mods-foobar                     ← linked worktree on Windows host (feature/mods/foobar)
```

All four live in the same git repo. Any one can push, PR, or merge independently.

---

## Branch naming

Convention: `<type>/<area>/<slug>`

| Type | Use for |
|---|---|
| `feature` | New capabilities (default) |
| `fix` | Bug fixes |
| `chore` | Housekeeping, deps, CI |

Canonical area names (maps directly to paths in the repo):

| Area | Covers |
|---|---|
| `tvsm` | `tools/tvsm/**` |
| `znelchar` | `tools/znelchar/**`, `tools/znelchar-gui/**` |
| `tvs-env` | `tools/tvs-environment/**` |
| `content` | `content/**` |
| `mods` | `mods/**` |
| `infra` | Cross-cutting developer infrastructure: `.devcontainer/**`, `common/scripts/**`, `docs/ai/**`, `.gitignore`, `*.code-workspace*`, CI workflows (`.github/**`) |
| `deps` | Rush / package dependency updates (`rush.json` package resolution, `package.json` dep changes, lockfile) |
| `docs` | `docs/**` outside `docs/ai/` (user-facing documentation) |

Examples:
- `feature/tvsm/save-tools`
- `fix/znelchar/round-trip-encoding`
- `chore/deps/rush-update-q2-2026`
- `feature/content/guides-restructure`
- `feature/infra/worktree-workflow`

**Area names are for human/UI organization only. CI routing is driven by which files actually changed (`paths:` filters in workflow files), not by branch names.**

---

## CI behavior on feature branches

`ci-tools.yml` runs on pushes to `feature/**`, `fix/**`, `chore/**` when `tools/**`, `common/**`, or `rush.json` are modified.

`ci-mods.yml` runs on pushes to `feature/**`, `fix/**`, `chore/**` when `mods/**`, `common/**`, or `rush.json` are modified.

`pages.yml` only runs on `main` — no Pages deploy from feature branches.

A docs-only commit (`docs/**` only) touching no tools or mods files will not trigger either CI job. This is correct and intentional.

---

## Script reference

Both scripts live in `common/scripts/` and run from PowerShell 7.

### `new-worktree.ps1` — create a worktree

```powershell
# Minimal — defaults to feature/ type, main base branch, worktrees/tvs-<area>-<slug> path
./common/scripts/new-worktree.ps1 -Area tvsm -Slug save-tools

# With purpose (seeded into session handoff) and explicit type
./common/scripts/new-worktree.ps1 -Area tvsm -Slug save-tools `
  -Purpose "Implement TVSSave.Tools PS module (Phase 3)" `
  -Type feature

# Custom worktree path (useful for Windows host path or non-default location)
./common/scripts/new-worktree.ps1 -Area mods -Slug foobar `
  -WorktreePath 'C:\dev\tvs-mods-foobar'
```

What it does:
1. `git worktree add -b <type>/<area>/<slug> <path> <base>`
2. Adds the new root to `tvs.code-workspace`
3. Creates `<worktree>/temp/ai/session-handoff.latest.json` seeded from the handoff template

### `close-worktree.ps1` — close a worktree

```powershell
# Standard close (prompts for confirmation via ShouldProcess)
./common/scripts/close-worktree.ps1 -WorktreePath worktrees/tvs-tvsm-save-tools

# Push branch before closing
./common/scripts/close-worktree.ps1 -WorktreePath worktrees/tvs-tvsm-save-tools -Push

# Force (no confirmation, bypass dirty-worktree check)
./common/scripts/close-worktree.ps1 -WorktreePath worktrees/tvs-tvsm-save-tools -Force
```

What it does:
1. Stamps `closed_at` into the worktree's `session-handoff.latest.json`
2. Optionally pushes the branch
3. Removes the root from `tvs.code-workspace`
4. `git worktree remove <path>` (branch preserved)

---

## Full lifecycle example

```powershell
# 1. Start work on Phase 3 save tools
./common/scripts/new-worktree.ps1 -Area tvsm -Slug save-tools `
  -Purpose "Implement TVSSave.Tools PS module and tvsm save command surface"

# 2. VS Code: File > Open Workspace from File > tvs.code-workspace
#    (or open worktrees/tvs-tvsm-save-tools in a new window)

# 3. In the new worktree, do your work...
#    rush install, implement, test, commit

# 4. When done, close the worktree (from the main worktree terminal)
./common/scripts/close-worktree.ps1 -WorktreePath worktrees/tvs-tvsm-save-tools -Push

# 5. Open a PR on GitHub from feature/tvsm/save-tools into main

# 6. After merge, clean up local branch
git branch -d feature/tvsm/save-tools
```

---

## Using VS Code with multiple worktrees

The live `tvs.code-workspace` file (gitignored) is managed by the worktree scripts. When you run `new-worktree.ps1`, it adds the new root to the workspace file. When you run `close-worktree.ps1`, it removes it.

After either operation, reload VS Code to pick up the change:
**File > Open Workspace from File > tvs.code-workspace** (repo root)

All worktree roots appear in the VS Code Explorer side panel under their own collapsible section. Source control shows each root's branch independently.

You do **not** need a second devcontainer. Both windows attach to the same running container.

The committed template `tvs.code-workspace.template` always has a single root (`tvs`). The live `tvs.code-workspace` is local state and is gitignored. If the live file is ever lost, the devcontainer `postCreateCommand` will re-seed it, or you can run:

```bash
cp tvs.code-workspace.template tvs.code-workspace
```

---

## Windows / Visual Studio workflow

When working in Visual Studio 2022 on the Windows host (e.g., on C# mods), create a worktree at a native Windows path:

```powershell
# From within the devcontainer terminal, specifying a Windows-accessible path
./common/scripts/new-worktree.ps1 -Area mods -Slug my-feature `
  -WorktreePath '/mnt/c/dev/tvs-mods-my-feature'
```

Or create it from a Windows terminal (if git is on the host PATH):

```powershell
# From a Windows PowerShell / CMD terminal at the repo root
git worktree add -b feature/mods/my-feature C:\dev\tvs-mods-my-feature main
```

Then manually seed `temp/ai/session-handoff.latest.json` if you want LLM continuity from the VS side.

**Line endings**: `.gitattributes` enforces LF storage. VS 2022 will check out CRLF locally on Windows (standard behaviour) and git normalises back to LF on commit. No special config needed.

**Note**: Running `rush install` in a Windows-path worktree is independent of the devcontainer — both use the same content-addressed pnpm store via the path mapping. Do not run `rush install` in two worktrees simultaneously as the store is not designed for concurrent writes.

---

## For agents

See `AGENT_CONVENTIONS.md` → "Branching conventions" section for the rules agents must follow. Key points:

- All agent work happens on a named feature branch, never directly on `main`
- Merges to `main` are always human-initiated (PR or explicit local merge)
- Agents should call `new-worktree.ps1` at the start of a feature and `close-worktree.ps1` (with `-Push`) at the end
- The session handoff in `temp/ai/session-handoff.latest.json` inside the worktree is the continuity artifact; keep it updated

---

## Gotchas

- **Do not run `rush install` in two worktrees simultaneously.** The pnpm store is content-addressed but not designed for concurrent writes.
- **The `temp/` directory is gitignored.** Session handoffs in `temp/ai/` are local-only. They survive `close-worktree.ps1` only because the branch directory is removed by git worktree remove — copy the handoff somewhere persistent if you want it after closing.
- **The same branch cannot be checked out in two worktrees at once.** git will refuse. If you need to reference the same work from two places, create a second branch from it.
- **Rush change log verification** (`rush change --verify`) runs in CI for tools branches. If you add a Rush package or make a publishable change, ensure the changelog entry is committed.
- **Worktrees are not cross-environment accessible.** A worktree created inside the devcontainer (Linux) has a Linux absolute path in its `.git` file and cannot be used from the Windows host, and vice versa. The script automatically picks the right default path for the environment it runs in: `worktrees/` on Linux (devcontainer), `../` sibling on Windows (host). Work that needs Visual Studio or Unity should be created from the host; work that needs the devcontainer toolchain should be created from within it.
