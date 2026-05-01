# ADR-006: Mod Storage and Linking Strategy

- Status: Accepted · Implemented (Phase 2, 2026-05-01)
- Date: 2026-04-30
- Initiative: TVS Manager

## Context

BepInEx's standard installation model places all content directly under the game installation directory:

```
{gameDir}/
  BepInEx/
    plugins/      ← mod DLLs
    config/       ← per-mod config files
    patchers/     ← BepInEx patchers
    core/         ← BepInEx runtime
  winhttp.dll     ← Unity doorstop proxy (intercepts game startup)
  doorstop_config.ini
  TheVillainSimulator.exe
```

This creates a brittle situation: game updates on Steam (and similar platforms) frequently replace the entire game installation directory wholesale, wiping BepInEx, all installed mods, all mod config, and the doorstop proxy. Users in the community have already reported losing DLC content and configurations this way. The problem will compound as the mod ecosystem grows.

A secondary concern is mod version management: users who want to maintain separate mod sets (e.g., a stable profile for play and an experimental profile for testing) currently have no supported way to do so without manual file management.

## Decision

`tvsm` adopts a **store-and-link** mod management model. Mod files are never placed directly in the game installation directory. Instead:

1. **A version-addressed mod store** holds all downloaded mod artifacts outside the game directory, keyed by `{modName}/{version}/`.
2. **Mod profiles** declare which version of each mod is active.
3. **`tvsm mod apply`** materialises the active profile into a staging directory and establishes directory junctions (Windows) or symlinks (Linux/macOS) from `{gameDir}/BepInEx/{plugins,config,patchers}` into that staging directory.
4. **Post-update repair** is instant: when the game directory is wiped, `tvsm mod apply` recreates all junctions and re-drops the doorstop proxy from the store — no re-downloading, no reconfiguring.

### Directory layout

```
{modWorkDir}/                            ← configured via TVS.Environment
  store/
    BepInEx/
      5.4.23.2/
        BepInEx-core/                    ← BepInEx runtime files
        winhttp.dll                      ← doorstop proxy
        doorstop_config.ini
    TVSLib/
      1.2.3/  TVSLib.dll
      1.3.0/  TVSLib.dll
    SomeMod/
      0.5.0/  SomeMod.dll
  profiles/
    default.json
    dev.json
    stream.json
  staging/
    default/
      plugins/                           ← assembled from store entries
      config/                            ← preserved across game updates
      patchers/
  dev-links.json                         ← machine-local dev overlay (never snapshotted)
```

### Profile format

```json
{
  "schemaVersion": 1,
  "name": "default",
  "bepInExVersion": "5.4.23.2",
  "mods": {
    "TVSLib":  { "version": "1.2.3", "enabled": true },
    "SomeMod": { "version": "0.5.0", "enabled": false }
  },
  "snapshots": [
    {
      "id": "2026-05-01T12:00:00Z",
      "label": "before-install-SomeMod",
      "bepInExVersion": "5.4.23.2",
      "mods": {
        "TVSLib": { "version": "1.2.3", "enabled": true }
      }
    }
  ]
}
```

Key design points:
- **Snapshots are embedded** in the profile file rather than stored as separate files. This keeps rollback atomic — one read, one write, no directory management. `tvsm mod snapshot [label]` prepends to the `snapshots` array; `tvsm mod rollback` pops the most recent entry and restores `mods` + `bepInExVersion` from it.
- **`enabled: false` preserves the version pin** rather than removing the entry. Temporarily disabling a mod for debugging does not lose the version selection.
- **`bepInExVersion` is profile-level**, not per-mod. BepInEx is a monolith — mixed versions are not supported.
- Multiple profiles can coexist; only one is active per game install at a time. Switching profiles re-runs `tvsm mod apply` with the new profile's selections.

### Linking mechanism

On **Windows**, `tvsm` creates NTFS directory junctions (`New-Item -ItemType Junction`). Junctions require no elevated privileges, no Developer Mode, and work on all Windows 10/11 versions. They are transparent to the game process. Individual mod files within the staging directory are regular files (copied from the store on `apply`), not links — this avoids nested junction complications and ensures config files can be written by mods at runtime without affecting the store.

On **Linux** (Proton/Steam compatibility layer), `New-Item -ItemType SymbolicLink` is used instead. Symlinks are native on Linux and require no special permissions.

### `winhttp.dll` / doorstop proxy

The doorstop proxy must reside in `{gameDir}/` itself (alongside the game executable). `tvsm mod apply` copies it from the store on every apply — if the game update wipes it, the next `apply` restores it. The proxy version is pinned to the active profile's `bepInExVersion`.

### Config file preservation

Mod config files (`BepInEx/config/*.cfg`) are written by mods at runtime. They are stored in the **staging directory** (not in the game directory), so a game wipe does not affect them. On `apply`, the config staging directory is linked back into `{gameDir}/BepInEx/config/`, making configs durable across game updates.

### Relationship to TVS.Environment profiles

TVS.Environment profiles (in `~/.tvs/config.json`) hold environment keys: `gameDir`, `modWorkDir`, etc. Mod profiles (in `{modWorkDir}/profiles/`) hold mod version selections. Both are addressed by the same profile name so `tvsm --profile dev` consistently resolves both the environment and mod set for the `dev` profile.

### Developer workflow: dev links

Mod developers need their build output active in the game directory without going through the store. `tvsm mod dev link` provides an `npm link`-style overlay:

```powershell
tvsm mod dev link MyMod --src mods/csharp/MyMod/bin/Debug/net6.0
tvsm mod dev unlink MyMod
tvsm mod dev list
```

**Mechanics:**
- Dev links are stored in `{modWorkDir}/dev-links.json` — a machine-local file, never included in profile snapshots or rollback.
- `tvsm mod apply` creates a **direct junction/symlink** for each dev-linked mod pointing straight at the declared source path, bypassing staging entirely. Each `dotnet build` makes the new DLL live in-game immediately with no further `tvsm` commands.
- `tvsm mod status` displays dev-linked mods distinctly (e.g. `[DEV] MyMod → mods/csharp/...`).
- `tvsm mod dev unlink MyMod` removes the direct link; if a store version exists in the active profile, `apply` re-establishes the store-backed staging link.
- Dev links are always re-applied on every `tvsm mod apply` — declaring a dev link means you always want it active until you explicitly unlink it.
- Rollback and snapshot operations are entirely unaware of `dev-links.json`; dev links persist independently across profile mutations.

**Dev links format:**

```json
{
  "schemaVersion": 1,
  "links": {
    "MyMod": {
      "src": "C:/dev/tvs/mods/csharp/MyMod/bin/Debug/net6.0",
      "installLayout": "plugins-dll",
      "linkedAt": "2026-05-01T00:00:00Z",
      "note": "optional freeform annotation"
    },
    "NewItemPack": {
      "src": "C:/dev/tvs/mods/items/NewItemPack/build",
      "installLayout": "gameroot-overlay",
      "linkedAt": "2026-05-01T00:00:00Z"
    }
  }
}
```

Key design points:
- **`src` is always an absolute path** in the stored file. `tvsm mod dev link` resolves any relative `--src` argument against the current working directory at link time before writing. This eliminates ambiguity at apply time regardless of where the CLI is subsequently invoked.
- **`installLayout`** declares how the source is applied (see the `installLayout` taxonomy below). Defaults to `plugins-dll` when omitted.
- **`note`** is optional freeform text shown in `tvsm mod dev list`.
- `dev-links.json` is machine-local and should be added to `.gitignore` if `modWorkDir` is inside a repository.

### `installLayout` taxonomy

`installLayout` is declared on both registry entries and dev-links entries. It tells `tvsm mod apply` how to materialise a mod into the game environment.

| Value | Applies to | Behaviour |
|---|---|---|
| `bepinex-root` | Registry only | Extract archive into `{gameDir}/`; places `winhttp.dll`, `doorstop_config.ini`, and `BepInEx/core/` at their expected locations |
| `plugins-dll` | Both | Locate `{modName}.dll` in `src`; copy/link into `staging/plugins/` (or `{gameDir}/BepInEx/plugins/` for dev links) |
| `plugins-dir` | Both | Copy/link the entire `src` directory as `staging/plugins/{modName}/` |
| `patchers-dll` | Both | Locate `{modName}.dll` in `src`; copy/link into `staging/patchers/` |
| `gameroot-overlay` | Both | Copy/link contents of `src` directly into `{gameDir}/`; intended for custom formats (e.g. JSON + AssetBundle item packs) that live outside the BepInEx tree |
| `config-only` | Both | Copy/link contents of `src` into `staging/config/` |

Default when omitted: `plugins-dll` (dev-links only; registry entries must declare `installLayout` explicitly — a missing value is a validation error).

### Community registry schema

The registry is a JSON file hosted on GitHub Pages (or as a GitHub release asset). It is fetched lazily on `tvsm mod install`, `update`, and `status`, and cached locally at `{modWorkDir}/.registry-cache.json` with a configurable TTL (default: 1 hour, controlled by `communityRegistryCacheTtlMinutes` in TVS.Environment).

```json
{
  "schemaVersion": 1,
  "updated": "2026-05-01T00:00:00Z",
  "mods": [
    {
      "name": "BepInEx",
      "description": "Unity mod framework. Required by all TVS mods.",
      "required": true,
      "recommended": true,
      "versions": [
        {
          "version": "5.4.23.2",
          "url": "https://github.com/BepInEx/BepInEx/releases/download/v5.4.23.2/BepInEx_x64_5.4.23.2.zip",
          "sha256": "...",
          "installLayout": "bepinex-root",
          "requires": [],
          "gameVersionRange": ">=0.1"
        }
      ]
    },
    {
      "name": "TVSLib",
      "description": "Shared library required by all TVS mods.",
      "required": true,
      "recommended": true,
      "versions": [
        {
          "version": "1.2.3",
          "url": "https://...",
          "sha256": "...",
          "installLayout": "plugins-dll",
          "requires": ["BepInEx"],
          "gameVersionRange": ">=0.45"
        }
      ]
    }
  ]
}
```

Key design constraints:
- `installLayout` is **required** on every version entry — a missing value is a validation error at registry parse time.
- `required: true` mods are installed without prompting during `tvsm mod install --all`.
- `requires` is a list of other registry mod names; `tvsm` resolves the install order (dependency-first).
- `gameVersionRange` uses semver range syntax (e.g. `>=0.45`, `>=0.45 <1.0`). Enforcement behaviour:
  - **At install**: hard block — tvsm refuses to install a version whose range excludes the detected game version.
  - **At apply**: warn only — each out-of-range mod emits a warning, but apply proceeds. `tvsm mod apply --force` suppresses the warnings entirely (intended for post-update wipe recovery).
  - **`tvsm mod status`**: flags out-of-range mods with an `[OUTDATED RANGE]` indicator.
- Registry updates are never applied automatically to installed mods without user confirmation.

## New and modified commands

| Command | Behaviour |
|---|---|
| `tvsm mod apply [--profile] [--force]` | Assemble staging dir from store + (re-)create junctions + drop doorstop proxy + apply dev links. Warns on out-of-range mods; `--force` suppresses warnings |
| `tvsm mod install <name>` | Download to store → update active profile → run apply |
| `tvsm mod update [name]` | Fetch latest from registry → store → update profile → apply |
| `tvsm mod remove <name>` | Remove from active profile → apply (does not delete from store) |
| `tvsm mod rollback` | Revert profile to previous snapshot → apply |
| `tvsm mod status` | Diff active profile against what is linked in game dir; detect wipe; show dev links |
| `tvsm mod store list` | Show all mod versions currently in the store |
| `tvsm mod store prune` | Remove store entries not referenced by any profile |
| `tvsm mod profile list` | List available mod profiles |
| `tvsm mod profile switch <name>` | Set active profile → apply |
| `tvsm mod profile new <name>` | Clone active profile under a new name |
| `tvsm mod dev link <name> --src <path>` | Register a live build output path as a dev overlay; apply immediately |
| `tvsm mod dev unlink <name>` | Remove dev link; fall back to store version if present; apply |
| `tvsm mod dev list` | Show all active dev links and their source paths |

## Consequences

**Positive:**
- Game updates become a non-event: `tvsm mod apply` restores everything in seconds with no network traffic.
- Mod version history is preserved in the store; rollback is a profile revert + re-link, not a restoration from archive.
- Multiple mod profiles (stable/dev/stream) coexist without copying files.
- Config files survive game updates.
- No elevated privileges required on Windows (junctions, not symlinks).
- Mod developers get a live feedback loop: `tvsm mod dev link` + `dotnet build` = immediate in-game effect with no manual copy step.

**Tradeoffs:**
- `tvsm mod apply` must be re-run after every game update (or triggered automatically by detecting a missing junction — `tvsm mod status` can flag this).
- Staging directory is not a live symlink tree: applying a profile assembles (copies) files into staging first. This is a deliberate choice to allow mods to write config at runtime without corrupting the store.
- DLC content placed in `{gameDir}` by external tools (e.g., the game's own DLC mechanism) is still at risk from wholesale game updates; this is outside `tvsm`'s scope.

## Alternatives Considered

1. **Direct copy on every install (current model).** Simple but fragile to game updates; no version history without manual backup. Rejected.

2. **Full symlink tree (each mod DLL linked individually).** More elegant than staging copies but complicates runtime config writes and is not supported on Windows without Developer Mode (for file symlinks). Rejected.

3. **Symlink the entire `BepInEx/` directory.** Clean, but some game launchers and anti-cheat systems refuse to follow directory junctions for the entire BepInEx subtree. Staging + per-subdirectory junction is more robust. Chosen.

4. **Wrapper/launcher that injects mods without modifying the game directory.** Outside the scope of BepInEx's architecture; would require reimplementing Unity injection. Rejected.
