# Node — `intake`

| Field | Value |
|---|---|
| `id` | `intake` |
| `purpose` | Capture or create the ticket, restate the objective, seed the run's state file. |
| `maps to` | [`/start-task`](../../commands/start-task.md) step 1 (ticket capture/creation + sub-task identification) |
| `reads` | Jira ticket (`getJiraIssue`, incl. `comment`+`subtasks`) if the Atlassian MCP is connected; otherwise pasted ticket text from the user. Never requires Jira. |
| `writes` | `.claude/state/<TASK_ID>.json` — initial record (`task_id`, `objective`, `workflow`, `phase: intake`, `created_at`/`updated_at`). Best-effort; a write failure is logged, not fatal. |
| `allowed_actions` | Read Jira (read-only), ask the user for pasted text, restate the goal, identify parent vs. sub-task, create the state file. |
| `forbidden_actions` | Transitioning the ticket (that's step 5 of `/start-task`, after the branch-base is confirmed — not this node's job), writing code, creating a branch. |
| `dependencies` | none (entry node) |
| `success_criteria` | A ticket key or pasted-text objective is captured and restated in one line; `state.task_id` is set. |
| `failure_route` | If neither a valid key nor usable pasted text is available, halt and ask the user — do not guess a ticket. |
| `maximum_attempts` | 1 (this is a capture step, not a corrective retry target) |
| `evidence_required` | `state.objective` populated; `state.task_id` populated. |
