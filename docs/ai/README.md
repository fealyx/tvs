# AI continuity docs

Monorepo-level artifacts for preserving context across host and devcontainer sessions.

## Files

- `SESSION_HANDOFF_TEMPLATE.json`: canonical schema for concise cross-session handoff.
- `SESSION_HANDOFF_WORKFLOW.md`: runbook covering what to keep in git vs local-only state.

### Mod Dev Bootstrap Initiative

- `MOD_DEV_BOOTSTRAP_INITIATIVE.md`: long-term roadmap for reusable mod project scaffolding.
- `ADR-001-mod-dev-engine-boundary.md`: engine boundary and responsibilities for the mod-dev scaffold tool.
- `template-pack.schema.json`: initial schema draft for declarative template packs.
- `template-pack.example.mod-only.json`: example pack document aligned to the schema.

### TVS Manager Initiative

- `TVSM_MANAGER_INITIATIVE.md`: north star roadmap for `tvsm` and the broader tool ecosystem (unified manager, save tools, config profile, community mod registry).
- `ADR-002-shared-environment-profile.md`: decision to centralize environment config in `TVS.Environment` / `~/.tvs/config.json`.
- `ADR-003-tvsm-application-stack.md`: decision to implement `tvsm` as a .NET 8 console app with Spectre.Console.
- `ADR-004-tvs-save-tools-module.md`: decision to introduce `TVSSave.Tools` as a separate PS module following the Znelchar.Tools pattern.
- `ADR-005-unified-tvs-tools-bundle.md`: decision to ship a single unified distribution bundle replacing per-tool portables.

## Local snapshot path

- `temp/ai/session-handoff.latest.json` (gitignored)

## Usage

1. Fill a handoff payload using `SESSION_HANDOFF_TEMPLATE.json`.
2. Save the current working snapshot to `temp/ai/session-handoff.latest.json`.
3. Promote durable decisions and commands into versioned docs when they stabilize.
