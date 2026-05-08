# ⚠️ Znelchar.Tools Portable Distribution Deprecation Notice

**Date:** 2026-05-07  
**Applies to:** `znelchar-portable-<version>.zip` distributions

## Deprecation Summary

The `znelchar-portable-<version>.zip` distribution is **deprecated** as of the TVSM Manager Initiative Phase 4.

## Replacement

**New primary distribution:** [`tvs-tools-full-<version>.zip`](../../docs/ai/adr/ADR-005-unified-tvs-tools-bundle.md)

The unified TVS Tools bundle replaces the standalone portable distributions with a single download that includes:

- `TVSM` (TVSM Manager)
- `Znelchar.Tools` (character file tools)
- `TVSSave.Tools` (save file tools)
- `TVS.Environment` (shared environment profile)
- Bundled `pwsh` 7.x runtime (in `-full` variant)

## Why the Change?

The new TVSM Unified Bundle:

- **Eliminates runtime duplication** — one `pwsh` runtime shared across all tools (~70–120 MB savings per extra tool)
- **Single download experience** — users get everything they need in one artifact
- **Natural entry point** — `tvsm` becomes the discovery surface for all TVS tooling
- **Backwards compatible** — per-tool launchers (`inspect.cmd`, `extract.cmd`, etc.) are included for existing workflows

## For Users with Their Own pwsh

If you already have PowerShell 7 installed or are in a CI/Linux environment:

**Use:** `tvs-tools-core-<version>.zip` (no bundled runtime)

This variant is cross-platform and includes `.sh` launchers for Linux/macOS.

## Migration Guide

1. **Download** the appropriate bundle from the [releases page](../../docs/ai/adr/ADR-005-unified-tvs-tools-bundle.md):
   - [`tvs-tools-full-<version>.zip`](../../docs/ai/adr/ADR-005-unified-tvs-tools-bundle.md) — Windows end-users (includes `pwsh`)
   - [`tvs-tools-core-<version>.zip`](../../docs/ai/adr/ADR-005-unified-tvs-tools-bundle.md) — Developers, CI, Linux (bring your own `pwsh`)

2. **Extract** to your preferred location

3. **Update shortcuts/scripts** (if applicable):
   - Old: `znelchar-portable/run-znelchar.cmd`
   - New: `tvs-tools-full/inspect.cmd` (or any per-tool launcher)

4. **Your existing workflows will continue to work** via the backwards-compatible launchers

## What Continues to Be Published

| Artifact | Status |
|----------|--------|
| `znelchar-module-<version>.zip` | ✅ Continues (for PS module path users) |
| `znelchar-core-<version>.zip` | ✅ Continues (no bundled runtime) |
| `tvs-tools-full-<version>.zip` | ✅ New primary (replaces `znelchar-portable`) |
| `tvs-tools-core-<version>.zip` | ✅ New core variant (cross-platform) |
| `znelchar-portable-<version>.zip` | ⚠️ **Deprecated** |

## More Information

- [ADR-005: Unified TVS Tools Distribution Bundle](../../docs/ai/adr/ADR-005-unified-tvs-tools-bundle.md)
- [TVSM Manager Initiative](../../docs/ai/initiatives/TVSM_MANAGER_INITIATIVE.md)
- [Unified Bundle Distribution Documentation](./docs/DISTRIBUTION.md) (updated)
