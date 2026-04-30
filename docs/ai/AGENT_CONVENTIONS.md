# Agent Conventions

Rules for AI agents operating in this repository. These define what agents may do autonomously, what requires explicit human instruction, and what is reserved for human judgment only.

---

## Guiding principle

Agents should preserve the *integrity* and *trustworthiness* of the doc system. Documents that exist to record deliberate human decisions (ADRs) must remain under human control. Documents that exist to track mechanical progress (initiative status) or operational state (session handoff) are safe to automate.

---

## Architecture Decision Records

**Agents MUST NOT create or finalize ADRs without explicit human instruction.**

ADRs are permanent historical records of a deliberate decision. Their value comes from the reasoning, the alternatives considered, and the fact that a human chose to commit them. An agent-generated ADR that has not been reviewed and deliberately accepted is not an ADR — it is a draft.

Permitted:
- Drafting an ADR in-session when a human asks for one or when a significant design decision is being made and the human has not yet objected
- Proposing that an existing ADR's status should be updated (e.g., Proposed → Accepted) and asking the human to confirm
- Reading and cross-referencing existing ADRs to inform implementation

Not permitted:
- Creating a new ADR file and committing it as "Accepted" without explicit human sign-off
- Marking an ADR as "Superseded" without human instruction
- Silently rewriting the content of an existing ADR

When creating a draft ADR, use the filename prefix `DRAFT-ADR-XXX-` and note its draft status in the document header. The human decides when (and whether) to promote it.

---

## Initiative Documents

**Agents MAY update initiative documents to reflect completed work.**

Initiative docs are living planning documents, not permanent records. Keeping them accurate is valuable and low-risk.

Permitted:
- Marking a deliverable ✅ once it is implemented and verified
- Marking a phase complete once all its deliverables are done
- Adding a deliverable to an in-progress phase when directed by the human
- Updating phase descriptions to reflect scope changes agreed upon in-session
- Adding references to new ADRs in the "Related ADRs" section

Not permitted:
- Removing or rewriting phase history (even if a phase was redesigned, keep the record)
- Adding new phases or significantly expanding initiative scope without human direction

---

## Session Handoff

**Agents SHOULD write the session handoff snapshot at the end of a work session.**

The session handoff exists specifically to survive the loss of chat history. Writing it is mechanical and adds clear value.

Permitted and encouraged:
- Writing or updating `temp/ai/session-handoff.latest.json` at any major milestone and at session end
- Following the schema in `session/SESSION_HANDOFF_TEMPLATE.json`
- Ensuring `next_session_bootstrap.first_3_actions` is populated and immediately executable

Notes:
- The snapshot is gitignored (`temp/`). It is local-only operational state, not a document.
- Do not commit the snapshot to git.
- If `temp/ai/` does not exist, create it.

---

## README and cross-reference maintenance

**Agents MAY update `docs/ai/README.md`** to reflect structural changes (new ADRs added to the table, new initiative docs listed, etc.) when directed to do so or when performing a task that adds new docs.

When moving or renaming files in `docs/ai/`, agents MUST check all sibling docs for relative-path references and fix them as part of the same task.

---

## Monorepo hygiene

### Rush shrinkwrap

`common/config/rush/pnpm-lock.yaml` is a **committed artifact**. CI runs `rush install`, which fails fast if the shrinkwrap is stale — this is intentional and correct. `rush update` must never be added to CI to paper over a stale shrinkwrap.

**Rule:** Any commit that modifies `rush.json` (adding/removing a project) or any project's `package.json` (adding/removing/changing dependencies) **must** also include an updated shrinkwrap in the same commit.

After making either of those changes, run:

```
node common/scripts/install-run-rush.js update
```

Then stage and commit `common/config/rush/pnpm-lock.yaml` along with your other changes.

**Agents MUST follow this rule.** If an agent adds a project to `rush.json` or edits a `package.json`, it must run `rush update` and include the shrinkwrap in the change before considering the task complete.

---

## Summary table

| Document type | Create | Update status/progress | Update content | Finalize/commit |
|---|---|---|---|---|
| ADR | Draft only (with `DRAFT-` prefix) | Propose, human confirms | Never | Human only |
| Initiative doc | Human direction | ✅ autonomously | Scope changes: human direction | Autonomous for progress; human for scope |
| Session handoff | Autonomous | Autonomous | Autonomous | N/A (gitignored) |
| README / cross-refs | If directed | Autonomous when structure changes | If directed | Autonomous |
