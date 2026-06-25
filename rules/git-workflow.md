# Rules — Git workflow & CI/CD

Each repo is an **independent git repository** (this is not a monorepo — see `workspace.md`). Run all
git commands inside the specific repo folder. The details below come from each repo's `.gitlab-ci.yml`,
`.husky/`, and `git remote -v`; anything inferred is marked **Unknown / needs confirmation**.

## Hosting
- GitLab, self-hosted: `https://gitlab.citynow.vn/quapp/platform/<repo>.git` (e.g.
  `quapp-functions-backend`, `quapp-ai-mcp`). Code review happens via GitLab **Merge Requests**.

## Branch model (environment branches)
- Long-lived branches map to environments and drive deploys (from `.gitlab-ci.yml` rules):
  - `develop` — **default branch** (CI `origin/HEAD -> origin/develop`) → deploys to **dev**
  - `staging` → deploys to **stg**
  - `production` → deploys to **prd**
- Work happens on short-lived branches merged via MR.

## Branch base (confirm per fix — never default to `develop`)
- Base each branch off `staging` or the **latest** `production`, depending on the fix — **not** `develop`.
- The correct base differs per fix; **ask/confirm the base** before branching. Never default to `develop`.

## Branch naming (observed in real branches)
- `feature/<user>/<short-desc>` and `bugfix/<user>/<short-desc>`, often including a Jira key:
  - e.g. `bugfix/khactuong.ngohoang/PQF-21432-inactive-user-session-destroyed`
  - e.g. `feature/khactuong.ngohoang/cors-config`
- Jira project key seen in branches/tickets: **`PQF`**.
- Some legacy branches use looser names (`bug/...`); prefer the `feature|bugfix/<user>/<key>-<desc>`
  form for new work.

## Frontend git hooks (`quapp-functions-frontend/.husky/`)
- `pre-commit` → `lint-staged` (ESLint + Prettier on staged files)
- `pre-push` → `yarn tsc` (type-check must pass before push)
- `commit-msg` → hook present (exports `GIT_PARAMS`). *(Exact commit-message convention it enforces —
  Unknown / needs confirmation; check the configured commitlint/rule before relying on a specific format.)*

## CI/CD pipelines (`.gitlab-ci.yml` per repo)
| Repo | Stages | Trigger / notes |
|------|--------|-----------------|
| `quapp-functions-backend` | `build → sast → deploy → test` | branch-based: `develop`/`staging`/`production` |
| `quapp-ai-mcp` | `build → sast → deploy` | branch-based: `develop`/`staging`/`production` |
| `quapp-functions-frontend` | `build → sast → deploy` | branch-based; copies `$ENV_FILE` → `.env` at build |
| `quapp-migration` | `build → deploy` | branch-based; deploy uses `$KUBECONFIG_FILE` |
| `quapp-ai-mcp-migration` | `build → deploy` | branch-based: `develop`/`staging`/`production` |
| `quapp-jupyterlab-ai-assistant-ext` | `build → publish → trigger` | **tag-based**: runs only on version tags matching `^v\d+\.\d+\.\d+(\.dev\d+\|\.pre\d+\|-batch\d+)?$`; builds a wheel + publishes |

- Build jobs build a Docker image (`docker:20.10.16-dind`), tag it `:$CI_COMMIT_SHORT_SHA-$CI_PIPELINE_ID`
  + `:latest`, and push to the GitLab container registry; deploy applies the `k8s/` manifests via a
  provided kubeconfig.
- The JupyterLab extension is **released by pushing a version tag** (it publishes a PyPI/npm wheel), not
  by merging to an environment branch. See its `RELEASE.md` for the bump procedure.

## Merge Request format (title + description)
- **Title** = a short description of the work done (the main task) — **not** a conventional-commit
  prefix and **not** the Jira key. E.g. `AI Suggestion toggle: error toast + UI rollback on settings.set()/load failure`.
- **Description** = just the Jira link, in the form `Task: <jira-issue-url>`
  (e.g. `Task: https://citynow-org.atlassian.net/browse/PQF-21640`). No changelog/checklist body.
- Jira base URL: `https://citynow-org.atlassian.net/browse/<KEY>`.
- Tooling: `glab` is authenticated for `gitlab.citynow.vn`. Edit an existing MR with
  `glab mr update <iid> --title "…" --description "Task: <url>"` (run inside the repo).
- Opening an MR via push options can set these too: `-o merge_request.title=… -o merge_request.description="Task: <url>"`
  (push-option values **cannot contain newlines**).

## Conventions & tooling
- Commit/MR/Jira flow is GitLab + Jira. Relevant available skills: `commit` (conventional commits),
  `/start-task`, `/ship-task`, `mr-feedback`.
- **Only commit or push when explicitly asked.** Never push directly to `develop`/`staging`/`production`;
  open an MR from a `feature/`/`bugfix/` branch.
- Don't commit secrets or `.env` files (see `workspace.md`).
