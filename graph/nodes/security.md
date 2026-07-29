# Node — `security`

| Field | Value |
|---|---|
| `id` | `security` |
| `purpose` | Security-specific review (OWASP Top 10, injection, secrets, auth) for changes touching input handling, queries, or authentication. Conditional — not run for changes that don't touch this surface. |
| `maps to` | [`security-review`](../../skills/security-review/SKILL.md) skill; Step 0 is always the deterministic [`secret-scan.sh`](../../skills/security-review/secret-scan.sh) gate, which also runs unconditionally at `/ship-task`'s STOP gate regardless of whether this node was routed in. |
| `reads` | The diff, routed to one of `security-review`'s reference files (input-validation, web-output, auth-secrets-deps) by what changed. |
| `writes` | A findings report; `state.findings[]`, `state.evidence[]` (secret-scan exit code + any WARN lines), `state.phase: security`. Read-only beyond that. |
| `allowed_actions` | Run `secret-scan.sh`, apply the OWASP checklist, spawn the shared `deep-reviewer` agent instance if `review` already triggered one for the same diff (never a second one). |
| `forbidden_actions` | Editing code to fix a finding; overriding a `secret-scan.sh` BLOCKER without moving the secret to env/Secrets Manager first; treating a WARN line as automatically safe without a human judgment call. |
| `dependencies` | `implement` |
| `success_criteria` | `secret-scan.sh` exits 0 with no BLOCKER lines; no unresolved Blocker/Major security finding. |
| `failure_route` | Any BLOCKER → back to `implement` for a fix; this is never retried automatically — `rules/java.md` Phase 4 already treats security review as never-downgraded, so a BLOCKER always waits for a human-directed fix. |
| `maximum_attempts` | 1 for the secret-scan gate (it is deterministic — re-running it without changing the code changes nothing) + 1 re-review after a fix for the LLM checklist portion. |
| `evidence_required` | `state.evidence[]` entry for the secret-scan exit status; `state.findings[]` for the checklist portion. |

## When this node is skipped
Changes with no input-handling, query, or auth surface touched (per `analyze`'s routing decision)
skip the OWASP-checklist portion of this node — but `secret-scan.sh` still always runs at `ship`'s
STOP gate regardless, since it is a `/ship-task` step, not conditional on this node being routed in.
