---
name: jira-bugfix
description: Drive a bug-fix Jira workflow end to end — create/fetch a Bug, reproduce, fix with a regression test, move it across the board, branch, commit, PR, and transition to done. Use when user says "fix bug from Jira", "work on bug PROJ-456", "create a Bug", or when linking a bug fix to a Jira ticket.
---

# Jira Bug Fix Workflow Skill

Drive a **bug fix** (Jira **Bug**) through its full lifecycle:
create → triage → reproduce → fix + regression test → branch → commit → PR → done.

For new features, use the [jira-feature](../jira-feature/SKILL.md) skill instead.

## When to Use
- User says "fix bug PROJ-456" / "work on bug from Jira" / "create a Bug"
- Fixing defective behavior that should be tracked in Jira
- Linking a bug-fix branch/PR to a Jira ticket

## Prerequisites

**Required**: Jira MCP server configured (see project [mcp.json](../../../mcp.json)).
Uses [`mcp-atlassian`](https://github.com/sooperset/mcp-atlassian) tools:

| Tool | Purpose |
|------|---------|
| `jira_get_issue` | Read repro steps, stack trace, affected version |
| `jira_search` | JQL search (find duplicate bugs) |
| `jira_create_issue` | Create the Bug |
| `jira_update_issue` | Set priority, assignee, Fix Version |
| `jira_get_transitions` | List valid next statuses |
| `jira_transition_issue` | Move across the board |
| `jira_add_comment` | Post root cause + PR link |

> ⚠️ Transition names/IDs vary per project. NEVER hard-code a transition ID —
> always call `jira_get_transitions` first and match by name.

## Workflow

### Step 1 — Create or fetch the Bug
**If creating** — a bug without **reproduction steps** is not actionable:
```
Tool: jira_create_issue
{
  "project_key": "PROJ",
  "issue_type": "Bug",
  "summary": "NPE when plugin directory is missing",
  "description": "h3. Environment\nJava 21, app v3.2.1\n\nh3. Steps to Reproduce\n# Start app with no /plugins dir\n# Trigger plugin scan\n\nh3. Expected\nEmpty plugin list, no error\n\nh3. Actual\nNullPointerException at PluginManager.scan()\n\n{code}\njava.lang.NullPointerException\n  at PluginManager.scan(PluginManager.java:88)\n{code}",
  "additional_fields": {
    "labels": ["bug"],
    "priority": { "name": "High" }
  }
}
```
**If existing**: `jira_get_issue PROJ-456` — read the stack trace, repro steps, affected version.

### Step 2 — Triage priority (optional)
For severity (P0–P3), set the `priority` via `jira_update_issue`.

### Step 3 — Assign & move to In Progress
```
jira_update_issue        → set assignee (+ priority in same call)
jira_get_transitions     → find "In Progress"
jira_transition_issue    → that transition id
```

### Step 4 — Branch
First run the [java-coding-standards](../java-coding-standards/SKILL.md) **Phase 0** branch setup:
check the current branch, and if not on the base (`main`/`develop`), checkout the base and `git pull`
before branching. Then create the branch — embed the key so Jira auto-links commits:
```
bugfix/khactuong.ngohoang/PROJ-456-npe-missing-plugin-dir
```

### Step 5 — Reproduce → fix → test
For a non-trivial or unclear defect, run [jira-bug-investigate](../jira-bug-investigate/SKILL.md) first
to confirm the **root cause** (symptom→trigger→cause) before touching code — fix the cause, not the symptom.

Apply the [java-coding-standards](../java-coding-standards/SKILL.md) gate while fixing — it routes
you to code-craft, spring-stack-patterns, test-quality, java-code-review, and security-audit.
1. **Reproduce first** — write a failing test that captures the bug.
2. Fix the **root cause**, not the symptom.
3. Keep the test as a **regression test** so it can't return.

### Step 6 — Commit
Defer message wording to the [git-commit](../git-commit/SKILL.md) skill; put the key in the footer:
```
fix(plugin-loader): prevent NPE when plugin directory is missing

Guard against a null plugin directory during scan; return an empty
list instead of throwing. Adds regression test.

PROJ-456
```

### Step 7 — PR + transition
- PR title includes `PROJ-456`.
- `jira_add_comment` → PR link + one-line root-cause summary.
- `jira_transition_issue` → "In Review" → after merge, "Done" / "Resolved".
- Set **Fix Version/s** via `jira_update_issue` if the project tracks releases.

## Status Flow (typical — names vary)
```
Open ──▶ In Progress ──▶ In Review ──▶ Done
                ▲              │
                └──── rework ◀─┘
```

## Token Optimization
- `jira_get_issue` once; cache key, status, repro detail for the session.
- Batch assignee + priority into one `jira_update_issue` call.
- Call `jira_get_transitions` only when about to transition.

## Anti-patterns
❌ Hard-coding transition IDs · Bug with no repro steps · fixing the symptom without a regression test · transitioning to Done before merge · branches/commits missing the key.
✅ Reproduce-then-fix · add a regression test · resolve transitions by name · mirror the key across branch, commit footer, and PR title.

## Example
```
> "Fix the bug in PROJ-456"
1. jira_get_issue PROJ-456 → read repro + stack trace
2. assign self + transition → In Progress
3. branch bugfix/khactuong.ngohoang/PROJ-456-npe-missing-plugin-dir (from updated base)
4. failing test → fix → test passes
5. commit "fix(plugin-loader): ... PROJ-456"
6. open PR, comment root cause + link, transition → In Review → (merge) → Done
```

## References
- [mcp-atlassian server](https://github.com/sooperset/mcp-atlassian)
- [jira-feature skill](../jira-feature/SKILL.md) · [git-commit skill](../git-commit/SKILL.md)
- [Atlassian: Smart commits & dev panel linking](https://support.atlassian.com/jira-software-cloud/docs/process-issues-with-smart-commits/)
