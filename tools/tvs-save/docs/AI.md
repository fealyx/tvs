# AI Agent Context — tvs-save-tools

This document provides context for AI coding agents working in this project. For human-facing documentation, see [`CHARACTER-WORK-DIR.md`](CHARACTER-WORK-DIR.md) and [ADR-004](../../../../docs/ai/adr/ADR-004-tvs-save-tools-module.md).

## Project Summary

`tvs-save-tools` is a PowerShell module (`TVSSave.Tools`) for working with TVS game save files and the character working directory. Core capabilities:

- **List saves** (`Get-TVSSaveCharacterList`) — enumerate character presets from the player data directory
- **Export preset** (`Export-TVSCharacterPreset`) — export a character preset slot to a `.znelchar` file by composing `presetSlot{n}.tmp.txt` + `SkinPresetTextures/` textures
- **Import preset** (`Import-TVSCharacterPreset`) — import a `.znelchar` file into the game by writing `presetSlot{n}.tmp.txt` and `SkinPresetTextures/` textures
- **Expand preset** (`Expand-TVSCharacterPreset`) — expand a preset slot into the `characterWorkDir` layout (pretty-printed `characterData.json` + copied textures)
- **Compress preset** (`Compress-TVSCharacterPreset`) — re-compose a `.znelchar` from an expanded `characterWorkDir` slot
- **Export all** (`Export-TVSAllCharacterPresets`) — batch export all occupied preset slots
- **Sync work dir** (`Sync-TVSCharacterWorkDir`) — sync game save state directly into `characterWorkDir` without znelchar intermediary (used by the live watch path)
- **Watch** (`Watch-TVSCharacterSync`, `Stop-TVSCharacterSync`) — file-system watcher that calls `Sync-TVSCharacterWorkDir` on save change

## Module Architecture

```
module/TVSSave.Tools/
├── TVSSave.Tools.psd1       # Module manifest (RequiredModules: Znelchar.Tools)
├── TVSSave.Tools.psm1       # Module root (dot-sources all functions)
├── Public/                  # Exported commands (one function per file)
│   ├── ConvertFrom-TVSPresetSlot.ps1   # Parse presetSlot{n}.tmp.txt → object
│   ├── ConvertTo-TVSPresetSlot.ps1     # Serialize object → presetSlot{n}.tmp.txt
│   ├── Export-TVSCharacterPreset.ps1
│   ├── Import-TVSCharacterPreset.ps1
│   ├── Expand-TVSCharacterPreset.ps1
│   ├── Compress-TVSCharacterPreset.ps1
│   ├── Export-TVSAllCharacterPresets.ps1
│   ├── Get-TVSSaveCharacterList.ps1
│   ├── Sync-TVSCharacterWorkDir.ps1
│   ├── Watch-TVSCharacterSync.ps1
│   └── Stop-TVSCharacterSync.ps1  (or similar)
└── Private/                 # Internal helpers (not exported)
    ├── Invoke-SyncDebounce.ps1
    ├── Read-TVSSaveIndex.ps1
    └── Write-TVSSaveIndex.ps1
```

Public commands map 1:1 to `.ps1` files in `Public/`. Adding a new public command means adding a file there and updating `TVSSave.Tools.psd1`.

## Dependency on Znelchar.Tools

`TVSSave.Tools` declares `Znelchar.Tools` as a `RequiredModule`. It does **not** re-implement znelchar file format logic. When it needs to compose or decompose `.znelchar` envelopes (for explicit import/export operations), it calls:

- `Znelchar.Tools\Compose-ZnelcharPreset` — assemble `.znelchar` from `presetSlot` + textures
- `Znelchar.Tools\Expand-ZnelcharPreset` — extract `presetSlot` + textures from `.znelchar`

`ConvertFrom-TVSPresetSlot` and `ConvertTo-TVSPresetSlot` are public so `Znelchar.Tools` can call them when it needs to parse or serialize the `_characterData` payload.

## Live Watch vs. Import/Export

There are two distinct pipelines — **do not conflate them**:

| Pipeline | Trigger | Path | Znelchar involved? |
|----------|---------|------|--------------------|
| **Live watch** | Save file changes on disk | `presetSlot{n}.tmp.txt` + `SkinPresetTextures/` → `characterWorkDir/` via `Sync-TVSCharacterWorkDir` | **No** — direct file copy, no base64 |
| **Export** | User runs `tvsm char export` | `presetSlot{n}.tmp.txt` + `SkinPresetTextures/` → `Compose-ZnelcharPreset` → `.znelchar` | **Yes** |
| **Import** | User runs `tvsm char import` | `.znelchar` → `Expand-ZnelcharPreset` → `presetSlot{n}.tmp.txt` + `SkinPresetTextures/` | **Yes** |

The live watch path must **never** encode textures to base64 as an intermediary step. `Sync-TVSCharacterWorkDir` copies texture files directly from `SkinPresetTextures/` to `characterWorkDir/presets/presetSlot{n}/textures/`.

## characterWorkDir Layout

See [`CHARACTER-WORK-DIR.md`](CHARACTER-WORK-DIR.md) for the full spec. Summary:

```
{characterWorkDir}/
  presets/
    presetSlot1/
      characterData.json     ← pretty-printed _characterData
      textures/
        RitaTorso_D.jpg      ← copied from SkinPresetTextures (not base64)
        RitaArms.jpg
  exports/
    MyCharacter.znelchar     ← composed znelchar for distribution
```

## Key Schema

`schemas/SaveFile.es3.schema.json` — schema for the TVS `.es3` save file format (partially reverse-engineered; unknown fields are treated as opaque passthrough).

## Session Continuity

Session continuity for this monorepo is managed under `docs/ai/` at the repository root.

- Handoff template: `../../../../docs/ai/session/SESSION_HANDOFF_TEMPLATE.json`
- Handoff runbook: `../../../../docs/ai/session/SESSION_HANDOFF_WORKFLOW.md`
- ADR for this module: `../../../../docs/ai/adr/ADR-004-tvs-save-tools-module.md`
