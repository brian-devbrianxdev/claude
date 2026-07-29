# Node — `review`

| Field | Value |
|---|---|
| `id` | `review` |
| `purpose` | Independent, findings-only review of the diff — correctness, project-rules, and (when the diff touches them) concurrency/performance/api-contract/architecture. The implementer never approves its own result; this node is the separate reviewer role the task requires. |
| `maps to` | [`code-review`](../../skills/code-review/SKILL.md) skill, escalating concurrency/architecture lenses or ≥2-repo/>10-file diffs to the [`deep-reviewer`](../../agents/deep-reviewer.md) agent (opus, read-only tools only) per `docs/rules/model-routing.md`. |
| `reads` | The working diff, `profiles/quapp/profile.md`, the repo's `.claude/rules/`, GitNexus `detect_changes`/`impact`/`api_impact`. Read-only. |
| `writes` | A ranked findings report (`Gate: PASS | CHANGES REQUESTED`), plus `state.findings[]` and `state.evidence[]` (the verdict string), `state.phase: review`. **Never edits code.** |
| `allowed_actions` | Read the diff and repo rules, spawn one `deep-reviewer` agent when a trigger fires (never two for the same diff), rank findings by severity. |
| `forbidden_actions` | Editing code to fix a finding itself (that's `implement`'s job, on the next attempt); approving/merging/committing; inventing issues not evidenced in the diff. |
| `dependencies` | `implement` (and `integrate` when routed in) |
| `success_criteria` | `Gate: PASS`, or all Blocker/Major findings resolved by a subsequent `implement` attempt and re-reviewed. |
| `failure_route` | Any Blocker/Major → back to `implement` (same repo) for a fix, then back to `review` for the same diff. This is the dependency that makes `implement`'s "done" non-final without this node running. |
| `maximum_attempts` | 2 (initial review + one re-review after a fix round). If the same Blocker/Major persists after 2 rounds, set `blocked` — implementer and reviewer disagree, needs a human call, not a 3rd automatic round. |
| `evidence_required` | `state.findings[]` (possibly empty) and the `Gate:` verdict string in `state.evidence[]`. |

## Non-negotiable
`ship` depends on this node (`review` in `completed_nodes` with a `PASS` verdict, or all
Blocker/Major findings explicitly resolved) — a run must never reach `ship` having skipped `review`,
regardless of how small the diff looks.
