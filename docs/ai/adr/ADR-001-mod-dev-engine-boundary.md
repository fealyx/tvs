# ADR-001: mod-dev Engine Boundary and Responsibilities

- Status: Proposed
- Date: 2026-04-07
- Updated: 2026-04-30
- Initiative: Mod Dev Bootstrap

## Context

We need a scalable way to generate modding project scaffolds across many variants (mod-only, single repo, monorepo, Unity-integrated, Thunderstore, ThunderKit). We also need to reuse existing PowerShell tooling patterns and avoid maintaining multiple divergent implementations.

Without clear boundaries, responsibilities can drift into wrappers (`dotnet new`, `npm create`) and template packs, leading to duplication and behavior skew.

Since the original writing of this ADR, the TVS Manager initiative has established a broader tool ecosystem: the `TVS.Environment` shared configuration module (`~/.tvs/config.json`), the `tvsm` CLI (ADR-003), `TVSSave.Tools` (ADR-004), and a unified distribution bundle (ADR-005). This ADR is revised to reflect how the `mod-dev` engine fits within that ecosystem — particularly around configuration defaults, distribution, and entry points.

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
- read `modWorkDir` from `TVS.Environment` (`Get-TVSEnvironment`) as the default scaffold output path when no explicit `-OutputPath` is provided.

Core engine does **not** own tooling self-update or distribution install logic. That responsibility belongs to `tvsm update` (see ADR-005).

Template pack responsibilities:

- declare base profile and optional add-on compatibility,
- declare template assets and destination mapping,
- declare token metadata/defaults/validation hints,
- declare conditional inclusion and post-actions.

Wrapper channels and their responsibilities:

**`dotnet new` package**
- map `dotnet new` template parameters to core engine arguments,
- bootstrap `pwsh` runtime if missing,
- call core engine and pass through output/exit code.

**`npm create` package**
- map `npm create` prompts to core engine arguments,
- bootstrap `pwsh` runtime if missing,
- call core engine and pass through output/exit code.

**`tvsm scaffold` command** (new, see ADR-003)
- exposes the scaffold engine as a first-class `tvsm` subcommand for developers already using the unified tool,
- renders interactive prompts and progress via Spectre.Console,
- maps TUI/CLI arguments to core engine arguments,
- delegates entirely to the core engine — no scaffold logic of its own.

**Direct PowerShell invocation**
- no wrapper layer; callers invoke the core engine cmdlets directly.

## Consequences

Positive:

- one source of truth for behavior,
- easier maintenance and testing,
- faster introduction of new templates,
- `TVS.Environment` integration means developers who have run `tvsm config init` get sensible output path defaults without additional arguments,
- `tvsm scaffold` gives developers using the unified bundle a TUI-friendly path to the scaffold engine at no extra implementation cost.

Tradeoffs:

- initial design overhead in defining stable engine contracts,
- wrappers cannot diverge for channel-specific convenience unless added to core contract,
- `TVS.Environment` becomes a soft dependency for default-parameter behavior; callers without a configured profile must always provide explicit paths.

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
4. Integrate `Get-TVSEnvironment` for default `-OutputPath` resolution (requires `TVS.Environment` module — see ADR-002).
5. Implement `tvsm scaffold` wrapper command in `tools/tvsm` that delegates to the core engine (see ADR-003).
