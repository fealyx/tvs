# znelchar-tools

PowerShell tooling for working with `.znelchar` character files.

## Requirements

- **PowerShell 7+** (`pwsh`) — required
- **`powershell-yaml` module** — optional, only needed for `Convert-ZnelcharToYaml`
  ```powershell
  Install-Module powershell-yaml -Scope CurrentUser
  ```

## Getting Started

### Option A: PowerShell Module

Extract `znelchar-module-<version>.zip` to a PowerShell module path, then:

```powershell
Import-Module Znelchar.Tools
Get-Command -Module Znelchar.Tools
```

### Option B: Portable Distribution

Extract `znelchar-core-<version>.zip` (requires `pwsh` on PATH) or `znelchar-portable-<version>.zip` (includes a bundled runtime). Per-tool `.cmd` / `.sh` launchers are also included.

See [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) for full build and install details.

---

## Key Workflows

### Inspect a file

```powershell
Get-ZnelcharInfo -InputPath ./character.znelchar
Get-ZnelcharInfo -InputPath ./character.znelchar -MetadataOnly
```

### Extract contents

Decompresses a `.znelchar` into `character.json`, textures, and a `manifest.json`:

```powershell
Export-ZnelcharContent -InputPath ./character.znelchar -OutputPath ./extracted
```

### Expand for Git collaboration

Decomposes `character.json` into a human-readable YAML folder hierarchy — one file per accessory, section, and behaviour group — ideal for parallel editing and readable diffs:

```powershell
Expand-ZnelcharData -InputPath ./extracted/character.json -OutputPath ./character-expanded
```

Edit files in `character-expanded/`, then reassemble:

```powershell
Compress-ZnelcharData -InputPath ./character-expanded -OutputPath ./character.json
```

See [docs/EXPANDED-FORMAT.md](docs/EXPANDED-FORMAT.md) for the full folder structure and schema reference.

### Repack into a `.znelchar`

```powershell
New-ZnelcharFile -CharacterJsonPath ./character.json -OutputPath ./character.znelchar
```

With a manifest from a previous extraction:

```powershell
New-ZnelcharFile -ManifestPath ./extracted/manifest.json -OutputPath ./character.znelchar
```

### Verify files

Semantic comparison (not byte-for-byte):

```powershell
Test-ZnelcharFile -LeftPath ./original.znelchar -RightPath ./repacked.znelchar
```

Full extract → pack → verify roundtrip:

```powershell
Test-ZnelcharRoundtrip -InputPath ./character.znelchar -WorkDir ./roundtrip-out
```

---

## Further Reading

- [docs/FORMAT.md](docs/FORMAT.md) — `.znelchar` file format reference
- [docs/EXPANDED-FORMAT.md](docs/EXPANDED-FORMAT.md) — expanded folder structure and Git workflow
- [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) — packaging variants, portable launchers, and the updater
