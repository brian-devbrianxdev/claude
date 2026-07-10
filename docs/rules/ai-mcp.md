# Rules — `ai/quapp-ai-mcp` (MCP AI code-generation service)

Shared Java conventions (strict layering, naming, Gradle wrapper, `controller/v1/`) live in
`workspace.md` and apply here. The repo's own `ai/quapp-ai-mcp/CLAUDE.md` has the fullest layering
rules — read it for deep work.

## Responsibility
AI service that generates quantum algorithm code (Qiskit / Cirq / PennyLane) via the **Model Context
Protocol (MCP)**, fronting multiple AI providers. Adds sessions, quotas, analytics/cost analysis, code
validation/security scanning, and streaming generation.

## Stack
- Spring Boot **3.4.5** (per `build.gradle`; the repo's CLAUDE.md text says 3.4.0 — **trust
  build.gradle**), **Java 21**, Gradle. Gradle root project name = `quapp-ai-mcp`.
- Lombok + MapStruct. PostgreSQL + Spring Data JPA. OAuth2 resource server (JWT).
- Caffeine **or** Redis cache. Resilience4j rate limiting.

## Entry point
`src/main/java/com/citynow/quao/QuappApplication.java`. Default `SERVER_PORT=8080`, context-path `/`.
API base used by clients: **`/api/v1`**.

## Key components
- **AI providers**: `component/AIProvider.java` (sealed) + `component/impl/` (Claude / OpenAI / Azure /
  Local).
- **MCP handlers**: `handler/McpProtocolHandler.java`, `SessionMethodHandler`, `GenerateMethodHandler`,
  `ProviderMethodHandler`.
- **Controllers**: `controller/` incl. `CodeGenerationStreamingController`, `*AnalyticsController`,
  `QuotaController`, plus versioned `controller/v1/`.
- **Code-generation feature DTOs/services**: `dto/codegen/`, `service/codegen/` (hand-written records;
  **not** a generated client).
- **3-layer repository pattern**: business `repository/` → `repository/impl/` (MapStruct mapper + JPA
  delegate) → `repository/jpa/`. **Never expose JPA entities outside the repository layer.**

## Build / test
```bash
./gradlew build
./gradlew bootRun
./gradlew test            # unit tests (excludes repo/controller tests)
./gradlew integrationTest # Testcontainers (needs Docker)
```
ai-mcp separates JPA/controller tests into `integrationTest`; plain `test` excludes them. See
`testing.md`.

## Config / environment
- Config is **env-var driven through `application.yml`**. *(The README references `cp .env.example .env`,
  but no `.env`/`.env.example` is present in the snapshot — Unknown / needs confirmation. Use the
  `application.yml` placeholders as the authoritative variable list.)*
- Notable vars: `DATABASE_URL/USERNAME/PASSWORD`, `CACHE_TYPE` (`caffeine`|`redis`) + `REDIS_ENABLED`,
  `JWT_ISSUER_URI` / `JWT_JWK_SET_URI`, `HIBERNATE_DDL_AUTO` (default `validate`), `SWAGGER_ENABLED`,
  provider keys (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `AZURE_OPENAI_*`, `OLLAMA_*`).
- Swagger at `/swagger-ui.html` when `SWAGGER_ENABLED=true`.

## Security
- OAuth2 **JWT resource server**. Keep `JWT_ISSUER_URI`/`JWK` consistent with the other services.
- Code security scanner: interface `component/security/scanner/SecurityScanner.java`, impl
  `component/security/scanner/impl/CodeSecurityScanner.java`.
- *(The README/CLAUDE.md and `docs/progress.md` mention a `@RequiresMcpPermission` MCP ACL annotation,
  but it was **not found in current source** — documented but unverified, Unknown / needs confirmation.)*

## Deploy
`docker/`, `docker-compose.yml`, `k8s/`. Host: `mcp-<env>.quapp.cloud`. DB migrations are run separately
by `quapp-ai-mcp-migration` (multi-schema, see `migration.md`) **before** this service deploys.

## Pitfalls
- Match **Java 21** when building from a terminal.
- Never return JPA entities from services/controllers — go through MapStruct mappers.
- Consumers (frontend, JupyterLab ext) call `/api/v1` — endpoint/DTO changes need matching client edits.
