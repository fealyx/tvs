# ADR-003: tvsm Application Technology Stack

- Status: Proposed
- Date: 2026-04-30
- Initiative: TVS Manager

## Context

`tvsm` must serve two distinct audiences with very different expectations:

1. **End-users (players, content creators)** who want to install mods, manage their setup, and occasionally inspect character files without knowing any PowerShell. They need a navigable, visually clear TUI they can drive with arrow keys and Enter.

2. **Power users and CI** who want a fully scriptable command-line surface with predictable exit codes, machine-readable output, and no interactive prompts unless requested.

A pure PowerShell script can satisfy (2) well, but the PS ecosystem lacks a high-quality cross-platform TUI library. Out-ConsoleGridView is Windows-only and limited. PSReadLine provides only line-editing, not composable TUI widgets. Building a rich menu, progress display, table renderer, and status panel in raw ANSI escape sequences is costly to maintain.

At the same time, the existing tooling and logic in the ecosystem is PowerShell. We do not want to rewrite Znelchar.Tools or TVSSave.Tools in C# simply to host them from a .NET process.

## Decision

`tvsm` is a **.NET 8 console application** using **[Spectre.Console](https://spectreconsole.net/)** for all interactive rendering. It lives at `tools/tvsm` in the monorepo as a C# project.

### Why .NET + Spectre.Console

- Spectre.Console provides a mature, composable widget library: tables, trees, progress bars, prompts, selection menus, live displays, and markup — all with consistent cross-platform ANSI rendering.
- .NET 8 is already present in the dev environment; the C# mod projects target it; there is no new runtime dependency.
- A self-contained single-file publish (`dotnet publish -r win-x64 --self-contained`) produces a distributable `tvsm.exe` that does not require a separate .NET install on end-user machines.
- Exit codes, stdout/stderr separation, and `--no-ansi` / `--json-output` flags are straightforward to implement cleanly in .NET.

### Interaction with PowerShell modules

`tvsm` does not reimplement Znelchar.Tools or TVSSave.Tools logic in C#. Instead, it hosts a **PowerShell runspace** to invoke module cmdlets when character or save file operations are needed. This pattern:

- Keeps a single source of truth for module behavior.
- Allows independent versioning of PS modules and `tvsm`.
- Means new PS cmdlets are automatically available to `tvsm` without a C# change.

For operations that do not require PS modules (config read/write, community registry fetch, mod file installation, BepInEx setup, filesystem snapshotting), `tvsm` implements the logic natively in C# — these operations do not benefit from the module abstraction and are simpler as direct .NET code.

### TVS.Environment profile

`tvsm` reads `~/.tvs/config.json` natively in C# (no PS dependency for config). It writes profile values through the same JSON file. The `TVS.Environment` PS module provides the PowerShell-consumer API for the same file; both readers/writers share the schema defined in ADR-002.

### Command surface design principles

- Top-level noun-verb grouping: `tvsm config`, `tvsm mod`, `tvsm char`, `tvsm save`, `tvsm update`.
- All commands accept `--profile <name>` and `--no-ansi`.
- Commands that produce structured data accept `--json` to emit machine-readable output to stdout (Spectre rendering goes to stderr in that mode).
- Destructive commands (`mod remove`, `mod rollback`) require `--confirm` or prompt interactively; passing `--yes` skips the prompt for scripting.
- `tvsm` with no arguments enters TUI menu mode.

### Spectre.Console widget usage guide

| Use case | Widget |
|---|---|
| Config table | `Table` with borders |
| Mod status list | `Table` with status column icons |
| Install/update progress | `ProgressContext` with multiple tasks |
| First-run wizard | `TextPrompt`, `SelectionPrompt` |
| TUI menu (no-args mode) | `SelectionPrompt` in a render loop |
| Error/warning callouts | `Markup` with `[red]`/`[yellow]` |
| Diff output | `Table` or side-by-side `Columns` |

## Project Structure

```
tools/tvsm/
  tvsm.csproj
  rush-project.json
  package.json
  src/
    Program.cs              # entry point, DI, root command
    Commands/
      ConfigCommand.cs
      ModCommand.cs
      CharCommand.cs
      SaveCommand.cs
      UpdateCommand.cs
    Services/
      EnvironmentProfileService.cs   # reads/writes ~/.tvs/config.json
      ModRegistryService.cs          # fetches/caches community registry
      ModSnapshotService.cs          # pre-mutation rollback snapshots
      PowerShellRunspaceService.cs   # hosts PS runspace for module ops
    Models/
      EnvironmentProfile.cs
      ModRegistryManifest.cs
    UI/
      Tables.cs             # reusable Spectre table builders
      Prompts.cs            # reusable Spectre prompts
  build/
    package.ps1             # produces tvsm-<version>.zip for standalone dist
```

The project uses [System.CommandLine](https://github.com/dotnet/command-line-api) for command parsing and middleware, combined with Spectre.Console for rendering. This combination is well-established in the .NET ecosystem.

## Consequences

Positive:
- First-class TUI experience for end-users with no extra effort on PS module authors.
- Clean separation: PS modules are logic, `tvsm` is the user-facing shell.
- `--json` mode makes `tvsm` composable in scripts and CI even though it is primarily a TUI tool.
- Self-contained publish means no .NET prerequisite for end-users.

Tradeoffs:
- Two languages in the tool surface (C# for `tvsm`, PowerShell for modules). Developers contributing to `tvsm` need C# familiarity.
- PS runspace hosting adds startup latency for character/save operations (mitigated by lazy runspace initialization).
- Self-contained publish is ~60–80 MB; acceptable for a desktop tool but worth noting.

## Alternatives Considered

1. **Pure PowerShell with custom ANSI TUI.**
   - Rejected: high maintenance cost for a rich TUI; limited widget ecosystem; would become a significant custom framework.

2. **Pure PowerShell with Out-ConsoleGridView / `Microsoft.PowerShell.ConsoleGuiTools`.**
   - Rejected: Windows-only; limited to selection lists; does not support progress display, rich tables, or wizard flows without substantial custom code.

3. **Electron/Tauri/WPF GUI application.**
   - Rejected: overkill for a CLI tool; much larger distribution surface; not ergonomic for scripting/CI use cases.

4. **Extend `znelchar-gui` to be the manager.**
   - Rejected: `znelchar-gui` is a web-technology character file editor; different user expectation and distribution model; merging mod management into it conflates unrelated concerns.

## Follow-Up Tasks

1. Create `tools/tvsm` C# project and add to Rush monorepo.
2. Add `System.CommandLine` and `Spectre.Console` NuGet packages.
3. Implement `EnvironmentProfileService` reading `~/.tvs/config.json`.
4. Implement `tvsm config show` and `tvsm config init` as the first vertical slice.
5. Implement `PowerShellRunspaceService` and validate it can invoke `Znelchar.Tools` cmdlets.
6. Define the full command surface spec as a follow-up doc.
