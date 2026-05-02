# ADR-007: Znelchar.Tools Direct Pipeline — Eliminating the `character.json` Intermediary

- Status: Accepted
- Date: 2026-05-02
- Initiative: TVS Save Tools / Znelchar.Tools

## Context

The current `Znelchar.Tools` pipeline for working with `.znelchar` files involves four distinct steps and two on-disk intermediary states:

```
.znelchar
  ↓ Export-ZnelcharContent   → {name}.extracted/  (character.json + textures/ + manifest.json)
  ↓ Expand-ZnelcharData      → {name}.expanded/   (YAML/JSON multi-file tree)
  ↑ Compress-ZnelcharData    ← {name}.expanded/   (→ character.json)
  ↑ New-ZnelcharFile         ← character.json + textures/ + manifest.json  (→ .znelchar)
```

The `.extracted/` directory — containing `character.json`, `textures/`, and `manifest.json` — is a necessary intermediary in the current design. It was introduced because `Expand-ZnelcharData` and `Compress-ZnelcharData` were scoped to operate on `character.json`, not `.znelchar` files directly.

This two-phase structure creates real problems:

1. **`TVSSave.Tools` is broken.** [`Expand-TVSCharacterPreset`](../../../tools/tvs-save/module/TVSSave.Tools/Public/Expand-TVSCharacterPreset.ps1) passes a `.znelchar` file path to `Expand-ZnelcharData`, which requires a `.json` input and throws immediately. [`Compress-TVSCharacterPreset`](../../../tools/tvs-save/module/TVSSave.Tools/Public/Compress-TVSCharacterPreset.ps1) uses the wrong parameter name (`-InputDir` instead of `-InputPath`) and expects `.znelchar` output, but `Compress-ZnelcharData` produces `character.json`. Both cmdlets are non-functional as shipped.

2. **The intermediary state has no end-user value.** `character.json` is a raw game-format dump. The expanded YAML/JSON tree is the human-readable, Git-friendly form users actually care about. The `.extracted/` directory is implementation noise.

3. **`manifest.json` carries the texture name mapping** needed to round-trip textures back into a `.znelchar` correctly (the `_textureName` values from the game's internal naming scheme). If the extracted state is destroyed, this mapping is lost — or must be reconstructed heuristically from sorted filenames, which may not match the original ordering.

4. **The expanded format already contains `textures/`**, copied from the `.extracted/textures/` folder by `Expand-ZnelcharData`. The texture files are therefore present in the expanded tree; only the name→filename mapping from `manifest.json` is missing.

The solution is to:
- Extend `Expand-ZnelcharData` to accept a `.znelchar` file as `-InputPath` (in addition to `character.json`), inlining the extraction step.
- Extend `_metadata.yaml` to embed the texture name map so the expanded tree is fully self-contained for repacking.
- Extend `Compress-ZnelcharData` to produce a `.znelchar` file as `-OutputPath` (in addition to `character.json`), inlining the `New-ZnelcharFile` step when a `.znelchar` output is requested.
- Retain `Export-ZnelcharContent` and `New-ZnelcharFile` as first-class public commands for users who need explicit control over intermediary artifacts.

## Decision

### 1. `Expand-ZnelcharData` accepts `.znelchar` input

When `-InputPath` resolves to a `.znelchar` file (detected by extension), `Expand-ZnelcharData` will:

1. Inline the extraction logic currently in `Export-ZnelcharContent` — read the outer JSON envelope, parse `_characterData`, decode `_textureDatas`.
2. Write the expanded YAML/JSON tree to `-OutputPath` as today.
3. Write `textures/` into the expanded tree as today (no change).
4. **Embed the texture name map in `_metadata.yaml`** (see §3 below) so no separate `manifest.json` is needed for repacking.

The existing `.json` input path remains supported without change. The `-TexturesPath` parameter retains its meaning when input is `character.json`.

### 2. `Compress-ZnelcharData` produces `.znelchar` output

When `-OutputPath` ends in `.znelchar`, `Compress-ZnelcharData` will:

1. Reconstruct `character.json` in memory (no temp file written to disk unless `-KeepIntermediaryJson` is passed).
2. Read the texture name map from `_metadata.yaml` in the expanded tree.
3. Call `New-ZnelcharFile` internally to produce the `.znelchar` output.

When `-OutputPath` ends in `.json` (the existing behaviour), `Compress-ZnelcharData` continues to produce `character.json` only — no behaviour change.

A `-KeepIntermediaryJson` switch may be passed to write the reconstructed `character.json` alongside the `.znelchar` output, for diagnostic purposes.

### 3. Texture name map in `_metadata.yaml`

`_metadata.yaml` gains a new optional field: `textures`. This is an ordered array of objects preserving the original `_textureName` → filename mapping from the `.znelchar` file's `_textureDatas` array:

```yaml
textures:
  - textureName: "CharacterName_Body_D"
    file: "CharacterName_Body_D.png"
  - textureName: "CharacterName_Face_D"
    file: "CharacterName_Face_D.png"
```

When `Expand-ZnelcharData` processes a `.znelchar` input, it populates this field. When it processes a `character.json` input, this field is omitted (the caller must supply texture information via `-TexturesPath` or a manifest to `New-ZnelcharFile`).

`Compress-ZnelcharData` reads this field when producing `.znelchar` output. If the field is absent and `.znelchar` output is requested, it falls back to sorted filenames from `textures/` (same behaviour as the current `New-ZnelcharFile` fallback).

### 4. `Export-ZnelcharContent` and `New-ZnelcharFile` remain public

These commands are retained as first-class public API for:
- Users who need the `character.json` intermediary for custom tooling or inspection.
- Users who want to manage texture directories manually before repacking.
- Diagnostic and round-trip verification workflows.

They are not deprecated. The direct pipeline is an additive capability.

### 5. Updated pipeline diagrams

**New direct pipeline (end-user workflow):**

```
.znelchar
  ↓ Expand-ZnelcharData -InputPath character.znelchar -OutputPath expanded/
  ↑ Compress-ZnelcharData -InputPath expanded/ -OutputPath character.znelchar
```

**Explicit pipeline (advanced / diagnostic):**

```
.znelchar
  ↓ Export-ZnelcharContent    → extracted/  (character.json + textures/ + manifest.json)
  ↓ Expand-ZnelcharData       → expanded/   (YAML/JSON tree + textures/)
  ↑ Compress-ZnelcharData     → character.json
  ↑ New-ZnelcharFile          → .znelchar
```

### 6. Impact on `TVSSave.Tools`

With the direct pipeline in place, [`Expand-TVSCharacterPreset`](../../../tools/tvs-save/module/TVSSave.Tools/Public/Expand-TVSCharacterPreset.ps1) and [`Compress-TVSCharacterPreset`](../../../tools/tvs-save/module/TVSSave.Tools/Public/Compress-TVSCharacterPreset.ps1) become correct simple delegations:

```powershell
# Expand-TVSCharacterPreset (corrected)
Expand-ZnelcharData -InputPath $SourcePath -OutputPath $OutputPath -Force

# Compress-TVSCharacterPreset (corrected)
Compress-ZnelcharData -InputPath $SourcePath -OutputPath $OutputPath -Force
```

No orchestration of `Export-ZnelcharContent` or `New-ZnelcharFile` is required in `TVSSave.Tools`. See [ADR-004](./ADR-004-tvs-save-tools-module.md) for the updated `TVSSave.Tools` design.

## Consequences

**Positive:**
- `TVSSave.Tools` `Expand-TVSCharacterPreset` and `Compress-TVSCharacterPreset` become correct and non-broken.
- End-users working with `.znelchar` files never need to manage an `.extracted/` directory.
- The expanded tree is fully self-contained: `Compress-ZnelcharData` can produce a valid `.znelchar` from the expanded directory alone, with no external manifest required.
- `Export-ZnelcharContent` + `New-ZnelcharFile` remain available for users who need granular control.

**Tradeoffs:**
- `Expand-ZnelcharData` gains dual-mode input handling (`.znelchar` vs `.json`). The existing `.json` validation must be relaxed or made conditional on extension.
- `_metadata.yaml` schema version must be incremented to v2 to reflect the new `textures` field. `Update-ExpandedDataStructure` must handle the v1→v2 migration (which is a no-op in terms of data — it simply adds an empty `textures: []` field).
- `Compress-ZnelcharData` gains dual-mode output handling (`.json` vs `.znelchar`). The `-OutputPath` validation must branch on extension.

## Alternatives Considered

1. **Persistent `unpacked/` directory alongside `expanded/`.**
   Rejected: creates three simultaneous on-disk representations of the same character (`presets/`, `unpacked/`, `expanded/`). Stale `unpacked/` data becomes a footgun — old textures or manifests could corrupt a repack. No end-user value.

2. **Temp directory destroyed after operations (TVSSave.Tools orchestrates).**
   Rejected for the general case: `manifest.json` is destroyed with the temp dir, losing the texture name mapping. The fallback (sorted filenames) is fragile. Rejected for TVSSave.Tools specifically: it should not need to know about the extraction pipeline internals.

3. **Keep the current four-step pipeline; fix TVSSave.Tools to orchestrate it.**
   Rejected: forces TVSSave.Tools to manage a persistent extracted state, adds complexity, and doesn't solve the end-user ergonomics problem. The intermediary remains visible.

## Follow-Up Tasks

1. Extend `Expand-ZnelcharData` to accept `.znelchar` input; inline extraction logic.
2. Add `textures` array to `_metadata.yaml` schema (v2); update `character-expanded-metadata.schema.json`.
3. Implement `Update-ExpandedDataStructure` v1→v2 migration (no-op data migration; adds empty `textures` field).
4. Extend `Compress-ZnelcharData` to produce `.znelchar` output when `-OutputPath` ends in `.znelchar`.
5. Fix [`Expand-TVSCharacterPreset`](../../../tools/tvs-save/module/TVSSave.Tools/Public/Expand-TVSCharacterPreset.ps1) — remove `-InputDir`/`-OutputDir` mismatch; call `Expand-ZnelcharData` with `.znelchar` input path directly.
6. Fix [`Compress-TVSCharacterPreset`](../../../tools/tvs-save/module/TVSSave.Tools/Public/Compress-TVSCharacterPreset.ps1) — call `Compress-ZnelcharData` with `.znelchar` output path directly.
7. Update [`tools/znelchar/docs/EXPANDED-FORMAT.md`](../../../tools/znelchar/docs/EXPANDED-FORMAT.md) to document the new direct workflow.
8. Update [`tools/znelchar/docs/AI.md`](../../../tools/znelchar/docs/AI.md) to reflect the revised cmdlet surface.
9. Add/update roundtrip Pester tests covering `.znelchar` → `Expand-ZnelcharData` → `Compress-ZnelcharData` → `.znelchar`.
