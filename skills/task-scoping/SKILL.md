---
name: task-scoping
description: Map a Jira ticket or task description onto the QUAPP workspace before any code — identify the target repo(s), JDK, affected files/layers, and cross-repo contract/DB impact. Use when the user says "analyze TICKET", "scope this ticket", "where does this change go", or before starting implementation.
---

# Quapp Analyze

Read-only scoping skill. Turns a ticket/task into a concrete map of **what to change and where** in the
QUAPP workspace, so `change-implementation` can start from a confirmed plan. **No code changes.**

## When to Use
- User says "analyze PQF-123", "scope this ticket", "where does this go", "what's affected".
- Before `change-implementation` on anything non-trivial.

## Workflow Steps
1. **Read the ticket/task — including its comment thread.** If a Jira key, fetch it with `comment` in
   `fields`; otherwise use the description. Comments from PO/BA/dev/QA often refine or override the
   description — reconcile both (latest comment usually wins) and carry open questions as Unknowns.
   Restate the goal + acceptance criteria in your own words.
2. **Identify target repo(s)** from `CLAUDE.md` → Repository Map (functions-backend, functions-frontend,
   ai-mcp, jupyterlab-ai-assistant-ext, quapp-migration, quapp-ai-mcp-migration).
3. **Read that repo's rules**: the matching `.claude/rules/*.md` (+ `workspace.md`). Note the **JDK**.
4. **Locate affected files** — GitNexus first ([`../../docs/rules/gitnexus.md`](../../docs/rules/gitnexus.md)):
   `query` the concept + `gitnexus://repo/{name}/clusters` to find the owning area, then `context` on
   candidate symbols; fall back to grep for config/YAML/SQL. List concrete paths.
5. **Assess cross-cutting impact**:
   - Contract impact across tiers (frontend ↔ backend `BASE_URL` ↔ ai-mcp `/api/v1`) — no codegen, so
     list every consumer that needs a matching edit.
   - DB/schema impact → which migration repo (QuaO DB vs AI-MCP DB).
   - Auth/JWT, secrets, rate-limiting touch points.
6. **Produce the report** and suggest the next skill.

## Rules Claude Must Follow
- **Read-only.** Do not modify source. Do not invent architecture.
- Work from code + `.claude/rules/` evidence; cite file paths.
- Mark anything unverifiable as **Unknown / needs confirmation** — don't guess.
- Don't assume a monorepo; name the specific repo(s).

## Output Format
```
## Ticket: <key/title>
Goal: <1–2 lines>   Acceptance: <bullets>

Target repo(s): <repo> (JDK <17|21|n/a>)
Affected files:
  - path:line — why
Cross-repo / contract impact: <consumers to update, or "none">
DB / migration impact: <which migration repo, or "none">
Auth / secrets / other risks: <…>
Open questions (Unknown/confirm): <…>
Suggested next: change-implementation | bug-investigation
```

## Verification Checklist
- [ ] Correct repo(s) and JDK identified.
- [ ] Affected files are real paths (not guessed).
- [ ] Cross-tier consumers + migration repo impact considered.
- [ ] Unknowns flagged, not invented.

## QUAPP Reminders
- Not a monorepo — one repo at a time (`workspace.md`).
- Two DBs: `quapp-migration` ↔ QuaO platform; `quapp-ai-mcp-migration` ↔ AI-MCP (`migration.md`).
- JupyterLab ext: rules live in `AGENTS.md` (its `CLAUDE.md` is a symlink).
