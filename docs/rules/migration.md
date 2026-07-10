# Rules — Database migrations (`migration/quapp-migration` + `migration/quapp-ai-mcp-migration`)

Both repos are Liquibase **batch jobs** that run as Kubernetes Jobs **before** their paired service
deploys, then exit. They are not web servers.

## ⚠️ Two separate databases — keep changesets in the right repo
| Migration repo | Target DB | Paired service |
|----------------|-----------|----------------|
| `quapp-migration` | **QuaO platform DB** (changelog tables `QUAO_CHANGELOG` / `QUAO_CHANGELOG_LOCK`, `DEFAULT_SCHEMA`) | `functions-backend` |
| `quapp-ai-mcp-migration` | **AI-MCP DB** (multi-schema / multi-tenant) | `ai-mcp` |

Never add a platform changeset to the ai-mcp migration repo or vice versa.

## `migration/quapp-migration` — QuaO platform DB
- **Stack**: Spring Boot 3.0.5, **Java 17**, Gradle, Liquibase, PostgreSQL.
- **Entry**: `QuaoMigrationApplication.java`.
- **Changelogs**: `src/main/resources/migration/` (`changelog-master*.xml`, `release-0.0.1/`).
- **Test**: `MigrationSchemaTest` (Testcontainers).

## `migration/quapp-ai-mcp-migration` — AI-MCP DB (multi-schema)
- **Responsibility**: applies migrations to the default schema **plus every schema prefixed `ws_`**
  (one `SpringLiquibase` instance per schema — tenant isolation).
- **Stack**: Spring Boot 3.0.5, **Java 21**, Gradle, Liquibase, PostgreSQL.
- **Entry**: `QuappMigrationMcpApplication.java`. Key classes:
  `configuration/MultiSchemaLiquibaseConfig.java`, `configuration/DatabaseInitializer.java`.
  (See the repo's own `migration/quapp-ai-mcp-migration/CLAUDE.md`.)
- **Config (env via K8s ConfigMap)**: `DATABASE_URL`, `DATABASE_USERNAME/PASSWORD`, `DEFAULT_SCHEMA`,
  `CHANGE_LOG_LOCATION`, `ENV`.

## Migration file conventions
- Liquibase **formatted SQL**, named `VYYYYMMDDHHMI__description.sql`.
- Env-split changesets: `release-X.X.X/{changeset,dev,prd,rollback}/`.

## Build / deploy
```bash
./gradlew clean build    # full build with tests
./gradlew test           # tests only
```
- `quapp-migration`: deploy via `k8s/`, `Dockerfile`.
- `quapp-ai-mcp-migration`: deploy via `k8s/{cts,ctc}/<env>/{app.yaml,cm.yaml}`, `Dockerfile`.

## Pitfalls / rules
- Match the repo's JDK (quapp-migration = **17**, ai-mcp-migration = **21**).
- For any schema change, add a **new Liquibase changeset** here — never hand-edit the DB and never rely
  on `ddl-auto` in the services (it's `validate`).
- Migrations run before the service deploys; a broken changeset blocks the deploy.
