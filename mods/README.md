# TVS Mods

This directory is the .NET mod development workspace for The Villain Simulator.

## Layout

- `Mods.sln` is the shared Visual Studio / Rider solution for all mod projects.
- `TVS.Core/` is the shared library for cross-mod code.
- `Directory.Build.props` holds shared MSBuild defaults for all projects under `mods/`.
- `Directory.Packages.props` pins shared NuGet package versions.
- `GameDir.props.example` shows how to point the workspace at your local game install.

## First-time setup

1. Install a recent .NET SDK that supports building `netstandard2.1` projects.
2. Run the modding environment setup script:
   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/setup-modding-env.ps1
   ```
   This script will:
   - Auto-detect your TVS game install path (or prompt you for it)
   - Copy required game assemblies to `mods/.local/game-refs/managed/`
   - Generate `.env` file in the repo root with `TVS_GAME_DIR` and `TVS_PLAYER_DATA_DIR`
   - Generate `GameDir.props` pointing to the local assembly cache
3. (Optional) Review the generated `.env` and `mods/GameDir.props` files

## Build

- `rush build --to @tvs/mods`
- `npm run build` from this directory

Both commands build `Mods.sln` through the workspace wrapper script.

## Assembly management

### Local cache and game references

Game assemblies are copied to `mods/.local/game-refs/managed/` during setup.
This keeps your repo independent of game install location and prevents build conflicts.
The local cache is gitignored and regenerated if needed.

To add new assemblies to the copy manifest, edit `game-assemblies.json` and re-run the setup script.

### Publicized assemblies

`TVS.Core` is configured to publicize `Assembly-CSharp.dll` if it is available.
That is the default starting point because it usually contains most game code.

You can add more assemblies later without restructuring the repo. The usual pattern is:

1. Add a new `<Reference Include="YourAssembly">` if the assembly is not already referenced in `Directory.Build.props`.
2. Mark that reference with `<Publicize>true</Publicize>` in the specific project that needs broader access.
3. Keep publicization scoped to the projects and assemblies that actually need it.

## Adding a new mod project

1. Create `mods/TVS.YourMod/TVS.YourMod.csproj`.
2. Reference `TVS.Core` with `<ProjectReference Include="..\TVS.Core\TVS.Core.csproj" />`.
3. Add BepInEx plugin metadata with `BepInEx.PluginInfoProps`.
4. Add the project to `Mods.sln`.
