# Node — `release_audit`

| Field | Value |
|---|---|
| `id` | `release_audit` |
| `purpose` | Prove a whole release (a list of tickets) meets 100% of requirements and that no two tickets conflict, before shipping the release as a batch. Conditional — only activated for release-scope work (`workflow: release`, see [`../workflows/release.yaml`](../workflows/release.yaml)); never runs for single-ticket work. |
| `maps to` | [`completion-audit`](../../skills/completion-audit/SKILL.md) skill (+ [`single-ticket.md`](../../skills/completion-audit/single-ticket.md) for the per-ticket scoring logic it reuses) |
| `reads` | Every ticket in the release + comments, all 6 primary repos, `.claude/rules/java.md`'s test-routing table, GitNexus. |
| `writes` | A completeness verdict per ticket + a cross-ticket conflict report. `state.evidence[]`/`state.findings[]`, `state.phase: release_audit`. **Never edits code, never transitions a ticket.** Its one side effect (syncing repos to `develop` for evidence, stash-safe) is always reverted to the original branch/stash before returning. |
| `allowed_actions` | Read across repos/tickets, fan out one worker per ticket in parallel (sonnet tier) once the ≥4-ticket/≥2-repo threshold is crossed, run one cross-ticket conflict-synthesis pass (opus tier) as the fan-in. |
| `forbidden_actions` | Editing code, transitioning any ticket, leaving a repo checked out on `develop` after the audit finishes. |
| `dependencies` | `implement` (+ `test` + `review`) for every ticket in the release — an audit of unimplemented work is not meaningful. |
| `success_criteria` | Every ticket scores ✅ Done or has an explicit 🟡 Partial/❌ Not Done reason; no unresolved cross-ticket conflict. |
| `failure_route` | A ❌/🟡/conflict finding routes back to that specific ticket's own `implement`/`review` — the release audit itself is never "retried," its findings are. |
| `maximum_attempts` | 1 (read-only audit; re-running before anything changes produces the same read) |
| `evidence_required` | Per-ticket verdicts + the conflict-synthesis report, both in `state.evidence[]`. |

## Parallelism note
Mirrors `implement`'s fan-out rule (`design.md` §5): parallel per-ticket workers are safe because
each worker reads a different ticket/repo combination; the single conflict-synthesis pass is the
mandatory fan-in, run once, after every worker returns.
