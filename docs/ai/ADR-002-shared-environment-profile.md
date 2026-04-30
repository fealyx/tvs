# ADR-002: Shared Environment Profile (TVS.Environment)

- Status: Proposed
- Date: 2026-04-30
- Initiative: TVS Manager

## Context

Every script that needs to locate the game install, player data directory, or mod output directory currently implements its own resolution chain independently:

- `mod-manager.ps1` parses `.env` at the repo root.
- `setup-modding-env.ps1` checks `.env`, then `GameDir.props` (MSBuild XML), then the Windows registry (Steam uninstall key), then prompts interactively.
- znelchar portable launchers currently have no environment awareness; users pass paths as arguments each time.
- `fetch-tvs-build-data.ps1` and build scripts read from `GameDir.props` only.

This means:
- Onboarding requires multiple setup steps that are not obviously connected to each other.
- Changing the game directory requires finding and updating multiple files (`.env`, `GameDir.props`, possibly script arguments saved in shortcuts/aliases).
- Adding new tools means implementing the same resolution chain a third or fourth time, with subtle drift.
- Znelchar.Tools cmdlets cannot provide sensible default parameter values because there is no canonical source of truth for the user's environment.

## Decision

Introduce a `TVS.Environment` PowerShell module that owns all user-environment configuration for TVS tooling.

### Profile storage

The primary profile is stored at `~/.tvs/config.json`. This is user-scoped (not per-project) and survives workspace cleans. A local `.tvs-config.json` found by nearest-ancestor search from the current directory can override individual keys for project-specific contexts (e.g., a secondary test game installation).

Priority order (highest to lowest):
1. Explicit parameter value (callers can always override)
2. Nearest-ancestor `.tvs-config.json`
3. `~/.tvs/config.json` (user profile)
4. Legacy `.env` at repo root (read-only compatibility shim during migration)
5. Legacy `GameDir.props` (read-only compatibility shim during migration)
6. Windows registry Steam uninstall key (auto-detect, game dir only)
7. `null` / not set

### Profile schema

```json
{
  "schemaVersion": 1,
  "activeProfile": "default",
  "profiles": {
    "default": {
      "gameDir": "C:/Steam/steamapps/common/The Villain Simulator",
      "playerDataDir": "C:/Users/User/AppData/LocalLow/...",
      "characterWorkDir": "D:/My TVS Characters",
      "modWorkDir": "D:/My TVS Mods",
      "communityRegistryUrl": "https://fealyx.github.io/tvs/tvs-mod-registry.json",
      "communityRegistryCacheTtlMinutes": 60
    },
    "dev": {
      "gameDir": "C:/Steam/steamapps/common/The Villain Simulator",
      "characterWorkDir": "D:/TVS-Dev/characters",
      "modWorkDir": "D:/TVS-Dev/mods"
    }
  }
}
```

Named profiles allow context switching with `--profile <name>` or `$env:TVS_PROFILE`. Keys not present in a named profile fall back to the `default` profile values.

### Module API

```powershell
# Read the resolved environment (applies priority chain, named profile, overlays)
Get-TVSEnvironment [-Profile <string>] [-Key <string>]

# Write a key to the user profile
Set-TVSEnvironmentValue -Key <string> -Value <string> [-Profile <string>]

# Run the interactive first-run wizard (delegates to tvsm config init in normal usage)
Initialize-TVSEnvironment

# Test that required keys are set and paths resolve
Test-TVSEnvironment [-RequiredKeys <string[]>]
```

### Consumers

All consuming scripts and modules should call `Get-TVSEnvironment` and accept its output as default parameter values. They must not implement their own `.env` or `GameDir.props` parsing after migration.

| Consumer | Keys used |
|---|---|
| `Znelchar.Tools` cmdlets | `characterWorkDir` for `-OutputPath` defaults |
| `TVSSave.Tools` cmdlets | `playerDataDir`, `characterWorkDir` |
| `mod-manager.ps1` / `tvsm mod` | `gameDir`, `modWorkDir` |
| `setup-modding-env.ps1` | `gameDir` |
| `mods/csharp/scripts/build.ps1` | `gameDir` (emit as env var for MSBuild) |
| `tvsm config` | full profile read/write |

### MSBuild integration

During dev env setup, `setup-modding-env.ps1` will continue to write `GameDir.props` as the MSBuild-visible artifact, but will now derive its value from `Get-TVSEnvironment` rather than prompting independently. This keeps MSBuild integration working without requiring MSBuild to understand the profile format.

## Consequences

Positive:
- Single place to change environment configuration.
- Znelchar.Tools and TVSSave.Tools can advertise useful parameter defaults.
- New tools are easy to onboard — one `Get-TVSEnvironment` call.
- `tvsm config init` wizard becomes the single first-run setup experience.

Tradeoffs:
- Requires a migration pass over all existing consuming scripts.
- The `.env` / `GameDir.props` compatibility shims must be maintained until all consumers are migrated.
- Profile at `~/.tvs/config.json` is not version-controlled by default; developers sharing a codebase each configure their own.

## Alternatives Considered

1. **Continue with `.env` + `GameDir.props` as the shared standard.**
   - Rejected: does not solve the duplication problem; cannot be consumed by tvsm without embedding its own reader; cannot support named profiles.

2. **Environment variables only (`$env:TVS_GAME_DIR` etc.).**
   - Rejected: environment variables do not persist across sessions on Windows without extra setup; no GUI or TUI for managing them; no profile/overlay model.

3. **Single-repo `.tvs-config.json` only (no user profile).**
   - Rejected: forces every user to configure on each clone/workspace; not suitable for end-users who do not have a repo checkout at all.

## Follow-Up Tasks

1. Create `tools/tvs-environment` module skeleton.
2. Define the full set of canonical profile keys with types and validation rules.
3. Implement the priority resolution chain.
4. Migrate `mod-manager.ps1` and `setup-modding-env.ps1`.
5. Add `Get-TVSEnvironment` default-value wiring to `Znelchar.Tools` cmdlets.
6. Remove `.env` and `GameDir.props` parsing from all migrated consumers (keep shims until all are done).
