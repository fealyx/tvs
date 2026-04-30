# ADR-003: tvsm Application Technology Stack

- Status: Accepted
- Date: 2026-04-30
- Revised: 2026-04-30
- Initiative: TVS Manager

## Context

`tvsm` must serve two distinct audiences with very different expectations:

1. **End-users (players, content creators)** who want to install mods, manage their setup, and occasionally inspect character files without knowing any PowerShell. They need a navigable, visually clear TUI they can drive with arrow keys and Enter.

2. **Power users and CI** who want a fully scriptable command-line surface with predictable exit codes, machine-readable output, and no interactive prompts unless requested.

The entire existing tooling ecosystem — Znelchar.Tools, TVSSave.Tools, TVS.Environment, mod scripts — is PowerShell. A .NET application would need to host a PowerShell runspace to invoke these modules anyway, adding complexity without removing the PS dependency. The distribution size argument for a self-contained .NET executable is not compelling when a bundled `pwsh` portable achieves the same result with a comparable footprint and without introducing a second language.

PowerShell 7 satisfies both audiences well: it is cross-platform (Windows, Linux, macOS), supports predictable exit codes, stdout/stderr separation, and `--json`-style output modes. `System.IO.FileSystemWatcher` covers the save-watch use case natively. [PwshSpectreConsole](https://github.com/ShaunLawrie/PwshSpectreConsole) — a PS module wrapping Spectre.Console — bridges the TUI quality gap, providing selection menus, tables, progress bars, and prompts from PowerShell without leaving the language.

## Decision

`tvsm` is a **PowerShell 7 module and script application** using **[PwshSpectreConsole](https://github.com/ShaunLawrie/PwshSpectreConsole)** for end-user-facing interactive output. It lives at `tools/tvsm` in the monorepo.

### Why PowerShell + PwshSpectreConsole

- Consistent language across all tool layers: no context-switch between C# and PS for contributors.
- PwshSpectreConsole provides Spectre.Console-quality tables, selection menus, progress bars, and prompts from within PowerShell — the same widget quality that motivated the original .NET consideration, without leaving PS.
- No PS runspace hosting complexity — modules are imported directly.
- Cross-platform from day one: works on Windows (end-users, mod devs) and Linux (CI, Proton users) without a separate publish step.
- Distribution via a portable bundle with a packaged `pwsh` runtime provides equivalent end-user experience to a self-contained .NET executable, at comparable bundle size.
- CI pipeline integration is natural — calling `pwsh tvsm.ps1 mod status` in a Linux runner requires no additional toolchain. PwshSpectreConsole rendering is suppressed via `--no-ansi` / `--json` for CI output.
- Exit codes, machine-readable `--json` output, and `--no-ansi` flags are straightforward in PowerShell.

### .NET as a future option

A rewrite in .NET remains a viable path if one or more of the following becomes a practical need:

- PwshSpectreConsole lacks a widget required for a specific use case (e.g., `AnsiConsole.Live()` for a continuously-updated status panel) and no workaround is available.
- Startup latency of `pwsh` process spin-up becomes a problem for interactive use.
- A single zero-prerequisite executable with no runtime folder is specifically required by an end-user distribution channel (e.g., winget, MSIX).

This ADR should be revisited if those conditions arise. The module boundary is clean enough that a future `tvsm` C# rewrite can consume the same `TVS.Environment`, `Znelchar.Tools`, and `TVSSave.Tools` PS modules via a runspace with no changes to the modules themselves.

### Interaction with PowerShell modules

`tvsm` imports `TVS.Environment`, `Znelchar.Tools`, and `TVSSave.Tools` directly — they are PS modules and `tvsm` is a PS application. There is no runspace hosting, no marshaling, no output stream adaptation.

### TVS.Environment profile

`tvsm` calls `Get-TVSEnvironment` and `Set-TVSEnvironmentValue` from the `TVS.Environment` module, identical to every other consumer in the ecosystem.

### Command surface design principles

- Top-level noun-verb grouping: `tvsm config`, `tvsm mod`, `tvsm char`, `tvsm save`, `tvsm update`.
- All commands accept `--profile <name>` and `--no-ansi`.
- Commands that produce structured data accept `--json` to emit machine-readable output to stdout (Spectre rendering goes to stderr in that mode).
- Destructive commands (`mod remove`, `mod rollback`) require `--confirm` or prompt interactively; passing `--yes` skips the prompt for scripting.
- `tvsm` with no arguments enters TUI menu mode.

### Output and TUI approach

| Use case | Widget / Approach |
|---|---|
| Config table | `Format-SpectreTable` (PwshSpectreConsole) |
| Mod status list | `Format-SpectreTable` with status column markup |
| Install/update progress | `Invoke-SpectreCommandWithProgress` |
| First-run wizard | `Read-SpectreText`, `Read-SpectreSelection` |
| TUI menu (no-args mode) | `Read-SpectreSelection` in a loop |
| File system watcher | `System.IO.FileSystemWatcher` + `Register-ObjectEvent` |
| Error/warning callouts | `Write-SpectreHost` with `[red]`/`[yellow]` markup |
| Machine-readable output | `ConvertTo-Json` to stdout; Spectre rendering to stderr when `--json` |

When `--no-ansi` is passed, PwshSpectreConsole falls back to plain text output automatically.

## Project Structure

```
tools/tvsm/
  package.json
  rush-project.json
  module/
    TVSM/
      TVSM.psd1
      TVSM.psm1
      Private/
        Read-ModRegistry.ps1        # fetches/caches community registry JSON
        New-ModSnapshot.ps1         # pre-mutation rollback snapshot
        Resolve-ModInstallOrder.ps1 # dependency-sorted install order
      Public/
        Get-TVSMStatus.ps1          # tvsm mod status
        Install-TVSMMod.ps1         # tvsm mod install
        Remove-TVSMMod.ps1          # tvsm mod remove
        Invoke-TVSMRollback.ps1     # tvsm mod rollback
        Test-TVSMEnvironment.ps1    # tvsm mod verify
        Watch-TVSSave.ps1           # tvsm save watch
  tvsm.ps1                         # entry-point launcher script
  build/
    package.ps1                    # produces tvsm-<version>.zip for portable dist
```

Command dispatch is handled in `tvsm.ps1` via a `switch` on the first positional argument, delegating to module functions. This mirrors the pattern in `mod-manager.ps1` and is idiomatic for the codebase.

## Consequences

Positive:
- Single language across the entire tool surface; all contributors work in PowerShell.
- Spectre.Console-quality TUI via PwshSpectreConsole — selection menus, tables, progress bars — without leaving PS.
- No runspace hosting complexity; modules imported directly.
- Cross-platform without a separate build/publish step.
- CI integration is trivial: `pwsh tvsm.ps1 <command>` works on any runner with PowerShell 7.
- `--json` and `--no-ansi` modes work naturally alongside PwshSpectreConsole.

Tradeoffs:
- PwshSpectreConsole is less mature than Spectre.Console directly; some advanced widgets (e.g., live-display panels) may not be available or may have rough edges.
- Adds a module dependency (`PwshSpectreConsole`) that must be bundled in the portable distribution.
- PowerShell startup time (~300–500 ms on a cold run) is perceptible for interactive use but not a blocker.
- A future .NET rewrite would be a significant effort if PwshSpectreConsole limitations become a real constraint.

## Alternatives Considered

1. **.NET 8 console application with Spectre.Console.**
   - Deferred, not rejected. Strongest argument is live TUI widgets and a zero-prerequisite single `.exe`. Becomes the preferred option if PowerShell startup latency or TUI limitations become real friction. See the .NET future option section above.

2. **PowerShell without PwshSpectreConsole (`Format-Table` / `Write-Host` only).**
   - Viable for CI/power-user workflows but produces a noticeably weaker end-user experience. Rejected in favour of PwshSpectreConsole given the end-user audience.

3. **Electron/Tauri/WPF GUI application.**
   - Rejected: overkill; not ergonomic for scripting/CI use cases.

4. **Extend `znelchar-gui` to be the manager.**
   - Rejected: `znelchar-gui` is a web-technology character file editor; merging mod management into it conflates unrelated concerns.

## Follow-Up Tasks

1. Create `tools/tvsm` package and add to Rush monorepo (`package.json`, `rush-project.json`). ✅
2. Scaffold `TVSM.psm1` / `TVSM.psd1` and `tvsm.ps1` entry-point, mirroring `Znelchar.Tools` structure. ✅
3. Add `PwshSpectreConsole` to the module's dependency list; include it in the portable bundle build. ✅
4. Implement `tvsm config show` and `tvsm config init` (delegates to `Initialize-TVSEnvironment`) as the first vertical slice, using Spectre widgets. ✅
5. Define the full command surface spec as a follow-up doc.
6. Add Pester tests in Phase 2 alongside the mod-manager implementation. Phase 1 cmdlets were reviewed and deferred: `Invoke-TVSMConfigInit` is interactive TUI (not unit-testable at the prompt level); `Get-TVSMVersion` and the Phase 2/3 stubs have no logic to assert. Priority tests for Phase 2: `Show-TVSMConfig` display-contract, `Get-TVSMModStatus` manifest parsing, and `Invoke-TVSMModRollback` snapshot/restore (safety-critical).
