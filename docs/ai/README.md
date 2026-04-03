# AI continuity docs

Monorepo-level artifacts for preserving context across host and devcontainer sessions.

## Files

- `SESSION_HANDOFF_TEMPLATE.json`: canonical schema for concise cross-session handoff.
- `SESSION_HANDOFF_WORKFLOW.md`: runbook covering what to keep in git vs local-only state.

## Local snapshot path

- `temp/ai/session-handoff.latest.json` (gitignored)

## Usage

1. Fill a handoff payload using `SESSION_HANDOFF_TEMPLATE.json`.
2. Save the current working snapshot to `temp/ai/session-handoff.latest.json`.
3. Promote durable decisions and commands into versioned docs when they stabilize.
