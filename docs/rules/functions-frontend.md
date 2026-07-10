# Rules — `functions/quapp-functions-frontend` ("quao-frontend" web UI)

## Responsibility
The user-facing web application (dashboard, function editor, projects, billing/admin, AI chat,
user guide). npm package name `quao-frontend`; app title "Quapp Functions".

## Stack
- **UmiJS Max** (`@umijs/max`) + **React 18** + **Ant Design 5 / Pro Components**, **TypeScript 4.9**.
- Monaco editor, `@ant-design/charts`, Formik + Yup, `@stomp/stompjs` (live updates),
  `@microsoft/fetch-event-source` (SSE streaming), `react-markdown`, `react-joyride` (user-guide tours).
- Tests: **Jest** + Testing Library. Lint: ESLint + Prettier + Husky. SonarQube.

## Folder structure (`src/`)
`pages/` (routes), `services/` (HTTP clients), `dataSources/` (**one folder per feature/screen — the
dominant organizing pattern**, e.g. `Functions/`, `Projects/`, `BillingAccount/`, `AIChatStandalone/`,
`UserGuide/`, `Workflows/`…), `components/`, `containers/`, `contexts/`, `hooks/`, `formiks/`,
`wrappers/`, `ghosts/`, `constants/`, `locales/`, `utils/`, `types/`, `runtimeConfigs/`.
Routing/config in `config/` (`config.ts`, `routes.ts`).

## Config / environment
- `config/config.ts` injects `define`d globals from env: **`BASE_URL`** (→ functions-backend),
  **`MCP_API_BASE_URL`** (→ quapp-ai-mcp), **`CMS_BASE_URL`** (→ CMS), plus `DOCS_URL`,
  `ID_QAPP_STORE_DOMAIN`, `QUAPP_STORE_DOMAIN`, `CLARITY_KEY`, `QUAPP_CLOUD_CONTACT`,
  `PRIVACY_POLICY_URL` (full list in `config/config.ts`).
- Runtime env switches: `REACT_APP_ENV` / `UMI_ENV` / `MOCK`. Local files: `.env`, `mock/`.
- Known hosts: `functions-{dev,stg}.quapp.cloud`, `mcp-dev.quapp.cloud/api/v1`, `id-dev.quapp.store`,
  `cms-dev.quapp.store/api`, `docs.quapp.cloud`.

## Build / dev
```bash
yarn install            # uses yarn; postinstall runs `max setup`
yarn start:dev          # dev server (REACT_APP_ENV=dev, MOCK=none)
yarn build              # production build (`max build`)
yarn test               # Jest
yarn lint               # eslint + prettier + tsc --noEmit
```
Testing detail in `testing.md`. Git hooks (Husky) in `git-workflow.md`.

## Frontend patterns
- Feature-folder organization under `dataSources/` (one folder per screen).
- UmiJS conventional routing (`config/routes.ts`); Ant Design Pro layout.
- STOMP for live data; SSE (`fetch-event-source`) for streaming AI responses.
- Calls **two** backends: `BASE_URL` (QuaO platform) for product features, `MCP_API_BASE_URL`
  (ai-mcp `/api/v1`) for AI code generation.

## Deploy
`Dockerfile`, `k8s/`, `buildspec.yaml`.

## Coding style (frontend)
- **No comments and no unit tests when implementing frontend code.** Write self-explanatory code; do
  **not** add JSDoc, inline, or explanatory comments, and do **not** author new Jest/unit tests for
  frontend changes — unless the user explicitly asks for them.
- **Only import-struct comments are allowed** — the import-grouping headers (`// libs`, `// types`,
  `// stores`, `// hooks`, `// others`, …). Nothing else.
- Pre-existing tests still run for verification (`yarn test`, see `testing.md`); this rule is about not
  *writing* new comments/tests during implementation.

## Pitfalls
- **Use `yarn`, not npm** — Husky + `max setup` wiring can break otherwise.
- No generated API client — when a backend/MCP DTO or route changes, update `src/services/` by hand.
- This repo has **no Playwright/e2e** (see `testing.md`); don't assume browser tests exist.
- **Never suppress `onChange` on a controlled input to guard IME** — it blocks Vietnamese typing. Fix
  char-duplication via a stable input DOM (e.g. AntD `suffix`), not `onChange` gating.
