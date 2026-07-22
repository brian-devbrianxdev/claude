---
name: completion-audit
description: Audit a Jira ticket against the codebase to judge whether it is actually complete — map each acceptance criterion to code/tests, score a completion percentage, list what is missing, and produce a plan to finish it that follows the project's code rules. Use when user says "audit JIRA-123", "is this ticket done", "check completion of PROJ-456", or "what's left on this story".
---

# Jira Ticket Audit Skill

Given a Jira ticket, determine how complete it really is by checking the codebase — not by trusting
the ticket status. Produce an evidence-backed completion percentage, a gap list, and a plan to finish.

## When to Use
- User says "audit JIRA-123" / "is PROJ-456 actually done" / "what's left on this story"
- Before moving a ticket to Done, or when a ticket's status looks optimistic
- Sprint review / handoff verification

## Prerequisites
- Jira MCP server configured (see [mcp.json](../../../mcp.json)) — uses `jira_get_issue`,
  `jira_search`, `jira_get_transitions` from [`mcp-atlassian`](https://github.com/sooperset/mcp-atlassian).
- Read access to the codebase.

## Workflow

### Step 1 — Load the ticket & derive the requirement set
`jira_get_issue PROJ-123`. Extract the **acceptance criteria** (or, if absent, decompose the
description/summary into concrete, checkable requirements). Also note:
- issue type (Story vs Bug — a Bug's "criterion" is *the reported defect no longer reproduces* + a regression test),
- linked subtasks, the issue key (for grepping branches/commits), and Fix Version.

Turn everything into a flat **checklist of atomic requirements**. If criteria are vague, state the
assumption you're auditing against rather than guessing silently.

### Step 2 — Find the evidence in the codebase
For each requirement, search for implementing code AND tests:
- grep by feature keywords, endpoint paths, class/method names, config keys, the issue key in commits.
- Trace each criterion to concrete files (`path:line`).
- Distinguish **implemented** vs **implemented + tested** — untested code is not "done". **Exception:
  FE source** — per [`rules/testing.md`](../../rules/testing.md), `quapp-functions-frontend` (entire
  repo) and `quapp-jupyterlab-ai-assistant-ext`'s TS/React `src/` code do not require new unit tests;
  implemented-but-untested code there still scores Done. Does **not** cover that ext's Python server
  extension or its Playwright/Galata suite — those keep the normal untested-is-Partial rule.

Use the [rules/java.md](../../rules/java.md) routing table to know where things
*should* live (controller/service/entity/config) when hunting for them.

### Step 3 — Score each requirement
Rate every checklist item:
| Status | Meaning |
|--------|---------|
| ✅ Done | Implemented **and** covered by a passing test |
| 🟡 Partial | Implemented but untested, incomplete, or only happy-path (untested does **not** apply to in-scope FE source — see the exception above) |
| ❌ Missing | No evidence in the codebase |
| ⚠️ Unknown | Can't verify (needs running app / external system / clarification) |

### Step 4 — Compute completion percentage
```
completion % = (Σ weight × status_factor) / Σ weight
status_factor: Done=1.0, Partial=0.5, Missing=0, Unknown=excluded from denominator (reported separately)
```
Weight by effort/importance when criteria are uneven; otherwise weight each equally. Always show the
math (e.g. "6 of 8 criteria done, 1 partial → 81%"), never a bare number.

### Step 5 — Report the audit
Output a concise, evidence-linked report:
```
## Audit: PROJ-123 — "Add OAuth2 login"
Completion: 81%  (✅ 6  🟡 1  ❌ 1  ⚠️ 0 of 8 criteria)

| # | Acceptance criterion         | Status | Evidence / Gap                          |
|---|------------------------------|--------|-----------------------------------------|
| 1 | Google OAuth2 flow works     | ✅     | OAuth2Controller.java:42, tests pass    |
| 2 | Token refresh handled        | 🟡     | RefreshService.java:30 — no test        |
| 3 | Errors surfaced to UI        | ❌     | no error mapping found                  |
```

### Step 6 — Plan to complete (only the gaps)
For every 🟡 / ❌ / ⚠️ item, produce an ordered plan that **adheres to the project's code rules** —
route it through the [rules/java.md](../../rules/java.md) gate:
- **Phase 0** branch setup (`<type>/khactuong.ngohoang/...` from an updated base) before coding,
- self-explanatory code, **no comments** (Javadoc on public APIs only),
- tests mandatory (regression test for any bug-type gap),
- self-review gate (code-review + security-review) before commit.

Each plan item: what to change, where (`path`), which test to add, and which skill governs it. Keep
the plan minimal — close the gap, don't gold-plate.

## Output Contract
1. Completion % with the count breakdown and the math.
2. Per-criterion table with status + evidence/gap.
3. Ordered completion plan referencing code rules (or "✅ nothing missing" if 100%).
Do **not** change any code or transition the ticket — this skill only audits and plans.

## Token Optimization
- `jira_get_issue` once; cache the criteria list.
- Search by targeted keywords; read only the file regions that match, not whole files.
- Batch the searches per criterion; don't re-read the ticket between criteria.

## Anti-patterns
❌ Trusting the ticket's status field instead of checking code.
❌ Counting untested code as "done" (except in-scope FE source — `quapp-functions-frontend` and the
   JupyterLab ext's TS/React `src/` — where it's a rule, not an anti-pattern — see `rules/testing.md`).
❌ Inventing a percentage without showing which criteria back it.
❌ Editing code or moving the ticket — that's [/start-task](../../commands/start-task.md) /
   [/ship-task](../../commands/ship-task.md), not this audit.
✅ Evidence-linked statuses, transparent math, a minimal rules-compliant plan for the gaps only.

## Example
```
> "Audit PROJ-456 — is it done?"
1. jira_get_issue → 5 acceptance criteria
2. grep codebase, trace each to files + tests
3. score: ✅3 🟡1 ❌1 → 70%
4. report table with path:line evidence
5. plan the 🟡 (add test) and ❌ (implement + test) via rules/java.md gate
```

## References
- [/start-task](../../commands/start-task.md) · [/ship-task](../../commands/ship-task.md) · [rules/java.md](../../rules/java.md)
- [mcp-atlassian server](https://github.com/sooperset/mcp-atlassian)
