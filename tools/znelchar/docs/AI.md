# AI Agent Context — znelchar-tools

This document provides context for AI coding agents working in this project. For human-facing documentation, see the root [README.md](../README.md) and the other files in this `docs/` folder.

## Project Summary

`znelchar-tools` is a PowerShell module (`Znelchar.Tools`) for working with `.znelchar` character files. Core capabilities:

- **Inspect** — read metadata and structure from a `.znelchar` file
- **Extract** (`Export-ZnelcharContent`) — decompress a `.znelchar` into `character.json`, textures, and a manifest
- **Expand** (`Expand-ZnelcharData`) — decompose `character.json` into a YAML/JSON folder hierarchy for Git collaboration
- **Compress** (`Compress-ZnelcharData`) — reconstruct `character.json` from an expanded folder hierarchy
- **Repack** (`New-ZnelcharFile`) — build a `.znelchar` from extracted artifacts
- **Verify** (`Test-ZnelcharFile`, `Test-ZnelcharRoundtrip`) — semantic comparison and roundtrip validation
- **Update** (`Update-ZnelcharTools`) — in-place updater for distributed installs
- **Compose from game save** (`Compose-ZnelcharPreset`) — assemble a portable `.znelchar` from a game-persisted `presetSlot{n}.tmp.txt` file and the matching skin textures in `{playerDataDir}/SkinPresetTextures/`
- **Decompose to game save** (`Expand-ZnelcharPreset`) — extract `_characterData` and `_textureDatas` from a `.znelchar` back into `presetSlot{n}.tmp.txt` and `SkinPresetTextures/` so the game can load the character

## Module Architecture

```
module/Znelchar.Tools/
├── Znelchar.Tools.psd1       # Module manifest
├── Znelchar.Tools.psm1       # Module root (dot-sources all functions)
├── Public/                   # Exported commands (one function per file)
└── Private/                  # Internal helpers (not exported)
```

Public commands map 1:1 to `.ps1` files in `Public/`. Adding a new public command means adding a file there and updating `Znelchar.Tools.psd1`.

Schemas for validation and documentation live in `schemas/`.

## Game-Save Integration

Two cmdlets bridge `Znelchar.Tools` with the TVS game's live character save state:

| Cmdlet | Direction | Source / Target |
|--------|-----------|-----------------|
| `Compose-ZnelcharPreset` | game save → `.znelchar` | Reads `presetSlot{n}.tmp.txt` + `SkinPresetTextures/*.jpg` |
| `Expand-ZnelcharPreset` | `.znelchar` → game save | Writes `presetSlot{n}.tmp.txt` + `SkinPresetTextures/*.jpg` |

**Key facts about game save character data:**

- `presetSlot{n}.tmp.txt` contains the raw `_characterData` JSON string (the escaped-JSON field of a `.znelchar`), not a full znelchar envelope.
- Skin textures are stored by the game as discrete `.jpg` files in `{playerDataDir}/SkinPresetTextures/`.
- Custom texture filenames appear in `_characterData` at `skinData.skinMaterials[*].diffuse` with a file extension (e.g. `RitaTorso_D.jpg`). Built-in game textures use bare names (no extension) and are **not** present in `SkinPresetTextures`.
- These cmdlets are for explicit import/export. The live save-watch hot path in `TVSSave.Tools` uses `Sync-TVSCharacterWorkDir` to copy files directly without znelchar encoding.

## Key Schemas

| Schema | Purpose |
|--------|---------|
| `schemas/znelchar.schema.json` | Outer `.znelchar` file format |
| `schemas/characterData.schema.json` | `_characterData` inner JSON |
| `schemas/manifest.schema.json` | Extraction manifest (`manifest.json`) |
| `schemas/character-expanded.schema.json` | Expanded folder structure |
| `schemas/character-expanded-metadata.schema.json` | `_metadata.yaml` in expanded structure |
| `schemas/opinionDataString.schema.json` | `opinionDataString` nested payload |
| `schemas/releaseManifest.schema.json` | Distribution release manifest |

## npm Scripts

`package.json` at the project root exposes scripts that wrap the PowerShell scripts in `scripts/`. These are development and CI shortcuts; end-users use the PowerShell module directly or portable launchers. See [docs/README.md](README.md) for the full script reference.

## Session Continuity

Session continuity for this monorepo is managed under `docs/ai/` at the repository root.

- Handoff template: `../../../docs/ai/SESSION_HANDOFF_TEMPLATE.json`
- Handoff runbook: `../../../docs/ai/SESSION_HANDOFF_WORKFLOW.md`
- Recommended local-only snapshot (gitignored): `../../../temp/ai/session-handoff.latest.json`
