# ADR-006: Mod Storage and Linking Strategy

- Status: Accepted
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
```

### Profile format

```json
{
  "schemaVersion": 1,
  "name": "default",
  "bepInExVersion": "5.4.23.2",
  "mods": {
    "TVSLib":   { "version": "1.2.3", "enabled": true },
    "SomeMod":  { "version": "0.5.0", "enabled": true }
  }
}
```

Multiple profiles can coexist; only one is active per game install at a time. Switching profiles re-runs `tvsm mod apply` with the new profile's selections.

### Linking mechanism

On **Windows**, `tvsm` creates NTFS directory junctions (`New-Item -ItemType Junction`). Junctions require no elevated privileges, no Developer Mode, and work on all Windows 10/11 versions. They are transparent to the game process. Individual mod files within the staging directory are regular files (copied from the store on `apply`), not links — this avoids nested junction complications and ensures config files can be written by mods at runtime without affecting the store.

On **Linux** (Proton/Steam compatibility layer), `New-Item -ItemType SymbolicLink` is used instead. Symlinks are native on Linux and require no special permissions.

### `winhttp.dll` / doorstop proxy

The doorstop proxy must reside in `{gameDir}/` itself (alongside the game executable). `tvsm mod apply` copies it from the store on every apply — if the game update wipes it, the next `apply` restores it. The proxy version is pinned to the active profile's `bepInExVersion`.

### Config file preservation

Mod config files (`BepInEx/config/*.cfg`) are written by mods at runtime. They are stored in the **staging directory** (not in the game directory), so a game wipe does not affect them. On `apply`, the config staging directory is linked back into `{gameDir}/BepInEx/config/`, making configs durable across game updates.

### Relationship to TVS.Environment profiles

TVS.Environment profiles (in `~/.tvs/config.json`) hold environment keys: `gameDir`, `modWorkDir`, etc. Mod profiles (in `{modWorkDir}/profiles/`) hold mod version selections. Both are addressed by the same profile name so `tvsm --profile dev` consistently resolves both the environment and mod set for the `dev` profile.

## New and modified commands

| Command | Behaviour |
|---|---|
| `tvsm mod apply [--profile]` | Assemble staging dir from store + (re-)create junctions + drop doorstop proxy |
| `tvsm mod install <name>` | Download to store → update active profile → run apply |
| `tvsm mod update [name]` | Fetch latest from registry → store → update profile → apply |
| `tvsm mod remove <name>` | Remove from active profile → apply (does not delete from store) |
| `tvsm mod rollback` | Revert profile to previous snapshot → apply |
| `tvsm mod status` | Diff active profile against what is linked in game dir; detect wipe |
| `tvsm mod store list` | Show all mod versions currently in the store |
| `tvsm mod store prune` | Remove store entries not referenced by any profile |
| `tvsm mod profile list` | List available mod profiles |
| `tvsm mod profile switch <name>` | Set active profile → apply |
| `tvsm mod profile new <name>` | Clone active profile under a new name |

## Consequences

**Positive:**
- Game updates become a non-event: `tvsm mod apply` restores everything in seconds with no network traffic.
- Mod version history is preserved in the store; rollback is a profile revert + re-link, not a restoration from archive.
- Multiple mod profiles (stable/dev/stream) coexist without copying files.
- Config files survive game updates.
- No elevated privileges required on Windows (junctions, not symlinks).

**Tradeoffs:**
- `tvsm mod apply` must be re-run after every game update (or triggered automatically by detecting a missing junction — `tvsm mod status` can flag this).
- Staging directory is not a live symlink tree: applying a profile assembles (copies) files into staging first. This is a deliberate choice to allow mods to write config at runtime without corrupting the store.
- DLC content placed in `{gameDir}` by external tools (e.g., the game's own DLC mechanism) is still at risk from wholesale game updates; this is outside `tvsm`'s scope.

## Alternatives Considered

1. **Direct copy on every install (current model).** Simple but fragile to game updates; no version history without manual backup. Rejected.

2. **Full symlink tree (each mod DLL linked individually).** More elegant than staging copies but complicates runtime config writes and is not supported on Windows without Developer Mode (for file symlinks). Rejected.

3. **Symlink the entire `BepInEx/` directory.** Clean, but some game launchers and anti-cheat systems refuse to follow directory junctions for the entire BepInEx subtree. Staging + per-subdirectory junction is more robust. Chosen.

4. **Wrapper/launcher that injects mods without modifying the game directory.** Outside the scope of BepInEx's architecture; would require reimplementing Unity injection. Rejected.
