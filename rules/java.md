# Rules — Java coding standards (write-time gate)

**Authority for how Java is written/changed in this workspace.** This replaces the former
`java-coding-standards` *skill* — the policy lives here (a rule), the *teaching* lives in skills
(`code-craft`, `spring-stack-patterns`, `test-authoring`), enforcement lives in `code-review` /
`security-review`, and the deterministic reminders live in `hooks/quapp-guard.sh` +
`settings.json`. Apply this whenever you write or modify `.java` code.

## Phase 0 — Branch setup (always first)
Per [`../profiles/quapp/profile.md`](../profiles/quapp/profile.md) and `git-workflow.md`:
1. `git branch --show-current`.
2. If not on the intended base, `git checkout <base>` + `git pull` (base = `staging` or latest
   `production`, **confirmed per ticket — never default to `develop`**).
3. Branch: `feature|bugfix/khactuong.ngohoang/PQF-<key>-<short-desc>`.
4. Never implement on a base/env branch. (`/start-task` automates this.)

## Phase 1 — Design (pick what applies)
| Change involves… | Read |
|------------------|------|
| Any new/edited class, method, naming, responsibilities, patterns | [code-craft](../skills/code-craft/SKILL.md) |
| Spring components, JPA entities/queries, logging | [spring-stack-patterns](../skills/spring-stack-patterns/SKILL.md) |
| Threads/async, hot paths, public REST endpoints, package structure | the matching lens of [code-review](../skills/code-review/SKILL.md) |

Match the naming/structure/idioms of surrounding code first; reach for a pattern only when it earns
its place (YAGNI).

## Phase 2 — While writing
- **No comments.** Write self-explanatory code (intention-revealing names, small methods). The only
  allowed exceptions: required Javadoc on public APIs, license headers, machine-read annotations
  (`@Override`, etc.). (Frontend/JupyterLab TS additionally forbid new tests/comments — see those rules.)
- Keep methods small; respect single responsibility and dependency direction (code-craft).
- Strict layering: **JPA entities never leave the repository layer** (`workspace.md`).
- Structured, MDC-aware logging (spring-stack-patterns, logging section).

## Phase 3 — Tests (mandatory)
Every change ships with tests ([test-authoring](../skills/test-authoring/SKILL.md)):
- Feature → unit + integration covering the acceptance criteria.
- Bug fix → a **regression test** that fails before the fix and passes after.

## Phase 4 — Self-review gate (before commit)
Run as a checklist on the diff:
1. [code-review](../skills/code-review/SKILL.md) — correctness + project-rules; add concurrency /
   performance / api-contract / architecture lenses if the change touches them.
2. [security-review](../skills/security-review/SKILL.md) — for input handling / queries / auth.

Do not commit until Phases 3–4 pass; then hand commit wording to
[commit](../skills/commit/SKILL.md). (`/ship-task` automates review→test→commit→MR.)

## Anti-patterns
❌ Comments explaining code · ❌ committing without the Phase 3/4 gate · ❌ a pattern the surrounding
code doesn't use · ❌ returning JPA entities from services/controllers.
