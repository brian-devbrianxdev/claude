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
- **Atlassian `cloudId`**: pass the site hostname directly (e.g. `citynow-org.atlassian.net`) to
  `getJiraIssue` — don't `ToolSearch`/call `getAccessibleAtlassianResources` first "just in case"; only
  fall back to it if the hostname call actually fails. Loading a tool schema you never end up calling
  is wasted context.

## Workflow

### Step 0 — Sync every relevant repo to latest `develop` first
Before gathering evidence, sync each repo the ticket touches to a current baseline — the same
safety-gated procedure as the release-mode Step 0 in [SKILL.md](SKILL.md), just applied to however
many repos this one ticket touches (often fewer than the full six). Do this yourself, sequentially,
before auditing — not inside a sub-agent:
1. `git status --short` — if dirty, **never discard**: `git stash push -u` and note it; if the dirty
   state looks like unfinished work you don't recognize, stop and ask instead of stashing blind.
2. Record the **current branch** (`git branch --show-current`) so it can be restored afterward.
3. `git fetch origin && git checkout develop && git pull --ff-only origin develop`.
4. Inspect the ticket's `feature/*`/`bugfix/*` branch **read-only** against this fresh baseline —
   `git log <branch>`, `git diff develop...<branch> --stat`, `git show <branch>:<path>` — without
   checking it out.
5. Restore the repo's original branch (`git checkout <original branch>`, `git stash pop` if stashed)
   once this repo's evidence is gathered — don't wait until the whole audit ends if only this one
   repo is done; but never leave a repo sitting on `develop` when the audit finishes.

**Ancestry is not proof of merge status — diff content instead.** `git merge-base --is-ancestor
<branch> develop` reliably says "not merged" even when the branch's code is **already fully on
develop**, in two situations observed across this workspace:
- **Squash-merged repos** (e.g. `quapp-functions-frontend`): GitLab squashes the MR into one new
  commit on `develop`, so the original branch commits are never its ancestors.
- **Duplicate/parallel commits** (observed in `sdk/qapp-common`, `sdk/quapp-sdk-templates`,
  `functions-backend`): the same change was pushed to `develop` via a different commit (different
  SHA, same or equivalent message/diff) — often because the work was applied twice (e.g. once
  locally, once via a teammate's branch/MR) — leaving the original local branch orphaned/redundant
  even though nothing is missing.

So before scoring anything ❌ Missing or flagging a branch as "unmerged", always check
**`git diff develop...<branch> -- <path>` for actual content**, not just ancestry. An empty diff
means the code is already on `develop` — score it accordingly and note the local branch as stale
housekeeping (safe to drop/rebase), not as a real gap. See
`.claude/rules/git-workflow.md` for the branch/merge model.

### Step 1 — Load the ticket & derive the requirement set
`jira_get_issue PROJ-123`. Extract the **acceptance criteria** (or, if absent, decompose the
description/summary into concrete, checkable requirements). Also note:
- issue type (Story vs Bug — a Bug's "criterion" is *the reported defect no longer reproduces* + a regression test),
- linked subtasks, the issue key (for grepping branches/commits), and Fix Version.

Turn everything into a flat **checklist of atomic requirements**. If criteria are vague, state the
assumption you're auditing against rather than guessing silently.

**Only audit code vs. requirement — filter subtasks down to code-implementation ones.** A story's
subtask list normally mixes real dev work with a fixed trailing lifecycle pattern the
`solution-planning` skill always appends: `[QA] Verify: ...`, `[BE]/[FE] Review code`, `[BE]/[FE]
Resolve feedback merge request`. These are **process/workflow subtasks, not requirements** —
1. Never decompose them into checklist criteria.
2. Never let their Jira status (To Do / In Progress / Review) justify marking a *code* requirement
   🟡/❌ — a requirement whose code is implemented and correct is not held back by a QA/E2E subtask,
   a code-review subtask, or a resolve-feedback-MR subtask still sitting in To Do. Those are lifecycle
   gates the ticket's own workflow tracks separately (`/ship-task`), not something this audit re-scores.
3. Only the **`[BE]`/`[FE]`-labeled implementation subtasks** (the ones naming an actual repo/deliverable,
   e.g. "qapp-common: Language.C + RUNNER_MAP + version bump") are in scope for evidence-gathering —
   trace requirements to code and to that repo's own applicable code-level tests (unit/integration per
   `rules/java.md`/`rules/testing.md`), not to a separate manual/E2E verification pass.

Still **report** the process subtasks' status for context (e.g. "QA E2E verify: To Do — not scored"),
just don't let them move the completion %.

### Step 2 — Find the evidence in the codebase
For each requirement, search for implementing code AND tests:
- **Prefer GitNexus** (`query`/`context`/`impact` — load via `ToolSearch`; see
  [docs/rules/gitnexus.md](../../docs/rules/gitnexus.md)) over grep to find implementing symbols —
  it's cheaper and more precise than an agent grepping blind through a repo it doesn't know. Fall back
  to grep by feature keywords/endpoint paths/class names/config keys/issue-key-in-commits only where
  GitNexus doesn't cover it (dynamic routes, WS/STOMP/SSE, cross-ext calls).
- Trace each criterion to concrete files (`path:line`).
- Distinguish **implemented** vs **implemented + tested** — untested code is not "done". **Exception:
  FE source** — per [`rules/testing.md`](../../rules/testing.md), `quapp-functions-frontend` (entire
  repo) and `quapp-jupyterlab-ai-assistant-ext`'s TS/React `src/` code do not require new unit tests;
  implemented-but-untested code there still scores Done. Does **not** cover that ext's Python server
  extension or its Playwright/Galata suite — those keep the normal untested-is-Partial rule.

Use the [rules/java.md](../../rules/java.md) routing table to know where things
*should* live (controller/service/entity/config) when hunting for them.

**If the ticket spans multiple repos** (common — a Story's `[BE]`/`[FE]` subtasks often land in
different repos), it's fine to fan out **one read-only agent per repo** here, same idea as the
release-mode Step 2 fan-out. If you do:
- **Pin `model: 'sonnet'`** explicitly on every one of those `Agent`/`Workflow` calls — per
  [`docs/rules/model-routing.md`](../../docs/rules/model-routing.md) ("`completion-audit` — per-ticket
  audit workers: sonnet"; rule 2: "subagent fan-outs must set `model` explicitly per the table; only
  orchestrators inherit"). This applies in single-ticket mode too, not just release mode — don't spawn
  an unpinned agent and let it default.
- Give each agent the GitNexus-over-grep instruction above directly in its prompt.
- Keep the synthesis (scoring, completion %, the plan) at the orchestrator — don't have a sub-agent
  compute the final percentage or write the plan.

### Step 3 — Score each requirement
Rate every checklist item:
| Status | Meaning |
|--------|---------|
| ✅ Done | Implemented **and** covered by a passing test |
| 🟡 Partial | Implemented but untested, incomplete, or only happy-path (untested does **not** apply to in-scope FE source — see the exception above) |
| ❌ Missing | No evidence in the codebase |
| ⚠️ Unknown | Can't verify (needs running app / external system / clarification) |

"Covered by a passing test" means the implementation subtask's own **automated** repo-level tests
(unit/integration per `rules/java.md`/`rules/testing.md`) where they exist and were actually run. For
a repo with no automated test runner (e.g. `quapp-sdk-templates`, whose only stated verification is a
live Docker build), don't require that live build/deploy/invoke to have happened — score on careful
code-reading against the contract instead. Either way, do **not** withhold ✅/🟡 merely because a
separate ticket-level QA/E2E, code-review, or resolve-feedback-MR subtask hasn't run yet — note its
pending status as context, never as the reason for the score.

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
- `jira_get_issue` once; cache the criteria list. Pass the site hostname as `cloudId` directly —
  don't `ToolSearch`/call `getAccessibleAtlassianResources` unless the hostname call fails.
- Request a minimal explicit `fields` list (never `*all`); note the Jira API still nests full subtask
  objects (avatars, self-links) regardless — that overhead isn't prunable further from this side.
- Search by targeted keywords; read only the file regions that match, not whole files.
- **Prefer GitNexus over grep-heavy agents** for locating implementing symbols (see Step 2) — it's the
  cheaper path per query and avoids an agent burning tool-calls rediscovering repo structure blind.
- Batch the searches per criterion; don't re-read the ticket between criteria.
- If fanning out one agent per repo (Step 2), **pin `model: 'sonnet'` on every call** — an unpinned
  fan-out risks running on a costlier default tier for what's routine evidence-mapping work.

## Anti-patterns
❌ Trusting the ticket's status field instead of checking code.
❌ Counting untested code as "done" (except in-scope FE source — `quapp-functions-frontend` and the
   JupyterLab ext's TS/React `src/` — where it's a rule, not an anti-pattern — see `rules/testing.md`).
❌ Inventing a percentage without showing which criteria back it.
❌ Editing code or moving the ticket — that's [/start-task](../../commands/start-task.md) /
   [/ship-task](../../commands/ship-task.md), not this audit.
❌ Treating a `[QA] Verify`/`Review code`/`Resolve feedback merge request` subtask as a requirement,
   or downgrading correctly-implemented code because that subtask is still To Do — those are lifecycle
   gates the ticket's own workflow tracks, not this audit's scope (see Step 1).
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
