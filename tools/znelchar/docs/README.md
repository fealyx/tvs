# znelchar tools

PowerShell-first tooling for `.znelchar` files.

## Scripts

- `npm run inspect -- -InputPath ../../temp/Foxy.znelchar`
- `npm run inspect -- -InputPath ../../temp/Foxy.znelchar -MetadataOnly`
- `npm run extract -- -InputPath ../../temp/Foxy.znelchar -OutputDir ./out/Foxy`
- `npm run extract -- -InputPath ../../temp/Foxy.znelchar -OutputDir ./out/Foxy-meta -MetadataOnly`
- `npm run pack -- -CharacterJsonPath ./out/Foxy/character.json -TexturesDir ./out/Foxy/textures -OutputPath ./out/Foxy.repacked.znelchar`
- `npm run dump-yaml -- -InputPath ../../temp/Foxy.znelchar -OutputPath ./out/Foxy.yaml`
- `npm run verify -- -LeftPath ../../temp/Foxy.znelchar -RightPath ./out/Foxy.repacked.znelchar`
- `npm run verify:ci -- -LeftPath ../../temp/Foxy.znelchar -RightPath ./out/Foxy.repacked.znelchar`
- `npm run verify -- -LeftPath ../../temp/Foxy.znelchar -RightPath ./out/Foxy.repacked.znelchar -DiffReportPath ./out/Foxy.verify.json`
- `npm run verify:report -- -LeftPath ../../temp/Foxy.znelchar -RightPath ./out/Foxy.repacked.znelchar`
- `npm run verify:roundtrip -- -InputPath ../../temp/Foxy.znelchar -WorkDir ./out/roundtrip-foxy -Force`
- `npm run verify:roundtrip:ci -- -InputPath ../../temp/Foxy.znelchar -WorkDir ./out/roundtrip-foxy -Force`
- `npm run build:dist`

## Notes

### File Structure & Extraction
- `.znelchar` outer JSON uses `_characterData` (escaped JSON string) and optional `_textureDatas`.
- Initial schema is intentionally permissive to avoid rejecting unknown keys in real-world files.
- **Custom Icon Handling**: If `_characterData` contains a `customIconData` field (base64-encoded image), extraction will:
  1. Write it to a separate `customIcon.<ext>` file with format auto-detected from file headers (PNG/JPG/GIF/WebP/BMP)
  2. Remove `customIconData` from the extracted `character.json`
  3. Store icon metadata (hash, size, format, MIME type) in `manifest.json`
  - During packing, the icon is automatically re-embedded into `_characterData` if the manifest contains icon metadata
### Verification
- `verify` performs semantic comparison of character payload and texture content hashes (not byte-for-byte text comparison).
- `customIconData` is compared by SHA256 hash of the decoded icon bytes.
- `verify -CiSummary` emits a one-line CI summary plus exit code for pipeline logs.
- `verify` can emit a machine-readable diff report JSON via `-DiffReportPath`.
- `verify:roundtrip` runs extract -> pack -> verify in one command, ensuring icon data survives round-trip.
- `verify:roundtrip:ci` forwards CI summary output from verify.
### Extraction Artifacts
- `extract` produces:
  - `character.json`: Unescaped, fully expanded character data (with `customIconData` removed if present)
  - `customIcon.<ext>`: Icon image if `customIconData` was extracted
  - `textures/`: Folder with decoded texture files
  - `manifest.json`: Metadata for all extracted artifacts (source file, timestamps, hashes, and icon/texture inventory)
- `manifest.json` uses the schema at `schemas/manifest.schema.json`
- `inspect -MetadataOnly` skips nested `_characterData`/`opinionDataString` parsing for large files.
- `extract -MetadataOnly` skips nested `_characterData` parse and texture decoding; it writes a metadata manifest only.
- `pack` now validates manifest integrity with stronger guardrails for duplicate names, missing texture files, and mismatched manifest metadata.
- PowerShell module sources are under `module/Znelchar.Tools`.
- `build/package.ps1` produces two distributables: module zip and portable zip.
- portable packaging supports embedding a portable PowerShell runtime via `-PortableRuntimeZipPath` or `-DownloadPortableRuntime`.
- See `docs/DISTRIBUTION.md` for packaging and module-install details.
- `dump-yaml` uses `ConvertTo-Yaml` when available. Install module if needed:
  - `Install-Module powershell-yaml -Scope CurrentUser`

## Session Continuity

- Session continuity is managed globally for this monorepo under `docs/ai/`.
- Use `../../../docs/ai/SESSION_HANDOFF_TEMPLATE.json` as the standard payload for cross-session handoff.
- Use `../../../docs/ai/SESSION_HANDOFF_WORKFLOW.md` for the runbook and persistence policy.
- Recommended local-only snapshot path (gitignored): `../../../temp/ai/session-handoff.latest.json`
