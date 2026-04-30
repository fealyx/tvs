# Session handoff workflow

Use this workflow when moving between host VS Code and devcontainer sessions.

## Goal

Keep implementation context durable without relying on extension chat history persistence.

## What to keep in git

1. Keep `docs/ai/SESSION_HANDOFF_TEMPLATE.json` as the stable handoff schema.
2. Keep docs and decisions that matter long-term (architecture, format constraints, distribution behavior).
3. Keep reproducible commands in docs so a new session can execute immediately.

## What to keep local-only

1. Active session snapshot JSON with current progress and pending work.
2. Temporary notes for experiments and one-off diagnostics.

Recommended path for local snapshot:

- `temp/ai/session-handoff.latest.json`

This path is ignored by git via the root `temp/` ignore rule.

## Suggested cadence

1. Update local snapshot at major milestones.
2. Before ending a session, ensure `next_session_bootstrap.first_3_actions` is executable as-is.
3. Promote stable insights from local snapshot into versioned docs when they are no longer volatile.

## Bootstrap checklist for a new session

1. Read the latest local snapshot JSON.
2. Execute `first_3_actions` in order.
3. Confirm definition of done and highest-priority open work.
4. Continue implementation and refresh the snapshot.
