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

When private TVS game assemblies are not available, projects that depend only on public packages still build normally.
`TVS.SampleMod` also includes a fallback compile path for CI / no-game-refs environments so the workspace can stay green without distributing private game DLLs.
Its full runtime implementation is only compiled when `TVSManagedDir` points at a valid managed assembly cache.

If `TVSAutoDeployOnBuild` is true in `mods/GameDir.props`, plugin projects are copied
to `BepInEx/plugins` automatically after each successful build.

## Mod manager

Use the mod manager script for install/deploy workflows:

- `npm run mod:install:bepinex` installs BepInEx 5 to your `TVS_GAME_DIR`
- `npm run mod:install:dev` installs default development helper mods from manifest
- `npm run mod:deploy` deploys all built plugin projects to `BepInEx/plugins`

The script source is `mods/scripts/mod-manager.ps1`.

## Assembly management

### Local cache and game references

Game assemblies are copied to `mods/.local/game-refs/managed/` during setup.
This keeps your repo independent of game install location and prevents build conflicts.
The local cache is gitignored and regenerated if needed.

To add new assemblies to the copy manifest, edit `game-assemblies.json` and re-run the setup script.

### Project asset manifests

Projects with runtime assets should declare them in `assets/assets.manifest.json`.
The first implementation lives at `mods/TVS.SampleMod/assets/assets.manifest.json` and supports any mix of:

- asset bundles
- loose runtime files
- extra assembly dependencies

Manifest files are validated by `mods/scripts/validate-mod-assets.ps1`.

Validation checks include:

1. JSON schema conformance against `mods/schemas/assets.manifest.schema.json`
2. required file existence
3. optional SHA-256 hash verification
4. release-path safety checks to prevent path traversal

Run locally:

```powershell
npm run validate:assets
```

CI also runs this validation before restoring and building `Mods.sln`.

### Private CI build-data flow

GitHub Actions can also populate `mods/.local/game-refs/managed/` from the private `fealyx/tvs-build-data` repository.
The CI helper is `mods/scripts/fetch-tvs-build-data.ps1`.

It performs four steps:

1. Download a pinned manifest such as `0.45.json` from the private repo.
2. Resolve the manifest's release tag.
3. Download the zip plus `.sha256` release assets and verify the checksum.
4. Extract the bundle to the same local cache path used by `setup-modding-env.ps1`, then generate `mods/GameDir.props` pointing `TVSManagedDir` at that cache.

The workflow uses the `TVS_BUILD_DATA_TOKEN` secret when it is available.
If the secret is missing, CI still builds with the existing `TVS.SampleMod` no-game-refs fallback path.

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
