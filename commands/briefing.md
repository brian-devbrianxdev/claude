---
description: Session-start briefing — spawns 3 parallel agents to gather open MRs, in-progress Jira tickets, and workspace git state, then synthesizes a single actionable snapshot.
argument-hint: []
model: sonnet
---

# /briefing

Session-start status briefing for the Quapp workspace. Spawns three agents concurrently (all
read-only), then synthesizes one actionable snapshot. Run at the start of each working session.

## Execution — 3 parallel agents

Spawn all three at the same time (do not wait for one before starting the next):

---

**Agent 1 — Open MRs** (model: sonnet)

For each repo in the workspace, run inside that repo's directory:
```
glab mr list --author=@me --state=opened --output=json 2>/dev/null
```
Repos to check (all 10): `functions/quapp-functions-backend`, `functions/quapp-functions-frontend`,
`ai/quapp-ai-mcp`, `ai/quapp-jupyterlab-ai-assistant-ext`, `ai/quapp-jupyterlab-s3-ext`,
`migration/quapp-migration`, `migration/quapp-ai-mcp-migration`, `sdk/qapp-common`,
`sdk/quapp-sdk-templates`, `sdk/quapp-qiskit`.

For each MR found, capture: iid, title, source_branch, target_branch, pipeline status
(`success`/`failed`/`running`/`pending`/`—`), web_url. Skip repos with no open MRs.
If `glab` is unavailable or fails for a repo, note it as `glab unavailable`.

---

**Agent 2 — Jira in-progress** (model: haiku)

Call `searchJiraIssuesUsingJql` twice:
1. `assignee = currentUser() AND status = "In Progress" ORDER BY updated DESC`
2. `assignee = currentUser() AND status = "Review" ORDER BY updated DESC`

Fields: `summary`, `status`, `priority`, `updated`, `parent`, `issuetype`.
Return a flat list: `key`, `summary`, `status`, `parent.key` (if subtask), `issuetype.name`.
If Jira MCP unavailable, return `{unavailable: true}`.

---

**Agent 3 — Workspace git state** (model: haiku)

For each of the 10 repos above, inside that repo's directory (skip if no `.git` dir):
- `git branch --show-current` → current branch
- `git status --porcelain | wc -l | tr -d ' '` → uncommitted file count
- `git log --oneline @{u}..HEAD 2>/dev/null | wc -l | tr -d ' '` → commits ahead of remote (0 if no upstream)
- Check GitNexus freshness: if `.gitnexus/` exists, compare `git log -1 --format=%ct` vs newest file mtime in `.gitnexus/` (same logic as session-start.sh)

Return per repo: `{ name, branch, dirty, ahead, gitnexus_stale }`.

---

## Synthesis (after all 3 agents complete)

Build a compact briefing in this format:

```
## Quapp Briefing — <YYYY-MM-DD>

### Open MRs (<count>)
| Repo | MR | Branch | Pipeline | URL |
|------|----|--------|----------|-----|
| quapp-functions-backend | !2939 | bugfix/PQF-22396-... | ✅ | ... |

### In progress (<count>)
| Ticket | Summary | Status | Type |
|--------|---------|--------|------|
| PQF-22350 | Language C support | In Progress | Story |

### Workspace state
| Repo | Branch | Dirty | Ahead | GitNexus |
|------|--------|-------|-------|----------|
| quapp-jupyterlab-ai-assistant-ext | feature/PQF-22323-... | 2 files | 0 | ⚠️ stale |

### Action items
- <concise bullet per item needing attention: failed pipeline, stale GitNexus, dirty repo, MR waiting>
```

Omit sections with zero items. Omit repos with nothing notable (clean branch, no MR, no stale index).
If Jira was unavailable, note it once under "In progress".

## Rules
- Read-only. No git checkouts, branch switches, or state changes.
- If a `glab` call fails (auth, network), skip that repo with one ⚠️ note — don't abort.
- Keep the Action items list to ≤6 bullets; prioritize failed pipelines and blockers.
- Pipeline status icons: ✅ success · ❌ failed · ⏳ running/pending · — not set.
