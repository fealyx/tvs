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

- `.znelchar` outer JSON uses `_characterData` (escaped JSON string) and optional `_textureDatas`.
- Initial schema is intentionally permissive to avoid rejecting unknown keys in real-world files.
- `verify` performs semantic comparison of character payload and texture content hashes (not byte-for-byte text comparison).
- `verify -CiSummary` emits a one-line CI summary plus exit code for pipeline logs.
- `verify` can emit a machine-readable diff report JSON via `-DiffReportPath`.
- `verify:roundtrip` runs extract -> pack -> verify in one command.
- `verify:roundtrip:ci` forwards CI summary output from verify.
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
