# Rules — sdk/quapp-sdk-templates

Catalog of quantum function templates for the Quapp platform.
GitLab: `quapp/platform/quapp-sdk-templates`. Source of truth: `sdk/quapp-sdk-templates/CLAUDE.md`.
**No application lives here** — this repo is pure source artifacts synced to S3.

## Template families

| Directory | Handler language | Count |
|-----------|-----------------|-------|
| `template/<sdk>/` | Python (`handler.py`) | 15 |
| `template/js-<sdk>/` | JavaScript (`function/handler.js`) | 7 |
| `template/qs-<sdk>/` | Q# (`function/Handler.qs`) | 8 |

Root-level dirs (`chemical-energy-calculation/`, `option-pricing/`, …) are standalone example apps,
not part of the build/sync system.

## Deployment (S3 sync, no Docker build here)
- CI: `aws s3 sync --delete template/ <bucket>` on push.
- Branch → bucket: `develop` → dev, `staging` → stg, `production` → prod, `ctc-production` → ctc.
- **Only `template/` syncs to S3** — files outside `template/` never ship.
- Templates are built into Docker images later by `quapp-functions-backend`, not in this CI.

## Multi-language bridge contract (JS/Q# templates)
The subprocess bridge is defined in `sdk/qapp-common`. Do not change `handler.js`/`Handler.qs`
signatures without checking the `SubprocessBridge` contract in `qapp-common`:

- **JS** (`handler_runner.js`): `handler.js` must `export default { processing, postProcessing }`.
- **Q#** (`Handler.qs`): must keep `Processing(input : String) : String` and `PostProcessing(jobResult : String) : String`.

Python sends `{"action": "processing"|"post_processing", ...}`; handler replies `{"status": "success", "result": ...}`.

## What varies between templates (the minimal diff)
Only these 5 things differ across any two same-family templates:
1. `Sdk.<SDK>` enum in `index.py`
2. `<Sdk>HandlerFactory()` call in `index.py`
3. `Language.JAVASCRIPT` vs `Language.QSHARP` in `index.py`
4. `quapp-<sdk>` package in `requirements.txt` + `Dockerfile`
5. Default `handler.js` / `Handler.qs` body

## Adding a new SDK template
Copy the nearest same-family, same-model (gate vs. annealing) template and change the 5 points above.
Place under `template/<js|qs>-<sdk>/` so CI syncs it.

## Branch layout notes
- `qs-*` templates are on `feature/PQF-20605/PQF-20621/add-qs-<sdk>-template` branches.
- Full set of 13 `js-*` templates on `feature/PQF-19659/multi-language-sdk-v1`; only 7 merged to `develop`.

## Safety notes
- `develop` is auto-synced to the dev S3 bucket — never merge broken templates there.
- `production` syncs to the live bucket — treat as a protected branch.
- `.mcp.json` at repo root contains live API tokens and is `.gitignore`d — never commit or echo it.
- Docs (`docs/`) are in Vietnamese; keep technical terms in English.
