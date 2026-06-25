---
name: code-review
description: Review the current uncommitted diff (or a branch) in a QUAPP repo against the .claude/rules conventions before commit/MR. Use when the user says "review my diff", "review changes before commit", "check this against the rules", or "pre-MR review".
---

# Quapp Review

Read-only review of pending changes against QUAPP workspace rules. Produces severity-ranked findings at
`file:line` and a pass/fail gate. **No edits.**

## When to Use
- User says "review my diff", "pre-MR check", "does this follow the rules", before commit/MR.
- After `change-implementation`, as an independent check.

## Workflow Steps
1. **Detect scope.** Run `git status` / `git diff` (and `git diff <base>...` for a branch) in the
   changed repo(s). Identify which repo(s) and what changed.
2. **Load the rules** for each touched repo: matching `.claude/rules/*.md` + `workspace.md`.
3. **Check the diff** against:
   - Java: strict layering, naming, **no JPA entity leakage**, `controller/v1/` versioning.
   - Frontend: `dataSources/` placement, no `console.log`/`any` drift, `yarn` usage.
   - JupyterLab ext: edited `AGENTS.md` (not symlinks); backend/frontend logic kept separate.
   - Cross-tier **contract sync** (frontend ↔ backend ↔ ai-mcp) — flag unmatched DTO/endpoint edits.
   - DB changes in the **correct migration repo**; no `ddl-auto` reliance.
   - **Secrets** never committed; auth/rate-limiting not weakened; correct JDK.
   - Minimal-diff hygiene: no TODOs, dead code, or unrelated changes.
4. **Rank findings** (Blocker / Major / Minor / Nit) at `file:line` with a concrete fix.
5. For deep dives, point to specialist skills (don't duplicate them).

## Rules Claude Must Follow
- **Read-only.** Do not modify source. Do not invent issues — cite the rule + `file:line`.
- Distinguish a real rule violation from a style preference; say which.
- Mark uncertain findings **Unknown / needs confirmation**.

## Output Format
```
## Diff Review — <repo>(s), <N> files
Gate: PASS | CHANGES REQUESTED

| Severity | file:line | Issue | Rule | Fix |
|----------|-----------|-------|------|-----|

Deep-dive suggestions: code-review | security-review | code-review | /code-review
```

## Verification Checklist
- [ ] Reviewed the actual `git diff`, not assumptions.
- [ ] Each finding cites a rule + `file:line`.
- [ ] Contract-sync and migration-repo placement checked.
- [ ] No secrets / no auth weakening introduced.

## QUAPP Reminders
- One repo at a time; match its JDK (`workspace.md`).
- No generated cross-repo client — a DTO/route change must have matching consumer edits.
- Specialist gates already exist: `code-review`, `code-review`, `security-review`,
  `code-review` — use them for depth.
