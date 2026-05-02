# ADR-004: TVSSave.Tools PowerShell Module

- Status: Accepted
- Date: 2026-05-02
- Initiative: TVS Manager

## Context

TVS save files contain more than embedded `.znelchar` character data. They carry gameplay state, settings, and multiple character references. Players and developers have expressed interest in tooling that can:

- list and inspect characters stored in save slots,
- export character data from save slots to `.znelchar` files for editing,
- import edited `.znelchar` files back to save slots,
- expand character data to our multi-file format for deeper editing,
- automatically sync these representations when the game saves (live development workflow),
- diff two save states to understand what changed between play sessions,
- create and restore save snapshots (separate from mod rollback).

`Znelchar.Tools` is scoped specifically to `.znelchar` character file operations. Expanding its scope to include save-file parsing would violate its stated purpose and muddy its distribution story. Save file operations also have a different set of dependencies: filesystem watching, game-format-specific parsing, and tighter coupling to the player data directory.

Therefore, save file tooling belongs in a separate module.

## Save File Format

### `SaveFile.es3`

An Easy Save 3 (Unity asset) JSON file — a direct serialisation of C# objects. Each top-level key is a save key; each value is an object with `__type` (C# fully-qualified type name) and `value` fields.

The key relevant to character tooling is `SavedPresetNames`:

```json
"SavedPresetNames": {
  "__type": "System.Collections.Generic.List`1[[System.String, mscorlib, ...]], mscorlib",
  "value": ["Snowball", "Kimmy", null, null, ...]
}
```

`value` is a sparse array where index = in-game slot number and element = character name string (or `null` for empty slots). The array may be very long (100+ elements).

All other keys in `SaveFile.es3` (progression data, mission stats, store unlocks, flags) are treated as opaque passthrough — they must survive read/write round-trips without modification.

### `presetSlot{n}.txt.tmp`

Each occupied character slot has a corresponding file named `presetSlot{n}.txt.tmp` where `n` is the zero-based slot index.

The file contains a znelchar JSON payload that has been JSON-stringified and placed as the sole content inside `{` … `}` brackets — as if it were an object key with no value. This is an artefact of the Easy Save 3 serialiser. The file is therefore **not valid JSON**.

Example structure (abbreviated):
```
{"{\"version\":\"v0.2\",\"isSynth\":false,\"blendshapes\":[...]}
```

Note: the closing `}` may be absent (EOF before it). Both cases must be handled.

**Parsing strategy:**
1. Read raw file content.
2. Strip leading `{` and, if present, trailing `}`.
3. JSON-unescape the resulting string to recover valid znelchar JSON.

**Round-trip write strategy:**
1. JSON-escape the znelchar JSON string.
2. Wrap: `{` + escaped-string (no closing brace, to match observed game output — or with closing brace; both are tolerated on read).

## Decision

Introduce `TVSSave.Tools` as a new PowerShell module following the same structure and distribution patterns as `Znelchar.Tools`:

- **Module distribution**: `tvs-save-module-<version>.zip` for PS module path users.
- **Core distribution**: `tvs-save-core-<version>.zip` (requires `pwsh` on PATH).
- No standalone portable bundle — the unified TVS Tools bundle (ADR-005) subsumes this.

### Dependency on Znelchar.Tools

`TVSSave.Tools` declares `Znelchar.Tools` as a required module. It does not re-implement character file extraction.

Per [ADR-007](./ADR-007-znelchar-direct-pipeline.md), `Znelchar.Tools` supports a **direct pipeline** in which `Expand-ZnelcharData` accepts a `.znelchar` file as input (not just `character.json`) and `Compress-ZnelcharData` produces a `.znelchar` file as output (not just `character.json`). The `.extracted/` intermediary state is an implementation detail that never surfaces to `TVSSave.Tools` or to end-users.

`Expand-TVSCharacterPreset` and `Compress-TVSCharacterPreset` therefore delegate directly to these two commands with no additional orchestration:

```powershell
# Expand-TVSCharacterPreset — simplified delegation
Expand-ZnelcharData -InputPath $SourcePath -OutputPath $OutputPath -Force

# Compress-TVSCharacterPreset — simplified delegation
Compress-ZnelcharData -InputPath $SourcePath -OutputPath $OutputPath -Force
```

No calls to `Export-ZnelcharContent` or `New-ZnelcharFile` are required inside `TVSSave.Tools`.

### Cmdlet surface

#### Private helpers

```powershell
# Parse SaveFile.es3; return @{ SlotIndex = int; Name = string }[] for occupied slots only
Read-TVSSaveIndex [-Path <string>]

# Round-trip SaveFile.es3, updating only SavedPresetNames; all other keys pass through untouched
Write-TVSSaveIndex [-Path <string>] -SlotNames <hashtable>

# Strip {…} wrapper + JSON-unescape → znelchar JSON string
ConvertFrom-TVSPresetSlot -Path <string>

# JSON-escape znelchar string + wrap in { … } → write presetSlot file
ConvertTo-TVSPresetSlot -ZnelcharJson <string> -OutputPath <string>
```

#### Public cmdlets

```powershell
# List occupied character slots (reads SaveFile.es3 via TVS.Environment playerDataDir)
Get-TVSSaveCharacterList [-Path <string>]

# Export one preset slot file → {characterWorkDir}/presets/{name}.znelchar
Export-TVSCharacterPreset [-Slot <int>] [-Name <string>] [-OutputPath <string>]

# Export all occupied preset slots
Export-TVSAllCharacterPresets [-OutputPath <string>]

# Import {characterWorkDir}/presets/{name}.znelchar → presetSlot{n}.txt.tmp
# -Force is required; warns that the game should not be running
Import-TVSCharacterPreset -Name <string> [-Slot <int>] [-SourcePath <string>] -Force

# Expand .znelchar → {characterWorkDir}/expanded/{name}/ via Znelchar.Tools direct pipeline (ADR-007)
Expand-TVSCharacterPreset [-Name <string>] [-SourcePath <string>] [-OutputPath <string>]

# Compress {characterWorkDir}/expanded/{name}/ → {characterWorkDir}/presets/{name}.znelchar via Znelchar.Tools direct pipeline (ADR-007)
Compress-TVSCharacterPreset -Name <string> [-SourcePath <string>] [-OutputPath <string>]

# Start background FSW watcher; returns watcher ID
# Default: exports .znelchar on game save change
# -Expand: also calls Expand-TVSCharacterPreset after export
Watch-TVSCharacterSync [-Path <string>] [-OutputPath <string>] [-Expand] [-Quiet]

# Stop watcher(s)
Stop-TVSCharacterSync [[-Id] <string>]
```

### File watcher design

`Watch-TVSCharacterSync` starts a background PS runspace with a `FileSystemWatcher` pointed at the player data directory and the `characterWorkDir/presets/` directory. Events are enqueued into a `[System.Collections.Concurrent.ConcurrentQueue]` and drained on a single processing thread to avoid races.

**Reaction rules:**

| Trigger | Reaction |
|---|---|
| `presetSlot{n}.txt.tmp` created or modified | `ConvertFrom-TVSPresetSlot` → write `presets/{name}.znelchar`; if `-Expand`, also `Expand-TVSCharacterPreset` |
| `presets/{name}.znelchar` created or modified | `ConvertTo-TVSPresetSlot` → write `presetSlot{n}.txt.tmp`; update `SaveFile.es3` if name changed |
| `SaveFile.es3` modified | Detect slot renames → rename corresponding `.znelchar` files and `expanded/` directories |

**Feedback-loop mitigation:**

- `$script:OutboundLocks`: per-path hashtable of `[datetime]` expiry (3 s window).
- Before writing any file, register its path in the lock table.
- On receiving an FSW event, skip processing if the path has an active outbound lock.
- 750 ms debounce delay before processing any event, allowing the game to complete all writes.

**Intentional one-way constraint:** the `expanded/` directories are **not watched**. Changes there do not trigger automatic compression back to `.znelchar`. This avoids feedback loops from partial multi-file edits. Users explicitly call `Compress-TVSCharacterPreset` or `tvsm save compress` when ready.

### Module location

```
tools/tvs-save/
  module/
    TVSSave.Tools/
      Public/
        Get-TVSSaveCharacterList.ps1
        Export-TVSCharacterPreset.ps1
        Export-TVSAllCharacterPresets.ps1
        Import-TVSCharacterPreset.ps1
        Expand-TVSCharacterPreset.ps1
        Compress-TVSCharacterPreset.ps1
        Watch-TVSCharacterSync.ps1
        Stop-TVSCharacterSync.ps1
      Private/
        Read-TVSSaveIndex.ps1
        Write-TVSSaveIndex.ps1
        ConvertFrom-TVSPresetSlot.ps1
        ConvertTo-TVSPresetSlot.ps1
        Invoke-SyncDebounce.ps1
      TVSSave.Tools.psd1
      TVSSave.Tools.psm1
  data/
    schemas/
      SaveFile.es3.schema.json
  docs/
    FORMAT.md
  tests/
    ConvertFrom-TVSPresetSlot.Tests.ps1
    Get-TVSSaveCharacterList.Tests.ps1
  build/
    package.ps1
  package.json
  rush-project.json
```

## Consequences

Positive:
- Clean separation of concerns: character file tools vs save file tools.
- `Znelchar.Tools` remains independently useful for content creators who do not interact with save files.
- File watcher workflow closes the loop between play sessions and character development.
- Same distribution pattern means contributors already familiar with one module can work on the other.
- `-Force` guard on `Import-TVSCharacterPreset` prevents accidental overwrites of live save data.
- `Expand-TVSCharacterPreset` and `Compress-TVSCharacterPreset` are thin delegations to `Znelchar.Tools`; no orchestration of extraction or repacking logic lives in `TVSSave.Tools`.

Tradeoffs:
- Users installing both modules independently face a two-step install; mitigated by the unified bundle.
- Save file format may evolve with game updates, requiring module updates; this is unavoidable. The opaque-passthrough strategy for `SaveFile.es3` minimises breakage surface.
- Background watcher runspace adds complexity; must be tested for resource leaks.
- The `{…}` wrapper format of `presetSlot{n}.txt.tmp` is not valid JSON; our parser must handle both with and without the closing brace.
- `Expand-TVSCharacterPreset` and `Compress-TVSCharacterPreset` correctness depends on the `Znelchar.Tools` direct pipeline being implemented (ADR-007). These cmdlets are non-functional until ADR-007 is shipped.

## Alternatives Considered

1. **Add save file commands to `Znelchar.Tools`.**
   - Rejected: violates the scope of a "character file" tool; would bloat the module for users who only need character operations.

2. **Implement save tooling as standalone scripts rather than a module.**
   - Rejected: standalone scripts cannot be imported and composed; no discoverability via `Get-Command`.

3. **Implement save tooling in C# within tvsm directly.**
   - Rejected: merges logic into the UI layer; prevents independent PS-module usage; harder to test.

4. **Watch the `expanded/` directory for changes and auto-compress.**
   - Rejected: multi-file edits are incremental; auto-compression on each partial file change would produce invalid intermediate states and create feedback loops. Explicit `compress` command preserves intent.

## Follow-Up Tasks

1. Create `tools/tvs-save` directory structure and Rush project.
2. Implement `Read-TVSSaveIndex` / `Write-TVSSaveIndex` with round-trip Pester tests.
3. Implement `ConvertFrom-TVSPresetSlot` / `ConvertTo-TVSPresetSlot` with round-trip Pester tests against the observed file format.
4. Implement `Export-TVSCharacterPreset` and `Export-TVSAllCharacterPresets`.
5. Implement `Import-TVSCharacterPreset` with `-Force` guard.
6. Implement ADR-007 direct pipeline in `Znelchar.Tools` (prerequisite for steps 7–8).
7. Fix `Expand-TVSCharacterPreset` — pass `.znelchar` path directly to `Expand-ZnelcharData`; remove stale intermediary logic.
8. Fix `Compress-TVSCharacterPreset` — pass expanded directory and `.znelchar` output path directly to `Compress-ZnelcharData`; remove stale intermediary logic.
9. Implement `Watch-TVSCharacterSync` and `Stop-TVSCharacterSync`; validate resource cleanup.
10. Wire `tvsm save` commands to the module.
11. Publish `SaveFile.es3.schema.json` and wire into `collect-schemas.js`.
