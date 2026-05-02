# characterWorkDir Layout

The `characterWorkDir` (configured via `TVS.Environment` as the `characterWorkDir` profile key) is the working directory for character data extracted from the game's player data. It holds editable source files and distribution artifacts for all character preset slots.

## Directory Structure

```
{characterWorkDir}/
  presets/
    presetSlot1/
      characterData.json          ← expanded (pretty-printed) _characterData
      textures/
        RitaTorso_D.jpg           ← copied from {playerDataDir}/SkinPresetTextures/
        RitaArms.jpg
        RitaLegs.jpg
        RitaHead1_D.jpg
    presetSlot2/
      characterData.json
      textures/
        ...
  exports/
    MyCharacter.znelchar          ← composed znelchar for distribution
    OtherCharacter.znelchar
```

## File Descriptions

### `presets/presetSlot{n}/characterData.json`

A pretty-printed copy of the raw `_characterData` JSON string from the game's `presetSlot{n}.tmp.txt` file. This is the full character payload, including:

- `blendshapes` — morph targets and their values
- `accessories` — equipped items with colors, blendshapes, and material overrides
- `skinData.skinMaterials` — skin material definitions; entries with a file extension in `diffuse` reference textures from `SkinPresetTextures/`
- All other character properties (voice, traits, opinions, etc.)

This file is the source-of-truth for the character's shape and equipment. It can be diffed in Git and edited by hand.

> **Note:** This is NOT a full `.znelchar` file. It is only the `_characterData` portion. To produce a portable `.znelchar`, use `Compose-ZnelcharPreset` (in `Znelchar.Tools`) which combines this file with the textures.

### `presets/presetSlot{n}/textures/`

Skin texture images copied directly from `{playerDataDir}/SkinPresetTextures/`. Only textures referenced in `characterData.json` at `skinData.skinMaterials[*].diffuse` (with a file extension) are copied here. Built-in game textures (bare names, no extension) are not present.

Files are copied as-is — **no base64 encoding**. This preserves the original image quality and avoids unnecessary encoding/decoding overhead in the live watch path.

### `exports/`

Distribution-ready `.znelchar` files produced by `Compose-ZnelcharPreset`. These are portable and self-contained (textures are base64-encoded inside the file). They are suitable for sharing with other players.

The `exports/` directory is not managed automatically — files here are written only by explicit export operations (`tvsm char export` / `Compose-ZnelcharPreset`).

## How Files Get Here

### Live watch path (automatic, no znelchar involved)

`Sync-TVSCharacterWorkDir` (called by `Watch-TVSCharacterSync` on save file change):

```
presetSlot{n}.tmp.txt ──► pretty-print JSON ──► presets/presetSlot{n}/characterData.json
SkinPresetTextures/*.jpg ──► file copy ──────► presets/presetSlot{n}/textures/
```

No znelchar encoding/decoding occurs. This is intentional: the game writes textures as discrete files, so copying them directly is the correct approach.

### Explicit export

`Compose-ZnelcharPreset` (in `Znelchar.Tools`), called by `tvsm char export`:

```
presets/presetSlot{n}/characterData.json ──┐
                                            ├──► exports/{name}.znelchar
presets/presetSlot{n}/textures/            ┘
```

### Explicit import

`Expand-ZnelcharPreset` (in `Znelchar.Tools`), called by `tvsm char import`:

```
{input}.znelchar ──► presets/presetSlot{n}/characterData.json
                 └──► presets/presetSlot{n}/textures/
                 └──► {playerDataDir}/SkinPresetTextures/  (written for game to load)
```

## Texture Detection Rules

When scanning `characterData.json` for texture references:

- `skinData.skinMaterials[*].diffuse` values **with a file extension** (`.jpg`, `.png`, `.bmp`, etc.) → custom player textures, present in `SkinPresetTextures/`
- `skinData.skinMaterials[*].diffuse` values **without a file extension** (bare name like `"Automata-Arms_1004"`) → built-in game asset, not in `SkinPresetTextures/`, skip

## Relationship to znelchar Expanded Format

This layout is **distinct** from the `character-expanded/` folder structure produced by `Expand-ZnelcharData` (in `Znelchar.Tools`). That format decomposes `_characterData` into a YAML/JSON folder hierarchy for Git collaboration and roundtrip back to a `.znelchar`.

The `characterWorkDir` layout is simpler: `characterData.json` is a single pretty-printed JSON file (not decomposed into per-section YAML files). It is optimised for developer inspection and diff-watching during live play sessions, not for structured Git editing of individual character properties.

If you want the full expanded/decomposed format for Git collaboration, use `Expand-ZnelcharData` on the `.znelchar` in `exports/`.
