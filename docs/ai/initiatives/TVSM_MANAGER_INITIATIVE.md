# TVS Manager Initiative

Long-term planning and continuity reference for the `tvsm` (TVS Manager) effort.

## Purpose

Provide a durable, implementation-oriented strategy for building a unified tool manager that serves end-users, mod developers, and content creators. This document connects several related efforts: centralized environment configuration, save-file tooling, mod installation, and unified distribution.

Treat this as the canonical north star for `tvsm` and the broader tool ecosystem around it. It should survive context resets and tangent work.

## Problem Statement

As the TVS tool ecosystem grows, users and developers encounter increasing friction:

1. **Configuration fragmentation.** Game directory, player data path, character working directory, and mod output path are resolved differently by each script (`mod-manager.ps1` uses `.env`, `setup-modding-env.ps1` uses `.env` and `GameDir.props` and a registry lookup, znelchar portable launchers have their own conventions). This multiplies onboarding burden and creates subtle drift bugs.

2. **Runtime duplication.** `znelchar-tools` ships a portable bundle with a bundled `pwsh`. A forthcoming save-file tools module would do the same. Users interested in both would carry two runtimes and face the question of which portable to run for cross-cutting workflows.

3. **Mod installation friction.** Players must manually download and install BepInEx, TVSLib, optional utility mods, and keep them updated. There is no single command that bootstraps a complete mod environment.

4. **No user-facing CLI orchestration.** All tools are script-invocation style, requiring knowledge of parameter names. A first-time user — or a returning user after a game update — cannot quickly verify, repair, or update their setup.

## Scope

`tvsm` is the umbrella manager for the TVS tool ecosystem. It encompasses:

- **TVS.Environment**: a shared configuration module all other tools read from.
- **TVSSave.Tools**: a new PS module for save-file operations.
- **tvsm CLI**: a PowerShell script application providing TUI and scriptable CLI modes.
- **Unified TVS Tools bundle**: a single distribution artifact replacing per-tool portable bundles for end-users.
- **Community mod registry**: a hosted manifest driving `tvsm mod install` and update workflows.

What `tvsm` does NOT own:
- Core `.znelchar` operations — those remain in `Znelchar.Tools`.
- Mod build/compile logic — that stays in `mods/csharp/scripts`.
- Template scaffolding — that is the Mod Dev Bootstrap Initiative's domain.

## Guiding Principles

1. One config profile, read everywhere.
2. [PwshSpectreConsole](https://github.com/ShaunLawrie/PwshSpectreConsole) for all end-user-facing interactive output in `tvsm`; .NET/Spectre.Console directly if PwshSpectreConsole proves insufficient for a specific use case.
3. PS modules stay independently useful; `tvsm` orchestrates but does not replace them.
4. No internet required for basic offline operations — community manifest fetching is lazy and cached.
5. Mutations (mod installs, updates, overwrites) are preceded by a rollback snapshot.
6. Name things for end-users first: commands should read like plain English.

## Proposed Architecture

See the following ADRs for detailed decisions on each layer:

- [ADR-002](../adr/ADR-002-shared-environment-profile.md): Shared environment profile (`TVS.Environment`)
- [ADR-003](../adr/ADR-003-tvsm-application-stack.md): tvsm application technology (PowerShell + PwshSpectreConsole)
- [ADR-004](../adr/ADR-004-tvs-save-tools-module.md): `TVSSave.Tools` PS module
- [ADR-005](../adr/ADR-005-unified-tvs-tools-bundle.md): Unified distribution bundle
- [ADR-006](../adr/ADR-006-mod-storage-and-linking-strategy.md): Mod storage and linking strategy

### High-level component diagram

```
tvsm CLI (PowerShell module + tvsm.ps1 entry point)
  ├── reads TVS.Environment profile (~/.tvs/config.json)
  ├── imports Znelchar.Tools for character operations
  ├── imports TVSSave.Tools for save operations
  ├── fetches community mod registry (cached JSON from GitHub)
  └── delegates dev env setup to mods/csharp/scripts via TVS.Environment

TVS.Environment (PS module)
  └── shared by Znelchar.Tools, TVSSave.Tools, tvsm, mods/csharp/scripts

TVSSave.Tools (PS module)
  └── depends on Znelchar.Tools for embedded character data extraction

Community Mod Registry (hosted JSON)
  └── consumed by tvsm; design: GitHub Pages or GitHub release asset
```

## Feature Inventory

### Environment and Config

- [ ] `tvsm config set <key> <value>` — write a profile key
- [ ] `tvsm config get <key>` — read a profile key
- [ ] `tvsm config show` — display all resolved config in a Spectre table
- [ ] `tvsm config init` — interactive first-run wizard (TUI)
- [ ] Named profiles (`--profile dev`, `--profile stream`)
- [ ] `TVS_PROFILE` environment variable for CI/scripted overrides
- [ ] Local `.tvs-config.json` project-level overlay (nearest-ancestor search)

### Mod Management

- [ ] `tvsm mod apply [--profile]` — assemble staging from store and (re-)establish game dir junctions/symlinks
- [ ] `tvsm mod status` — diff active profile against linked state; detect post-update wipe
- [ ] `tvsm mod install <name>` — download to store, update active profile, apply
- [ ] `tvsm mod install --all` — install all registry-recommended mods
- [ ] `tvsm mod update [name]` — update one or all mods in store + re-apply
- [ ] `tvsm mod remove <name>` — remove from active profile + apply (store entry preserved)
- [ ] `tvsm mod rollback` — revert profile to pre-mutation snapshot + apply
- [ ] `tvsm mod verify` — check BepInEx integrity, junction health, TVSLib presence
- [ ] `tvsm mod snapshot [name]` — manually create a named profile snapshot
- [ ] `tvsm mod store list` — list all downloaded mod versions in the store
- [ ] `tvsm mod store prune` — remove store entries not referenced by any profile
- [ ] `tvsm mod profile list` — list available mod profiles
- [ ] `tvsm mod profile switch <name>` — switch active mod profile + apply
- [ ] `tvsm mod profile new <name>` — clone active profile under a new name
- [ ] `tvsm mod dev link <name> --src <path>` — register a live build output path as a dev overlay; bypass staging
- [ ] `tvsm mod dev unlink <name>` — remove dev link; fall back to store version if present
- [ ] `tvsm mod dev list` — show all active dev links and their source paths

### Character and Save File Tooling (TUI façade over PS modules)

- [ ] `tvsm char inspect <file>` — pretty-print znelchar metadata via Spectre
- [ ] `tvsm save list [dir]` — list save files in configured playerDataDir
- [ ] `tvsm save unpack <file>` — unpack a save and expand embedded character data into characterWorkDir
- [ ] `tvsm save watch` — file-system watcher; auto-unpacks and expands on save file change
- [ ] `tvsm save diff <file1> <file2>` — semantic diff between two saves or character states

### Self-Update

- [ ] `tvsm update check` — check all bundled tools for available updates
- [ ] `tvsm update apply` — update tvsm and bundled modules in-place

### Interactive Mode

- [ ] `tvsm` (no arguments) — launch TUI menu for end-users who prefer navigation to commands

## Community Mod Registry Design

The registry is a JSON file hosted on GitHub (either GitHub Pages at the content site, or as a GitHub release asset on this repo). It is fetched lazily on `tvsm mod install/update/status` and cached locally with a configurable TTL (default: 1 hour).

Minimal schema:

```json
{
  "schemaVersion": 1,
  "updated": "2026-04-30T00:00:00Z",
  "mods": [
    {
      "name": "TVSLib",
      "description": "Required shared library for TVS mods.",
      "recommended": true,
      "required": true,
      "versions": [
        {
          "version": "1.2.3",
          "url": "https://...",
          "sha256": "...",
          "requires": ["BepInEx"],
          "gameVersionRange": ">=0.45"
        }
      ]
    }
  ]
}
```

Key design constraints:
- `required: true` mods are installed without prompting during `tvsm mod install --all`.
- `requires` is a list of other registry mod names; `tvsm` resolves the install order.
- `gameVersionRange` is checked against the detected game version before install.
- Registry updates are never applied automatically to installed mods without user confirmation.

## Phased Implementation Plan

### Phase 0: TVS.Environment Module ✅ COMPLETE

Goals:
- Implement `TVS.Environment` PS module with profile read/write.
- Migrate `mod-manager.ps1`, `setup-modding-env.ps1`, and znelchar portable launchers to use it.

Deliverables:
- `tools/tvs-environment` module skeleton. ✅
- Profile schema and default key set. ✅
- Migration of existing config resolution in consuming scripts. ✅
- `Resolve-TVSProfileKey` priority chain with Pester test coverage. ✅

Exit criteria:
- All existing scripts that previously parsed `.env` / `GameDir.props` separately now call `Get-TVSEnvironment`. ✅

### Phase 1: tvsm CLI Skeleton ✅ COMPLETE

Goals:
- PowerShell module + `tvsm.ps1` entry-point script under `tools/tvsm`.
- `tvsm config` command surface fully functional, delegating to `TVS.Environment`.
- Help output and version command.

Deliverables:
- `tools/tvsm` package in Rush monorepo. ✅
- `TVSM` PS module scaffold mirroring `Znelchar.Tools` structure. ✅
- `PwshSpectreConsole` bundled as a dependency (auto-installed at runtime if absent). ✅
- `tvsm config init` — PwshSpectreConsole wizard with gameDir validation. ✅
- `tvsm config show` — Spectre table of all resolved keys + derived `pluginsDir`. ✅
- `tvsm config get/set` — thin wrappers over `TVS.Environment`. ✅
- `tvsm version` — component version table. ✅
- Interactive TUI menu on no-args invocation (`Read-SpectreSelection`). ✅
- `--json`, `--no-ansi`, `--profile` flags wired through all commands. ✅
- Dev-repo and portable-bundle `PSModulePath` seeding in `tvsm.ps1`. ✅
- UTF-8 encoding swap with session-scoped restore for Spectre Unicode output. ✅
- `build/package.ps1` producing `tvsm-module-<version>.zip` with co-bundled dependencies. ✅
- Phase 2/3 command stubs (`mod *`, `save watch`) with Phase labels. ✅

Exit criteria:
- `tvsm config init` walks a new user to a complete, valid profile. ✅
- `tvsm config show` renders the resolved config as a formatted table. ✅

### Phase 2: Mod Manager

Goals:
- Implement the store-and-link mod management model per [ADR-006](../adr/ADR-006-mod-storage-and-linking-strategy.md).
- Supersede `mods/csharp/scripts/mod-manager.ps1` (legacy prototype — copy-based, no store, no versioning).
- Implement community mod registry fetch and cache.
- Implement rollback/profile snapshot mechanism.
- Implement dev link overlay for mod developer workflows (`tvsm mod dev link`).

Background — why store-and-link:
Game updates on Steam replace the entire game installation directory, wiping BepInEx, all mods, and mod configs. The store-and-link model keeps all mod artifacts in `{modWorkDir}/store/` and re-establishes directory junctions (Windows) / symlinks (Linux) into `{gameDir}/BepInEx/{plugins,config,patchers}` on demand. After a game update, `tvsm mod apply` restores everything in seconds with no network traffic. See ADR-006 for the full layout and rationale.

Deliverables:
- Mod store layout under `{modWorkDir}/store/{modName}/{version}/`.
- Mod profile format (`{modWorkDir}/profiles/{name}.json`) with version selection and enabled flags.
- Staging directory assembly: copy store entries into `{modWorkDir}/staging/{profile}/`.
- Junction/symlink creation for `{gameDir}/BepInEx/{plugins,config,patchers}` → staging.
- Doorstop proxy (`winhttp.dll`) copy from store into `{gameDir}/` on every apply.
- `tvsm mod apply [--profile]` — assemble + link + drop doorstop + apply dev links.
- `tvsm mod status` — diff active profile vs. linked state; detect post-update wipe; show dev links.
- `tvsm mod install <name>` — download to store → update profile → apply.
- `tvsm mod update [name]` — fetch latest → store → profile → apply.
- `tvsm mod remove <name>` — remove from profile → apply (store entry preserved).
- `tvsm mod rollback` — revert profile to pre-mutation snapshot → apply (dev links unaffected).
- `tvsm mod verify` — check BepInEx integrity, TVSLib presence and version, junction health.
- `tvsm mod snapshot [name]` — manually create a named profile snapshot.
- `tvsm mod store list` / `tvsm mod store prune`.
- `tvsm mod profile list` / `tvsm mod profile switch <name>` / `tvsm mod profile new <name>`.
- `tvsm mod dev link <name> --src <path>` / `tvsm mod dev unlink <name>` / `tvsm mod dev list`.
- `dev-links.json` overlay format (machine-local, gitignored, excluded from snapshots/rollback).
- Community registry v1 JSON hosted and validated.
- Pester test suite under `tools/tvsm/tests/`:
  - `Show-TVSMConfig.Tests.ps1` — display-contract tests for null/empty key mapping and derived `pluginsDir` row.
  - `Get-TVSMModStatus.Tests.ps1` — manifest parsing and version-mismatch detection.
  - `Invoke-TVSMModRollback.Tests.ps1` — rollback snapshot creation and restore (highest-priority; safety-critical path).

Exit criteria:
- A fresh Windows user can run `tvsm mod install --all` and have a working BepInEx + TVSLib environment with no manual steps.
- Running `tvsm mod apply` after a game update restores all junctions and the doorstop proxy without re-downloading anything.
- Switching mod profiles (`tvsm mod profile switch dev`) takes effect immediately without manual file management.
- All Pester tests pass in CI.

### Phase 3: TVSSave.Tools Module

Goals:
- Implement `TVSSave.Tools` PS module.
- Implement `tvsm save` command surface as a façade over it.

Deliverables:
- `tools/tvs-save` module (module/core distribution).
- `tvsm save watch` with auto-expand into characterWorkDir.

Exit criteria:
- A developer can run `tvsm save watch` and have any save change automatically expanded into their working directory.

### Phase 4: Unified Bundle

Goals:
- Single `tvs-tools-<version>.zip` artifact replacing per-tool portable bundles.
- tvsm as the entry point for all end-user interaction.

Deliverables:
- Unified build script under `tools/tvsm/build/`.
- Updated distribution docs.
- Deprecation notice in znelchar-tools portable.

Exit criteria:
- End-user can download one zip, run `tvsm.exe`, and access all tool capabilities.
