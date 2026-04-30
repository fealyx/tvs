# ADR-004: TVSSave.Tools PowerShell Module

- Status: Proposed
- Date: 2026-04-30
- Initiative: TVS Manager

## Context

TVS save files contain more than embedded `.znelchar` character data. They carry gameplay state, settings, and potentially multiple character references. Players and developers have expressed interest in tooling that can:

- unpack and inspect the contents of a save file,
- automatically export character data when a save changes (live development workflow),
- diff two save states to understand what changed between play sessions,
- create and restore save snapshots (separate from mod rollback).

`Znelchar.Tools` is scoped specifically to `.znelchar` character file operations. Expanding its scope to include save-file parsing would violate its stated purpose and muddy its distribution story (a character file tool is useful to content creators who have no interest in game saves). Save file operations also have a different set of dependencies: they need filesystem watching, potentially binary parsing of game-specific formats, and tighter coupling to the player data directory.

Therefore, save file tooling belongs in a separate module.

## Decision

Introduce `TVSSave.Tools` as a new PowerShell module following the same structure and distribution patterns as `Znelchar.Tools`:

- **Module distribution**: `tvs-save-module-<version>.zip` for PS module path users.
- **Core distribution**: `tvs-save-core-<version>.zip` (requires `pwsh` on PATH).
- No standalone portable bundle — in the unified bundle era (see ADR-005), the unified TVS Tools bundle subsumes this.

### Dependency on Znelchar.Tools

`TVSSave.Tools` declares `Znelchar.Tools` as a required module. It does not re-implement character file extraction. When it needs to unpack character data embedded in a save, it calls `Export-ZnelcharContent` and `Expand-ZnelcharData` from `Znelchar.Tools`.

This means `TVSSave.Tools` standalone usage requires `Znelchar.Tools` to also be installed. The unified bundle handles this transparently for end-users.

### Proposed cmdlet surface

```powershell
# List save files in a directory (defaults to TVS.Environment playerDataDir)
Get-TVSSaveFile [-Path <string>] [-Latest]

# Unpack a save file: extract embedded character data and save metadata
Export-TVSSaveContent -InputPath <string> -OutputPath <string> [-ExpandCharacters]

# Show a summary of a save file
Get-TVSSaveInfo -InputPath <string>

# Compare two saves; returns a structured diff object
Compare-TVSSave -ReferencePath <string> -DifferencePath <string>

# Register a file-system watcher that calls Export-TVSSaveContent on change
Watch-TVSSaveDirectory [-Path <string>] [-OutputPath <string>] [-ExpandCharacters]
Stop-TVSSaveWatch

# Snapshot and restore
New-TVSSaveSnapshot -InputPath <string> [-Label <string>]
Restore-TVSSaveSnapshot -SnapshotPath <string> [-OutputPath <string>]
Get-TVSSaveSnapshot [-Path <string>]
```

### File watcher design notes

`Watch-TVSSaveDirectory` starts a background PS runspace with a `FileSystemWatcher` pointed at the player data directory. On each save-file change event:

1. Debounce (100 ms) to avoid processing mid-write partial files.
2. Call `Export-TVSSaveContent` with `-ExpandCharacters` if configured.
3. Write expanded output into `TVS.Environment` `characterWorkDir`.
4. Emit a brief log line to the host (or suppress with `-Quiet`).

`Watch-TVSSaveDirectory` returns a watcher ID. `Stop-TVSSaveWatch` terminates the background runspace. `tvsm save watch` wraps these cmdlets and displays live status via Spectre.Console.

### Module location

```
tools/tvs-save/
  module/
    TVSSave.Tools/
      Public/
        Get-TVSSaveFile.ps1
        Export-TVSSaveContent.ps1
        Get-TVSSaveInfo.ps1
        Compare-TVSSave.ps1
        Watch-TVSSaveDirectory.ps1
        Stop-TVSSaveWatch.ps1
        New-TVSSaveSnapshot.ps1
        Restore-TVSSaveSnapshot.ps1
        Get-TVSSaveSnapshot.ps1
      Private/
        Read-TVSSaveFormat.ps1
        Invoke-SaveDebounce.ps1
        ...
      TVSSave.Tools.psd1
      TVSSave.Tools.psm1
  data/
  docs/
  build/
    package.ps1
  package.json
  rush-project.json
```

This mirrors the `tools/znelchar` layout exactly to minimize onboarding friction for contributors already familiar with that structure.

## Save File Format

The format of TVS save files is not yet fully reverse-engineered. The initial implementation strategy is:

1. Implement format discovery scripts in `tools/tvs-save/docs/` as the format is explored.
2. Implement a best-effort parser for the currently understood structures.
3. Mark any unrecognised fields as opaque passthrough so round-trips do not corrupt data.
4. Document known format fields in `tools/tvs-save/data/` as JSON schemas where practical.

This mirrors the approach taken with `Znelchar.Tools` during its early development.

## Consequences

Positive:
- Clean separation of concerns: character file tools vs save file tools.
- `Znelchar.Tools` remains independently useful for content creators who do not interact with save files.
- File watcher workflow closes the loop between play sessions and character development.
- Same distribution pattern means contributors already familiar with one module can work on the other.

Tradeoffs:
- Users installing both modules independently face a two-step install; mitigated by the unified bundle.
- Save file format may evolve with game updates, requiring module updates; this is unavoidable.
- Background watcher runspace adds complexity; must be tested for resource leaks.

## Alternatives Considered

1. **Add save file commands to `Znelchar.Tools`.**
   - Rejected: violates the scope of a "character file" tool; would bloat the module for users who only need character operations; naming would become confusing.

2. **Implement save tooling as standalone scripts rather than a module.**
   - Rejected: standalone scripts cannot be imported and composed; no discoverability via `Get-Command`; inconsistent with the module pattern the ecosystem is building on.

3. **Implement save tooling in C# within tvsm directly.**
   - Rejected: merges logic into the UI layer; prevents independent PS-module usage from the command line; harder to test in isolation.

## Follow-Up Tasks

1. Create `tools/tvs-save` directory structure and Rush project.
2. Research TVS save file format; document findings in `tools/tvs-save/docs/FORMAT.md`.
3. Implement `Get-TVSSaveInfo` and `Export-TVSSaveContent` as the first vertical slice.
4. Implement `Watch-TVSSaveDirectory` and validate resource cleanup.
5. Wire `tvsm save` commands to the module via the PS runspace in `tvsm`.
