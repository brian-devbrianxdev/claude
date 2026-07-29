# Node — `integrate`

| Field | Value |
|---|---|
| `id` | `integrate` |
| `purpose` | Fan-in barrier for multi-repo changes: confirm a touched HTTP/DTO contract is kept in sync on every side that consumes it, since `workspace.md` is explicit that "no codegen does it for you." Conditional — only activated when `analyze` flagged a cross-repo contract change. |
| `maps to` | No single existing skill owned this before; the check itself is `workspace.md`'s "keep cross-tier contracts in sync" rule, previously exercised ad hoc inside `change-implementation`'s own review of its diff. This node formalizes it as an explicit fan-in step rather than an implicit expectation. |
| `reads` | The diffs from every `implement` instance in `state.completed_nodes[]` that touched a shared contract (frontend ↔ backend ↔ ai-mcp DTOs/routes, per root `CLAUDE.md` §3 "Cross-Repo Interaction"). |
| `writes` | `state.decisions[]` — an explicit confirmation record ("contract X kept in sync between repo A and repo B") or a finding if it wasn't. `state.phase: integrate`. |
| `allowed_actions` | Compare the producer and consumer sides of a contract, flag a mismatch, ask the user to confirm intent if a mismatch looks deliberate (e.g. a staged rollout). |
| `forbidden_actions` | Silently "fixing" a mismatch by editing the other repo without going back through `implement` for that repo; skipping this node when `analyze` flagged a contract change. |
| `dependencies` | `implement` (all fanned-out instances that touch a shared contract) |
| `success_criteria` | Every repo consuming a changed contract has a matching change, confirmed explicitly. |
| `failure_route` | Route back to `implement` for whichever repo is out of sync — this is not a `test` failure, it's a scope gap. |
| `maximum_attempts` | 2 (a genuine contract mismatch found twice after a claimed fix is a `blocked` escalation, not a 3rd silent retry) |
| `evidence_required` | `state.decisions[]` entry naming the contract and both sides checked. |

## When this node is skipped
Single-repo changes, and multi-repo changes where `analyze` found no shared HTTP/DTO/event contract
touched, skip this node entirely (per the routing table in `design.md` §4) — it is not run "just in
case."
