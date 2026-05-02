# TVSSave.Tools Initiative

Long-term planning and backlog for the `TVSSave.Tools` PowerShell module.

## Purpose

Track features and improvements to `TVSSave.Tools` beyond the Phase 3 scope defined in the TVSM Manager Initiative. This document is a living backlog stub; items here are candidates for future phases or standalone releases.

## Phase 3 scope (current)

See [TVSM_MANAGER_INITIATIVE.md Phase 3](./TVSM_MANAGER_INITIATIVE.md#phase-3-tvssavetools-module) and [ADR-004](../adr/ADR-004-tvs-save-tools-module.md) for the full Phase 3 deliverable set.

Summary: character preset slot support — export/import `presetSlot{n}.txt.tmp` ↔ `.znelchar`, expand/compress, bi-directional file watcher.

### Znelchar.Tools pipeline fix (prerequisite — ADR-007)

`Expand-TVSCharacterPreset` and `Compress-TVSCharacterPreset` are currently non-functional. Both cmdlets pass the wrong input types to `Znelchar.Tools` functions that require the `.extracted/` intermediary state. [ADR-007](../adr/ADR-007-znelchar-direct-pipeline.md) resolves this by extending `Expand-ZnelcharData` to accept `.znelchar` input and `Compress-ZnelcharData` to produce `.znelchar` output directly — eliminating the need for `TVSSave.Tools` to orchestrate `Export-ZnelcharContent` or `New-ZnelcharFile`. Both `TVSSave.Tools` cmdlets become correct thin delegations once ADR-007 is implemented.

## Future backlog

### Save snapshots and restore

- `New-TVSSaveSnapshot [-Label <string>]` — copy the entire player data directory to a timestamped snapshot in `{saveWorkDir}/snapshots/`.
- `Restore-TVSSaveSnapshot -SnapshotPath <string> [-OutputPath <string>]` — restore a snapshot (with confirmation prompt; does not require `-Force` since it restores to a target path rather than overwriting live data directly).
- `Get-TVSSaveSnapshot [-Path <string>]` — list available snapshots with label, date, and size.
- `tvsm save snapshot` / `tvsm save restore` tvsm façade commands.

### Save diffing

- `Compare-TVSSave -ReferencePath <string> -DifferencePath <string>` — structured diff between two `SaveFile.es3` files or two `presetSlot{n}.txt.tmp` files; returns a diff object and optionally renders a Spectre side-by-side table.
- `tvsm save diff <file1> <file2>` façade.

### Settings.es3 introspection

- `Get-TVSSettings [-Path <string>]` — parse `Settings.es3` and return a structured object.
- `Set-TVSSetting -Key <string> -Value <object>` — write a setting back to `Settings.es3` with round-trip safety.

### Broader ES3 support

- `Get-TVSES3Value -Path <string> -Key <string>` — generic ES3 key reader; useful for ad-hoc inspection of any `.es3` file.
- `Set-TVSES3Value -Path <string> -Key <string> -Value <object> [-Type <string>]` — generic ES3 key writer.

### Progressive schema coverage

As more of the `SaveFile.es3` structure is understood, extend the JSON schema and add typed accessors (progression data, mission stats, store unlocks).

### `tvsm save` command expansion

- `tvsm save info` — pretty-print a summary of a save (character count, progression stats, last used character).
- `tvsm save clean` — remove orphaned `.znelchar` and `expanded/` entries for slots that no longer exist in `SaveFile.es3`.
