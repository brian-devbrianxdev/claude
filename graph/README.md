# Graph — ticket-lifecycle workflow layer

**What this is:** a declarative map of how the existing 4 commands + 16 skills + 3 agents fit
together as named workflow nodes, plus a small durable state file per ticket. **What this is not:**
a new runtime, engine, or framework. There is no code here that executes — Claude Code has no
workflow engine, so this directory is read by the orchestrating model the same way it already reads
`docs/rules/model-routing.md`: a document that shapes behavior, not a program that runs.

If you're looking for *how a skill actually works*, read the skill (`../skills/<name>/SKILL.md`).
This directory only adds the missing coordination metadata: which nodes exist, what depends on
what, when a node is skipped, how many times it may retry, and what durable evidence it must leave
behind. See `../refactor/audit.md` and `../refactor/design.md` for the evidence and reasoning behind
every decision here.

## Layout

- **`nodes/`** — one Markdown file per workflow phase. Each states `id`, `purpose`, `reads`,
  `writes`, `allowed_actions`, `forbidden_actions`, `dependencies`, `success_criteria`,
  `failure_route`, `maximum_attempts`, `evidence_required`. Every node points at the skill/command
  that actually does the work — read that file for the real instructions.
- **`workflows/`** — YAML files listing nodes + `when:` routing conditions for one workflow shape:
  - `ticket.yaml` — the default: a single Jira ticket, one or more repos, ending at a human ship gate.
  - `bugfix.yaml` — same shape, `analyze` replaced by `bug-investigation`, regression test mandatory.
  - `release.yaml` — a list of tickets audited together via `completion-audit`; read-only, no `ship`.
- **`schemas/`** — JSON Schema for the two structured artifacts: `task-state.schema.json` (the
  per-ticket run ledger) and `node-result.schema.json` (what one node contributes to it).

## How to use this as the orchestrating model

1. At `/start-task`, read `workflows/ticket.yaml` (or `bugfix.yaml` if the ticket is a Bug), decide
   `planned_nodes` from the `when:` conditions using what `task-scoping`/`bug-investigation` found,
   and write the initial `../state/<TICKET>.json` (schema in `schemas/task-state.schema.json`).
2. As each node in `planned_nodes` runs (by invoking the skill/command it maps to — normally, not
   through any special graph syntax), append a `node-result`-shaped record to the state file's
   `evidence`/`findings`/`test_results`, and move the node from `active_nodes` to `completed_nodes`
   or `blocked_nodes`.
3. Respect `dependencies` — do not run a node before everything in its `dependencies` list is in
   `completed_nodes`. In particular: **`ship` depends on `test` and `review` (and `security` when
   routed in) — never skip straight to `ship` because a fix "looks obviously fine."**
4. Respect `maximum_attempts` (see each node file, and `design.md` §6 for the rationale) — after the
   limit, set the node to `blocked` in state and report to the human instead of retrying again.
5. The state file is **advisory and best-effort** — if it can't be written (no `jq`, permissions,
   whatever), say so once and keep going with the existing conversation-based flow. It must never
   become a new blocking dependency for work that worked fine without it before this layer existed.

## Relationship to existing state mechanisms (don't duplicate these)

- **Jira ticket** stays the durable source of truth for the objective/acceptance criteria — the
  state file mirrors a *pointer* to it (`task_id`), not a copy of its content.
- **`/handoff`** stays the human-triggered, cross-session narrative doc. If `../state/<TICKET>.json`
  exists, `/handoff` links to it rather than re-deriving the same facts.
- **`session-start.sh`**'s per-session snapshot (branch/dirty/JDK/Docker/GitNexus freshness) is
  environment state, regenerated every session by design — it is not merged into the ticket state
  file, which is scoped to one ticket's graph run, not the whole workspace.

## Adding or changing a node

- A node almost always **already has an implementation** — a skill, a command's step, or an agent.
  Don't write new instructions in the node file; point at the existing one and add only the
  governance fields listed above.
- If you find yourself wanting a node with no existing skill behind it, that's a signal to write a
  skill first (see `../skills/README.md`'s "Adding a new skill" checklist) — the graph coordinates
  capabilities, it doesn't replace the process for creating them.
- Update the relevant `workflows/*.yaml` and, if the state shape needs a new field, both JSON
  Schemas in `schemas/` — keep the two in sync (`node-result` fields must all have somewhere to land
  in `task-state`).
