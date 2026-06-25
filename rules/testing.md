# Rules — Testing

Run the relevant tests **inside the repo** before declaring work done, and report real results — never
claim green if you didn't run them.

## Per-repo commands
| Repo | Unit | Integration / more |
|------|------|--------------------|
| `quapp-functions-backend` | `./gradlew test` | CodeBuild `integration-test.buildspec.yml`; ad-hoc scripts in `api_testing/` (Postman collection/env) |
| `quapp-ai-mcp` | `./gradlew test` | `./gradlew integrationTest` (Testcontainers, **needs Docker**) |
| `quapp-functions-frontend` | `yarn test` (Jest; setup `tests/setupTests.jsx`, `jest.setup.ts`) | `yarn test:coverage`. **No Playwright/e2e** in this repo (no `ui-tests/`, no Playwright dep). |
| `quapp-jupyterlab-ai-assistant-ext` | `jlpm test` (Jest) + `pytest -vv -r ap --cov quapp_jupyterlab_ai_assistant` | Playwright/Galata in `ui-tests/` |
| `quapp-migration` | `./gradlew test` (Testcontainers) | — |
| `quapp-ai-mcp-migration` | `./gradlew test` | — |

## Notes
- **ai-mcp** splits JPA/controller tests into the `integrationTest` task; plain `./gradlew test` excludes
  them. Run both when touching repositories or controllers.
- Integration tests that use **Testcontainers** require a running Docker daemon.
- **Frontend** has only Jest unit tests + `tsc --noEmit` (via `yarn lint` / the `pre-push` hook). There
  is no browser/e2e suite in `quapp-functions-frontend`.
- **JupyterLab ext** is the only repo with Playwright/Galata UI tests (`ui-tests/`), plus Jest and
  pytest. Per-file checks: `npx tsc --noEmit src/<file>.ts`, `python -m py_compile <file>.py`.
- Match the repo's JDK for Gradle test runs (see `workspace.md`).
