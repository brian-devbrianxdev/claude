# Node — `test`

| Field | Value |
|---|---|
| `id` | `test` |
| `purpose` | Run the repo's real test suite per [`rules/testing.md`](../../rules/testing.md) and report real results — never claim green unrun. |
| `maps to` | [`rules/testing.md`](../../rules/testing.md)'s per-repo command table, executed as `/ship-task` step 2 |
| `reads` | The diff from `implement`/`integrate`; the repo's test command and JDK from `rules/testing.md` and `rules/workspace.md`. |
| `writes` | `state.test_results[]` (`repo`, `command`, `status`, `summary`), `state.phase: test`. |
| `allowed_actions` | Run the repo's own test command with the correct JDK; for a bug fix, confirm a regression test exists at the lowest reliable layer that fails before the fix (per `rules/java.md` Phase 3 and `rules/testing.md`); delegate a baseline-vs-diff disambiguation to a `general-purpose` (sonnet) subagent when a failure looks pre-existing, per `/ship-task` step 2's existing instruction. |
| `forbidden_actions` | Reporting a test as passing without having run it; skipping the mandatory regression test for a bug fix; running a repo's test suite with the wrong JDK without flagging the mismatch (the `quapp-guard.sh` hook already warns on this — this node must not silence that warning). |
| `dependencies` | `implement` (and `integrate` when routed in, for the consumer side of a contract change) |
| `success_criteria` | All required tests for the touched repo(s) pass; a bug fix has a regression test that fails on the pre-fix code and passes after. |
| `failure_route` | Back to `implement` for the same repo only — never to a different repo's `implement` instance. |
| `maximum_attempts` | 3. If the same test class fails identically after 3 attempts, set `blocked` and escalate to the human rather than retrying a 4th time. |
| `evidence_required` | `state.test_results[]` entries for every touched repo; real command output, not a claim. |
