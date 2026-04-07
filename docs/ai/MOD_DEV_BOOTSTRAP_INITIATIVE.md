# Mod Dev Bootstrap Initiative

Long-term planning and continuity reference for the TVS mod project bootstrap effort.

## Purpose

Provide a durable, implementation-oriented strategy for building and distributing reusable modding project templates and shared tooling, while minimizing duplication and long-term maintenance risk.

This document is intended to survive context resets and tangent work. Treat it as the canonical north star for the initiative.

## Problem Statement

We want to help developers quickly start modding projects in their own repositories with multiple setup shapes, including:

- full mod monorepo templates,
- single mod repository templates,
- standalone mod-only templates,
- workflows with Unity project integration,
- ThunderKit and Thunderstore-oriented variants.

At the same time, we already have useful PowerShell tooling and release/build logic in this repo that should be reused instead of duplicated.

## Guiding Principles

1. One engine, many entry points.
2. Keep templates mostly declarative (data over code).
3. Compose variants from base templates plus add-ons.
4. Keep PowerShell as the canonical implementation surface.
5. Make outputs deterministic and automation-friendly.
6. Centralize shared concerns like update/install logic.

## Proposed Architecture

### 1) Shared Core Library

Create a shared internal tooling library (working name: `tools/mod-dev`), implemented in PowerShell, that provides:

- template rendering and hydration,
- token/parameter validation,
- file operations with path traversal protection,
- archive and checksum utilities,
- distribution manifest helpers,
- common logging/output conventions,
- centralized self-update/install primitives.

### 2) Template Packs (Declarative)

Represent templates as versioned packs containing:

- folder and file structure,
- token schema and defaults,
- optional prompts/parameter metadata,
- conditional file inclusion rules,
- post-generation steps (script hooks with guardrails).

Template packs should contain minimal logic. Core behavior belongs in the shared library.

### 3) Composition Model

Avoid combinatorial template explosion by composing:

- base profile: `mod-only`, `single-repo`, `monorepo`,
- add-ons: `unity-link`, `thunderstore`, `thunderkit`, `ci-profile`, `release-profile`, etc.

Generation should accept one base plus N add-ons and produce the final scaffold deterministically.

### 4) Distribution Entry Points

Canonical engine stays in PowerShell; optional wrappers improve adoption:

- `dotnet new` package for .NET-centric users,
- `npm create` wrapper for Node-centric users,
- direct PowerShell command for power users and CI.

All entry points should delegate to the same underlying engine to prevent drift.

## Why This Fits TVS

- Current tooling already leans heavily on PowerShell for mod and znelchar workflows.
- Existing script patterns in `mods/scripts` are reusable starting points.
- Existing update/install behavior in znelchar can be generalized for common self-update flow.
- Rush monorepo structure can host the shared project cleanly under `tools`.

## Phased Implementation Plan

### Phase 0: Discovery and Contract Definition

Goals:

- Define target user journeys and first supported scenarios.
- Define template pack schema (`v1`) and compatibility guarantees.
- Define command surface and argument model.

Deliverables:

- template schema spec doc,
- command surface spec doc,
- implementation ADR for engine boundaries.

Exit criteria:

- Agreement on first template scope and stability constraints.

### Phase 1: Core Engine MVP

Goals:

- Build shared PowerShell module for rendering/hydration.
- Implement safe copy/hydration and dry-run mode.
- Add deterministic output and validation checks.

Deliverables:

- `tools/mod-dev` module skeleton,
- unit/integration tests for template application,
- `new-mod-project` command prototype.

Exit criteria:

- Can generate one production-ready template from CLI in non-interactive mode.

### Phase 2: First Public Template Set

Goals:

- Ship `single-repo` and `mod-only` base templates.
- Add at least one add-on (recommended: Thunderstore metadata/workflow integration).

Deliverables:

- versioned template packs,
- usage docs and examples,
- validation scripts for generated output.

Exit criteria:

- New user can scaffold, build, and package without manual fixups.

### Phase 3: Monorepo and Unity Integration

Goals:

- Add `monorepo` base template.
- Add Unity-aware integration add-on.

Deliverables:

- monorepo template variant,
- integration hooks and docs for Unity project workflows.

Exit criteria:

- Scaffolds with predictable local dev and CI behavior.

### Phase 4: Wrapper Channels and Distribution

Goals:

- Publish `dotnet new` wrapper.
- Publish `npm create` wrapper.
- Ensure wrappers call the same engine contract.

Deliverables:

- package/publish automation,
- compatibility tests across entry points.

Exit criteria:

- Equivalent scaffold results from each channel for same inputs.

## Backlog (Prioritized)

1. Define `template-pack.schema.json` with strict validation rules.
2. Define token naming and escaping conventions.
3. Implement dry-run with explicit file operation preview.
4. Implement provenance file in generated projects (engine/template versions).
5. Add idempotence checks and rerun behavior policy.
6. Add shared updater abstraction and migrate existing tool updater(s) onto it.
7. Add baseline test matrix for generated templates.

## Quality Gates

Every milestone should meet the following:

- deterministic output for identical inputs,
- no path traversal vulnerability in hydration/copy,
- non-interactive mode works end-to-end,
- generated project validates with documented commands,
- clear migration notes for schema or behavior changes.

## Risks and Mitigations

### Risk: Template Explosion

Mitigation: base-plus-add-on composition model; avoid bespoke templates for every combination.

### Risk: Engine Drift Across Entry Points

Mitigation: wrappers delegate only; no business logic in wrappers.

### Risk: Shared Library Becomes a Bottleneck

Mitigation: clear module boundaries, semantic versioning, compatibility tests.

### Risk: Update Flow Inconsistency

Mitigation: centralize update/install primitives and manifest format.

## Decision Log

Track major decisions here as one-liners.

- 2026-04-07: Canonical template engine will be PowerShell-first.
- 2026-04-07: Variant strategy is composition (base + add-ons), not independent combinatorial templates.
- 2026-04-07: Wrapper channels (`dotnet new`, `npm create`) are optional but should delegate to one engine.

## Session Continuity Protocol

When this effort pauses and resumes:

1. Update the decision log if scope or architecture changed.
2. Add or reorder backlog items to reflect current priorities.
3. Record current phase and next actionable step in a short note at top of active PR/issue.
4. If context is tight, continue by reading this file first.

## Immediate Next Steps

1. Create a short ADR that defines the `tools/mod-dev` project boundary and responsibilities.
2. Draft the `template-pack.schema.json` and sample pack for `mod-only`.
3. Build a thin MVP command that applies one sample pack with `-WhatIf`/dry-run support.
