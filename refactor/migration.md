# Migration — old to new, exact change list

Every row below is either **ADD** (new file, nothing replaced) or **EDIT** (small additive diff to
an existing file — old content preserved, nothing renamed or deleted). No **DELETE** rows exist in
this migration: the audit found nothing duplicated, obsolete, or unreachable in the active tree
(`_archived-skills/` and `backups/` were already retired before this session; both are left as-is).

## New files (ADD)

| Path | Purpose | Replaces |
|---|---|---|
| `.claude/refactor/audit.md` | Phase 2 output | — |
| `.claude/refactor/design.md` | Phase 3 output | — |
| `.claude/refactor/migration.md` | this file | — |
| `.claude/graph/README.md` | how to read the graph layer | — |
| `.claude/graph/schemas/task-state.schema.json` | task-state JSON Schema | — |
| `.claude/graph/schemas/node-result.schema.json` | node-result JSON Schema | — |
| `.claude/graph/nodes/intake.md` | node contract | historically `/quapp-start-ticket` (never existed under that name in this repo — see audit §0); maps to `/start-task` steps 1–2 |
| `.claude/graph/nodes/analyze.md` | node contract | maps to `task-scoping` (historically referred to as `quapp-analyze` only in the task prompt, not in this repo) |
| `.claude/graph/nodes/plan.md` | node contract | maps to `solution-planning` |
| `.claude/graph/nodes/implement.md` | node contract | maps to `change-implementation` (historically `quapp-implement` only in the task prompt) |
| `.claude/graph/nodes/integrate.md` | node contract (new formalization — no prior single owner; logic previously scattered across `workspace.md` "no codegen" + `change-implementation`'s "keep contracts in sync" step) | — |
| `.claude/graph/nodes/test.md` | node contract | maps to `rules/testing.md` per-repo commands |
| `.claude/graph/nodes/review.md` | node contract | maps to `code-review` (historically `quapp-review` only in the task prompt) |
| `.claude/graph/nodes/security.md` | node contract | maps to `security-review` |
| `.claude/graph/nodes/release-audit.md` | node contract | maps to `completion-audit` (historically `quapp-release-audit`, absorbed pre-existing per `skills/README.md`) |
| `.claude/graph/nodes/ship.md` | node contract | maps to `/ship-task` steps 3–8 (historically `/quapp-ship-ticket`) |
| `.claude/graph/workflows/ticket.yaml` | primary workflow definition | — (new; formalizes the reconstructed flow in `audit.md` §3.1–3.2) |
| `.claude/graph/workflows/bugfix.yaml` | bug lifecycle variant | — (new; formalizes `audit.md` §3.2) |
| `.claude/graph/workflows/release.yaml` | release-audit fan-out/fan-in | — (new; formalizes `audit.md` §3.3) |

`.claude/state/` is **not** pre-created with a placeholder file — it is created on demand by
`/start-task`'s new step (`mkdir -p`), the same lazy-create pattern `/handoff` already uses for its
own output directory. Nothing to migrate; it starts empty.

## Edited files (EDIT — additive only, existing content untouched except the noted insertion)

| Path | Change | Why |
|---|---|---|
| `.claude/.gitignore` | Add `state/` to the existing "Runtime state (per-machine, not shareable)" section (alongside `sessions/`, `projects/`, `cache/`, …) | Task's non-negotiable rule: runtime state must not be committed unless already treated as durable; this repo's own convention already ignores every other per-machine runtime dir the same way |
| `.claude/commands/start-task.md` | One new step (after branch creation, before the existing hand-off step): best-effort write of `.claude/state/<KEY>.json` from the task-state schema, seeded with `task_id`, `objective`, `repos`, `phase: intake`, `human_approval.branch_base_confirmed: true`. Failure to write (e.g. no `jq`) is non-fatal — logged, not blocking. | Makes `/start-task` the graph's `intake`+`analyze` entry point that also seeds durable state, per the task's "convert start/ship commands into clean graph entry and exit points" instruction |
| `.claude/commands/ship-task.md` | One new step (after the STOP gate, before commit): update `.claude/state/<KEY>.json` — `phase: ship`, append `evidence`/`findings`/`test_results` from steps 1–3, set `human_approval.ship_approved` once the user's go-ahead to commit is explicit. Read the file (if present) at the top of the command to skip re-deriving repo scope from scratch. Best-effort, same non-fatal-if-missing rule. | Makes `/ship-task` the graph's terminal `ship` node and the point where the run's state file reaches `ready_to_ship`/`shipped_pending_human` |
| `.claude/skills/README.md` | One new bullet under the existing pointer list: link to `.claude/graph/README.md` as "the ticket-lifecycle graph — how the 4 commands + 16 skills fit into named workflow nodes" | Discoverability; no change to the skill count/table, no skill renamed |
| `.claude/commands/handoff.md` | One new sentence in "Quapp context the next session always needs": mention `.claude/state/<KEY>.json` (if present) as a pointer to link rather than re-derive | Keeps `/handoff`'s own "the doc is the index; the artifacts are the content" rule consistent with the new artifact |
| `/Users/ngohoangkhactuong/Quapp/CLAUDE.md` (workspace root — not part of `.claude`'s git repo, and `Quapp/` itself is not a git repo, so this edit is not tracked by any VCS) | One new line in §6 pointing to `.claude/graph/README.md` | Keeps the root map's skills/commands section in sync with the new layer, per the file's own maintenance note ("update these docs when the architecture changes") |

## Deleted / renamed (NONE)

No file is deleted or renamed. The audit's naming-reality-check (§0) confirmed the `quapp-*`-
prefixed names the task prompt assumed do not exist in the active tree — there is nothing live to
rename away from. `_archived-skills/` and `backups/` remain exactly as they were (out of scope;
already correctly excluded from discovery and from CI per `skills/README.md` and
`check-markdown-links.sh`).

## Compatibility notes

- `/start-task` and `/ship-task` keep every existing step, argument, STOP gate, and output contract
  unchanged — the new step is purely additive and fails soft (missing `jq`, missing directory, etc.
  never blocks the existing flow).
- No skill's frontmatter, trigger phrase, or file path changes — nothing that invokes a skill by
  name today needs to change how it invokes it.
- `docs/rules/model-routing.md` is not edited — node contracts link to it exactly as every existing
  skill already does (its own rule 1).
- The three self-approval-risk skills identified in the audit (`commit`, `mr-feedback`,
  `merge-conflict-resolution`) are **not modified** — see `design.md` §7 for the reasoning.
