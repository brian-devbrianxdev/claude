# Rules — quapp-jupyterlab-s3-ext

JupyterLab 4 extension that bridges the Quapp workspace to the backend and S3.
Source of truth: `ai/quapp-jupyterlab-s3-ext/CLAUDE.md` (a regular file, not a symlink — edit it directly).
GitLab: `quapp/platform/quapp-ide/quapp-jupyterlab-s3-ext`.

## Two halves, one package

| Half | Root | Role |
|------|------|------|
| Python server ext | `quapp_jupyterlab_s3_bridge/` | Overrides JupyterLab's `ContentsManager`; REST handlers at `/s3bridge/*` |
| TS/React frontend | `src/` | File-browser plugin — version dropdown, save-to-S3 button, sync-status column |

## Key classes (Python)
- **`S3SelectiveContentsManager`** (`manager.py`) — central class; handles get/save/delete, enforces language/extension rules, hashes files for sync.
- **`ManagerCache`** — holds file hashes, decoded JWT, active token, `version_id`, function language. Call `clear_caches()` on auth errors.
- **`setup_handlers`** (`handlers.py`) — registers `/s3bridge/initialize`, `/s3bridge/versions`, `/s3bridge/upload-s3`, `/s3bridge/file-status`, `/s3bridge/session/close`.

## Auth
- Reads Cognito `idToken` from the `*.idToken` cookie; mirrors it to `QUAPP_ACCESS_TOKEN` env var.
- `SessionCloseHandler` is hit via `navigator.sendBeacon` on `pagehide` — revokes the cookie.
- On JWT change (`is_jwt_changed`), stale caches are cleared to prevent session bleed.

## Branch / release model
- Long-lived env branches: `develop` → dev, tag `vX.Y.Z.devN` → dev, `.preN` → staging, plain `vX.Y.Z` → production.
- **Release by tag** — version is sourced from `package.json` via `hatch-nodejs-version`. See `RELEASE.md`.
- CI: build wheel → publish to GitLab PyPI → trigger JupyterHub project (ID 374) to rebuild the notebook image.

## Dev workflow
```bash
pip install -e ".[test]"
jupyter labextension develop . --overwrite
jupyter server extension enable quapp_jupyterlab_s3_bridge
jlpm build          # after TS changes
jlpm watch          # iterative TS dev
```

## Tests
```bash
pytest -vv -r ap --cov quapp_jupyterlab_s3_bridge   # Python
jlpm test                                             # Jest (frontend)
# Playwright: see ui-tests/README.md
```

## Safety notes
- Language/extension enforcement is in `S3SelectiveContentsManager.save()` — do not bypass.
- Creating directories is intentionally forbidden (`save()` / `new_untitled()` rejects dirs).
- The `MCP_API_BASE_URL` / `MCP_API_KEY` section in the README is aspirational — the module is not present; do not reference it.
