# TVS Unity Workspace

This project is the Rush-managed Unity workspace for mod asset authoring and headless batch builds.

## Rush package

- Name: `@tvs/mods-unity`
- Path: `mods/unity`

## Build commands

From repo root:

```bash
rush build --to @tvs/mods-unity
```

From `mods/unity`:

```bash
npm run build
# or
npm run build:assetbundles
```

## Unity executable resolution

The batch script resolves Unity in this order:

1. `-UnityPath` argument
2. `UNITY_EXECUTABLE` env var
3. `UNITY_PATH` env var
4. `UNITY_EDITOR_PATH` env var
5. `Unity` / `unity` / `unity-editor` on PATH
6. Known install paths (Linux/macOS/Windows defaults)

If Unity cannot be found, the build exits with a clear error.

## Line endings

Tracked Unity and .NET project files in this repo are normalized to LF.

- Keep `core.autocrlf` disabled for this repository.
- `*.cmd` and `*.bat` stay CRLF as the explicit Windows shell exception.
- If Visual Studio prompts about inconsistent line endings, normalize the affected tracked files back to LF.

## Batch build behavior

The script calls the Unity method:

- `TVS.Mods.Unity.Editor.BatchBuild.BuildAll`

Default output:

- `mods/unity/Builds/AssetBundles/Windows64`

Log file:

- `mods/unity/Builds/unity-batch-build.log`

Example with explicit Unity path:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./mods/unity/scripts/build.ps1 -UnityPath "/opt/unity/Editor/Unity"
```

Example with custom output and target:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./mods/unity/scripts/build.ps1 -OutputDir "./Builds/AssetBundles/StandaloneLinux64" -BuildTarget "StandaloneLinux64" -Strict
```
