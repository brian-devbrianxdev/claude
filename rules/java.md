# Rules — Java coding standards (write-time gate)

**Authority for how Java is written/changed in this workspace.** This replaces the former
`java-coding-standards` *skill* — the policy lives here (a rule), the *teaching* lives in skills
(`code-craft`, `spring-stack-patterns`, `test-authoring`), enforcement lives in `code-review` /
`security-review`, and the deterministic reminders live in `hooks/quapp-guard.sh` +
`settings.json`. Apply this whenever you write or modify `.java` code.

## Phase 0 — Branch prerequisite
Before modifying any Java, confirm you are on a permitted working branch per
[`git-workflow.md`](git-workflow.md). Branch creation and base selection are owned by
`/start-task` and are not repeated here.

## Phase 1 — Design (pick what applies)
| Change involves… | Read |
|------------------|------|
| Any new/edited class, method, naming, responsibilities, patterns | [code-craft](../skills/code-craft/SKILL.md) |
| Spring components, JPA entities/queries, logging | [spring-stack-patterns](../skills/spring-stack-patterns/SKILL.md) |
| Threads/async, hot paths, public REST endpoints, package structure | the matching lens of [code-review](../skills/code-review/SKILL.md) |
| Package/module boundaries, a new abstraction, cross-domain dependency, a new module/service | [code-review/architecture.md](../skills/code-review/architecture.md) — discovery-first review process + concrete anti-pattern/abstraction criteria, and [java-architecture-enforcement.md](../docs/rules/java-architecture-enforcement.md) for the ArchUnit-vs-Modulith decision framework and the rules that make layering checkable |
| A schema change touching an existing (non-empty) table, or anything in a migration repo | [migration.md](../docs/rules/migration.md) — mandatory staged pattern for adding `NOT NULL`, precondition guidance |

Match the naming/structure/idioms of surrounding code first; reach for a pattern only when it earns
its place (YAGNI). Do not propose Spring Modulith, Hexagonal/Clean Architecture, or a
package-by-feature rewrite without a concrete driver — see the decision framework in
`java-architecture-enforcement.md`.

## Phase 2 — While writing
- **No redundant comments.** Write self-explanatory code (intention-revealing names, small methods).
  Do not add comments that restate what the code does. A comment is allowed only when it explains
  something that cannot be made clear through naming or decomposition:
  - a non-obvious business or concurrency invariant
  - a deliberate workaround with a reference (ticket, vendor bug, spec clause)
  - a security or compatibility constraint that would surprise a future reader
  - a regex, SQL, or algorithm whose intent is genuinely non-obvious
  Required Javadoc on public APIs and license headers are always allowed.
  Machine-read annotations (`@Override`, etc.) are not comments.
  (Frontend/JupyterLab TS: same rule — no restating-what-the-code-does comments.)
- Keep methods small; respect single responsibility and dependency direction (code-craft).
- Strict layering: **JPA entities never leave the repository layer** (`workspace.md`).
- Structured, MDC-aware logging (spring-stack-patterns, logging section).

## Phase 3 — Tests (risk-based, mandatory)
Every change requires validation. The required level depends on what changed
([test-authoring](../skills/test-authoring/SKILL.md)):

| Change type | Required tests |
|-------------|---------------|
| Domain or calculation logic | Unit tests |
| Repository, query, transaction, integration boundary | Integration tests |
| REST or event contract | Controller / contract integration tests |
| Bug fix | Regression test at the lowest reliable layer that fails before the fix |
| Config or build-only change | Targeted build or smoke verification |

Not every change needs both unit and integration tests. A DTO rename or log
enrichment does not justify a new integration test; a transaction boundary
change does not get away with only a unit test.

## Phase 4 — Self-review gate (before commit)
Run as a checklist on the diff:
1. [code-review](../skills/code-review/SKILL.md) — correctness + project-rules; add concurrency /
   performance / api-contract / architecture lenses if the change touches them.
2. [security-review](../skills/security-review/SKILL.md) — for input handling / queries / auth.
3. For `functions-backend`/`ai-mcp`: don't treat a green CI pipeline as sufficient — see
   [quality-gates.md](../docs/rules/quality-gates.md). Both repos' Sonar/Trivy quality gates are
   currently non-blocking or dead-ruled in CI; Phases 3–4 here are the actual safety net, not a
   formality on top of one.

Do not commit until Phases 3–4 pass; then hand commit wording to
[commit](../skills/commit/SKILL.md). (`/ship-task` automates review→test→commit→MR.)

## Anti-patterns
❌ Comments explaining code · ❌ committing without the Phase 3/4 gate · ❌ a pattern the surrounding
code doesn't use · ❌ returning JPA entities from services/controllers.
