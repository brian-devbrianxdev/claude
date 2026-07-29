# Node — `implement`

| Field | Value |
|---|---|
| `id` | `implement` |
| `purpose` | Make the minimal, scoped code change per repo, after explicit human approval of the plan. |
| `maps to` | [`change-implementation`](../../skills/change-implementation/SKILL.md) skill, invoked once per repo in `state.repos[]` |
| `reads` | Current code, GitNexus `context`/`impact`, `CLAUDE.md` Repository Map, the repo's `.claude/docs/rules/*.md` and `.claude/rules/java.md` gate. |
| `writes` | Source code (the actual diff). `state.completed_nodes[]`/`state.retries.implement`, `state.phase: implement`. Never commits or pushes — that is `ship`'s job only. |
| `allowed_actions` | Propose a plan, wait for human approval (mandatory — do not skip), make the diff, run lint/build checks, summarize files touched + risks. |
| `forbidden_actions` | Committing, pushing, opening an MR, transitioning the ticket, approving its own diff as final (that requires `review` — see `dependencies` on the `review` node's `dependencies: [implement]`, which makes this a two-way contract: `implement` cannot be treated as done without `review` running next). |
| `dependencies` | `analyze` (and `plan` when routed in) |
| `success_criteria` | Diff builds/lints cleanly per the repo's own checks; every file touched is explained. |
| `failure_route` | On a failed build/lint or a rejected plan, retry within this same node (new plan or fixed diff), up to `maximum_attempts`. |
| `maximum_attempts` | 2 per repo. On a 3rd failure of the *same* problem, set the repo's fan-out branch to `blocked` in `state.blocked_nodes[]` and escalate to the human (consider `engineering-advisor` only if its own 4-condition gate is met — do not invoke it routinely). |
| `evidence_required` | `state.completed_nodes[]` entry with `attempt` count; files-touched list; risk summary. |

## Parallelism note
When `state.repos[]` has more than one entry, `implement` fans out one instance per repo (never
per file within a repo — repos are separate git working trees by construction, so no file-ownership
overlap is possible). See `design.md` §5 for the migration-ordering and contract-dependency checks
that must pass before this fan-out is allowed to run all repos concurrently rather than in the
required order.
