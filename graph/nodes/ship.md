# Node — `ship`

| Field | Value |
|---|---|
| `id` | `ship` |
| `purpose` | The terminal, human-controlled gate: prepare everything needed to commit/push, then stop and wait for explicit human go-ahead. Never auto-commits, auto-pushes, or auto-approves its own STOP condition. |
| `maps to` | [`/ship-task`](../../commands/ship-task.md) steps 3–8 (the STOP gate through logging work) |
| `reads` | `state.test_results[]`, `state.findings[]`, `state.evidence[]` from `test`/`review`/`security` (or re-derives them inline if no state file exists — this node must work with or without one). |
| `writes` | Diff summary, changed repos/branches, test evidence, review findings, risks, suggested commit message. On explicit human approval only: a commit, a push, an MR (target = the branch base confirmed at `intake`), a ticket transition, and a work-log entry. `state.phase: ship`, `state.human_approval.ship_approved`, `state.final_status`. |
| `allowed_actions` | Everything `/ship-task` steps 1–8 already do — review invocation, testing, the deterministic secret-scan, commit, push, MR creation, ticket transition, work logging — **all gated by the existing STOP condition, unchanged.** |
| `forbidden_actions` | Committing or pushing while any test is red or any review/security Blocker/Major is unresolved; committing or pushing without the human's explicit go-ahead at the STOP gate; approving its own gate (there is no self-override — see `rules/java.md` Phase 4 and `commands/ship-task.md` step 3, both unchanged by this refactor). |
| `dependencies` | `test`, `review` (and `security` when routed in). **Hard dependency — this node must refuse to run if any of these are missing from `state.completed_nodes[]`, even absent a state file, by re-deriving and re-running them inline first.** |
| `success_criteria` | MR opened at the confirmed base branch, ticket transitioned, work logged — or, if the human declines to proceed, a clean halt with nothing committed/pushed. |
| `failure_route` | Any red at the STOP gate → halt, report, wait. This is not a corrective retry — the fix happens back at `implement`/`test`/`review`, and `ship` is re-invoked afterward. |
| `maximum_attempts` | 1 — the STOP gate is a hard halt, not a loop. Re-invoking `/ship-task` after fixing the upstream issue is a fresh attempt at this same node, not a retry within one attempt. |
| `evidence_required` | `state.final_status` set to `ready_to_ship` (halted, waiting) or `shipped_pending_human` (MR opened) — never `done` set by this node itself; only the human's own subsequent confirmation outside the graph closes that out. |
