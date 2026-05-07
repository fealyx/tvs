# ADR-005: Unified TVS Tools Distribution Bundle

- Status: Proposed
- Date: 2026-04-30
- Initiative: TVS Manager

## Context

The existing distribution strategy for `Znelchar.Tools` produces three artifacts:

- `znelchar-module-<version>.zip` — for users who install into a PS module path.
- `znelchar-core-<version>.zip` — portable without a bundled runtime (requires `pwsh` on PATH).
- `znelchar-portable-<version>.zip` — portable with a bundled `pwsh` runtime.

This is a reasonable approach for a single self-contained tool. However, as the ecosystem grows:

- `TVSSave.Tools` will follow the same three-artifact pattern.
- A user who wants both tools would have to download two separate portable zips, each potentially bundling a separate copy of the `pwsh` runtime (~70–120 MB each).
- `tvsm` is a .NET app and has its own distribution artifact.
- Users would need to know about three separate tools, find the right download for each, and keep them updated independently.

The portable distribution model was designed before `tvsm` existed. Now that `tvsm` is the intended end-user entry point for everything, the portable bundle model needs to evolve.

## Decision

Introduce a **Unified TVS Tools bundle** (`tvs-tools-<version>.zip`) as the primary end-user distribution artifact. The individual module-only zips continue to be published for PS module path users; the portable variants are deprecated in favor of the unified bundle.

### Bundle contents

```
tvs-tools-<version>/
  tvsm.exe                          # self-contained .NET 8 single-file publish
  tvsm.sh                           # POSIX launcher (for Proton/Linux users)
  modules/
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
    # Per-tool .cmd/.sh launchers for direct znelchar-tools access
    # (backwards compatibility with users who know the existing commands)
    inspect.cmd / inspect.sh
    extract.cmd / extract.sh
    expand.cmd / expand.sh
    compress.cmd / compress.sh
    pack.cmd / pack.sh
    dump-yaml.cmd / dump-yaml.sh
    verify.cmd / verify.sh
    verify-roundtrip.cmd / verify-roundtrip.sh
    update.cmd / update.sh
  VERSION
  SHA256SUMS.txt
```

`tvsm.exe` is a self-contained .NET 8 publish and does not need the bundled `pwsh` runtime for its own operation. The bundled `pwsh` is for the PS modules when invoked via `tvsm`'s runspace, and for users who invoke the per-tool launchers directly.

### What continues to be published separately

| Artifact | Audience | Continued? |
|---|---|---|
| `znelchar-module-<version>.zip` | PS module path users | Yes |
| `tvs-save-module-<version>.zip` | PS module path users | Yes |
| `tvs-environment-module-<version>.zip` | PS module path users | Yes |
| `znelchar-core-<version>.zip` | Scripting/CI users | Yes (no bundled runtime) |
| `tvs-tools-<version>.zip` | End-users, developers | Yes (replaces portables) |
| `znelchar-portable-<version>.zip` | (end-users) | **Deprecated** — replaced by unified bundle |

A deprecation notice will appear in the `znelchar-portable` release notes pointing to the unified bundle.

### Build pipeline

The unified bundle build lives at `tools/tvsm/build/package-unified.ps1`. It:

1. Calls `tools/znelchar/build/package.ps1` with `-CreateModule:$true -CreateCore:$false -CreatePortable:$false` to produce module content.
2. Calls `tools/tvs-save/build/package.ps1` similarly.
3. Calls `tools/tvs-environment/build/package.ps1` similarly.
4. Runs `dotnet publish tools/tvsm -r win-x64 --self-contained -o <staging>/tvsm.exe`.
5. Downloads or copies in the bundled `pwsh` portable zip.
6. Assembles all staged content into the final zip.
7. Emits `tvs-tools-release-manifest.json` and `SHA256SUMS.txt`.

The CI release workflow runs this script after the individual module builds.

### Self-update

`tvsm update apply` can update the unified bundle in-place:

1. Downloads the latest `tvs-tools-release-manifest.json` from the release repository.
2. Compares versions of each component against what is currently installed.
3. Downloads only the changed components (or the full bundle zip for simplicity in v1).
4. Validates SHA256.
5. Swaps files with a safe overwrite pattern (rename-on-Windows compatible).

The existing `update.cmd` launcher (which currently calls `Update-ZnelcharTools`) is updated to delegate to `tvsm update apply` when running inside the unified bundle context.

### Version manifest

The unified bundle ships `VERSION` containing:

```json
{
  "bundleVersion": "1.0.0",
  "components": {
    "tvsm": "1.0.0",
    "Znelchar.Tools": "0.2.0",
    "TVSSave.Tools": "0.1.0",
    "TVS.Environment": "0.1.0",
    "pwsh": "7.5.0"
  }
}
```

This allows `tvsm update check` to report per-component update availability even when the bundle version has not changed.

## Consequences

Positive:
- End-users download one artifact and have everything.
- One `pwsh` runtime shared by all modules — no duplication.
- `tvsm` becomes the natural entry point and discovery surface for all functionality.
- Backwards-compatible per-tool launchers mean existing workflows and shortcuts continue to work.
- PS module path users (developers) are not affected; their workflow is unchanged.

Tradeoffs:
- Unified bundle is larger than any single-tool portable (~150–200 MB with bundled `pwsh`); this is a one-time download accepted by users who want the convenience.
- Build pipeline is more complex; must be carefully ordered and tested.
- Component version skew within the bundle must be managed (e.g., if TVSSave.Tools releases independently).
- Deprecating `znelchar-portable` may affect existing users who have automated the current download URL; provide clear migration guidance.

## Alternatives Considered

1. **Continue separate portable bundles per tool, no unified bundle.**
   - Rejected: end-users with multiple tools carry multiple runtimes; `tvsm` has no natural distribution home.

2. **Unified bundle without per-tool launchers (tvsm-only entry point).**
   - Rejected: breaks existing users' workflows and scripts; the per-tool launchers are a minor inclusion that provides meaningful compatibility.

3. **NuGet global tool for tvsm instead of a zip bundle.**
   - Rejected: requires .NET SDK on the user's machine; unfamiliar install pattern for the game player audience; harder to bundle `pwsh` runtime alongside.

4. **Winget / MSIX package.**
   - Not rejected outright; could be a future distribution channel for end-users who prefer it. Does not replace the zip bundle for developers and CI.

## Follow-Up Tasks

1. Draft `tools/tvsm/build/package-unified.ps1` scaffolding.
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
- The bundle's version manifest will continue to track `TVSSave.Tools` version independently, allowing it to be updated when the dedicated initiative delivers new functionality.

### No Changes Required

The unified bundle architecture, build pipeline, and distribution strategy described in this ADR remain unchanged. The deferral affects only the timeline for full Save Tools feature availability, not the bundle's design or structure.
