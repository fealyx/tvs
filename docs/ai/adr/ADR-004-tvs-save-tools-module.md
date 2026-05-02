# ADR-004: TVSSave.Tools PowerShell Module

- Status: Amended
- Date: 2026-04-30 (amended 2026-05-02)
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
