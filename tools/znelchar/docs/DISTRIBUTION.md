# Distribution Build

## ⚠️ Portable Distribution Deprecation Notice

The `znelchar-portable-<version>.zip` distribution is **deprecated** as of Phase 4 (TVSM Manager Initiative).

**Replacement:** [`tvs-tools-full-<version>.zip`](../../docs/ai/adr/ADR-005-unified-tvs-tools-bundle.md) (includes bundled `pwsh` runtime)

**Why:** The new TVSM Unified Bundle includes Znelchar.Tools, TVSSave.Tools, TVS.Environment, and tvsm in a single download with shared `pwsh` runtime.

**For users with their own `pwsh`:** Use [`tvs-tools-core-<version>.zip`](../../docs/ai/adr/ADR-005-unified-tvs-tools-bundle.md) (no bundled runtime).

**Migration:** Download the appropriate tvs-tools bundle from the [releases page](../../docs/ai/adr/ADR-005-unified-tvs-tools-bundle.md). Your existing workflows will continue to work via backwards-compatible launchers.

See [`DEPRECATION_NOTICE.md`](../DEPRECATION_NOTICE.md) for full details.

## Overview

`build/package.ps1` creates three distribution variants:

- `znelchar-module-<version>.zip` — for PowerShell module path users (continued)
- `znelchar-core-<version>.zip` — portable without bundled runtime (continued)
- `znelchar-portable-<version>.zip` — ⚠️ **deprecated**, replaced by `tvs-tools-full-<version>.zip`

Build output also includes release metadata files:

- `znelchar-release-manifest.json`
- `SHA256SUMS.txt`

## Unified TVS Tools Bundle

As of Phase 4, the primary end-user distribution is the **Unified TVS Tools Bundle**, published in two variants:

| Artifact | Includes `pwsh` runtime | Audience |
|----------|-------------------------|----------|
| `tvs-tools-full-<version>.zip` | Yes (win-x64) | Windows end-users who want a zero-prerequisite install |
| `tvs-tools-core-<version>.zip` | No | Users/CI/Linux who provide their own `pwsh` |

The unified bundle includes:
- `TVSM` (TVSM Manager) — main entry point
- `Znelchar.Tools` — character file tools
- `TVSSave.Tools` — save file tools
- `TVS.Environment` — shared environment profile
- Bundled `pwsh` 7.x runtime (in `-full` variant only)

### When to Use Each Variant

**Use `tvs-tools-full` if:**
- You're a Windows end-user who wants everything in one download
- You don't have PowerShell 7 installed
- You want a zero-prerequisite install experience

**Use `tvs-tools-core` if:**
- You're a developer or CI environment with `pwsh` already on PATH
- You're on Linux/macOS
- You want a lightweight download without the runtime

### Backwards Compatibility

The unified bundle includes per-tool launchers for backwards compatibility:
- `inspect.cmd` / `inspect.sh`
- `extract.cmd` / `extract.sh`
- `expand.cmd` / `expand.sh`
- `compress.cmd` / `compress.sh`
- `pack.cmd` / `pack.sh`
- `dump-yaml.cmd` / `dump-yaml.sh`
- `verify.cmd` / `verify.sh`
- `update.cmd` / `update.sh`

Existing workflows and shortcuts continue to work with these launchers.

For full details, see [ADR-005: Unified TVS Tools Distribution Bundle](../../docs/ai/adr/ADR-005-unified-tvs-tools-bundle.md).

## Build Commands

From `tools/znelchar`:

```powershell
npm run build:dist
```

Only module package:

```powershell
npm run build:dist:module
```

Only core package:

```powershell
npm run build:dist:core
```

Only portable package: ⚠️ **Deprecated**

```powershell
npm run build:dist:portable
```

> **Note:** For the new unified bundle, use `tools/tvsm/build/package-unified.ps1` instead.

## Portable Runtime Options

> ⚠️ **Deprecated:** The `znelchar-portable` variant is deprecated. Use `tvs-tools-full-<version>.zip` for a bundled runtime experience.

`core` never includes a bundled runtime and always relies on host `pwsh`.

`portable` (deprecated) could optionally include a bundled runtime.

To include a pre-downloaded PowerShell portable zip (deprecated, for legacy builds only):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./build/package.ps1 -CreatePortable -CreateModule:$false -CreateCore:$false -PortableRuntimeZipPath C:/downloads/PowerShell-7.5.0-win-x64.zip
```

To download from GitHub releases during build (deprecated, for legacy builds only):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./build/package.ps1 -CreatePortable -CreateModule:$false -CreateCore:$false -DownloadPortableRuntime -PortableRuntimeVersion 7.5.0 -PortableRuntimeRid win-x64
```

To emit release URLs in the manifest (used for updater workflows):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./build/package.ps1 -ReleaseRepositoryOwner <owner> -ReleaseRepositoryName <repo>
```

## Portable Launchers

> ⚠️ **Note:** The `znelchar-portable` variant is deprecated. The unified bundle (`tvs-tools-full` or `tvs-tools-core`) includes these launchers.

`core` and (deprecated) `portable` bundles include direct per-tool launchers:

- `inspect.cmd` / `inspect.sh`
- `extract.cmd` / `extract.sh`
- `expand.cmd` / `expand.sh`
- `compress.cmd` / `compress.sh`
- `pack.cmd` / `pack.sh`
- `dump-yaml.cmd` / `dump-yaml.sh`
- `verify.cmd` / `verify.sh`
- `verify-roundtrip.cmd` / `verify-roundtrip.sh`
- `update.cmd` / `update.sh`

Legacy shims are still included:

- `run-znelchar.cmd`
- `run-znelchar.sh`

Usage example:

```powershell
./inspect.cmd -InputPath ./samples/Foxy.znelchar -MetadataOnly
```

Updater example:

```powershell
./update.cmd -Operation check -Variant core -ManifestPath ./znelchar-release-manifest.json
```

> **Migration:** In the unified bundle, these launchers are located in the `launchers/` directory.

## Module Usage

After extracting `znelchar-module-<version>.zip` to a PowerShell module path:

```powershell
Import-Module Znelchar.Tools
Get-Command -Module Znelchar.Tools
```

Exposed commands:

- `Get-ZnelcharInfo`
- `Export-ZnelcharContent`
- `Expand-ZnelcharData` — decomposes `character.json` into a YAML/JSON folder hierarchy
- `Compress-ZnelcharData` — reconstructs `character.json` from an expanded folder hierarchy
- `New-ZnelcharFile`
- `Convert-ZnelcharToYaml`
- `Test-ZnelcharFile`
- `Test-ZnelcharRoundtrip`
- `Update-ZnelcharTools`

## Updater Workflows

Check for updates using local release metadata:

```powershell
npm run update:check -- -Variant core -ManifestPath ./dist/znelchar-release-manifest.json
```

Install from local dist artifacts:

```powershell
npm run update:install -- -Variant core -ManifestPath ./dist/znelchar-release-manifest.json -AssetDirectory ./dist -InstallPath ./dist/update-install-core -Force
```

Verify an installed copy:

```powershell
npm run update:verify -- -Variant core -ManifestPath ./dist/znelchar-release-manifest.json -InstallPath ./dist/update-install-core
```

Run updater hardening self-test (check, install, verify, rollback simulation, checksum simulation):

```powershell
npm run update:selftest
```

Run updater hardening self-test across all variants (`core`, `module`, `portable` ⚠️ deprecated):

```powershell
npm run update:selftest:matrix
```

> ⚠️ **Note:** The `update:selftest:matrix` includes `portable` for legacy coverage. New unified bundle testing uses `tvsm update check` and `tvsm update apply`.

CI runs `update:selftest:matrix` to enforce variant matrix coverage.
