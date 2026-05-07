# ADR-005: Unified TVS Tools Distribution Bundle

- Status: Accepted
- Date: 2026-04-30
- Amended: 2026-05-07
- Initiative: TVS Manager

## Context

The existing distribution strategy for `Znelchar.Tools` produces three artifacts:

- `znelchar-module-<version>.zip` — for users who install into a PS module path.
- `znelchar-core-<version>.zip` — portable without a bundled runtime (requires `pwsh` on PATH).
- `znelchar-portable-<version>.zip` — portable with a bundled `pwsh` runtime.

This is a reasonable approach for a single self-contained tool. However, as the ecosystem grows:

- `TVSSave.Tools` will follow the same three-artifact pattern.
- A user who wants both tools would have to download two separate portable zips, each potentially bundling a separate copy of the `pwsh` runtime (~70–120 MB each).
- `tvsm` is a PowerShell module application and has its own distribution artifact.
- Users would need to know about three separate tools, find the right download for each, and keep them updated independently.

The portable distribution model was designed before `tvsm` existed. Now that `tvsm` is the intended end-user entry point for everything, the portable bundle model needs to evolve.

## Decision

Introduce a **Unified TVS Tools bundle** as the primary end-user distribution artifact, published in two variants:

| Artifact | Includes `pwsh` runtime | Audience |
|---|---|---|
| `tvs-tools-full-<version>.zip` | Yes (win-x64) | Windows end-users who want a zero-prerequisite install |
| `tvs-tools-core-<version>.zip` | No | Users/CI/Linux who provide their own `pwsh` |

The individual module-only zips continue to be published for PS module path users. The existing `znelchar-portable-<version>.zip` is deprecated in favor of `tvs-tools-full`.

### Rationale for two variants

- The `pwsh` portable runtime is ~70–120 MB. Not all users need it bundled — developers, CI environments, and Linux users typically already have `pwsh` on PATH.
- A `-full` vs `-core` split is idiomatic (mirrors the existing znelchar pattern) and keeps the core artifact lightweight.
- Linux support is provided via `tvs-tools-core` only. The game is Windows-only; Linux users are contributors and CI environments who can be expected to provide their own `pwsh` runtime. A Linux runtime bundle is not warranted at this time.

### Bundle contents

#### `tvs-tools-full-<version>.zip` (Windows, runtime-included)

```
tvs-tools-full-<version>/
  tvsm.ps1                          # main entry point
  modules/
    TVSM/
      TVSM.psd1
      TVSM.psm1
      ...
    Znelchar.Tools/
      Znelchar.Tools.psd1
      Znelchar.Tools.psm1
      ...
    TVSSave.Tools/
      TVSSave.Tools.psd1
      TVSSave.Tools.psm1
      ...
    TVS.Environment/
      TVS.Environment.psd1
      TVS.Environment.psm1
      ...
  runtime/
    pwsh/                           # bundled pwsh 7.x portable (win-x64)
      pwsh.exe
      ...
  launchers/
    # Per-tool .cmd launchers for backwards compatibility
    inspect.cmd
    extract.cmd
    expand.cmd
    compress.cmd
    pack.cmd
    dump-yaml.cmd
    verify.cmd
    update.cmd
  VERSION.json
  SHA256SUMS.txt
```

#### `tvs-tools-core-<version>.zip` (runtime-free, cross-platform)

Same structure as `-full` minus the `runtime/` directory and `.cmd` launchers.
Includes `.sh` launchers for Linux/macOS.

```
tvs-tools-core-<version>/
  tvsm.ps1
  modules/
    TVSM/ ...
    Znelchar.Tools/ ...
    TVSSave.Tools/ ...
    TVS.Environment/ ...
  launchers/
    inspect.sh
    extract.sh
    expand.sh
    compress.sh
    pack.sh
    dump-yaml.sh
    verify.sh
    update.sh
  VERSION.json
  SHA256SUMS.txt
```

### What continues to be published separately

| Artifact | Audience | Continued? |
|---|---|---|
| `znelchar-module-<version>.zip` | PS module path users | Yes |
| `tvs-save-module-<version>.zip` | PS module path users | Yes |
| `tvs-environment-module-<version>.zip` | PS module path users | Yes |
| `znelchar-core-<version>.zip` | Scripting/CI users | Yes (no bundled runtime) |
| `tvs-tools-full-<version>.zip` | Windows end-users | Yes (replaces znelchar-portable) |
| `tvs-tools-core-<version>.zip` | Developers, CI, Linux | Yes |
| `znelchar-portable-<version>.zip` | (end-users) | **Deprecated** — replaced by `tvs-tools-full` |

A deprecation notice will appear in the `znelchar-tools` portable release notes pointing to the unified bundle.

### Build pipeline

The unified bundle build lives at `tools/tvsm/build/package-unified.ps1`. It:

1. Calls `tools/znelchar/build/package.ps1` with `-CreateModule:$true -CreateCore:$false -CreatePortable:$false` to produce module content.
2. Calls `tools/tvs-save/build/package.ps1` similarly.
3. Calls `tools/tvs-environment/build/package.ps1` similarly.
4. Stages all module content plus `tvsm.ps1` and launchers.
5. Downloads or copies in the bundled `pwsh` portable zip (for `-full` only).
6. Assembles both the `-full` and `-core` zips.
7. Emits `VERSION.json` and `SHA256SUMS.txt` for each.

The CI release workflow runs this script after the individual module builds.

### Self-update

`tvsm update apply` updates TVSM and all bundled modules atomically (no per-component partial updates prior to v1.0):

1. Downloads the latest `tvs-tools-release-manifest.json` from the release repository.
2. Compares the current bundle version against the latest.
3. Downloads the appropriate full or core zip (matching the currently installed variant).
4. Validates SHA256.
5. Swaps files with a safe overwrite pattern (rename-on-Windows compatible).

**Note:** Module-level independent updates are deferred until after v1.0. Before v1.0, the bundle version is the only version that matters; all components are updated together.

**Note:** Mod and mod registry updates are entirely separate from tooling updates. `tvsm mod update` operates independently and is not triggered by `tvsm update apply`.

`tvsm update check` reports whether a newer bundle version is available and lists per-component version changes included in that update.

### Version manifest

The unified bundle ships `VERSION.json` containing:

```json
{
  "bundleVersion": "1.0.0",
  "variant": "full",
  "components": {
    "TVSM": "1.0.0",
    "Znelchar.Tools": "0.2.0",
    "TVSSave.Tools": "0.1.0",
    "TVS.Environment": "0.1.0",
    "pwsh": "7.5.0"
  }
}
```

The `variant` field (`full` or `core`) allows `tvsm update apply` to download the correct artifact automatically.

## Consequences

Positive:
- End-users download one artifact and have everything (or choose the lighter core variant).
- One `pwsh` runtime shared by all modules — no duplication.
- `tvsm` becomes the natural entry point and discovery surface for all functionality.
- Backwards-compatible per-tool launchers mean existing workflows and shortcuts continue to work.
- PS module path users (developers) are not affected; their workflow is unchanged.
- Linux/CI users are supported via `tvs-tools-core` without unnecessary runtime bundling.

Tradeoffs:
- Two unified bundle artifacts to maintain; build pipeline must produce both from a single staged directory.
- Component version skew within the bundle is irrelevant pre-v1.0 (all updated atomically), but must be revisited for v1.0+ independent release cadences.
- Deprecating `znelchar-portable` may affect existing users; provide clear migration guidance in release notes.

## Alternatives Considered

1. **Continue separate portable bundles per tool, no unified bundle.**
   - Rejected: end-users with multiple tools carry multiple runtimes; `tvsm` has no natural distribution home.

2. **Unified bundle without per-tool launchers (tvsm-only entry point).**
   - Rejected: breaks existing users' workflows and scripts; the per-tool launchers are a minor inclusion that provides meaningful compatibility.

3. **NuGet global tool for tvsm instead of a zip bundle.**
   - Rejected: requires .NET SDK on the user's machine; unfamiliar install pattern for the game player audience; harder to bundle `pwsh` runtime alongside.

4. **Winget / MSIX package.**
   - Not in scope for Phase 4. Could be a future distribution channel; does not replace the zip bundle for developers and CI.

5. **Per-component update (update only changed modules).**
   - Deferred until after v1.0. Premature complexity given the rate of breaking changes pre-1.0.

6. **Linux runtime bundle.**
   - Not warranted. The game is Windows-only; Linux users are contributors and CI environments who provide their own `pwsh`. Revisit if a significant Linux end-user base emerges.

## Follow-Up Tasks

1. Draft `tools/tvsm/build/package-unified.ps1` scaffolding (produces both `-full` and `-core`).
2. Define the unified bundle release workflow in CI.
3. Add deprecation notice to `znelchar-tools` portable release notes.
4. Implement `tvsm update check` and `tvsm update apply` commands.
5. Update `tools/znelchar/docs/DISTRIBUTION.md` to reference the unified bundle.

---

## Addendum (2026-05-07): Save Tools Deferral Impact

### Context

The full implementation of `TVSSave.Tools` has been deferred until after the TVSM Manager Initiative is complete (see [ADR-004 Addendum](../adr/ADR-004-tvs-save-tools-module.md#addendum-2026-05-07-deferral-of-full-save-tools-implementation)).

### Impact on Unified Bundle

- The unified bundle design remains valid; `TVSSave.Tools` will be included in its current form (architecturally sufficient as a binding layer between Znelchar Tools and TVSM).
- The `-Experimental` flag in `tvsm` hides Save Tools from the default surface, so the current minimal implementation does not affect end-user experience.
- Full `TVSSave.Tools` feature integration (character preset workflows, enhanced file watcher, deeper save file tooling) will be incorporated into the unified bundle as part of a **dedicated Save Tools initiative** after TVSM Manager completion.
- The bundle's `VERSION.json` will continue to track `TVSSave.Tools` version independently, allowing it to be updated when the dedicated initiative delivers new functionality.

### No Changes Required

The unified bundle architecture, build pipeline, and distribution strategy described in this ADR remain unchanged. The deferral affects only the timeline for full Save Tools feature availability, not the bundle's design or structure.

---

## Addendum (2026-05-07): Phase 4 Scope Decisions

The following decisions were made during Phase 4 planning:

1. **Two distribution variants** (`-full` with bundled `pwsh`, `-core` without) replace the original single-artifact design.
2. **Linux support** is provided via `-core` only. No Linux runtime bundle planned.
3. **Self-update is atomic** (all components updated together) until v1.0. Per-component updates are deferred.
4. **Mod registry updates** (`tvsm mod update`) are independent from tooling updates (`tvsm update apply`).
5. **No migration tooling** for existing znelchar-portable users at this stage — the user base is small and breaking changes are expected.
6. **No additional distribution channels** (Winget, MSIX) in Phase 4 scope.
