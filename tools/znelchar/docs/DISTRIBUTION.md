# Distribution Build

## Overview

`build/package.ps1` creates two distribution variants:

- `znelchar-module-<version>.zip`
- `znelchar-portable-<version>.zip`

## Build Commands

From `tools/znelchar`:

```powershell
npm run build:dist
```

Only module package:

```powershell
npm run build:dist:module
```

Only portable package:

```powershell
npm run build:dist:portable
```

## Portable Runtime Options

To include a pre-downloaded PowerShell portable zip:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./build/package.ps1 -CreatePortable -CreateModule:$false -PortableRuntimeZipPath C:/downloads/PowerShell-7.5.0-win-x64.zip
```

To download from GitHub releases during build:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./build/package.ps1 -CreatePortable -CreateModule:$false -DownloadPortableRuntime -PortableRuntimeVersion 7.5.0 -PortableRuntimeRid win-x64
```

## Portable Launchers

Portable bundles include:

- `run-znelchar.cmd`
- `run-znelchar.sh`

Usage example:

```powershell
./run-znelchar.cmd inspect -InputPath ./samples/Foxy.znelchar -MetadataOnly
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
