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
- **tvsm CLI**: a .NET console application providing TUI and scriptable CLI modes.
- **Unified TVS Tools bundle**: a single distribution artifact replacing per-tool portable bundles for end-users.
- **Community mod registry**: a hosted manifest driving `tvsm mod install` and update workflows.

What `tvsm` does NOT own:
- Core `.znelchar` operations — those remain in `Znelchar.Tools`.
- Mod build/compile logic — that stays in `mods/csharp/scripts`.
- Template scaffolding — that is the Mod Dev Bootstrap Initiative's domain.

## Guiding Principles

1. One config profile, read everywhere.
2. Spectre.Console for all interactive user-facing surfaces in `tvsm`.
3. PS modules stay independently useful; `tvsm` orchestrates but does not replace them.
4. No internet required for basic offline operations — community manifest fetching is lazy and cached.
5. Mutations (mod installs, updates, overwrites) are preceded by a rollback snapshot.
6. Name things for end-users first: commands should read like plain English.

## Proposed Architecture

See the following ADRs for detailed decisions on each layer:

- [ADR-002](./ADR-002-shared-environment-profile.md): Shared environment profile (`TVS.Environment`)
- [ADR-003](./ADR-003-tvsm-application-stack.md): tvsm application technology (.NET + Spectre.Console)
- [ADR-004](./ADR-004-tvs-save-tools-module.md): `TVSSave.Tools` PS module
- [ADR-005](./ADR-005-unified-tvs-tools-bundle.md): Unified distribution bundle

### High-level component diagram

```
tvsm CLI (.NET, Spectre.Console)
  ├── reads TVS.Environment profile (~/.tvs/config.json)
  ├── invokes Znelchar.Tools (PS runspace) for character operations
  ├── invokes TVSSave.Tools (PS runspace) for save operations
  ├── fetches community mod registry (cached JSON from GitHub)
  └── delegates dev env setup to mods/csharp/scripts via env vars

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

- [ ] `tvsm mod status` — inventory of installed mods in the plugins dir; flag version mismatches or missing deps
- [ ] `tvsm mod install <name>` — install a named mod from the community registry
- [ ] `tvsm mod install --all` — install all mods the registry marks as recommended
- [ ] `tvsm mod update [name]` — update one or all installed mods
- [ ] `tvsm mod remove <name>` — uninstall a mod
- [ ] `tvsm mod rollback` — restore plugins dir from the most recent pre-mutation snapshot
- [ ] `tvsm mod verify` — check BepInEx integrity, TVSLib presence and version, config manager presence
- [ ] `tvsm mod snapshot` — manually create a named rollback point

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

### Phase 0: TVS.Environment Module

Goals:
- Implement `TVS.Environment` PS module with profile read/write.
- Migrate `mod-manager.ps1`, `setup-modding-env.ps1`, and znelchar portable launchers to use it.

Deliverables:
- `tools/tvs-environment` module skeleton.
- Profile schema and default key set.
- Migration of existing config resolution in consuming scripts.

Exit criteria:
- All existing scripts that previously parsed `.env` / `GameDir.props` separately now call `Get-TVSEnvironment`.

### Phase 1: tvsm CLI Skeleton

Goals:
- .NET console app project under `tools/tvsm`.
- Spectre.Console wired up; help output and version command.
- Reads `TVS.Environment` profile natively.
- `tvsm config` command surface fully functional.

Deliverables:
- `tools/tvsm` project in Rush monorepo.
- Config TUI wizard for first-run.

Exit criteria:
- `tvsm config init` walks a new user to a complete, valid profile.
- `tvsm config show` renders the resolved config in a Spectre table.

### Phase 2: Mod Manager

Goals:
- Absorb and formalize behavior from `mods/csharp/scripts/mod-manager.ps1`.
- Implement community mod registry fetch and cache.
- Implement rollback snapshot mechanism.

Deliverables:
- `tvsm mod status`, `install`, `update`, `remove`, `rollback`, `verify` commands.
- Community registry v1 JSON hosted and validated.

Exit criteria:
- A fresh Windows user can run `tvsm mod install --all` and have a working BepInEx + TVSLib environment with no manual steps.

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
