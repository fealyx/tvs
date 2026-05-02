# ADR-004: TVSSave.Tools PowerShell Module

- Status: Amended
- Date: 2026-04-30 (amended 2026-05-02)
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
2. Research TVS save file format; document findings in `tools/tvs-save/docs/FORMAT.md`.
3. Implement `Get-TVSSaveInfo` and `Export-TVSSaveContent` as the first vertical slice.
4. Implement `Watch-TVSSaveDirectory` and validate resource cleanup.
5. Wire `tvsm save` commands to the module via the PS runspace in `tvsm`.

---

## Amendment (2026-05-02): Znelchar File Structure, Texture Storage, and Character Data Re-Composition/Decomposition

### Corrected Understanding of presetSlot Files

> **Previous assumption (now invalidated):** `presetSlot{n}.tmp.txt` files were believed to contain the full `.znelchar` file content.

**Corrected understanding:** `presetSlot{n}.tmp.txt` files contain **only the `_characterData` portion** of a `.znelchar` file — specifically, the raw character payload JSON string. The full `.znelchar` structure is a distinct envelope that wraps this content together with encoded texture data.

### Full Znelchar File Structure

A `.znelchar` file exported via `Export-TVSCharacterPreset` is a JSON object with two top-level fields:

```json
{
  "_characterData": "<escaped JSON string — contents of presetSlot{n}.tmp.txt>",
  "_textureDatas": [
    {
      "_textureName": "RitaTorso_D.jpg",
      "_textureData": "<base64-encoded image bytes>"
    },
    {
      "_textureName": "RitaArms.jpg",
      "_textureData": "<base64-encoded image bytes>"
    }
  ]
}
```

This structure is already reflected in [`tools/znelchar/schemas/znelchar.schema.json`](../../../tools/znelchar/schemas/znelchar.schema.json) which defines `_characterData` as an escaped JSON string and `_textureDatas` as an array of `{ _textureName, _textureData }` objects. The schema is correct; the prior working assumption about `presetSlot` files was not.

Reference: [`temp/character-work/presets/Reeda.znelchar.pretty-print.json`](../../../temp/character-work/presets/Reeda.znelchar.pretty-print.json) is the pretty-printed `_characterData` payload for the Reeda character preset (not a full znelchar envelope).

### Texture Storage Location

Game-persisted character skin textures are stored as **discrete image files** in:

```
{playerDataDir}/SkinPresetTextures/
```

Example files observed in [`temp/playerdata/SkinPresetTextures`](../../../temp/playerdata/SkinPresetTextures):

| File | Skin category |
|------|--------------|
| `RitaTorso_D.jpg` | Torso diffuse (category 0) |
| `RitaArms.jpg` | Arms diffuse (category 1) |
| `RitaLegs.jpg` | Legs diffuse (category 2) |
| `RitaHead1_D.jpg` | Head/face diffuse (category 3, 8) |

Texture filenames are referenced within the `_characterData` payload under `skinData.skinMaterials[*].diffuse`. Entries whose `diffuse` value contains a file extension (e.g. `.jpg`) are custom player textures sourced from `SkinPresetTextures`; entries referencing bare asset names (e.g. `"Automata-Arms_1004"`) are built-in game textures and are **not** stored in `SkinPresetTextures`.

### Re-Composition: presetSlot → znelchar

Re-composition assembles a portable `.znelchar` file from the game's persisted character state. The pipeline is:

```
presetSlot{n}.tmp.txt   ──┐
                           ├──► Compose-ZnelcharPreset ──► output.znelchar
SkinPresetTextures/        ┘
  RitaTorso_D.jpg
  RitaArms.jpg
  ...
```

**Steps:**

1. Read `presetSlot{n}.tmp.txt` as a raw string → this becomes the `_characterData` value.
2. Parse the JSON in `_characterData` to extract `skinData.skinMaterials[*].diffuse` values.
3. Filter to filenames that have a file extension (`.jpg`, `.png`, etc.) — these are custom textures.
4. For each custom texture filename, locate the matching file in `{playerDataDir}/SkinPresetTextures/`.
5. Base64-encode each located file's bytes.
6. Construct the `_textureDatas` array: `[{ _textureName: "<filename>", _textureData: "<base64>" }, ...]`.
7. Serialize `{ _characterData: "<raw string from step 1>", _textureDatas: [...] }` as JSON → write to `.znelchar`.

**Error conditions to handle:**
- A referenced texture filename is not found in `SkinPresetTextures` → warn and skip (do not fail); the resulting znelchar will be missing that texture.
- `presetSlot{n}.tmp.txt` does not exist or is empty → fail early with a clear message.

### Decomposition: znelchar → presetSlot

Decomposition extracts game-ready files from an imported `.znelchar`. The pipeline is:

```
input.znelchar ──► Expand-ZnelcharPreset ──► presetSlot{n}.tmp.txt
                                         └──► SkinPresetTextures/
                                                RitaTorso_D.jpg
                                                RitaArms.jpg
                                                ...
```

**Steps:**

1. Parse the `.znelchar` JSON envelope.
2. Write `_characterData` (the raw string value, not re-serialized) to `presetSlot{n}.tmp.txt`.
3. For each entry in `_textureDatas`:
   a. Base64-decode `_textureData` to raw image bytes.
   b. Write bytes to `{playerDataDir}/SkinPresetTextures/{_textureName}`.
4. Confirm that every `diffuse` filename referenced in `_characterData.skinData.skinMaterials` is accounted for in `SkinPresetTextures` after extraction (validation step, warn-only).

**Filename resolution:** `_textureName` values in `_textureDatas` are expected to match the `diffuse` values in `_characterData` exactly (including extension). No renaming or transformation is required.

**Collision policy:** If a file already exists in `SkinPresetTextures` with the same name, overwrite by default; offer `-NoClobber` flag to skip existing files.

### Refactoring Evaluation

#### Pipeline refactoring (texture encoding/decoding in intermediary steps)

The prior pipeline in `TVSSave.Tools` conceived of znelchar files as intermediary artifacts that always carried texture data through base64 encoding. Now that texture storage is confirmed to be `SkinPresetTextures` as discrete files:

- **Save-watch pipeline:** `Watch-TVSSaveDirectory` → `Export-TVSSaveContent` currently calls `Export-ZnelcharContent` + `Expand-ZnelcharData` to decompose embedded character data. This remains correct for processing **imported** znelchar files (i.e., znelchar files that arrived from outside the game and were not generated by the game's own export). However, for the **live save-watch workflow** where the game writes `presetSlot{n}.tmp.txt` directly, no znelchar file is involved at all — the pipeline should read `presetSlot{n}.tmp.txt` directly and copy changed textures from `SkinPresetTextures` to the `characterWorkDir` without any encoding/decoding round-trip.
- **Recommendation:** Introduce a dedicated `Sync-TVSCharacterWorkDir` private function that reads `presetSlot{n}.tmp.txt` + `SkinPresetTextures` and writes the expanded work directory without going through znelchar composition. Reserve znelchar composition/decomposition for explicit import/export operations.
- **No unnecessary base64 in intermediary steps:** The previous design that encoded textures into a znelchar as an intermediary before writing them to `characterWorkDir` should be removed. Textures should be copied as raw files from `SkinPresetTextures` to `characterWorkDir/textures/` directly.

#### `characterWorkDir` organization

Given that textures are stored separately from `_characterData`, the `characterWorkDir` layout should mirror this split:

```
{characterWorkDir}/
  presets/
    presetSlot1/
      characterData.json          ← expanded (pretty-printed) _characterData
      textures/
        RitaTorso_D.jpg           ← copied from SkinPresetTextures
        RitaArms.jpg
        RitaLegs.jpg
        RitaHead1_D.jpg
  exports/
    MyCharacter.znelchar          ← composed znelchar for distribution
```

This layout makes it unambiguous which files are the editable source-of-truth (`characterData.json`, `textures/`) vs. distribution artifacts (`exports/`). It avoids any confusion between raw `presetSlot{n}.tmp.txt` content and a full znelchar envelope.

**Decision:** Adopt the above `characterWorkDir` layout as the standard for Phase 3 implementation. The `Sync-TVSCharacterWorkDir` function should write to this structure. `Compose-ZnelcharPreset` and `Expand-ZnelcharPreset` cmdlets should accept paths conforming to this layout as their working directory parameter.
