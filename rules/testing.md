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

## Frontend test-writing exception (overrides the global "every change needs tests" default)
**Applies to all FE/UI source in the workspace, not one repo** — currently that means:
  - **`quapp-functions-frontend`** — the entire repo (it's 100% frontend).
  - **`quapp-jupyterlab-ai-assistant-ext`'s TypeScript/React frontend only** — the `src/` panel code
    (`jlpm test` / Jest). Its **Python server extension** (`quapp_jupyterlab_ai_assistant/`, `pytest`) is
    backend code and is **not** covered — that half keeps mandatory tests. **Playwright/Galata
    (`ui-tests/`) also keeps its expectations** — this exception is about *unit* tests specifically, and
    Playwright is this repo's only real UI regression coverage.
  - If a future repo/module is added whose source is frontend/UI (TS/React or similar client code), this
    exception extends to it too — the boundary is "is this FE source", not "is this
    `quapp-functions-frontend`".

- **FE source in scope does not require new unit tests.** This is a deliberate, project-level override
  of the global engineering-principle default ("every implementation suggests its tests") — scoped to
  frontend/UI code only. Root cause: `quapp-functions-frontend` has no e2e/Playwright suite at all, and
  the team's own convention (see `docs/rules/functions-frontend.md`,
  `docs/rules/jupyterlab-ai-assistant-ext.md`) is not to author new Jest tests during implementation
  unless the user explicitly asks — for either FE codebase.
- This exception applies everywhere test effort is normally assumed, not just at write-time:
  - **Implementation** (`change-implementation`, ad-hoc coding): no new Jest/spec files for in-scope FE
    changes unless the user explicitly asks for them.
  - **`solution-planning` estimates**: do not add a test-writing work item, or pad the estimate for FE
    test effort, for work scoped to in-scope FE source. Backend/ai-mcp/migration work — and the
    JupyterLab ext's **Python** server-extension work — in the same ticket still gets its mandatory test
    line per `rules/java.md` (Java) or the ext's pytest expectations.
  - **`completion-audit` scoring**: implemented-but-untested in-scope FE code scores **✅ Done**, not
    🟡 Partial — the untested-code-is-Partial rule does not apply there.
- **Still run the existing suite for verification** — `yarn test` / `jlpm test` (+ `tsc --noEmit` /
  `yarn lint`) before declaring FE work done, per the table above. The exception is about *authoring new
  tests*, not about skipping verification that nothing pre-existing broke.
- Every other repo/module keeps the mandatory-test rule unchanged: `quapp-functions-backend` /
  `quapp-ai-mcp` / both migration repos via `rules/java.md` Phase 3; the JupyterLab ext's **Python**
  server extension keeps pytest, and its **Playwright/Galata** UI suite keeps its expectations.
