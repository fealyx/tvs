# Expanded Character Data Format

For collaborative character development in Git, znelchar-tools supports an "expanded" format that decomposes `character.json` into a structured folder hierarchy of atomic YAML/JSON files.

## Workflow

1. **Export znelchar** → `extracted/`
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
   - Individual accessory changes in separate files
   - Different collaborators can edit different files in parallel
   - Git diffs are readable and granular

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
├── _metadata.yaml           # Schema version, source hash, timestamps
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
├── textures/                # Texture files copied from extracted textures/ (roundtripped by compress)
│   ├── SomeTexture_D.png
│   └── ...
└── images/                  # Optional: user-managed supplementary images (never packed)
    ├── cover.png
    └── ...
```

### Image directories

- **`customIcon.<ext>`** — decoded from `customIconData` in `_characterData`. Singular; re-embedded by `Compress-ZnelcharData` automatically.
- **`textures/`** — copied from the extracted `textures/` folder; re-used by `New-ZnelcharFile` to repack into `_textureDatas`. `Compress-ZnelcharData` returns its path as `TexturesPath` for convenience.
- **`images/`** — user-managed, never read or written by tooling. Safe to add cover art, reference sheets, etc.

## Format Preference

- **YAML (default)**: Human-readable, recommended for Git workflows
  ```powershell
  Expand-ZnelcharData -InputPath character.json -OutputPath character-expanded -Format yaml
  ```

- **JSON (optional)**: Also supported for programmatic access
  ```powershell
  Expand-ZnelcharData -InputPath character.json -OutputPath character-expanded -Format json
  ```

## Git Collaboration Benefits

1. **Atomic edits**: Each character element (accessory, bone, etc.) in its own file
2. **Parallel development**: Multiple people edit different files without conflicts
3. **Readable diffs**: Changes to individual items show clearly
4. **Merge-friendly**: Accidental conflicts in different items resolve easily
5. **Traceable history**: Git blame shows who changed what and when

## Schema Versioning

The `_metadata.yaml` file tracks the schema version:
```yaml
schemaVersion: 1
expandedAtUtc: "2025-04-26T12:34:56.789Z"
dataFormat: "yaml"
sourceFile: "character.json"
sourceHashSha256: "abc123..."
characterName: "Rita"
```

If you upgrade znelchar-tools and the schema changes:
```powershell
Update-ExpandedDataStructure -InputPath character-expanded -FromVersion 1 -ToVersion 2
```

Currently only schema v1 is implemented. Migration infrastructure is in place for future versions.

## Files Overview

| File | Contents |
|------|----------|
| `_metadata.yaml` | Versioning, source info, `hasCustomIcon`, `textureCount` |
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

## Notes

- The expanded structure is designed for human editing and Git collaboration
- The binary `.znelchar` format remains the distribution/storage format
- `customIconData` is decoded to `customIcon.<ext>` at the expanded root — not stored as base64 in `base.yaml`
- `textures/` is copied from the `textures/` folder produced by `Export-ZnelcharContent` and roundtripped back through `New-ZnelcharFile`
- `images/` is user-managed and completely ignored by all tooling
- Empty arrays and null values are preserved correctly
