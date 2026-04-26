# znelchar format notes

## Outer object

- `_characterData`: string containing escaped JSON.
- `_textureDatas`: optional array of texture entries.

## Texture entry shape

- `_textureName`: file-like texture name (for example `myTexture.png`).
- `_textureData`: base64 payload for texture bytes.

## Known behavior

- Some files have empty `_textureDatas` arrays.
- `_characterData` can itself include nested escaped JSON strings in some properties.
- Additional top-level and nested keys may exist; tooling should preserve unknown keys.

---

# Expanded Character Data Format

For collaborative character development in Git, znelchar-tools supports an "expanded" format that decomposes `character.json` into a structured folder hierarchy of atomic YAML/JSON files.

## Workflow

1. **Export znelchar** → `extracted/character.json`
   ```powershell
   Export-ZnelcharContent -InputPath character.znelchar -OutputPath extracted
   ```

2. **Expand to structured format** → `character-expanded/`
   ```powershell
   Expand-ZnelcharData -InputPath extracted/character.json -OutputPath character-expanded -Format yaml
   ```

3. **Edit files in version control** (Git, etc.)
   - Individual accessory changes in separate files
   - Different collaborators can edit different files in parallel
   - Git diffs are readable and granular

4. **Compress back to JSON** → `character.json`
   ```powershell
   Compress-ZnelcharData -InputPath character-expanded -OutputPath character.json
   ```

5. **Repack into znelchar** → `character.znelchar`
   ```powershell
   New-ZnelcharFile -CharacterJsonPath character.json -OutputPath character.znelchar
   ```

## Folder Structure

```
character-expanded/
├── _metadata.yaml           # Schema version, source hash, timestamps
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
└── ui/
    └── colors.yaml          # UI color definitions
```

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
| `_metadata.yaml` | Versioning, source info |
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

## Round-trip Guarantees

- **Semantically equivalent**: Expand → Edit → Compress → Expand produces identical results
- **No data loss**: All character properties preserved through the cycle
- **Deterministic JSON**: Condensed JSON uses consistent formatting for reliable diffs
- **Format agnostic**: YAML and JSON formats produce equivalent results

## Notes

- The expanded structure is designed for human editing and Git collaboration
- The binary `.znelchar` format remains the distribution/storage format
- Textures remain in a separate `/textures/` folder alongside the expanded structure
- Custom icons are handled separately during packing/unpacking
- Empty arrays and null values are preserved correctly
