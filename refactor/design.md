# Design — Graph Engineering layer for the Quapp harness

Built directly on the audit (`audit.md`). Principle: **the graph is a thin, additive coordination
layer over existing skills/commands/hooks/agents — it does not reimplement any of them.** No new
runtime, no third-party framework: Claude Code has no workflow engine, so the graph is declarative
(YAML + Markdown node contracts + JSON Schemas) and is *interpreted by the orchestrating model*
(the session, or `/start-task`/`/ship-task`) exactly the way `docs/rules/model-routing.md` is today
— a document that skills read and follow, not code that executes itself.

## 1. What's new vs. what's reused

| New | Reused as-is (unchanged behavior) |
|---|---|
| `.claude/graph/README.md` — how to read/use the graph | All 16 skills |
| `.claude/graph/nodes/*.md` — one contract per phase | All 4 commands (`/start-task`, `/ship-task`, `/review-mr`, `/handoff`) |
| `.claude/graph/workflows/{ticket,bugfix,release}.yaml` | All 3 agents (`deep-reviewer`, `drafter`, `engineering-advisor`) |
| `.claude/graph/schemas/{task-state,node-result}.schema.json` | All 3 hooks |
| `.claude/state/<KEY>.json` — durable, git-ignored, per-ticket state | `docs/rules/model-routing.md` (still the *only* tier table) |
| One new step each in `/start-task` and `/ship-task` (state init/update) | `profiles/quapp/profile.md` (still the *only* identity source) |

Nothing is deleted. Nothing is renamed. The three self-approval risks found in the audit (`commit`,
`mr-feedback`, `merge-conflict-resolution`) are **not rewritten** — see §7 for why, and how the
graph mitigates the risk structurally instead (by making `review` a non-skippable dependency of
`ship` in the workflow definition, not by changing those three skills).

## 2. Shared state model

### 2.1 Three durability tiers (kept distinct, not merged)
| Tier | Where | Lifetime | Owner |
|---|---|---|---|
| **Source of truth** | Jira ticket (objective, acceptance criteria, comments) | Durable, cross-session, cross-machine | Jira/Atlassian |
| **Workflow run state** (*new*) | `.claude/state/<TICKET>.json` | One ticket's graph run; git-ignored, machine-local | This refactor |
| **Cross-session narrative** | `~/.claude/projects/.../handoffs/*.md` | Human-triggered, prose | `/handoff` (unchanged) |

The new `state/<TICKET>.json` is **not** a fourth source of truth competing with Jira or replacing
`/handoff` — it's the machine-readable ledger of *which graph nodes ran, in what order, with what
evidence, for this one ticket*, so that:
- a node can check "did `review` already pass before I run `ship`?" without re-reading the whole
  conversation;
- retries have a counter that survives a `/clear` (the harness's own recommended token-hygiene
  practice, per `start-task.md`'s "Token hygiene" section — which today means state is **lost** on
  `/clear` unless it's a Jira comment or a branch name; this file fixes that without contradicting
  the token-hygiene advice, since the state file is tiny and cheap to re-read, unlike conversation
  history).
- `/handoff` can *link to* `state/<TICKET>.json` instead of re-deriving/duplicating its contents —
  update `/handoff` only to mention this file's existence, not to change its own content rules.

### 2.2 Where the file lives and why it's git-ignored
`.claude/state/` sits at the harness root, alongside `sessions/`, `cache/`, `history.jsonl` —
all of which `.gitignore` already marks as "Runtime state (per-machine, not shareable)". Per the
task's non-negotiable rule ("Runtime task state must not be committed unless the existing workspace
explicitly treats it as a durable project artifact"), and since nothing in this harness commits
per-machine runtime state today, `state/` is added to that exact `.gitignore` section — see
`migration.md` for the diff. No `.gitkeep` is committed; the directory is created on first write by
`/start-task` (`mkdir -p`), the same pattern `/handoff` already uses for its own output folder.

### 2.3 `task-state.schema.json` (see `graph/schemas/task-state.schema.json` for the authoritative
version — summarized here):

```
task_id            string   — e.g. "PQF-22349" (parent) or "PQF-22349-BE" (sub-task, if tracked separately)
objective           string   — one-line restatement (mirrors /start-task step 1)
acceptance_criteria  string[] — pulled from the ticket, optional
repos                object[] — {name, path, branch, jdk?} — one per repo in scope (task-scoping output)
phase                enum     — intake|analyze|plan|implement|integrate|test|review|security|release_audit|ship|done|blocked
planned_nodes        string[] — node ids the router decided to activate (see §4)
active_nodes         string[] — currently running (normally 0 or 1 item; >1 only during a parallel fan-out)
completed_nodes      object[] — {node, attempt, result_ref} — result_ref points at a node-result record (§2.4)
blocked_nodes        object[] — {node, reason, since}
decisions            object[] — {node, decision, rationale, timestamp} — e.g. branch-base confirmation, plan approval
evidence             object[] — {node, type, ref, summary} — test report paths, review verdicts, secret-scan exit code
findings             object[] — {node, severity, file, line, summary} — carried over from code-review/security-review output
test_results         object[] — {repo, command, status, summary}
retries              object   — {<node_id>: count} — see §6 for bounds
human_approval        object   — {branch_base_confirmed, plan_approved, ship_approved} booleans + who/when
final_status          enum     — in_progress|ready_to_ship|shipped_pending_human|blocked|abandoned
created_at / updated_at  string (ISO 8601)
```

### 2.4 `node-result.schema.json` (see `graph/schemas/node-result.schema.json`) — what a node
writes back into `evidence`/`findings`/`test_results` when it finishes:

```
node_id       string
status         enum   — success|failure|blocked|skipped
summary        string
evidence       string[]  — file:line refs, command+report paths, verdict strings ("Gate: PASS")
findings       object[]  — {severity, file, line, summary} (same shape code-review already emits in prose)
attempt        integer
model_tier     string  — from docs/rules/model-routing.md, for traceability
next_action    string  — what should happen next (route to next node, or to failure_route)
failure_reason string  — only when status=failure|blocked
```

This is not a new reporting format for skills to learn — it's a JSON mirror of what `code-review`,
`security-review`, `completion-audit`, and `/ship-task`'s STOP-gate summary **already say in
prose**. A node writes this JSON *in addition to* its normal prose response; the prose is what the
user reads, the JSON is what `state/<TICKET>.json` accumulates.

## 3. Node contracts

Ten node contracts in `.claude/graph/nodes/`, each a short Markdown file with the eight fields the
task requires (`id`, `purpose`, `reads`, `writes`, `allowed_actions`, `forbidden_actions`,
`dependencies`, `success_criteria`, `failure_route`, `maximum_attempts`, `evidence_required`). Every
node maps to an **existing** skill/command — the contract is a pointer + the missing governance
metadata (bounds, evidence requirement), not a rewrite of the skill's logic.

| Node id | Maps to (existing) | New in the contract |
|---|---|---|
| `intake` | `/start-task` steps 1–2 | evidence_required: ticket key or pasted text captured in state |
| `analyze` | `task-scoping` | maximum_attempts: 1 (read-only, no retry concept applies) |
| `plan` | `solution-planning` (conditional — see §4) | failure_route: back to `analyze` if scope was wrong |
| `implement` | `change-implementation`, fanned out per repo when multi-repo | maximum_attempts: 2 per repo, then `blocked` → human |
| `integrate` | manual cross-repo contract-sync check (`workspace.md` — "no codegen does it for you") | evidence_required: explicit confirmation both sides of a touched DTO/route were updated |
| `test` | per-repo commands in `rules/testing.md` | failure_route: back to `implement` (same repo only), maximum_attempts: 3, then `blocked` |
| `review` | `code-review` (+ `deep-reviewer` escalation) | failure_route: back to `implement`; **cannot be skipped by `ship`** (hard dependency) |
| `security` | `security-review` (conditional — see §4) | failure_route: back to `implement`; secret-scan BLOCKER always halts, no retry |
| `release_audit` | `completion-audit` (conditional — release scope only) | maximum_attempts: 1 (read-only; a failed audit is a finding, not a retry target) |
| `ship` | `/ship-task` steps 3–8 | the human-controlled terminal gate; `allowed_actions` explicitly excludes auto-approving its own STOP gate |

Full contracts are in the actual files (Phase 4); this table is the index.

## 4. Conditional routing (the planner activates only relevant nodes)

Routing decisions are made once, at `analyze`, and recorded in `state.planned_nodes`:

- **Docs-only change** (no `.java`/`.ts`/`.py`/`.sql` touched): skip `implement`'s repo fan-out
  complexity, `test`, and `security`; keep a lightweight `review` pass only.
- **Single-repo change**: `implement` runs once, no fan-out, `integrate` is skipped (no cross-repo
  contract to sync).
- **Multi-repo change** (e.g. PQF-22349/22350 backend+frontend language support seen in this
  workspace's live branch state): `implement` fans out one branch per repo (see §5 for the
  parallelism check); `integrate` becomes mandatory.
- **Bug fix**: `analyze` is `bug-investigation` instead of `task-scoping` (or in addition to it, per
  `bug-investigation`'s own hand-off note); `test`'s success criteria requires a regression test
  specifically (already `rules/testing.md`'s existing rule, now made a routing precondition instead
  of prose).
- **DB/migration touching change**: `implement` must include the correct migration repo
  (`quapp-migration` or `quapp-ai-mcp-migration` per `docs/rules/migration.md`'s two-DB rule);
  `test` adds the migration repo's Testcontainers-or-local-Postgres verification.
- **Security-sensitive change** (auth, input handling, queries — same trigger `security-review`
  already uses): `security` node is mandatory, not conditional-skipped.
- **Release-scope work** (a list of tickets, not one): `release_audit` activates; single-ticket work
  never runs it.

This table is encoded once in `graph/workflows/ticket.yaml`'s `when:` conditions — it does not
reintroduce the routing logic that already lives inside each skill (e.g. `security-review`'s own
"when input handling/queries/auth" trigger stays the authority for *whether security-review itself
engages*; the workflow's `when:` just decides whether the *node* is on the plan at all, mirroring
that same trigger at one level up so a docs-only change never even proposes it).

## 5. Controlled parallelism

Fan-out is limited to `implement` (per-repo) and `release_audit`'s existing `completion-audit`
per-ticket workers (unchanged — already parallel today). Before fanning `implement` out across
repos, the router checks (mirrors the task's required pre-fan-out checklist):
- **File ownership overlap**: none possible — each repo is a separate git working tree (`workspace.md`
  §"Not a monorepo"), so file-level collision across repos cannot happen by construction.
- **API/contract dependency**: if `analyze` flagged a DTO/route change spanning repos, `implement`
  fans out but **`integrate` becomes a mandatory fan-in barrier** before `test` starts on the
  consumer side — a frontend implement branch must not test against a backend contract that hasn't
  landed.
- **Migration ordering**: if both a service repo and its paired migration repo are in scope, the
  migration repo's `implement`+`test` must complete before the service repo's `test` runs (migration
  Job runs first in the real deploy pipeline per `git-workflow.md`'s CI table — the graph mirrors
  that ordering rather than inventing a new one).
- **Shared generated artifacts**: none exist cross-repo (`workspace.md` — "no generated cross-repo
  client"), so this check is a no-op by evidence, recorded as such rather than skipped silently.

Fan-in always happens through `integrate` (multi-repo) or `completion-audit`'s conflict-synthesis
pass (release) — never implicitly. `review` and `test` remain sequential per repo; the task's
instruction to parallelize "only independent work" is satisfied by restricting parallelism to
exactly the two places above.

## 6. Bounded retries

| Node | Max attempts | No-progress condition | Escalation |
|---|---|---|---|
| `implement` | 2 per repo | Same test/review failure recurs after attempt 2 | `blocked`, human review requested; suggest `engineering-advisor` if it's a genuine decision boundary per its own 4-condition gate |
| `test` | 3 | Same failing test class across attempts | `blocked`, report to user — do not retry a 4th time silently |
| `review` | 2 (i.e. one re-review after one fix round) | Same Blocker/Major finding persists | `blocked` — implementer and reviewer disagree, needs a human call |
| `security` | 1 (secret-scan) + 1 (LLM checklist) | Any BLOCKER from `secret-scan.sh` | never retried automatically — always a human fix, per existing `rules/java.md` Phase 4 |
| `plan`, `analyze`, `release_audit` | 1 | n/a — read-only, re-running produces the same read, not a retry in the corrective sense | — |
| `ship` | 1 (the STOP gate is not a retry loop — it's a hard halt) | any red at STOP | halt, report, wait for the user to resolve upstream and re-invoke `/ship-task` |

Every bound above is a **new, numeric** value — the audit found "no bound found" everywhere, so
these are proposed thresholds based on the workspace's own existing qualitative language (e.g.
`rules/testing.md`'s regression-test rule, `code-review`'s Blocker/Major-must-resolve gate), not
arbitrary numbers. They are documented in the node contracts (Phase 4) and are advisory to the
orchestrating model (there is no engine to hard-stop a 3rd retry) — the same enforcement model
`hooks/quapp-guard.sh` uses for *deterministic* things and prose-rule files use for everything else.

## 7. Independent quality gates — what changes and what deliberately doesn't

- **`implement` → `review` is now a hard dependency in `graph/workflows/ticket.yaml`**: the workflow
  definition states `review.dependencies: [implement]` and `ship.dependencies: [test, review]` (and
  `security` when routed in). This closes the one real gap found in the audit (§3, "change-
  implementation gap") — a user following the graph document can no longer treat `implement`'s
  "done" as final without `review` having run, because the workflow document says so explicitly,
  even though no engine enforces it mechanically.
- **`commit`, `mr-feedback`, `merge-conflict-resolution` are left unchanged.** Rationale: all three
  are utility skills that sit *downstream* of a review gate in every graph workflow they're actually
  used in (`ship` calls `commit` only after `review`+`test` pass the STOP gate; `mr-feedback` acts on
  an *already-reviewed* MR's threads; `merge-conflict-resolution` is bounded by the external guard
  hook and typically followed by a fresh `/ship-task` review pass on the resulting merge commit,
  per that skill's own "re-run the repo's checks" step). Rewriting three independently-reviewed,
  CI-tested skills to add a redundant internal review call would (a) duplicate logic `ship`/the
  workflow already provides, (b) risk the exact "opportunistic refactor beyond what's asked"
  the task's non-negotiable rules forbid, and (c) not fix a graph-level problem — these three are
  invoked as standalone utilities by design, not as graph nodes. **Residual risk, recorded rather
  than silently accepted**: a user invoking `commit`/`mr-feedback`/`merge-conflict-resolution`
  *outside* any workflow (ad hoc, mid-session) still gets no independent review before the commit
  lands. This is called out in the final report as a known limitation, not fixed here.

## 8. Human-controlled shipping (unchanged gate, now graph-visible)

`ship`'s node contract states explicitly (`forbidden_actions: ["commit without STOP-gate pass",
"push", "open MR without explicit human go-ahead already embedded in /ship-task's existing flow"]`)
that it prepares: diff summary, changed repos/branches, test evidence, review findings, risks,
suggested commit message — **all of which `/ship-task` already produces** — and that committing/
pushing remains gated by the STOP condition that already exists in `commands/ship-task.md` step 3.
No new gate is invented; the graph makes the existing one an explicit, checkable node property.

## 9. File layout (final)

```
.claude/
├── commands/                      (unchanged, +1 additive step each in start-task.md/ship-task.md)
├── rules/                         (unchanged)
├── skills/                        (unchanged)
├── hooks/                         (unchanged)
├── agents/                        (unchanged)
├── graph/
│   ├── README.md                  how to read/use this layer; explicitly declarative, no engine
│   ├── workflows/
│   │   ├── ticket.yaml            primary lifecycle: intake→analyze→plan?→implement→integrate?→test→review→security?→ship
│   │   ├── bugfix.yaml            bug-investigation-first variant with mandatory regression test
│   │   └── release.yaml           completion-audit fan-out/fan-in, read-only, no ship node
│   ├── nodes/
│   │   ├── intake.md  analyze.md  plan.md  implement.md  integrate.md
│   │   ├── test.md  review.md  security.md  release-audit.md  ship.md
│   └── schemas/
│       ├── task-state.schema.json
│       └── node-result.schema.json
├── state/                         (new, git-ignored; created on first /start-task run)
└── refactor/
    ├── audit.md  design.md  migration.md
```

## 10. What is explicitly NOT being built

- No new skill, agent, or hook — every node maps to something that already exists.
- No YAML/graph execution engine, no Python/Node orchestration script — Claude reads the YAML the
  same way it already reads `docs/rules/model-routing.md`.
- No change to `/review-mr` or `/handoff` beyond a one-line pointer to the new graph doc (they
  already satisfy their own scoped purpose; forcing them into the ticket graph would misrepresent
  what they are — ad hoc, MR-scoped and session-scoped utilities, not ticket-lifecycle nodes).
- No change to any of the 9 workspace repos' code, build files, or CI.
- No change to `docs/rules/model-routing.md`'s table (still the single source for tiers — node
  contracts link to it, per its own rule 1).
