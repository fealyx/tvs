# Releasing

## Policy

This repository uses independent version streams per releasable surface.

Do not force lockstep versions across unrelated projects.

## Tag format

Use namespaced tags so one repository can host multiple release lines.

- `znelchar/vX.Y.Z` for znelchar tools artifacts
- `mods/vX.Y.Z` for mods-related releases
- `managed-assemblies-vA.B.C` for private `tvs-build-data` bundle tags
- Optional snapshot tag: `repo/vYYYY.MM.N`

## Version bump rules

- Bump only the project that changed.
- Keep unrelated project versions unchanged.
- If a breaking cross-project compatibility change happens, document the compatibility matrix in release notes.

## znelchar release checklist

1. Bump version in `tools/znelchar/package.json`.
2. Build distributions and verify updater matrix:
   - `npm --prefix tools/znelchar run build:dist`
   - `npm --prefix tools/znelchar run update:selftest:matrix`
3. Ensure `tools/znelchar/dist/znelchar-release-manifest.json` lists only current artifact filenames.
4. Create tag `znelchar/vX.Y.Z` and publish release.
5. Confirm release assets include:
   - `znelchar-module-<version>.zip`
   - `znelchar-core-<version>.zip`
   - `znelchar-portable-<version>.zip`
   - `znelchar-release-manifest.json`
   - `SHA256SUMS.txt`

## mods release checklist

1. Bump relevant mod project versions.
2. Build and test mods:
   - `pwsh -NoProfile -ExecutionPolicy Bypass -File ./mods/scripts/validate-mod-assets.ps1 -All`
   - `dotnet restore mods/Mods.sln --configfile mods/nuget.config --force-evaluate`
   - `dotnet build mods/Mods.sln --configuration Release --no-restore`
3. Prepare project-scoped release assets:
   - `pwsh -NoProfile -ExecutionPolicy Bypass -File ./mods/scripts/prepare-mod-release.ps1 -Configuration Release -OutputRoot ./release-artifacts/mods`
4. Create tag `mods/vX.Y.Z` and publish release notes describing included project folders/assets.

Automated `mods/*` release packaging is implemented in `.github/workflows/release.yml`.

## Why independent versions

Independent versions avoid no-op releases, keep changelogs meaningful, and reduce confusion for consumers who only depend on one surface.
