# Expanded Character Data Format

For collaborative character development in Git, znelchar-tools supports an "expanded" format that decomposes character data into a structured folder hierarchy of atomic YAML/JSON files.

## Workflow

### Direct pipeline (recommended)

The direct pipeline requires no intermediary `character.json` or `.extracted/` directory. `Expand-ZnelcharData` accepts a `.znelchar` file directly; `Compress-ZnelcharData` produces a `.znelchar` file directly.

```powershell
# Expand a .znelchar to the structured format
Expand-ZnelcharData -InputPath character.znelchar -OutputPath character-expanded

# Edit files in character-expanded/ ...

# Compress back to .znelchar
Compress-ZnelcharData -InputPath character-expanded -OutputPath character.znelchar
```

Texture name mappings are preserved automatically in `_metadata.yaml` (see [Texture map in `_metadata.yaml`](#texture-map-in-_metadatayaml) below). No manifest file is needed.

### Explicit pipeline (advanced / diagnostic)

For users who need direct access to intermediary artifacts (`character.json`, `manifest.json`, extracted textures), the four-step explicit pipeline remains fully supported:

1. **Extract znelchar** → `extracted/`
   ```powershell
   Export-ZnelcharContent -InputPath character.znelchar -OutputPath extracted
   ```

2. **Expand to structured format** → `character-expanded/`
   ```powershell
   Expand-ZnelcharData -InputPath extracted/character.json -OutputPath character-expanded -Format yaml
   ```
   The `textures/` folder produced by `Export-ZnelcharContent` is auto-discovered as a
   sibling of `character.json` and copied into the expanded structure. Pass `-TexturesPath`
   explicitly to override the auto-discovery path.

3. **Edit files in version control** (Git, etc.)

4. **Compress back to JSON** → `character.json`
   ```powershell
   $result = Compress-ZnelcharData -InputPath character-expanded -OutputPath character.json
   # $result.TexturesPath points to character-expanded/textures/ if present
   ```

5. **Repack into znelchar** → `character.znelchar`
   ```powershell
   New-ZnelcharFile -CharacterJsonPath character.json -TexturesDir $result.TexturesPath -OutputPath character.znelchar
   # Or use the original manifest if you have it:
   New-ZnelcharFile -ManifestPath extracted/manifest.json -CharacterJsonPath character.json
   ```

## Folder Structure

```
character-expanded/
├── _metadata.yaml           # Schema version, source hash, timestamps, texture map
├── customIcon.png           # Custom icon image (if present in source character data)
├── base.yaml                # Top-level metadata (version, isSynth, voicePitch, etc.)
├── blendshapes.yaml         # Blendshape definitions
├── skeleton/
│   ├── bones.yaml           # Bone data
│   └── bone-offsets.yaml    # Bone offset data
├── skin/
│   ├── materials.yaml       # Skin material definitions
│   ├── eye-materials.yaml   # Eye material definitions
│   └── custom-materials.yaml # Custom material overrides
├── accessories/
│   ├── _index.yaml          # Accessory metadata
│   ├── {ItemName}.yaml      # Individual accessories (one file per item)
│   └── ...
├── vertex-accessories/
│   ├── _index.yaml          # Vertex accessory metadata
│   ├── {PrefabName}.yaml    # Individual vertex accessories
│   └── ...
├── occlusion-data.yaml      # Occlusion mapping data
├── behavior/
│   ├── opinions.yaml        # Character opinions and preferences
│   └── traits.yaml          # Character traits
├── ui/
│   └── colors.yaml          # UI color definitions
├── textures/                # Texture files (roundtripped by compress)
│   ├── SomeTexture_D.png
│   └── ...
└── images/                  # Optional: user-managed supplementary images (never packed)
    ├── cover.png
    └── ...
```

### Image directories

- **`customIcon.<ext>`** — decoded from `customIconData` in `_characterData`. Singular; re-embedded by `Compress-ZnelcharData` automatically.
- **`textures/`** — copied from the source texture data; re-used by `Compress-ZnelcharData` (direct pipeline) or `New-ZnelcharFile` (explicit pipeline) to repack into `_textureDatas`.
- **`images/`** — user-managed, never read or written by tooling. Safe to add cover art, reference sheets, etc.

## Texture map in `_metadata.yaml`

When a `.znelchar` file is expanded via the direct pipeline, `_metadata.yaml` includes a `textures` array that preserves the original `_textureName` → filename mapping from the `.znelchar` file's `_textureDatas` section. This allows `Compress-ZnelcharData` to reconstruct a correctly-named `.znelchar` without any external manifest:

```yaml
schemaVersion: 2
expandedAtUtc: "2026-05-02T19:00:00.000Z"
dataFormat: yaml
characterName: Snowball
textures:
  - textureName: "Snowball_Body_D"
    file: "Snowball_Body_D.png"
  - textureName: "Snowball_Face_D"
    file: "Snowball_Face_D.png"
```

When `character.json` is used as input (explicit pipeline), the `textures` field is omitted from `_metadata.yaml`. In this case, `Compress-ZnelcharData` falls back to sorted filenames from `textures/` when producing `.znelchar` output — the same behaviour as `New-ZnelcharFile` without a manifest.

## Format Preference

- **YAML (default)**: Human-readable, recommended for Git workflows
  ```powershell
  Expand-ZnelcharData -InputPath character.znelchar -OutputPath character-expanded -Format yaml
  ```

- **JSON (optional)**: Also supported for programmatic access
  ```powershell
  Expand-ZnelcharData -InputPath character.znelchar -OutputPath character-expanded -Format json
  ```

## Git Collaboration Benefits

1. **Atomic edits**: Each character element (accessory, bone, etc.) in its own file
2. **Parallel development**: Multiple people edit different files without conflicts
3. **Readable diffs**: Changes to individual items show clearly
4. **Merge-friendly**: Accidental conflicts in different items resolve easily
5. **Traceable history**: Git blame shows who changed what and when

## Schema Versioning

The `_metadata.yaml` file tracks the schema version:

| Version | Changes |
|---------|---------|
| 1 | Initial expanded format. No texture map. |
| 2 | Added `textures` array for direct-pipeline roundtrip support (ADR-007). |

Example `_metadata.yaml` (v2):
```yaml
schemaVersion: 2
expandedAtUtc: "2026-05-02T12:34:56.789Z"
dataFormat: yaml
sourceFile: "character.znelchar"
sourceHashSha256: "abc123..."
characterName: Rita
textures:
  - textureName: "Rita_Body_D"
    file: "Rita_Body_D.png"
```

If you upgrade znelchar-tools and the schema changes:
```powershell
Update-ExpandedDataStructure -InputPath character-expanded -FromVersion 1 -ToVersion 2
```

The v1→v2 migration adds an empty `textures: []` field to `_metadata.yaml`. No data is lost; the direct compress pipeline will fall back to sorted filenames when `textures` is empty.

## Files Overview

| File | Contents |
|------|----------|
| `_metadata.yaml` | Versioning, source info, `hasCustomIcon`, `textureCount`, `textures` map (v2+) |
| `customIcon.<ext>` | Custom icon image decoded from character data (if present) |
| `base.yaml` | Character metadata (name, version, isSynth, voicePitch, reaction set) |
| `blendshapes.yaml` | Map of blendshape name -> numeric value |
| `skeleton/bones.yaml` | Bone hierarchy and scale data |
| `skeleton/bone-offsets.yaml` | Per-bone offset data |
| `skin/materials.yaml` | Body part material definitions (diffuse, specular, normal) |
| `skin/eye-materials.yaml` | Eye material presets and properties |
| `skin/custom-materials.yaml` | Custom material overrides |
| `accessories/{name}.yaml` | Individual accessory: colors, materials, visibility, and `blendshapes` as map of blendshape name -> numeric value |
| `vertex-accessories/{name}.yaml` | Vertex-based attachment: prefab, parent, modifiers, and nested `blendshapes` collections normalized to name -> numeric value maps |
| `occlusion-data.yaml` | Body part occlusion mappings |
| `behavior/opinions.yaml` | Opinion system with `_opinions` as map of opinion id -> opinion fields |
| `behavior/traits.yaml` | Traits with `_traits` as map of trait id -> active boolean |
| `ui/colors.yaml` | UI color customization |
| `textures/` | Texture files for repacking (roundtripped) |
| `images/` | Optional supplementary images (user-managed, never packed) |

## Round-trip Guarantees

- **Semantically equivalent**: Expand → Edit → Compress → Expand produces identical results
- **No data loss**: All character properties preserved through the cycle
- **Deterministic JSON**: Condensed JSON uses consistent formatting for reliable diffs
- **Format agnostic**: YAML and JSON formats produce equivalent results
- **Self-contained**: An expanded directory produced from a `.znelchar` input contains everything needed to produce a new `.znelchar` — no external manifest or `extracted/` directory required

## Notes

- The expanded structure is designed for human editing and Git collaboration
- The binary `.znelchar` format remains the distribution/storage format
- `customIconData` is decoded to `customIcon.<ext>` at the expanded root — not stored as base64 in `base.yaml`
- `textures/` is roundtripped back through `Compress-ZnelcharData` (direct pipeline) or `New-ZnelcharFile` (explicit pipeline)
- `images/` is user-managed and completely ignored by all tooling
- Empty arrays and null values are preserved correctly
