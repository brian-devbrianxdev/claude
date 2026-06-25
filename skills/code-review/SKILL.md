---
name: code-review
description: Review code for problems across whatever lens the change needs — correctness/null-safety/exceptions, project coding-standards compliance, concurrency/thread-safety, performance smells, REST API contracts, and macro architecture/layering — plus project-rules and cross-repo contract sync on the working diff. Use when the user says "review my code", "review the diff", "pre-MR review", "check this PR", "is this thread-safe", "review the API", or "check the architecture". Read-only; for security use security-review.
---

# Code Review

One review capability, scoped to what the change needs. Default target is the **working diff**;
review a package or branch when asked. Read-only — cite findings at `file:line`, rank
Blocker / Major / Minor / Nit, and distinguish a real rule violation from a style preference.

## Pick the lens(es) — load only what applies
| Scope | When | Depth reference |
|-------|------|-----------------|
| **correctness** (default) | any code change | [correctness.md](correctness.md) — null safety, exceptions, edge cases |
| **standards** | Java changed | [standards.md](standards.md) — coding-standards gate compliance (see `../../rules/java.md`) |
| **project-rules** | reviewing a diff before commit/MR | [project-rules.md](project-rules.md) — layering, cross-repo contract sync, migration-repo placement, JDK, secrets (was the `quapp-review` skill) |
| **concurrency** | threads / async / shared state touched | [concurrency.md](concurrency.md) |
| **performance** | hot paths, collections, streams, boxing | [performance.md](performance.md) |
| **api-contract** | public REST endpoint added/changed | [api-contract.md](api-contract.md) |
| **architecture** | package/module/dependency-direction questions | [architecture.md](architecture.md) |

For **security** (OWASP, injection, secrets, auth) use the separate [security-review](../security-review/SKILL.md) skill.

## Default flow (review a diff before MR)
1. **Detect scope** — `git status` / `git diff` (or `git diff <base>...`) in the changed repo(s);
   identify which repo(s) and what changed. Read [`../../profiles/quapp/profile.md`](../../profiles/quapp/profile.md)
   and the touched repo's [`../../rules/`](../../rules/) files.
2. **Run the relevant lenses** from the table — always correctness + project-rules on a diff; add
   concurrency/performance/api-contract/architecture only if the change touches them.
3. **Cross-tier contract sync** — no codegen exists; a backend/ai-mcp DTO or route change with no
   matching frontend/ext consumer edit is a finding (see project-rules.md).
4. **Rank findings** at `file:line` with a concrete fix; mark uncertain ones *Unknown / needs confirmation*.

## Output
```
## Review — <repo>(s), <N> files, scopes: <correctness, project-rules, …>
Gate: PASS | CHANGES REQUESTED
| Severity | file:line | Issue | Lens | Fix |
```

## Rules
- Read-only; never invent issues — cite a rule/lens + `file:line`.
- One repo at a time; match its JDK (`../../rules/workspace.md`). Two DBs (`migration.md`).
- Defer security depth to [security-review](../security-review/SKILL.md); deep standards policy lives
  in [`../../rules/java.md`](../../rules/java.md).
