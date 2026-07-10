# Workspace Rules (cross-cutting)

Conventions that apply across **all** Quapp repos. Repo-specific detail lives in the sibling
`.claude/rules/*.md` files; the high-level map is in the root `CLAUDE.md`.

## Not a monorepo
- This is a VS Code multi-root workspace (`Quapp.code-workspace`), **not** a git monorepo. Each
  subfolder under `ai/`, `functions/`, `migration/` is its own independent git repository.
- There is **no** root-level build, no shared lockfile, and no cross-repo package linking on disk —
  repos integrate at **runtime over HTTP** (see `CLAUDE.md` → Cross-Repo Interaction).
- **Don't** run a build at the workspace root, and **don't** `cd` across repos in one command. Run
  `git` / Gradle / `yarn` / `jlpm` **inside the specific repo folder**.

## JDK per repo (mismatch fails confusingly)
| Repo | JDK |
|------|-----|
| `functions/quapp-functions-backend` | **Java 17** |
| `functions/quapp-functions-frontend` | n/a (Node/yarn) |
| `ai/quapp-ai-mcp` | **Java 21** |
| `ai/quapp-jupyterlab-ai-assistant-ext` | n/a (Python + Node) |
| `migration/quapp-migration` | **Java 17** |
| `migration/quapp-ai-mcp-migration` | **Java 21** |

`Quapp.code-workspace` configures JavaSE-17 + JavaSE-21 (21 is the IDE default; terminal `JAVA_HOME`
points at openjdk@21). Match the repo's JDK when building from a terminal.

## Naming
- Most Java services use the package root `com.citynow.quao` and Gradle project names `QuaO`/`Quapp`.
  **"QuaO" and "Quapp" refer to the same product** across history.

## Shared Java-service conventions (apply to `functions-backend` + `ai-mcp`)
- **Strict layering**: Controller(DTO) → Service(domain Model) → Repository(Model) →
  RepositoryImpl(Entity↔Model via MapStruct) → JPA(Entity). **JPA entities never leave the
  repository layer.**
- Interfaces in `service/` / `repository/`; implementations in `*/impl/` with an `Impl` suffix.
- **Naming**: entities `<Name>Entity`; DTOs `<Action>Request` / `<Action>Response`; repos
  `<Entity>Repository` → `<Entity>RepositoryImpl` → `Jpa<Entity>Repository`; constants in `constants/`.
- **API versioning** via `controller/v1/` packages.
- Build/run with the Gradle **wrapper** (`./gradlew …`), never a system Gradle.

## Development workflow
1. Open the workspace via `Quapp.code-workspace` so both JDKs are wired up.
2. Work **inside one repo at a time** — each has its own branch/history (see `git-workflow.md`).
3. For a feature touching multiple tiers, change them in dependency order and **keep the HTTP/DTO
   contract in sync on both sides** — no codegen will do it for you (see "No generated client" below).
4. Frontend uses **`yarn`** (not npm); `postinstall`/`prepare` run `max setup` + Husky.
5. JupyterLab ext: after any TS change run `jlpm build` (or `jlpm watch`); re-run
   `jupyter labextension develop . --overwrite` after reinstalling the Python package.

## Environment / secrets (general)
- Java services are profile-driven; repo-specific variables are documented in each repo's rules file.
- **Never commit real secrets.** `.env` files exist in some repos — treat them as local-only.
- Backend secrets come from AWS Secrets Manager; migration/ai-mcp config is env-var driven.

## Cross-cutting pitfalls
- **Two "QuaO" databases.** `quapp-migration` ↔ QuaO platform DB; `quapp-ai-mcp-migration` ↔ AI-MCP DB.
  Don't add a platform changeset to the ai-mcp migration repo or vice versa (see `../docs/rules/migration.md`).
- **No generated cross-repo client.** A backend/MCP endpoint or DTO change won't propagate to the
  frontend/JupyterLab ext automatically — update the consumer by hand. *(Verified: no generated/shared
  API client is checked in. SpringDoc is present in the Java services, but no generated OpenAPI client
  exists. ai-mcp's `dto/codegen/` + `service/codegen/` are the hand-written quantum code-generation
  feature, not a generated HTTP client; `build/generated/` is only Lombok/MapStruct output.)*
- **Version drift in docs.** Verify versions in `build.gradle` / `package.json` before trusting prose.
  Example: ai-mcp's repo `CLAUDE.md` says Spring Boot 3.4.0 but `build.gradle` pins **3.4.5** — trust
  the build file.
- **Empty/placeholder READMEs**: `quapp-functions-backend`, `quapp-functions-frontend`,
  `quapp-migration`, `quapp-ai-mcp-migration` have minimal/empty READMEs — rely on the code and these
  rules.
- **JupyterLab ext `CLAUDE.md`/`GEMINI.md` are symlinks to `AGENTS.md`** — edit `AGENTS.md`
  (see `../docs/rules/jupyterlab-ai-assistant-ext.md`).

## General editing rules
1. **Do not modify source unless asked.** When asked, change only the relevant repo; keep edits scoped.
2. Follow each repo's existing conventions and match surrounding code style — don't introduce new
   patterns or new build tools.
3. Keep cross-tier contracts in sync (frontend ↔ backend ↔ ai-mcp) when you touch a DTO/route.
4. Don't weaken auth (JWT/OAuth2, any MCP authorization) or rate limiting; don't commit secrets.
5. For schema changes, add a Liquibase changeset in the **correct** migration repo — never hand-edit
   the DB or rely on `ddl-auto` (it's `validate`).
6. Run the repo's lint/tests before declaring done; report real results (see `testing.md`).
7. When something is genuinely unclear, mark it **"Unknown / needs confirmation"** rather than
   inventing behavior.

## Navigation — important file paths
- Backend entry: `functions/quapp-functions-backend/src/main/java/com/citynow/quao/QuaOApplication.java`
- Backend config: `functions/quapp-functions-backend/src/main/resources/application*.yml`
- Frontend routes/config: `functions/quapp-functions-frontend/config/{config.ts,routes.ts}`
- Frontend HTTP clients: `functions/quapp-functions-frontend/src/services/`
- ai-mcp entry: `ai/quapp-ai-mcp/src/main/java/com/citynow/quao/QuappApplication.java`
- ai-mcp MCP handlers: `ai/quapp-ai-mcp/src/main/java/com/citynow/quao/handler/`
- ai-mcp providers: `ai/quapp-ai-mcp/src/main/java/com/citynow/quao/component/`
- JupyterLab ext rules: `ai/quapp-jupyterlab-ai-assistant-ext/AGENTS.md` (CLAUDE.md is a symlink)
- JupyterLab MCP bridge: `ai/quapp-jupyterlab-ai-assistant-ext/quapp_jupyterlab_ai_assistant/mcp_http_client.py`
- Multi-schema migration: `migration/quapp-ai-mcp-migration/src/main/java/.../configuration/MultiSchemaLiquibaseConfig.java`

## Code navigation — GitNexus first
All 6 repos have a GitNexus knowledge-graph index (per-repo `.gitnexus/`). For "where does X live",
"what calls this", "what breaks if I change it", prefer the graph tools over blind grep — see
[gitnexus.md](../docs/rules/gitnexus.md) for the tool-per-phase table, freshness rules, and the cross-repo caveat
(single-repo graphs can't see frontend↔backend↔ai-mcp contracts — that sync check stays manual).

## Recommended first files to read for a new task
- **Backend/platform**: `functions-backend.md` → `QuaOApplication.java` → relevant `controller/<domain>/`
  → matching `service/`, `dto/<domain>/`, `application-<concern>.yml`.
- **Frontend/UI**: `config/routes.ts` → the feature's `src/dataSources/<Feature>/` and `src/pages/` →
  `src/services/` → `config/config.ts` for env globals.
- **AI / code generation**: `ai/quapp-ai-mcp/CLAUDE.md` → `handler/McpProtocolHandler.java` &
  `GenerateMethodHandler.java` → `component/AIProvider.java` (+ impls) → `controller/`.
- **JupyterLab IDE assistant**: `ai/quapp-jupyterlab-ai-assistant-ext/AGENTS.md` → `src/index.ts` →
  `mcp_http_client.py` + `handlers/` / `routes`.
- **Database/schema work**: the relevant `migration/*/src/main/resources/migration/` changelogs (+ that
  repo's CLAUDE.md), and `MultiSchemaLiquibaseConfig.java` for the AI-MCP tenant model.
