# Node — `analyze`

| Field | Value |
|---|---|
| `id` | `analyze` |
| `purpose` | Map the ticket onto the workspace: target repo(s), JDK, affected files/layers, cross-repo contract/DB impact. Decide `planned_nodes` for the rest of the run. |
| `maps to` | [`task-scoping`](../../skills/task-scoping/SKILL.md) skill (or [`bug-investigation`](../../skills/bug-investigation/SKILL.md) when `workflow: bugfix` — see [`../workflows/bugfix.yaml`](../workflows/bugfix.yaml)) |
| `reads` | Root `CLAUDE.md` Repository Map, target repo(s)' `.claude/docs/rules/*.md`, GitNexus (`query`/`context`), grep fallback. Read-only — no code edits. |
| `writes` | Chat report only, plus `state.repos[]`, `state.planned_nodes[]`, `state.workflow`, `state.phase: analyze`. No source-code or Jira writes. |
| `allowed_actions` | Read code/docs/graph, run GitNexus queries, propose the routing decision (§4 of `design.md`). |
| `forbidden_actions` | Editing code, writing to Jira, creating a branch. |
| `dependencies` | `intake` |
| `success_criteria` | Repo(s)/JDK/files/contracts identified; `planned_nodes` decided against the routing table in `design.md` §4 (docs-only / single-repo / multi-repo / migration-touching / security-sensitive / bugfix). |
| `failure_route` | If scope is genuinely ambiguous, ask the user (per `task-scoping`'s own instruction) rather than guessing — this is a qualitative stop, not a retry. |
| `maximum_attempts` | 1 (read-only; re-running produces the same read, not a corrective retry) |
| `evidence_required` | `state.repos[]` non-empty; `state.planned_nodes[]` set. |
