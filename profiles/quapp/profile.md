# Project Profile — Quapp

The **single source of project identity**. Capability skills (task-scoping, change-implementation,
solution-planning, the task lifecycle commands) and the `/start-task` / `/ship-task` commands read
these values instead of hardcoding them. Swapping this file + the rules below retargets the whole
skill set at a different project.

## Identity
| Key | Value |
|-----|-------|
| `project` | Quapp (vendor CITYNOW Co. Ltd.); product also called "QuaO" |
| `tracker` | Jira — key **PQF**, base `https://citynow-org.atlassian.net/browse/<KEY>` |
| `vcs.host` | GitLab self-hosted — `gitlab.citynow.vn/quapp/platform/<repo>` |
| `vcs.review_unit` | **Merge Request** (not GitHub PR); tooling `glab` (authenticated) |
| `git_user` | `khactuong.ngohoang` (branch-name segment) |

## Branch model
- Long-lived env branches: `develop` (dev) · `staging` (stg) · `production` (prd).
- **Base each fix off `staging` or the latest `production` — confirm per ticket, never default to
  `develop`.** (`/start-task` STOPs to confirm the base before branching.)
- Branch name: `feature|bugfix/khactuong.ngohoang/PQF-<key>-<short-desc>`.
- MR title = short description of the work (not the Jira key, not a conventional-commit prefix).
- MR description = `Task: <jira-url>` only.

## Workspace facts (authority = rules/, not this file)
- **Not a monorepo** — six independent repos under one VS Code workspace. One repo at a time.
- Repo → JDK matrix, the two databases, cross-repo HTTP contracts (no codegen), and per-repo
  build/test commands are owned by [../../rules/](../../rules/) — see `workspace.md`, `migration.md`,
  `testing.md`, and the per-repo files. This profile does not duplicate them.

## Pointers
- Coding/layering/contract rules: [../../rules/](../../rules/)
- Deterministic guards (yarn-not-npm, JDK match, edit-AGENTS-not-symlink, no-secrets):
  `hooks/quapp-guard.sh`
