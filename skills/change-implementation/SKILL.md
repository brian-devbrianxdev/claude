---
name: change-implementation
description: Implement a ticket/task in the QUAPP workspace through a guarded 8-step flow — read current code, identify repo(s), read rules, propose a plan, WAIT for approval, make a minimal diff, run checks, summarize files + risks. Use when the user says "implement PQF-123", "build this feature/fix", or after task-scoping.
---

# Quapp Implement

Drives a change through an **approval-gated, minimal-diff** flow. Code is only written after the user
approves the plan (step 5).

## When to Use
- User says "implement PQF-123", "do this ticket", "build the feature/fix", "apply the change".
- After `task-scoping` has scoped the work.

## Workflow Steps (mandatory, in order)
1. **Read the current code first.** Open the actual files involved and understand existing patterns
   before forming any plan. Use GitNexus `context` on the symbols you'll touch and `impact` to list
   every caller the diff must keep working ([`../../docs/rules/gitnexus.md`](../../docs/rules/gitnexus.md));
   fold that blast radius into the plan.
2. **Identify affected repo(s).** Map the task to repo(s) via `CLAUDE.md` → Repository Map; note the
   JDK. List every consumer if the change crosses tiers (frontend ↔ backend ↔ ai-mcp).
3. **Read relevant `.claude/rules/`.** The matching repo file(s) + `workspace.md` (+ `testing.md`).
4. **Propose a plan.** List the exact files to change, the approach, the cross-tier/DB impact, and the
   checks you'll run. Keep it minimal.
5. **WAIT for approval.** Do not edit source until the user approves. Use the question/approval step.
6. **Implement a minimal diff.** Change only what the plan covers; match surrounding style; reuse
   existing helpers. No drive-by refactors, no TODOs/dead code.
7. **Run relevant checks.** Use the per-repo test/lint commands from `.claude/rules/testing.md` with the
   repo's correct JDK. Non-obvious nuance to keep in mind: in `quapp-ai-mcp`, repo/controller tests belong
   in **`integrationTest`** (Testcontainers, needs Docker) while unit logic runs under `test`.
   If the change needs new tests, add minimal focused ones in the same step; defer deep JUnit/AssertJ
   authoring to the `test-authoring` skill.
8. **Summarize** changed files (table), what/why, checks run + results, and risks/follow-ups.

## Rules Claude Must Follow
- **No source edits before the step 5 approval. Do not invent architecture.**
- Minimal diff; operate in **one repo at a time**, but a single task may require a coordinated
  sequence across multiple repos (e.g. backend DTO + frontend consumer + ai-mcp contract). Do not
  declare the task complete until all required consumers are updated or explicitly recorded as
  follow-up work. Match each repo's JDK and conventions.
- Java: keep strict layering; **never expose JPA entities** outside the repository layer (`workspace.md`).
- Frontend: use **`yarn`**, not npm. JupyterLab ext: edit `AGENTS.md`, not the symlinks; `jlpm build` after TS edits.
- Keep cross-tier contracts in sync (frontend ↔ backend ↔ ai-mcp) — update every consumer.
- Schema changes → a new Liquibase changeset in the **correct** migration repo; never `ddl-auto`.
- Don't weaken auth/rate-limiting; never commit secrets. **Commit/push/MR only if explicitly asked**
  (then defer to `/start-task` / `/ship-task` / `commit`).
- Report real check results — never claim green if not run.

## Output Format
**Before approval:**
```
## Plan — <ticket>
Repo: <repo> (JDK <…>)
Files to change:
  - path — change
Approach: <short>
Contract/DB impact: <…>   Checks I'll run: <…>
```
**After implementation:**
```
## Done — <ticket>
| File | Change | Why |
Checks: <command> → <result>
Risks / follow-ups: <…>   Cross-tier edits needed elsewhere: <…>
```

## Verification Checklist
- [ ] Current code + relevant `.claude/rules/` read before planning.
- [ ] Affected repo(s) and JDK identified.
- [ ] Plan approved before any edit.
- [ ] Diff is minimal and matches repo conventions.
- [ ] Correct JDK; relevant tests/lint actually run and reported.
- [ ] Cross-tier consumers + migration repo handled.
- [ ] No secrets committed; no commit/push unless asked.

## Token hygiene
In the final summary, recommend running **`/ship-task` in a fresh session** (`/clear`) — the diff,
branch, and ticket carry all required state; dragging the scoping/implementation transcript into the
ship phase is the single largest token cost in a full-lifecycle session.

## QUAPP Reminders
- See `CLAUDE.md` §5 safety rules and the repo's `.claude/rules/*.md`.
- ai-mcp Spring Boot is 3.4.5 / Java 21; backend is 3.0.5 / Java 17 (`workspace.md` JDK matrix).
- No generated cross-repo client — DTO/endpoint changes don't propagate automatically.
