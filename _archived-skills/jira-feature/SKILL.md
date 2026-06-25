---
name: jira-feature
description: Drive a new-feature Jira workflow end to end — create/fetch a Story, move it across the board, branch, commit, PR, and transition to done. Use when user says "start a Jira feature", "work on feature PROJ-123", "create a Story", or when linking feature code to a Jira ticket.
---

# Jira Feature Workflow Skill

Drive a **new feature** (Jira **Story** / **Task**) through its full lifecycle:
create → assign → in progress → branch → commit → PR → review → done.

For bug fixes, use the [jira-bugfix](../jira-bugfix/SKILL.md) skill instead.

## When to Use
- User says "start a Jira feature" / "work on feature PROJ-123" / "create a Story"
- Implementing new functionality that should be tracked in Jira
- Linking feature commits/PRs to a Jira ticket

## Prerequisites

**Required**: Jira MCP server configured (see project [mcp.json](../../../mcp.json)).
Uses [`mcp-atlassian`](https://github.com/sooperset/mcp-atlassian) tools:

| Tool | Purpose |
|------|---------|
| `jira_get_issue` | Read fields, status, comments |
| `jira_search` | JQL search (find related/duplicate stories) |
| `jira_create_issue` | Create the Story |
| `jira_update_issue` | Set assignee, labels, fields |
| `jira_get_transitions` | List valid next statuses |
| `jira_transition_issue` | Move across the board |
| `jira_add_comment` | Post PR link / progress |

> ⚠️ Transition names/IDs vary per project. NEVER hard-code a transition ID —
> always call `jira_get_transitions` first and match by name.

## Workflow

### Step 1 — Create or fetch the Story
**If creating** — Stories must include **Acceptance Criteria**:
```
Tool: jira_create_issue
{
  "project_key": "PROJ",
  "issue_type": "Story",
  "summary": "Add OAuth2 login support",
  "description": "*As a* user\n*I want* to log in with Google\n*So that* I avoid another password\n\nh3. Acceptance Criteria\n* Google OAuth2 flow works end-to-end\n* Token refresh handled\n* Errors surfaced to UI",
  "additional_fields": { "labels": ["feature", "auth"] }
}
```
**If existing**: `jira_get_issue PROJ-123` to load context.

### Step 2 — Assign & move to In Progress
```
jira_update_issue        → set assignee to current user (+ labels in same call)
jira_get_transitions     → find "In Progress" / "Start Progress"
jira_transition_issue    → that transition id
```

### Step 3 — Branch
First run the [java-coding-standards](../java-coding-standards/SKILL.md) **Phase 0** branch setup:
check the current branch, and if not on the base (`main`/`develop`), checkout the base and `git pull`
before branching. Then create the branch — embed the key so Jira auto-links commits:
```
feature/khactuong.ngohoang/PROJ-123-oauth2-login
```

### Step 4 — Implement & commit
Apply the [java-coding-standards](../java-coding-standards/SKILL.md) gate while implementing — it
routes you to code-craft, spring-stack-patterns, test-quality, java-code-review, and
security-audit at the right phases. Tests + self-review must pass before committing.

Defer message wording to the [git-commit](../git-commit/SKILL.md) skill; put the key in the footer:
```
feat(auth): add OAuth2 login support

Implements Google OAuth2 authorization-code flow with token refresh.

PROJ-123
```

### Step 5 — PR + transition to review
- PR title includes `PROJ-123`.
- `jira_add_comment` → post the PR URL on the ticket.
- `jira_transition_issue` → "In Review" / "Code Review".

### Step 6 — Done
After merge: `jira_transition_issue` → "Done" / "Resolved". Optionally comment the release version.

## Status Flow (typical — names vary)
```
To Do ──▶ In Progress ──▶ In Review ──▶ Done
                 ▲              │
                 └──── rework ◀─┘
```

## Token Optimization
- `jira_get_issue` once; cache key, type, and status for the session.
- Batch assignee + labels into one `jira_update_issue` call.
- Call `jira_get_transitions` only when about to transition.

## Anti-patterns
❌ Hard-coding transition IDs · transitioning to Done before merge · Stories with no acceptance criteria · branches/commits missing the key.
✅ Resolve transitions by name · mirror the key across branch, commit footer, and PR title · one comment with the PR link at review.

## Example
```
> "Start a Jira feature for API rate limiting"
1. jira_create_issue (Story + acceptance criteria)
2. assign self + transition → In Progress
3. branch feature/khactuong.ngohoang/PROJ-201-api-rate-limiting (from updated base)
4. implement + commit "feat(api): add rate limiting ... PROJ-201"
5. open PR, comment link, transition → In Review → (merge) → Done
```

## References
- [mcp-atlassian server](https://github.com/sooperset/mcp-atlassian)
- [jira-bugfix skill](../jira-bugfix/SKILL.md) · [git-commit skill](../git-commit/SKILL.md)
- [Atlassian: Smart commits & dev panel linking](https://support.atlassian.com/jira-software-cloud/docs/process-issues-with-smart-commits/)
