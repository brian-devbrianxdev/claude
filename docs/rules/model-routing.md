# Rules — Model routing (single source of truth)

Route each phase of work to the **cheapest Claude model that holds quality**. This table is the only
place the skill→model mapping lives — skills/commands point here instead of restating it. When you
spawn a subagent (`Agent` tool `model:` param, or Workflow `agent(…, {model})`), pass the tier from
this table. When a whole phase runs inline and is clearly mis-tiered, suggest `/model` once at the
phase boundary — don't nag mid-task.

## Tiers

| Tier | Model id | Use for |
|------|----------|---------|
| **haiku** | `haiku` | Mechanical output: commit messages, changelogs, formatting, lint/checklist verification, simple classification, grading/verifying another agent's output |
| **sonnet** | `sonnet` | Normal engineering: implementation, features, refactoring, tests, docs, CRUD/API work, routine diff review, evidence-gathering subagents |
| **opus** | `opus` | Deep reasoning: hard debugging/root-cause, architecture decisions, large refactors, security review, performance analysis, concurrency review, ambiguous requirements, cross-repo/cross-module changes |
| **orchestrator** — *in this repo: `sonnet`, pinned by `settings.json`* (elsewhere: inherit whatever session model is running — Sonnet, Opus, Fable, ...) | *(omit `model` — inherit)* | Orchestration only: planning and decomposing large work, coordinating multiple agents, synthesizing several workers' results. Does **not** own Go/No-Go verdicts on high-risk changes — that is the advisor's role. |
| **advisor** (scarce) | `opus` | Manual-only: provides high-risk **recommendation** (not final authority). The orchestrator verifies advisor findings and owns the user-facing Go/No-Go verdict. Eligible only after Opus when: ≥2 viable approaches remain open, two attempts failed, rollback cost is high, or final sign-off on genuinely high-risk work. Never auto-spawned — see [`../architecture/executor-advisor-architecture.md`](../architecture/executor-advisor-architecture.md). Frontmatter defaults to `opus` (guaranteed available); optionally set `fable` in `agents/engineering-advisor.md` if a higher-tier alias exists locally. |

Rule of thumb: **workers get an explicit cheap tier; the orchestrator inherits the session model.**
Omitting `model` on a subagent = inherit — only omit when the subagent genuinely needs
orchestrator-level reasoning. In this repo the session default is pinned to `sonnet`
(`.claude/settings.json`) — the executor tier above is that pinned default, not an ad-hoc choice.

Three **named agents** (`../agents/`) carry the recurring routed roles so their model is pinned in
one place: **`deep-reviewer`** (opus — concurrency/architecture/security lenses, large cross-repo
diffs; the `code-review`/`security-review` skills instruct the executor to spawn one when a trigger
fires — not auto-enforced by a hook), **`drafter`** (haiku — changelog drafting, bulk summaries,
checklist verification), and **`engineering-advisor`** (opus by default — read-only,
`Read`/`Grep`/`Glob` only; invoked manually by the executor at a genuine decision boundary, never
automatically; optionally `fable` if the alias is available — see `engineering-advisor.md`). Prefer
them over ad-hoc `Agent(model: …)` calls for those roles.

## Skill / command routing table

| Task | Tier | Notes |
|------|------|-------|
| `/start-task` (whole command) | sonnet | Jira fetch + scoping + branching is routine; pinned via command frontmatter |
| `/ship-task` (whole command) | sonnet | Escalate individual review lenses per the code-review row |
| `task-scoping` | sonnet | Read-only mapping |
| `solution-planning` | **opus** | Design alternatives + estimation = ambiguity + trade-offs |
| `change-implementation` | sonnet | Escalate to opus only if the plan spans ≥2 repos or changes auth/contracts |
| `bug-investigation` | **opus** | Root-cause analysis |
| `code-review` — correctness / standards / project-rules / api-contract lenses | sonnet | Routine diff review |
| `code-review` — concurrency / architecture lens, or diff spanning ≥2 repos or >10 meaningfully changed files (excluding generated files, lockfiles, snapshots, formatting-only) | **opus** | Run that lens in an opus subagent (see the skill's escalation section) |
| `security-review` | **opus** | Never downgrade security |
| `completion-audit` — per-ticket audit workers | sonnet | Evidence mapping, structured output |
| `completion-audit` — cross-ticket conflict synthesis | **opus** | Cross-module contract reasoning |
| `completion-audit` — orchestration + final verdict | inherit | Session model synthesizes |
| `commit` | haiku-class | Trivial; run inline at whatever model is active — a subagent isn't worth the latency |
| `changelog` | haiku | For >~30 commits, delegate to a haiku subagent and relay its output |
| `release-note` | sonnet | Jira/Confluence gathering + inclusion judgment + user-facing writing; run inline |
| `mr-feedback` | sonnet | Apply requested edits thread-by-thread |
| `/review-mr` (whole command) | sonnet | Pinned via frontmatter; deep/security lenses escalate per the code-review row (one `deep-reviewer`) |
| `/handoff` | sonnet | Pinned via frontmatter; summarization + indexing, no deep reasoning |
| `grilling` | inherit | Interactive judgment about the user's plan — run at the session model |
| `merge-conflict-resolution` | sonnet | Escalate to opus if conflicting intents span ≥2 repos or touch auth/contracts |
| Output verification / checklist grading (any workflow) | haiku | e.g. "does this footprint match the schema/checklist" |
| `code-craft` / `spring-stack-patterns` / `test-authoring` | n/a | Knowledge references — they run at whatever tier loaded them |

## Escalation & de-escalation triggers

Escalate one tier when, mid-task, you hit: contradictory evidence after two hypotheses, a change that
crosses a repo/tier contract (`workspace.md` — no codegen), auth/JWT/rate-limit surface, concurrency,
or a migration touching both DB repos' territory. De-escalate (delegate down) when a step becomes
mechanical: bulk file reads, formatting, re-running checklists, summarizing something already decided.

## Rules

1. **Don't restate this table elsewhere** — link to this file. One place to maintain.
2. Subagent fan-outs (Workflow, Agent) must set `model` explicitly per the table; only orchestrators inherit.
3. Security (`security-review`) and root-cause (`bug-investigation`) are never routed below opus.
4. Never spawn a subagent *just* to change model for a small inline task — the handoff costs more than
   it saves. Routing applies to phases, not sentences.
5. If unsure between two tiers, pick the cheaper one and rely on the escalation triggers.
