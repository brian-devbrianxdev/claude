# Node — `plan`

| Field | Value |
|---|---|
| `id` | `plan` |
| `purpose` | Produce a solution design, an ordered implementation plan, and an effort/time estimate before any code is written. **Mandatory** (standing user directive, 2026-07-30) — opus must think through and identify the change on every ticket before a branch is created or code is written. Skipped only when the unit being opened is itself a sub-task already planned by a prior run (`/start-task` Step 3's one exception). |
| `maps to` | [`solution-planning`](../../skills/solution-planning/SKILL.md) skill (opus tier per `docs/rules/model-routing.md`) |
| `reads` | Jira ticket + comment thread, `analyze`'s output, `.claude/rules/` (layering, `testing.md`'s FE exception). |
| `writes` | Vietnamese Jira comment + Original Estimate + Story Points + role label (per `solution-planning`'s own contract); optionally Jira sub-tasks. `state.decisions[]` (the chosen approach + rationale), `state.phase: plan`. No source-code writes. |
| `allowed_actions` | Propose alternatives with trade-offs, write to Jira (comment/estimate/sub-tasks), invoke [`grilling`](../../skills/grilling/SKILL.md) if the plan is large/ambiguous and needs stress-testing before locking. |
| `forbidden_actions` | Writing source code, creating a branch, transitioning the ticket. |
| `dependencies` | `analyze` |
| `success_criteria` | A plan exists that `implement` can execute step-by-step; estimate recorded on the ticket. |
| `failure_route` | If `analyze`'s scope turns out to be wrong while planning, route back to `analyze` rather than planning against a bad map. |
| `maximum_attempts` | 1 (planning is not itself retried; if the plan is rejected, that surfaces as a `grilling` round or a fresh `plan` invocation with new input, not a bounded retry loop) |
| `evidence_required` | `state.decisions[]` records the chosen approach; Jira ticket carries the estimate. |
