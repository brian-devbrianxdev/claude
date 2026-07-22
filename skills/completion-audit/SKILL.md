---
name: completion-audit
description: Audit a whole release (a list of Jira tickets) across the QUAPP workspace to prove the code meets 100% of every ticket's requirements AND that no two tickets conflict (same-file overwrites, broken cross-repo contracts, clashing shared config/auth). Fans out one completeness audit per ticket in parallel, then runs a cross-ticket conflict-detection pass. Use when user says "audit the release", "release readiness check", "are these tickets done and conflict-free", or pastes a list of PQF tickets to verify before a release.
---

# Completion Audit

Audit ticket **completeness** against the codebase — for a **single ticket** (single-ticket mode; the
per-ticket logic lives in [single-ticket.md](single-ticket.md)) or a **whole release** (an explicit
list of tickets), where it additionally proves the tickets are **conflict-free**.

**Mode:** 1 ticket → run the per-ticket audit only, skip the conflict pass. ≥2 tickets → fan out one
per-ticket audit each (parallel) + one cross-ticket conflict pass. For a release list, prove two
things with codebase evidence:

1. **Completeness** — every ticket's requirements are 100% implemented **and** tested.
2. **Conflict-free** — no two tickets collide: same-file overwrites, broken cross-repo contracts, or
   clashing shared config/auth.

Read-only. **Never edits code, never transitions tickets.** It audits, scores, and produces a plan.

## When to Use
- User pastes a set of ticket keys and asks "is this release ready / complete / conflict-free".
- Pre-release / release-candidate gate, before cutting `staging` → `production`.
- After several `feature/*` + `bugfix/*` branches have merged and you need a combined verdict.

## Prerequisites
- Atlassian MCP available (`getJiraIssue`, `searchJiraIssuesUsingJql`) for ticket text. If a ticket key
  can't be fetched, mark it **⚠️ Unknown** and audit what's reachable — don't invent criteria.
- Read access to all six repos (see root `CLAUDE.md` → Repository Map).
- **Input = explicit ticket list.** The user supplies the keys (e.g. `PQF-21017 PQF-21432 PQF-21500`).
  Do not derive the set from a Fix Version or git history unless the user asks.
- **Every relevant repo must be synced to latest `develop` before evidence-gathering starts** — see
  Step 0. Do this yourself, sequentially, before invoking the `Workflow` tool.

## Execution model — multi-agent workflow
This skill is an **explicit opt-in to the `Workflow` tool** (a skill whose instructions tell you to call
Workflow). Use it: fan out **one audit agent per ticket** in parallel, then a **single conflict-detection
synthesis pass** over all the footprints together (a genuine barrier — conflict detection needs every
ticket's footprint at once).

- Each per-ticket agent is read-only and returns a **structured footprint** (schema below), not prose.
- Scale the conflict pass to the release size; for a 2–3 ticket release you may run it inline instead of
  spawning a workflow, but default to the workflow for ≥4 tickets or ≥2 repos touched.
- Per-ticket completeness logic mirrors [single-ticket.md](single-ticket.md) exactly
  (criteria → evidence → ✅/🟡/❌/⚠️ → %). Reuse it; don't reinvent the scoring.
- **Model routing** ([`../../docs/rules/model-routing.md`](../../docs/rules/model-routing.md)): per-ticket audit
  workers = **sonnet** (evidence mapping); the cross-ticket conflict synthesis = **opus** (cross-module
  contract reasoning); the orchestrator + final Go/No-Go verdict run at the **session model** (inherit —
  no `model` override). The script below already sets these.

## Workflow

### Step 0 — Sync repos to latest `develop` (orchestrator, sequential, safety-gated)
Before fanning out any agents, put every repo relevant to the ticket set on a known, current baseline
so "already merged to develop" claims and GitNexus queries are trustworthy. Do this yourself,
sequentially, in the main flow — **not** inside the parallel per-ticket agents in Step 2 (two agents
racing a `git checkout` in the same repo is unsafe).

For each relevant repo (see `CLAUDE.md` → Repository Map):
1. `git status --short` — if dirty, **never discard**: `git stash push -u` (per `workspace.md` / root
   safety rules) and note that a stash was made; if the dirty state looks like unfinished work you
   don't recognize, stop and ask instead of stashing blind.
2. Record the **current branch** (`git branch --show-current`) so it can be restored afterward.
3. `git fetch origin && git checkout develop && git pull --ff-only origin develop`.
4. If the repo's GitNexus index looks older than the new HEAD (session-start warning, or
   `mcp__gitnexus__detect_changes`), reanalyze it (`gitnexus-cli` skill) before trusting graph queries
   against it.

Ticket-specific `feature/*`/`bugfix/*` branches are still inspected from this `develop` baseline via
`git log <branch>`, `git diff develop..<branch>`, `git show <branch>:<path>` — **without** checking
them out — so Step 2's parallel per-ticket agents never need to mutate the working tree themselves.

**After** the release verdict (Step 4) has been reported, restore every repo you switched:
`git checkout <original branch>` (and `git stash pop` if you stashed one). Never leave a repo sitting
on `develop` when the audit started elsewhere — this skill is read-only and must not change what
branch the user was working on.

### Step 1 — Normalize the release
Collect the ticket keys from the user. For each, `getJiraIssue` (include `comment` in `fields`) and
extract the **flat checklist of atomic requirements** (acceptance criteria, or decompose the
description) — **reconciled with the comment thread**: PO/BA/dev/QA replies refine, drop, or add
requirements after the description was written, and the audit must score against the *final agreed*
spec (latest comment usually wins; unresolved questions become ⚠️ Unknown criteria). Note issue type
(a Bug's criterion is *defect no longer reproduces + regression test*), linked subtasks, and the issue
key (for grepping branches/commits). Restate each ticket's goal in one line so the user can confirm scope.

### Step 2 — Fan out: per-ticket completeness audit (parallel)
One agent per ticket. Each agent:
- Maps every requirement to implementing code **and** tests (`path:line`), using the
  [rules/java.md](../../rules/java.md) routing table and `.claude/rules/*.md` to
  know where things should live. Prefer GitNexus (`query`/`context`/`impact` — load via ToolSearch;
  see [docs/rules/gitnexus.md](../../docs/rules/gitnexus.md)) over grep to find implementing symbols and to
  fill `filesTouched[].symbols`; the graph is per-repo, so `contracts[]` cross-tier mapping stays manual.
- Scores each requirement ✅ Done / 🟡 Partial / ❌ Missing / ⚠️ Unknown and computes the ticket's
  completion % (Done=1.0, Partial=0.5, Missing=0; Unknown excluded from denominator, reported separately).
- Records its **footprint** — the raw material for conflict detection:

```
TICKET_FOOTPRINT schema (per ticket):
{
  ticket, title, issueType, completionPct,
  criteria: [{ id, text, status, evidence }],          // status ∈ ✅🟡❌⚠️
  filesTouched: [{ repo, path, symbols, lines }],       // every file the ticket implies a change in
  contracts:   [{ repo, kind, name, change }],          // kind ∈ dto|endpoint|ws|sse|stomp; change ∈ added|modified|removed
  configAuth:  [{ repo, area, key, change }],           // area ∈ security|jwt|rate-limit|env|yaml|constants
  migrations:  [{ repo, changeset, table }],            // QuaO DB vs AI-MCP DB
  unknowns: [ ... ]
}
```

### Step 3 — Barrier: cross-ticket conflict detection
Collect all footprints, then detect collisions. **Focus, in priority order (as requested):**

1. **Cross-repo contracts** — the highest-risk class given "no generated client" (`workspace.md`). For
   every `contracts[]` entry, check whether another ticket changes a **consumer or producer** of the same
   DTO/endpoint/WS/SSE/STOMP channel in an incompatible way. Map the tiers:
   frontend (`BASE_URL` / `MCP_API_BASE_URL`) ↔ functions-backend ↔ ai-mcp `/api/v1` ↔ jupyterlab ext
   (`mcp_http_client.py`). A backend DTO/route change with no matching frontend/ext edit in the release
   is itself a conflict (a **missing-counterpart** conflict), not just completeness debt.
2. **Shared config/auth** — overlapping edits to `security`, JWT issuer/JWK, rate-limit, env vars,
   shared `*.yml`, or `constants/`. Two tickets setting the same key to different values, or one
   weakening auth another tightens, is a hard conflict.
3. **Same-file edits** — two tickets touching the same `repo:path` (especially the same symbol / method /
   adjacent lines). Flag as 🔴 if the intents are incompatible (overwrite, contradictory logic), 🟠 if
   merely co-located (likely a merge-resolve, not a logic clash).

Secondary (report if present, even though not the primary focus): **DB migrations** — duplicate/colliding
Liquibase changesets, same-table changes, or ordering hazards in the same migration repo; remember the
two-DB split (`migration.md`).

Classify each finding:
| Severity | Meaning |
|----------|---------|
| 🔴 Conflict | Will break at build/runtime or silently corrupt behavior if both ship as-is |
| 🟠 Risk | Co-located / overlapping; needs a deliberate merge decision but not inherently broken |
| 🟢 Clear | Footprints overlap by path only, logically independent |

### Step 4 — Release verdict
Aggregate:
- **Release completeness %** = mean of per-ticket completion % (state the math; weight by effort only if
  the user gives weights). Call the release **complete only if every ticket is 100%** — a 90% average
  with one 60% ticket is **not** release-ready; say so explicitly.
- **Conflict status** = ✅ none / ⚠️ N risks / 🔴 N conflicts.
- **Go / No-Go**: No-Go if any ticket < 100% OR any 🔴 conflict exists.

## Output Contract
```
## Release Audit — <N tickets>
Verdict: NO-GO   (completeness 88%, 1 ticket < 100%; 🔴 2 conflicts, 🟠 1 risk)

### Completeness (per ticket)
| Ticket    | Title                  | %    | ✅ | 🟡 | ❌ | ⚠️ | Top gap (path) |
|-----------|------------------------|------|----|----|----|----|----------------|
| PQF-21017 | Web user-guide toggle  | 100% | 5  | 0  | 0  | 0  | —              |
| PQF-21432 | Inactive session …     | 60%  | 3  | 1  | 1  | 0  | SessionSvc:30 no test |

### Conflicts
| # | Sev | Tickets            | Where (repo:path / contract / key)        | Why it conflicts                |
|---|-----|--------------------|-------------------------------------------|---------------------------------|
| 1 | 🔴  | PQF-21432 ↔ 21500  | backend AuthFilter.java:88 (same method)  | both rewrite session-expiry; logic contradicts |
| 2 | 🔴  | PQF-21017 → (none) | contract: GET /api/v1/mcp/ai-tour-state   | backend DTO changed, no frontend consumer edit in release |

### Plan to release-ready (gaps + conflicts only)
- PQF-21432: add regression test … (path) — via rules/java.md gate
- Conflict #1: reconcile AuthFilter session-expiry — decide owning ticket, re-test both
- Conflict #2: add matching frontend edit in src/services/… or descope PQF-21017
```
Then: the per-ticket evidence tables on request. **No code changes, no ticket transitions.**

## Rules Claude Must Follow
- **Sync every relevant repo to latest `develop` before evidence-gathering** (Step 0), sequentially,
  with git-status/stash safety; restore each repo's original branch (and stash) once the verdict is
  reported. Never leave a repo switched to `develop` after the audit ends.
- **Read-only**; cite real `path:line`. Mark anything unverifiable **⚠️ Unknown**, never invent.
- **Not a monorepo** — name the specific repo for every file/contract/migration (`workspace.md`).
- Untested code is **🟡 Partial**, not Done — **except in-scope FE source** (`quapp-functions-frontend`
  entirely, and `quapp-jupyterlab-ai-assistant-ext`'s TS/React `src/` code), which per
  [`rules/testing.md`](../../rules/testing.md) does not require new unit tests; implemented-but-untested
  code there scores Done. The ext's Python server extension and its Playwright/Galata suite are **not**
  covered and keep the normal rule.
- A backend/ai-mcp contract change with **no matching consumer edit** in the release set is a conflict
  (missing counterpart), because no codegen propagates it.
- Match each repo's JDK only matters if you build — this skill doesn't build; it reads.
- Two DBs: keep migration findings in the correct repo (`migration.md`).
- JupyterLab ext: rules are in `AGENTS.md` (its `CLAUDE.md` is a symlink).

## Verification Checklist
- [ ] Every relevant repo was synced to latest `develop` before evidence-gathering (Step 0, sequential,
      stash-safe) and restored to its original branch afterward.
- [ ] Every supplied ticket was fetched (or flagged ⚠️ Unknown) and decomposed into atomic requirements.
- [ ] Each requirement traced to code **and** test, or marked ❌/🟡/⚠️ with a reason.
- [ ] Release marked complete only if **every** ticket is 100%.
- [ ] Cross-repo contracts, shared config/auth, and same-file edits each checked across all ticket pairs.
- [ ] Each conflict has both tickets, the exact location, and why; severity assigned.
- [ ] Go/No-Go stated with the math behind it.

## Anti-patterns
❌ Trusting ticket status; ❌ counting untested code as done outside the in-scope-FE-source exception
(`rules/testing.md`); ❌ averaging % and calling 88% "done" when a ticket is at 60%; ❌ checking
only same-file edits and missing a broken cross-repo contract; ❌ editing code or moving tickets. ✅
Evidence-linked statuses, pairwise conflict checks, transparent Go/No-Go.

## Workflow script template
Run via the `Workflow` tool (this skill is the opt-in). Pass the ticket keys as `args`.

```js
export const meta = {
  name: 'completion-audit',
  description: 'Per-ticket completeness audit (parallel) + cross-ticket conflict detection',
  phases: [{ title: 'Audit' }, { title: 'Conflicts' }],
}

const FOOTPRINT = {
  type: 'object',
  required: ['ticket', 'completionPct', 'criteria', 'filesTouched', 'contracts', 'configAuth'],
  properties: {
    ticket: { type: 'string' }, title: { type: 'string' }, issueType: { type: 'string' },
    completionPct: { type: 'number' },
    criteria: { type: 'array', items: { type: 'object',
      required: ['text', 'status'], properties: {
        text: { type: 'string' }, status: { type: 'string' }, evidence: { type: 'string' } } } },
    filesTouched: { type: 'array', items: { type: 'object',
      properties: { repo: { type: 'string' }, path: { type: 'string' },
        symbols: { type: 'string' }, lines: { type: 'string' } } } },
    contracts: { type: 'array', items: { type: 'object',
      properties: { repo: { type: 'string' }, kind: { type: 'string' },
        name: { type: 'string' }, change: { type: 'string' } } } },
    configAuth: { type: 'array', items: { type: 'object',
      properties: { repo: { type: 'string' }, area: { type: 'string' },
        key: { type: 'string' }, change: { type: 'string' } } } },
    migrations: { type: 'array', items: { type: 'object' } },
    unknowns: { type: 'array', items: { type: 'string' } },
  },
}

const CONFLICTS = {
  type: 'object', required: ['findings'],
  properties: { findings: { type: 'array', items: { type: 'object',
    required: ['severity', 'tickets', 'where', 'why'], properties: {
      severity: { type: 'string' },      // 🔴 | 🟠 | 🟢
      class: { type: 'string' },          // contract | config-auth | same-file | migration
      tickets: { type: 'array', items: { type: 'string' } },
      where: { type: 'string' }, why: { type: 'string' } } } } },
}

const tickets = Array.isArray(args) ? args : String(args || '').split(/\s+/).filter(Boolean)
if (!tickets.length) throw new Error('Pass ticket keys as args, e.g. ["PQF-1","PQF-2"]')

phase('Audit')
const footprints = (await parallel(tickets.map(t => () =>
  agent(
    `Audit Jira ticket ${t} for the QUAPP workspace, exactly like single-ticket.md (the per-ticket audit).\n` +
    `The orchestrator already synced every relevant repo to latest develop (Step 0) — do NOT git checkout ` +
    `or switch branches yourself; inspect feature/bugfix branches read-only via git log/diff/show against ` +
    `refs (e.g. git log <branch>, git diff develop..<branch>, git show <branch>:<path>).\n` +
    `1) getJiraIssue ${t}; build a flat checklist of atomic requirements (a Bug = defect no longer ` +
    `reproduces + regression test).\n` +
    `2) For each requirement, find implementing code AND tests across all six repos (cite repo:path:line). ` +
    `Use .claude/rules/*.md to know where things live. Untested code is 🟡 Partial, not Done — EXCEPT ` +
    `in-scope FE source (quapp-functions-frontend entirely, and quapp-jupyterlab-ai-assistant-ext's ` +
    `TS/React src/ code only — NOT its Python server extension or Playwright/Galata suite), which per ` +
    `rules/testing.md does not require new unit tests; score implemented-but-untested code there as ` +
    `Done, not Partial.\n` +
    `3) Score ✅/🟡/❌/⚠️ and compute completionPct (Done=1, Partial=.5, Missing=0; exclude Unknown).\n` +
    `4) Record the footprint: every file touched, every cross-repo contract (dto/endpoint/ws/sse/stomp) ` +
    `changed, every shared config/auth key touched (security/jwt/rate-limit/env/yaml/constants), and any ` +
    `Liquibase changeset. Read-only — do not edit anything.`,
    { label: `audit:${t}`, phase: 'Audit', schema: FOOTPRINT, agentType: 'Explore', model: 'sonnet' })
))).filter(Boolean)

const STATUS_WEIGHT = { '✅': 1, '🟡': 0.5, '❌': 0 }
const validation = footprints.map(fp => {
  const scored = fp.criteria.filter(c => c.status in STATUS_WEIGHT)
  const computed = scored.length
    ? Math.round(scored.reduce((s, c) => s + STATUS_WEIGHT[c.status], 0) / scored.length * 100)
    : 0
  const problems = []
  if (Math.abs(computed - fp.completionPct) > 1)
    problems.push(`completionPct ${fp.completionPct} != computed ${computed}`)
  const noEvidence = fp.criteria.filter(c => c.status === '✅' && !/:\d+/.test(c.evidence || ''))
  if (noEvidence.length)
    problems.push(`${noEvidence.length} ✅ criteria lack path:line evidence`)
  return { ticket: fp.ticket, computed, problems }
})
validation.filter(v => v.problems.length)
  .forEach(v => log(`⚠️ footprint ${v.ticket}: ${v.problems.join('; ')}`))

phase('Conflicts')
const conflicts = await agent(
  `You are given ${footprints.length} per-ticket footprints from one release:\n` +
  JSON.stringify(footprints, null, 2) +
  `\n\nDetect cross-ticket conflicts, in priority order:\n` +
  `1) CROSS-REPO CONTRACTS: a DTO/endpoint/ws/sse/stomp changed by one ticket whose consumer/producer ` +
  `in another tier is changed incompatibly OR not changed at all in this release (missing counterpart). ` +
  `Tiers: frontend(BASE_URL/MCP_API_BASE_URL) ↔ functions-backend ↔ ai-mcp /api/v1 ↔ jupyterlab ext.\n` +
  `2) SHARED CONFIG/AUTH: two tickets editing the same security/jwt/rate-limit/env/yaml/constants key ` +
  `to different/contradictory values, or one weakening what another tightens.\n` +
  `3) SAME-FILE EDITS: two tickets touching the same repo:path (esp. same symbol/adjacent lines) — ` +
  `🔴 if intents contradict, 🟠 if merely co-located.\n` +
  `Also report DB-migration collisions (same table / duplicate changeset / ordering) if present, ` +
  `respecting the two-DB split.\n` +
  `Severity: 🔴 breaks build/runtime or corrupts behavior; 🟠 needs a deliberate merge; 🟢 path-only overlap. ` +
  `For each finding give both tickets, the exact location, and why. Read-only.`,
  { label: 'conflict-synthesis', phase: 'Conflicts', schema: CONFLICTS, effort: 'high', model: 'opus' })

return { tickets, footprints, conflicts, validation }
```
After the workflow returns, first check `validation` — any footprint with problems (mis-computed %,
✅ criteria without `path:line` evidence) is untrusted: use the `computed` % instead and flag the
ticket ⚠️ in the report. Then build the Output Contract report from `footprints` + `conflicts`,
compute the release completeness %, and state Go/No-Go. For each gap (🟡/❌/⚠️) and each 🔴/🟠 conflict, write a minimal
plan item routed through [rules/java.md](../../rules/java.md) gate
(branch from the confirmed base, tests mandatory, self-review before MR). Close the gap; don't gold-plate.

## References
- [single-ticket.md](single-ticket.md) (per-ticket logic) · [task-scoping](../task-scoping/SKILL.md)
  (where things live) · [code-review](../code-review/SKILL.md) (diff-level rules) ·
  [rules/java.md](../../rules/java.md) (gate for the plan)
- `.claude/rules/workspace.md` (no codegen / cross-repo contracts), `migration.md` (two DBs)
