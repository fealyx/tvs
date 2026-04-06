# Distribution Build

## Overview

`build/package.ps1` creates three distribution variants:

- `znelchar-module-<version>.zip`
- `znelchar-core-<version>.zip`
- `znelchar-portable-<version>.zip`

Build output also includes release metadata files:

- `znelchar-release-manifest.json`
- `SHA256SUMS.txt`

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

Only portable package:

```powershell
npm run build:dist:portable
```

## Portable Runtime Options

`core` never includes a bundled runtime and always relies on host `pwsh`.

`portable` can optionally include a bundled runtime.

To include a pre-downloaded PowerShell portable zip:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./build/package.ps1 -CreatePortable -CreateModule:$false -CreateCore:$false -PortableRuntimeZipPath C:/downloads/PowerShell-7.5.0-win-x64.zip
```

To download from GitHub releases during build:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./build/package.ps1 -CreatePortable -CreateModule:$false -CreateCore:$false -DownloadPortableRuntime -PortableRuntimeVersion 7.5.0 -PortableRuntimeRid win-x64
```

To emit release URLs in the manifest (used for updater workflows):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./build/package.ps1 -ReleaseRepositoryOwner <owner> -ReleaseRepositoryName <repo>
```

## Portable Launchers

`core` and `portable` bundles include direct per-tool launchers:

- `inspect.cmd` / `inspect.sh`
- `extract.cmd` / `extract.sh`
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

## Module Usage

After extracting `znelchar-module-<version>.zip` to a PowerShell module path:

```powershell
Import-Module Znelchar.Tools
Get-Command -Module Znelchar.Tools
```

Exposed commands:

- `Get-ZnelcharInfo`
- `Export-ZnelcharContent`
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

Run updater hardening self-test across all variants (`core`, `module`, `portable`):

```powershell
npm run update:selftest:matrix
```

CI runs `update:selftest:matrix` to enforce variant matrix coverage.
