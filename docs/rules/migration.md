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
  on `ddl-auto` in the services (it's `validate`, except `ai-mcp`'s `application-dev.yml` which
  hardcodes `update` — see "ddl-auto drift risk" below, don't assume `validate` holds in that profile).
- Migrations run before the service deploys; a broken changeset blocks the deploy.

## Adding a NOT NULL column/constraint to an existing (non-empty) table — mandatory staged pattern

Applies to any Liquibase/Flyway-managed schema, not just these two repos. Never collapse this into
one changeset:
1. **Add the column nullable** (or add the constraint as `NOT VALID`/deferred), separate changeset.
2. **Backfill** existing rows in a separate changeset (`UPDATE ... SET col = <derived-or-default>
   WHERE col IS NULL`).
3. **Enforce `NOT NULL`** (or validate the constraint) only after the backfill changeset has run
   *and*, if any application code needs to write the new column first, after that code is deployed —
   document this ordering dependency explicitly in the changeset's `<comment>`, since Liquibase has
   no built-in way to block a changeset on "the paired service's new deploy has happened."
4. Only then, if a rename is also needed, do the `RENAME COLUMN` as its own final changeset.

Skipping straight to `ALTER COLUMN ... SET NOT NULL` on a table that already has rows is a
**destructive-risk changeset** — it will fail outright if any existing row is null, or silently
reject writes from an out-of-date service instance that hasn't been updated to populate the new
column yet. *(This exact staging was already followed correctly in `quapp-ai-mcp-migration`'s
`tenant_id`→`workspace_id` migration — treat it as the reference example.)*

## Preconditions — use them for environment/state-sensitive changesets, not just comments

When a changeset must only run in a specific schema, environment, or after a specific prior state,
prefer a Liquibase `<preConditions>` block (`sqlCheck`, `columnExists`, `tableExists`, `rowCount`,
etc.) over a comment-only warning — a precondition is tool-enforced; a comment narrating "run this
only after X" can be missed by a future author. *(`quapp-migration` already does this correctly for
a handful of platform-schema-only seed changesets, guarding with
`<preConditions onFail="MARK_RAN">`; `quapp-ai-mcp-migration` currently has none, relying entirely on
comments for its staged multi-tenant rollout — a gap worth closing there specifically.)*

## Multi-schema/multi-tenant migration runners often have no partial-failure isolation

If a migration job iterates multiple schemas/tenants and applies changesets to each in a loop, check
whether a single try/catch wraps the *entire* loop rather than per-schema: if so, one bad schema
aborts the whole run, leaving later schemas unmigrated with no compensating rollback of the ones
already done. Recovery is usually "fix the problem and re-run" (safe for individual changeset
idempotency, since a properly-tracked changelog table skips already-applied changesets), but any
manually-staged multi-step rollout (see the NOT-NULL pattern above) must be **manually re-verified**
after a partial-failure re-run — the tool has no awareness of a staging sequence, only of per-changeset
idempotency. *(Both migration repos here share exactly this shape in `MultiSchemaLiquibaseConfig` —
know this before assuming a re-run "just resumes safely" beyond single-changeset idempotency.)*

## `ddl-auto`/`hbm2ddl.auto` drift risk across environment profiles

If a migration tool is the schema authority, every environment profile of the paired service should
have `ddl-auto`/`hbm2ddl.auto` set to `validate` (or unset) — never `update`/`create`. Check every
profile, not just the ones you'd normally deploy to; a dev-only profile hardcoding a more permissive
value is a real schema-authority conflict if that profile is ever pointed at a shared/long-lived
database, and it's easy to miss because production profiles look correct. *(`ai-mcp`'s
`application-dev.yml` currently hardcodes `update` — a repo source-code fix, not a `.claude/` rule
fix; flag it rather than change it silently if you encounter it.)*

## Rollback coverage

New changesets should include a `<rollback>` block unless the change is a pure, already-idempotent
seed/data-correction script where a rollback wouldn't be meaningful — state clearly in the changeset
comment why one was omitted rather than silently skipping it. Note that having rollback SQL present
is not the same as it being verified: unless a test actually executes `liquibase rollback`, rollback
correctness is unverified regardless of how complete the coverage looks.
