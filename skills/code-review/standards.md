---
name: code-review
description: Review changed Java code and verify it complies with the rules/java.md gate — no comments except public Javadoc, self-explanatory naming, tests present, branch naming, and the relevant clean-code/SOLID/pattern rules. Produces a pass/fail checklist with violations at file:line. Use when user says "review my java changes", "check this follows coding standards", "does this pass the gate", or before committing/opening an MR.
---

# Java Standards Review Skill

Audit the **changed** Java code (the diff) against the
[rules/java.md](../../rules/java.md) gate and report compliance — what passes,
what violates a rule, and exactly where. This is a **read-only verifier**: it reports, it does not fix.

## When to Use
- User says "review my java changes" / "does this follow the coding standards" / "does this pass the gate"
- Before committing, or before opening a GitLab MR
- As the self-review step (Phase 4) inside [/start-task](../../commands/start-task.md) / [/ship-task](../../commands/ship-task.md)

## Scope
Review **only the diff**, not the whole codebase. Get the changed Java files:
```bash
git diff --name-only --diff-filter=ACMR | grep '\.java$'      # unstaged + staged vs working
git diff --staged --name-only --diff-filter=ACMR | grep '\.java$'
# or against the base branch for an MR:
git diff --name-only origin/<base>...HEAD | grep '\.java$'
```
Then read the actual hunks (`git diff <files>`), not the full files, except where context is needed.

## Checklist — map each rule to the diff

### A. Hard rules (from rules/java.md) — any hit = ❌ FAIL
| # | Rule | How to detect in the diff |
|---|------|---------------------------|
| A1 | **No comments** except public Javadoc, license headers, annotations | Flag added lines matching `//` or `/* */` that are NOT public-API Javadoc (`/** */` on public class/method), license, or annotations |
| A2 | **Tests present** | A code change with no added/updated test under `src/test/...`; for a bug fix, no **regression test** |
| A3 | **Branch naming** | Current branch matches `^(feature|bugfix|hotfix|refactor)/khactuong\.ngohoang/.+`; not committing on base |
| A4 | **No debug leftovers** | Added `System.out.println`, `printStackTrace()`, commented-out code, `TODO`/`FIXME` left in |

### B. Quality rules (route to the owning skill) — report as 🟡 WARN
| Area in the diff | Verify against |
|------------------|----------------|
| New/edited class or method | [clean-code](../code-craft/clean-code.md) (small methods, intention-revealing names, DRY/KISS/YAGNI), [solid-principles](../code-craft/solid.md) |
| Spring controller/service/config | [spring-boot-patterns](../spring-stack-patterns/spring-boot.md) |
| Entity / repository / query | [jpa-patterns](../spring-stack-patterns/jpa.md) (N+1, lazy loading, tx boundaries) |
| Threads / async / shared state | [code-review](../code-review/SKILL.md) |
| Public REST endpoint | [code-review](../code-review/SKILL.md) |
| Logging added/changed | [logging-patterns](../spring-stack-patterns/logging.md) (SLF4J, MDC, no `printf`) |
| Hot path / loops / collections | [code-review](../code-review/SKILL.md) |
| Correctness, null safety, exceptions | [code-review](../code-review/SKILL.md) |
| Input handling / queries / auth | [security-review](../security-review/SKILL.md) |

Only apply the rows that the diff actually touches — don't review areas that didn't change.

## Output Contract
Report a verdict, then a table:
```
## Standards review: <N> changed .java files   →   ❌ FAIL (2 hard, 3 warnings)

Hard rules
| Rule | Status | Location / Evidence                                  |
|------|--------|------------------------------------------------------|
| A1 no comments | ❌ | PluginManager.java:42 — inline `// loop plugins`      |
| A2 tests       | ❌ | OAuth2Service.java changed, no test in src/test       |
| A3 branch      | ✅ | feature/khactuong.ngohoang/PROJ-123-oauth2-login      |
| A4 leftovers   | ✅ | none                                                  |

Quality (warnings)
| Area | Skill | Note                                              |
|------|-------|---------------------------------------------------|
| service | clean-code | scan() is 60 lines — extract validation       |
| query   | jpa-patterns | findAll in loop → N+1 (UserRepo.java:88)     |
```
End with a short **verdict line**: `✅ PASS` (no hard fails) or `❌ FAIL — fix hard rules before commit`.

## Anti-patterns
❌ Reviewing the whole codebase instead of the diff.
❌ Auto-fixing — this skill only reports (use [simplify](../code-craft/clean-code.md) or apply manually to fix).
❌ Flagging public-API Javadoc, license headers, or annotations as comment violations (those are allowed).
❌ Warning about areas the diff didn't touch.
✅ Diff-scoped, hard-rules-first verdict, every finding with `file:line`.

## Example
```
> "Review my java changes — do they pass the gate?"
1. git diff --staged → 3 .java files
2. scan added lines for A1–A4 hard rules
3. route changed areas to quality skills (B)
4. report table + verdict: ❌ FAIL (1 comment, missing test)
```

## References
- [rules/java.md](../../rules/java.md) (the rules being enforced)
- [code-review](../code-review/SKILL.md) · [commit](../commit/SKILL.md)
