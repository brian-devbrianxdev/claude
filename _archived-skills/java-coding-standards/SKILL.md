---
name: java-coding-standards
description: Apply the project's existing coding skills whenever Java code is written or changed. Acts as the gate that pulls in code-craft, spring-stack-patterns, concurrency-review, test-quality, java-code-review, and security-audit at the right moments. Use BEFORE/DURING/AFTER implementing or modifying any Java code, and automatically inside the jira-feature and jira-bugfix workflows.
---

# Java Coding Standards Gate

This is an **orchestrator** skill. It does not redefine standards — it routes you to the
project's existing skills so every Java change follows the same conventions. Treat it as a
required gate: any time you write or modify `.java` code, walk these phases.

## When to Use
- Before writing new Java code or modifying existing Java code
- Inside the [jira-feature](../jira-feature/SKILL.md) / [jira-bugfix](../jira-bugfix/SKILL.md) implement step (invoked automatically)
- Whenever the user says "implement", "change", "refactor", or "add" Java code

## How to Use Another Skill
Load a referenced skill before acting on its phase, e.g. `view .claude/skills/code-craft/SKILL.md`
(or invoke it via its slash command). Apply only the skills relevant to the change — don't run all
ten on a one-line edit. Use the routing table to decide which apply.

---

## Phase 0 — Branch setup (always first)
Before writing any code, verify you are branching from a clean, up-to-date base:
1. `git branch --show-current` — check the current branch.
2. If **not** on the original/base branch (e.g. `main` / `develop`):
   `git checkout <base>` then `git pull` to bring it to the current state.
3. Create the working branch from the updated base, named:
   ```
   <type>/khactuong.ngohoang/<short-description>
   ```
   where `<type>` is `feature`, `bugfix`, `hotfix`, `refactor`, etc.
   Example: `feature/khactuong.ngohoang/PROJ-123-oauth2-login`
4. Never implement directly on the base branch.

## Phase 1 — Before writing (design)
Pick the skills that match what you're building:

| If the change involves... | Apply skill |
|---------------------------|-------------|
| Any new/edited class or method | [code-craft](../code-craft/SKILL.md) — clean-code + SOLID |
| An extensible / pluggable component | [code-craft](../code-craft/SKILL.md) — design patterns |
| Spring controllers, services, config | [spring-stack-patterns](../spring-stack-patterns/SKILL.md) — Spring Boot |
| Entities, repositories, queries | [spring-stack-patterns](../spring-stack-patterns/SKILL.md) — JPA |
| Threads, async, shared state | [concurrency-review](../concurrency-review/SKILL.md) |
| Public REST endpoints | [api-contract-review](../api-contract-review/SKILL.md) |

Match naming, structure, and idioms of the surrounding code first; reach for patterns only when they earn their place (avoid over-engineering — see clean-code's YAGNI).

## Phase 2 — While writing
- **Do NOT add comments to code.** Write self-explanatory code — intention-revealing names,
  small methods, clear structure — instead of explanatory comments. No inline comments, no
  block comments, no end-of-line comments. Allowed exceptions only: required Javadoc on public
  APIs, license headers, and machine-read annotations (`@Override`, `@SuppressWarnings`, etc.).
- Keep methods small, names intention-revealing (code-craft).
- Respect single responsibility and dependency direction (code-craft).
- Add structured, MDC-aware logging at the right points: [spring-stack-patterns](../spring-stack-patterns/SKILL.md) (logging).
- Watch for obvious performance smells (boxing, regex in loops, N+1): [performance-smell-detection](../performance-smell-detection/SKILL.md) and [spring-stack-patterns](../spring-stack-patterns/SKILL.md) — JPA.

## Phase 3 — Tests (mandatory)
Every code change ships with tests. Apply [test-quality](../test-quality/SKILL.md):
- New feature → unit + integration tests covering the acceptance criteria.
- Bug fix → a **regression test** that fails before the fix and passes after.

## Phase 4 — Self-review gate (before commit)
Run these as a checklist on the diff:
1. [java-code-review](../java-code-review/SKILL.md) — null safety, exception handling, correctness.
2. [security-audit](../security-audit/SKILL.md) — injection, validation, secrets (especially for input handling / queries / auth).
3. [concurrency-review](../concurrency-review/SKILL.md) — only if shared/async state was touched.

Do not commit until Phase 3 and Phase 4 pass. Then hand commit wording to [git-commit](../git-commit/SKILL.md).

---

## Quick Routing Cheat Sheet
```
new class/method ............ code-craft
spring component ............ spring-stack-patterns
entity / query .............. spring-stack-patterns (JPA)
async / threads ............. concurrency-review
public REST endpoint ........ api-contract-review (+ security-audit)
any logging ................. spring-stack-patterns (logging)
ALWAYS before commit ........ test-quality → java-code-review → security-audit
```

## Integration with Jira Workflows
The [jira-feature](../jira-feature/SKILL.md) and [jira-bugfix](../jira-bugfix/SKILL.md) skills
call this gate at their "implement" step, so the same standards apply automatically once a ticket
is In Progress — no separate request needed.

## Anti-patterns
❌ Adding comments to explain code — make the code self-explanatory instead (see Phase 2).
❌ Writing Java and committing without running the Phase 3/4 gate.
❌ Applying every skill to a trivial edit (wastes tokens — use the routing table).
❌ Introducing a design pattern the surrounding code doesn't use, just because.
✅ Match existing code, apply only the relevant skills, always test + review before commit.

## References
- All referenced skills live in [.claude/skills/](../) — see the [index](../README.md).
