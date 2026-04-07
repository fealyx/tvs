# ADR-001: mod-dev Engine Boundary and Responsibilities

- Status: Proposed
- Date: 2026-04-07
- Initiative: Mod Dev Bootstrap

## Context

We need a scalable way to generate modding project scaffolds across many variants (mod-only, single repo, monorepo, Unity-integrated, Thunderstore, ThunderKit). We also need to reuse existing PowerShell tooling patterns and avoid maintaining multiple divergent implementations.

Without clear boundaries, responsibilities can drift into wrappers (`dotnet new`, `npm create`) and template packs, leading to duplication and behavior skew.

## Decision

We define a PowerShell-first canonical engine in `tools/mod-dev` with these boundaries:

1. Core engine owns business logic.
2. Template packs are declarative and contain minimal logic.
3. Wrapper channels are adapters only and must delegate to the core engine.

Core engine responsibilities:

- parse and validate template pack manifest/schema,
- resolve parameter values (interactive and non-interactive),
- apply file/folder templates with deterministic ordering,
- perform safe path operations (no traversal/escape),
- execute guarded post-actions,
- emit provenance metadata for generated output,
- support dry-run previews,
- support reusable update/install primitives for tooling distribution.

Template pack responsibilities:

- declare base profile and optional add-on compatibility,
- declare template assets and destination mapping,
- declare token metadata/defaults/validation hints,
- declare conditional inclusion and post-actions.

Wrapper responsibilities:

- map wrapper-specific arguments to core engine arguments,
- bootstrap runtime dependency if missing,
- call core engine and pass through output/exit code.

## Consequences

Positive:

- one source of truth for behavior,
- easier maintenance and testing,
- faster introduction of new templates.

Tradeoffs:

- initial design overhead in defining stable engine contracts,
- wrappers cannot diverge for channel-specific convenience unless added to core contract.

## Alternatives Considered

1. `dotnet new` as canonical engine.
- Rejected: less aligned with existing PowerShell-heavy internal tooling and script reuse.

2. `npm create` as canonical engine.
- Rejected: introduces Node-first dependency for workflows that are already PowerShell-centric.

3. Multiple independent engines (PowerShell + dotnet + npm).
- Rejected: high risk of behavior drift and multiplied maintenance burden.

## Follow-Up Tasks

1. Create `template-pack.schema.json` and validate sample packs.
2. Define command surface contract for core engine.
3. Implement MVP command that applies one sample template pack with dry-run support.
