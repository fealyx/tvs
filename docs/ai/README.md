# AI Continuity Docs

Monorepo-level artifacts for preserving context, recording decisions, and maintaining continuity across sessions and contributors.

## Directory Structure

```
docs/ai/
  README.md              ← this file; start here
  AGENT_CONVENTIONS.md   ← rules for what AI agents may/must/must-not do autonomously
  adr/                   ← Architecture Decision Records (permanent, immutable)
  initiatives/           ← Long-term planning and north-star docs per initiative
  session/               ← Session handoff tooling and templates
```

---

## Architecture Decision Records (`adr/`)

ADRs are permanent historical records. Status values: `Proposed` → `Accepted` → `Deprecated` / `Superseded by ADR-XXX`. Records are never deleted or rewritten — superseded decisions are marked and a new ADR is created instead.

| ADR | Status | Summary |
|---|---|---|
| [ADR-001](./adr/ADR-001-mod-dev-engine-boundary.md) | Accepted | Engine boundary and responsibilities for the mod-dev scaffold tool |
| [ADR-002](./adr/ADR-002-shared-environment-profile.md) | Accepted | Centralize environment config in `TVS.Environment` / `~/.tvs/config.json` |
| [ADR-003](./adr/ADR-003-tvsm-application-stack.md) | Accepted | Implement `tvsm` as a PowerShell 7 module + script app using PwshSpectreConsole |
| [ADR-004](./adr/ADR-004-tvs-save-tools-module.md) | Accepted | Introduce `TVSSave.Tools` as a separate PS module following the Znelchar.Tools pattern |
| [ADR-005](./adr/ADR-005-unified-tvs-tools-bundle.md) | Proposed | Ship a single unified distribution bundle replacing per-tool portable zips |
| [ADR-006](./adr/ADR-006-mod-storage-and-linking-strategy.md) | Accepted | Store-and-link mod management: version-addressed store + directory junctions; survives game updates |

---

## Initiatives (`initiatives/`)

Initiative docs are living documents — they are updated as phases complete and scope evolves. Each initiative owns a slice of the feature roadmap and references the ADRs that govern its design decisions.

| Document | Status | Summary |
|---|---|---|
| [TVSM_MANAGER_INITIATIVE.md](./initiatives/TVSM_MANAGER_INITIATIVE.md) | Phase 2 active | North-star roadmap for `tvsm`: unified CLI, mod management, save tools, config profile, community registry |
| [MOD_DEV_BOOTSTRAP_INITIATIVE.md](./initiatives/MOD_DEV_BOOTSTRAP_INITIATIVE.md) | Proposed | Reusable mod project scaffolding via declarative template packs |

### Supporting files (`initiatives/`)

- `template-pack.schema.json` — schema for Mod Dev Bootstrap template pack documents
- `template-pack.example.mod-only.json` — example template pack aligned to the schema

---

## Session Tooling (`session/`)

| File | Purpose |
|---|---|
| [SESSION_HANDOFF_TEMPLATE.json](./session/SESSION_HANDOFF_TEMPLATE.json) | Canonical schema for a concise cross-session context handoff payload |
| [SESSION_HANDOFF_WORKFLOW.md](./session/SESSION_HANDOFF_WORKFLOW.md) | Runbook: what to keep in git vs. local-only, when and how to write a handoff |

Local working snapshot (gitignored): `temp/ai/session-handoff.latest.json`

---

## Agent conventions

[AGENT_CONVENTIONS.md](./AGENT_CONVENTIONS.md) defines what agents operating in this repo may do autonomously vs. what requires explicit human instruction. Read it before taking any action on docs in this directory.

Key rules at a glance:
- **ADRs**: draft only (with `DRAFT-` prefix); humans finalize
- **Initiative docs**: agents may mark deliverables/phases complete; humans direct scope changes
- **Session handoff**: fully autonomous — write it at milestones and end of session
- **README / cross-refs**: update autonomously when structure changes; new content needs direction

---

## Quick orientation for a fresh session

1. Read this README for the lay of the land.
2. Read the relevant initiative doc for the work area (e.g. `TVSM_MANAGER_INITIATIVE.md` for any `tvsm` or mod-management work).
3. Read the ADRs referenced by that initiative for the specific decisions governing the implementation.
4. Check `temp/ai/session-handoff.latest.json` for the most recent in-progress session state, if present.
