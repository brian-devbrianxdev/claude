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

## Model routing ([`../../docs/rules/model-routing.md`](../../docs/rules/model-routing.md))
Routine lenses (correctness, standards, project-rules, api-contract) run **inline at sonnet-class**.
Escalate to **opus** when the review needs deep reasoning:
- the **concurrency** or **architecture** lens applies, or
- the diff spans **≥2 repos** or **>10 files**, or
- the change touches auth/JWT/rate-limit surface.

To escalate without switching the session model, run the deep lens(es) in the **`deep-reviewer`**
agent (`../../agents/deep-reviewer.md`, pinned to opus): `Agent(subagent_type: "deep-reviewer",
prompt: "<lens name(s) + lens reference path(s) + file list/diff>")`, then merge its findings into
the single ranked table. **Spawn ONE deep-reviewer carrying all deep lenses that apply — including
the security checklist when security-review is also needed on the same diff** (each extra agent
re-reads the whole diff, ~80-90k tokens); don't send the routine lenses with it.
deep-reviewer has **no GitNexus access** (restricted tools) — running `impact`/`detect_changes`
yourself first and pasting the relevant output into its prompt is **mandatory**, not optional
(`../../docs/rules/gitnexus.md` rule 7): an evaluator without graph evidence can only produce
opinions ("this looks unused"), not verifiable findings.

## Default flow (review a diff before MR)
1. **Detect scope** — `git status` / `git diff` (or `git diff <base>...`) in the changed repo(s);
   identify which repo(s) and what changed. Read [`../../profiles/quapp/profile.md`](../../profiles/quapp/profile.md)
   and the touched repo's [`../../rules/`](../../rules/) files. Size the blast radius with GitNexus
   `detect_changes` (graph impact of the working diff) + `impact` on changed public symbols, and
   `api_impact`/`shape_check` when a route changed ([`../../docs/rules/gitnexus.md`](../../docs/rules/gitnexus.md)).
2. **Run the relevant lenses** from the table — always correctness + project-rules on a diff; add
   concurrency/performance/api-contract/architecture only if the change touches them.
3. **Cross-tier contract sync** — no codegen exists; a backend/ai-mcp DTO or route change with no
   matching frontend/ext consumer edit is a finding (see project-rules.md). Check the `quapp` group's
   Contract Registry first (`../../docs/rules/gitnexus.md` — deterministic route↔consumer lookup for
   the ~95 linked endpoints); anything outside it stays a manual check, and a clean single-repo
   `impact` is never proof of cross-tier safety.
4. **Rank findings** at `file:line` with a concrete fix; mark uncertain ones *Unknown / needs confirmation*.

## Output
```
## Review — <repo>(s), <N> files, scopes: <correctness, project-rules, …>
Gate: PASS | CHANGES REQUESTED
| Severity | file:line | Issue | Lens | Fix |
```

## Rules
- Read-only; never invent issues — cite a rule/lens + `file:line`.
- **Ground structural claims in the graph** — any finding that asserts a caller/consumer/dependency
  relationship ("nothing else calls X", "this breaks Y", "Z is the only consumer") must carry
  evidence from a GitNexus query (`impact`/`context`/`trace`/`detect_changes` — or `group impact`/
  `group contracts` for cross-repo, see `../../docs/rules/gitnexus.md`) or an explicit grep + read,
  confirmed at `file:line`. Without that evidence, report it as *Unknown / needs confirmation*, not
  as a finding.
- One repo at a time; match its JDK (`../../rules/workspace.md`). Two DBs (`migration.md`).
- Defer security depth to [security-review](../security-review/SKILL.md); deep standards policy lives
  in [`../../rules/java.md`](../../rules/java.md).
