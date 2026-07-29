# Audit — Quapp Claude Code harness (pre-refactor baseline)

Evidence-based. Every claim below was verified by reading the file or running the command shown;
nothing here is inferred from the task prompt's assumptions. Where the prompt's suggested names
(`quapp-analyze`, `quapp-implement`, `quapp-review`, `quapp-release-audit`, `/quapp-start-ticket`,
`/quapp-ship-ticket`) don't match what exists on disk, that's called out explicitly — **do not
assume these names exist; they don't, see §0.**

Scope note: `.claude/` is **its own independent git repository** (`main`, tracked to `origin/main`),
separate from the 9 workspace repos and from the (non-git) `Quapp/` root folder. It is a
versioned, CI-tested product in its own right (v1.0.0, tagged 2026-07-19, closing out a prior
external review's findings — see `CHANGELOG.md`). This changes the refactor posture: the target
isn't "impose structure on chaos," it's "add a thin, additive graph layer on top of an
already-disciplined system without breaking its CI, its guard tests, or its documented contracts."

## 0. Naming reality check (prompt vs. evidence)

| Prompt's assumed name | Exists? | Actual current name | Evidence |
|---|---|---|---|
| `quapp-guard` | ✅ yes | `hooks/quapp-guard.sh` | PreToolUse hook, Bash + Edit\|Write, in `settings.json` |
| `/quapp-start-ticket` | ❌ no | `/start-task` | `commands/start-task.md`; historical name only in `_archived-skills/jira-feature` and `backups/passB-.../commands/quapp-start-ticket.md` |
| `/quapp-ship-ticket` | ❌ no | `/ship-task` | `commands/ship-task.md` |
| `quapp-analyze` | ❌ no | `task-scoping` | `skills/task-scoping/SKILL.md` |
| `quapp-implement` | ❌ no | `change-implementation` | `skills/change-implementation/SKILL.md` |
| `quapp-review` | ❌ no | `code-review` | `skills/code-review/SKILL.md` |
| `quapp-release-audit` | ❌ no | `completion-audit` | `skills/completion-audit/SKILL.md` (absorbed `jira-ticket-audit` + `quapp-release-audit`) |

`skills/README.md` §"How it got here" documents this directly: two consolidation passes (A, B)
took 29 skills → 13, then 3 more skills + 2 commands were added, landing at **16 skills, 4
commands** today. The `quapp-*`-prefixed names are Pass-B-era history, preserved only in
`.claude/backups/passB-20260625-113051/` (a local, git-ignored snapshot dir) and
`.claude/_archived-skills/` (retired, out of discovery per `skills/README.md`). **Conclusion: the
system already did most of the consolidation this task asks for.** The remaining gap is graph
formalization (§5), not de-duplication.

## 1. Component inventory

### 1.1 Instructions / rules (guardrails — read every session or on repo entry)
| Path | Type | Purpose | Active? |
|---|---|---|---|
| `Quapp/CLAUDE.md` (workspace root, **not** in `.claude`'s git repo — untracked plain file, `Quapp/` itself is not a git repo) | instruction | Repo map, cross-repo interaction diagram, skill/command index | active |
| `rules/workspace.md` | rule | Not-a-monorepo, JDK matrix, shared Java conventions, navigation | active |
| `rules/git-workflow.md` | rule | GitLab hosting, branch model, branch-base-per-fix, CI/CD table, MR format | active |
| `rules/testing.md` | rule | Per-repo test commands; FE test-writing exception | active |
| `rules/java.md` | rule | Write-time Java gate: 4 phases (design→write→test→self-review) | active, **currently dirty** (uncommitted edit, see §7) |
| `rules/java-comment-rules.md` | rule | 15-rule comment policy | active, **currently untracked** (new file, uncommitted, see §7) |
| `docs/rules/*.md` (11 files) | rule (situational) | Per-repo rules (backend, frontend, ai-mcp, both migrations, both JupyterLab exts, qapp-common, sdk-templates) + `model-routing.md` + `gitnexus.md` + `java-architecture-enforcement.md` + `quality-gates.md` | active, loaded on demand |
| `profiles/quapp/profile.md` | project identity | Tracker key, VCS host, branch model, git user — single source, read by task-scoping/change-implementation/solution-planning/commands | active |
| `docs/architecture/executor-advisor-architecture.md` | doc | Executor(sonnet)/deep-reviewer(opus)/advisor(opus, scarce) routing rationale | active |

### 1.2 Commands (4 — graph entry points already, informally)
| Path | Trigger | Orchestrates | Model | Human gate |
|---|---|---|---|---|
| `commands/start-task.md` | `/start-task PQF-<key> [bug\|feature]` | fetch/create ticket → `task-scoping` → **STOP: confirm branch base** → propose branch name → transition ticket → create branch → hand off | sonnet (frontmatter) | ✅ branch-base confirmation |
| `commands/ship-task.md` | `/ship-task [PQF-<key>]` | `code-review` (+`security-review` if applicable) → test per repo → **STOP gate** (secret-scan + review/test red) → `commit` → push+MR → transition ticket → log work | sonnet (frontmatter) | ✅ commit/push STOP gate (never bypassed) |
| `commands/review-mr.md` | `/review-mr <repo> <iid> [--post]` | `glab mr view/diff` → `code-review` lenses → compose review → **ask before posting** unless `--post` | sonnet (frontmatter) | ✅ posting confirmation; never calls `glab mr approve` |
| `commands/handoff.md` | `/handoff [focus]` | Write session summary to `~/.claude/projects/.../handoffs/` (outside all repos) | sonnet (frontmatter) | n/a (no destructive action) |

### 1.3 Skills (16 — full catalogue; see also the Explore-agent deep-read in this session's transcript)
| Skill | Category | Reads/edits code? | Self-approves? |
|---|---|---|---|
| `task-scoping` | workflow | read-only | n/a |
| `solution-planning` | workflow | writes Jira only (comment/estimate/sub-tasks), no code | n/a |
| `change-implementation` | workflow | **edits code**, gated by one human approval on the *plan* (not on the resulting diff) | no — hands off to `/ship-task` for review |
| `completion-audit` (+`single-ticket.md`) | workflow | read-only (only side effect: syncs repos to `develop` for evidence gathering, restores original branch/stash after) | n/a |
| `bug-investigation` | workflow | read-only diagnosis | n/a — explicit "applying a fix is /ship-task, not this skill" |
| `grilling` | workflow | none — interactive Q&A | n/a |
| `code-review` | quality | read-only, reports findings, no silent rewrites (verified) | n/a |
| `security-review` | quality | read-only; Step 0 = deterministic `secret-scan.sh` hard gate | n/a |
| `code-craft`, `spring-stack-patterns`, `test-authoring` | core (knowledge) | reference only, pulled in while writing | n/a |
| `commit` | utility | **drafts + runs `git commit` in one pass** | **⚠️ self-executing, no internal review call** (see §3) |
| `changelog` | utility | generates/writes changelog text; delegates large ranges to `drafter` (haiku) | n/a |
| `release-note` | utility | **writes directly to Confluence** via `updateConfluencePage` | n/a (not code; post-hoc review invite only) |
| `mr-feedback` | utility | **applies code fix + replies + resolves thread + commits + pushes in one pass** for agreed feedback | **⚠️ implement+resolve+push in one pass** (see §3) |
| `merge-conflict-resolution` | utility | **resolves conflict hunks + commits/continues rebase in one pass** | **⚠️ implement+commit in one pass**, relies on the *external* guard hook, not a self-check (see §3) |

### 1.4 Agents (3 — model-pinned, tool-restricted subagents)
| Agent | Model | Tools | Role |
|---|---|---|---|
| `deep-reviewer` | opus (pinned) | Read, Grep, Glob, Bash — **no GitNexus** | Spawned by `code-review`/`security-review` for concurrency/architecture/security lenses or ≥2-repo/>10-file diffs; read-only, findings-only |
| `drafter` | haiku (pinned) | none beyond drafting; explicit forbidden-mutating-commands list | Mechanical bulk drafting (changelog, summaries, checklist verification) |
| `engineering-advisor` | opus (pinned, `fable` swap documented) | Read, Grep, Glob only | Manually invoked, never auto-spawned; 4-condition eligibility gate (≥2 viable approaches / 2 failed attempts / high rollback cost / final high-risk sign-off); read-only, advisory not authoritative |

### 1.5 Hooks (3 — deterministic enforcement, not prompts)
| Hook | Event | Enforces |
|---|---|---|
| `hooks/quapp-guard.sh` | PreToolUse (Bash, Edit\|Write) | **Blocks** (deny, not advisory): `git reset --hard`, `git clean -f*`, `git branch -D`, `git checkout/restore .`, `git push --force` (without `--force-with-lease`), `rm -rf` on `.git`/`.env`/`/`/`.`/`~`/wildcard, writes to `.env*` (non-template), edits to JupyterLab-ext `CLAUDE.md`/`GEMINI.md` symlinks, hardcoded-secret patterns in new content. **Advisory** (additionalContext, not blocking): yarn-not-npm reminder, JDK-mismatch reminder, root-level-build reminder. Has a degraded (no-`jq`) fallback path covering the worst cases via grep. |
| `hooks/java-gate.sh` | PreToolUse + PostToolUse (Edit\|Write, `.java` only) | Advisory reminder of the comment/test/review gate — **not enforced**, just surfaced |
| `hooks/session-start.sh` | SessionStart (startup\|resume) | Per-repo branch + dirty-flag + protected-branch warning, active JDK, Docker presence, GitNexus staleness — **exactly the "session snapshot" the graph's shared-state model should durably persist instead of only regenerating each session** |

**Verified working**: `tests/quapp-guard-test.sh` — 67/67 assertions passing (ran it live this session).
CI (`​.github/workflows/ci.yml`) runs this suite plus shellcheck, JSON validity, frontmatter/link
checks, and gitleaks on every push — this is the harness's own regression net.

### 1.6 State / durability today
- **No durable task-state file exists anywhere in `.claude/`.** State today lives in three places by
  deliberate design (see `commands/start-task.md` "Token hygiene" section): the **Jira ticket**
  (objective, acceptance criteria, comments), the **branch name** (repo + ticket key), and the
  **conversation** (recommended to `/clear` between `/start-task` and `change-implementation` — "all
  needed state lives on the ticket and the branch").
- `/handoff` is the one exception: an **explicit, human-triggered, cross-session narrative** doc
  saved to `~/.claude/projects/.../handoffs/` — outside every repo, never auto-triggered, never a
  machine-parseable schema (Markdown prose, by design — "state, not narrative" — a slight
  self-contradiction in its own doc, since a narrative doc is exactly what it produces, but its
  actual content rule is state-summary-not-conversation-replay).
- `session-start.sh` **regenerates** a snapshot every session (branch/dirty/JDK/Docker/GitNexus
  freshness) — this is real shared state, but it's ephemeral and recomputed, never written to disk
  for a *workflow* (as opposed to session) to consume across multiple command invocations.
- **Conclusion**: there is no structured, node-addressable, machine-validatable task state today —
  this is the one genuine gap the "Graph Engineering" ask fills that isn't already solved. See
  design.md for how the new `.claude/state/` layer coexists with (not replaces) Jira-as-source-of-
  truth and `/handoff`-as-cross-session-doc.

### 1.7 Documentation
`docs/reference/writing-great-skills*.md` (skill-authoring reference), `README.md` (install/layout),
`CHANGELOG.md` (real history since 1.0.0), `VERSION` (`1.0.0`), `examples/CLAUDE.md` (portable
template for adopting this harness elsewhere), `.github/workflows/ci.yml` (documents its own scope
in a header comment: deliberately does *not* run `doctor.sh` in CI).

## 2. Duplication and conflict analysis

- **No duplicate skills found.** The 29→16 consolidation already happened (§0). `completion-audit`
  and `single-ticket.md` share one scoring formula by design (release mode wraps single-ticket mode,
  explicitly documented as "reuse it, don't reinvent") — this is intentional shared logic, not
  accidental duplication, but it is two files that must be kept in sync if the formula changes.
- **Two skills carry non-Quapp house style**: `commit` (references generic "Java projects", GitHub)
  and `changelog` (GitHub issue links, generic Gradle) — inconsistent with every other skill's heavy
  Quapp/Jira/GitLab specificity. These look like unmodified upstream templates. Not a duplication
  bug, but a consistency gap worth flagging (out of scope to fix here — no behavior is wrong, just
  branding).
- **Model tier is declared in exactly one place** (`docs/rules/model-routing.md`, rule 1: "don't
  restate this table elsewhere") and every skill/agent that needs a tier links back to it rather than
  repeating it — this is the pattern the new graph node contracts should follow, not fight.
- **No conflicting instructions found** between `rules/`, `docs/rules/`, and `profiles/quapp/` —
  cross-references were spot-checked (`java.md` → `java-comment-rules.md`, `code-review` lenses →
  `rules/java.md`, `docs/rules/gitnexus.md` as sole GitNexus-usage authority) and are consistent.
- **No stale/dead references found** in the active tree (`_archived-skills/` and
  `plugins/marketplaces/` are correctly excluded from `check-markdown-links.sh` and from discovery
  generally). `scripts/check-markdown-links.sh` itself already guards this continuously in CI.
- **Same-actor implement+approve findings** (the one real "reviewer = implementer" risk the task
  asked me to look for) — three utility skills, not the main ticket workflow:
  1. **`commit`** — drafts message and runs `git commit` in the same pass, no internal review call.
  2. **`mr-feedback`** — for "agreed" review threads: applies the fix, replies, resolves the thread,
     commits, and pushes in one pass; only cites the `rules/java.md` gate, doesn't invoke `code-review`.
  3. **`merge-conflict-resolution`** — resolves conflict hunks and commits/continues-rebase in one
     pass; safety is delegated entirely to the *external* guard hook (which blocks destructive git,
     not bad merges), not a self-imposed review step.
  **Context**: in the primary ticket lifecycle, these three are always invoked *downstream* of
  `/ship-task`'s review+test+STOP gate (or, for `mr-feedback`, downstream of an already-approved MR
  review), so the graph's ticket workflow does not inherit this risk end-to-end. The risk is real
  only when a user invokes one of these three **standalone**, outside `/ship-task`. This is recorded
  as a residual risk in `migration.md`/final report, not fixed by rewriting three independently-
  reviewed, CI-tested skills (out of proportion to a graph-formalization task, and each already has
  its own deliberate safety net — see §4).
- **`change-implementation` gap**: has a genuine human approval gate *before* writing code (the
  plan), but no gate *between* "diff implemented" and "reported done" — it doesn't self-invoke
  `code-review`. This is fine *by design* (that responsibility is `/ship-task`'s), but it means a
  user who treats `change-implementation`'s "done" as final without running `/ship-task` never gets
  an independent review. The graph should make this dependency (`implement` → `review` is mandatory,
  not optional) explicit rather than relying on the user remembering to invoke the next command.
- **No unbounded retry loops found.** No skill has a numeric "STOP after N attempts." Every
  long-running flow bounds itself qualitatively instead: `bug-investigation` ("if you cannot build a
  repro loop, stop and say so"), `engineering-advisor` ("reinvoke only when new evidence... do not
  make every task multi-agent"), `completion-audit` (scale-based Workflow opt-in, not attempt-based).
  This is a workspace-wide pattern. The graph nodes should formalize a **numeric** `maximum_attempts`
  per the task's Phase-3 node-contract requirement, since "no bound found" was true everywhere,
  not because bounds are unnecessary but because nothing forced the question until now.
- **No case found where all repositories are loaded for a single-repo task.** `task-scoping` explicitly
  scopes to the relevant repo(s) before any other skill runs; `completion-audit` explicitly gates
  full-6-repo reads behind a ≥4-ticket/≥2-repo threshold. This concern (from the task's audit
  checklist) does not apply to this codebase as found.
- **Missing success criteria / evidence requirements**: skills report findings/verdicts in prose
  (e.g. `code-review`'s `Gate: PASS | CHANGES REQUESTED`), but nothing enforces that a *machine-
  readable* evidence record survives past the conversation. This is the same gap as §1.6 restated at
  the node level — the target design's `node-result` schema addresses it.

## 3. Current workflow reconstruction (as it exists today, not as advertised)

### 3.1 Ticket lifecycle (the primary workflow)
```
/start-task PQF-<key> [bug|feature]
  1. Fetch/create Jira ticket (read comments+subtasks; MCP optional, pasted text always works)
  2. task-scoping (read-only: repo(s), JDK, files/layers, contract/DB impact)
  3. STOP — confirm branch base (staging | latest production; never develop by default)
  4. Propose branch name (feature|bugfix/khactuong.ngohoang/PQF-<key>-<desc>)
  5. Transition ticket + sub-task to In Progress (Jira, if connected; skip silently otherwise)
  6. Create branch in the target repo(s)
  7. Hand off — recommend a fresh session (/clear) before change-implementation
       ↓
change-implementation PQF-<key>   [NOT a command — a skill, invoked by name/description match]
  1. Read current code + rules
  2. Propose a plan
  3. STOP — wait for human approval of the PLAN (not of the resulting diff)
  4. Minimal diff
  5. Run checks (lint/build, not full review)
  6. Summarize files + risks
       ↓ (user manually invokes next — no automatic hand-off)
/ship-task [PQF-<key>]
  1. code-review (+ security-review if input/auth/query touched) — deep lenses/large diffs →
     ONE deep-reviewer (opus) agent; Blocker/Major must resolve before continuing
  2. Test per repo (rules/testing.md commands, real results only; baseline-failure checks delegated
     to a general-purpose sonnet subagent when pre-existing failures are suspected)
  3. STOP gate — secret-scan.sh (BLOCKER = no commit) + any unresolved review/test red → STOP,
     report, wait. This is the one gate that can never be automated past.
  4. commit (conventional format, PQF key in footer)
  5. push -u + MR via glab push-options (title=short desc, description=Task: <jira-url>, target=
     the confirmed base from step 3 of /start-task)
  6. Transition ticket (Jira, if connected)
  7. Log work on matching [BE]/[FE] sub-task (create if missing, confirm hours first)
  8. Summarize
```
**Decision points**: branch-base confirmation (human), plan approval (human), STOP gate
(deterministic + review-driven), MR-target selection (derived from step-3 decision, not re-asked).
**Verification**: `code-review` + `security-review` (independent of the implementer — different
skill, own findings-only contract) + real test runs + deterministic secret scan.
**Exit condition**: MR opened, ticket transitioned, work logged. **Failure behavior**: STOP and
report — no retry loop, no auto-fix-and-recommit.

### 3.2 Bug lifecycle
```
bug-investigation JIRA-123  (read-only: repro, stack trace, GitNexus trace/impact, hypothesis)
       ↓ (explicit hand-off, never applies the fix itself)
/ship-task (or /start-task first if a branch doesn't exist yet) — same as §3.1, with the
   testing.md requirement "a bug fix needs a regression test" enforced at ship-task step 2.
```

### 3.3 Release audit lifecycle
```
completion-audit (paste a list of PQF tickets, or "audit the release")
  - <4 tickets & <2 repos: inline, sequential
  - ≥4 tickets or ≥2 repos: Workflow tool — one sonnet worker per ticket (parallel) → one opus
    conflict-synthesis pass (cross-ticket contract/config/auth clashes) → orchestrator verdict
  - Step 0: syncs all touched repos to develop for evidence (stash-safe), restores original
    branch/stash afterward
  - Read-only throughout: never edits code, never transitions tickets
```
This is already a real graph fan-out/fan-in pattern (parallel per-ticket workers → synthesis node),
just undocumented as such and not reusable as a named node in a YAML workflow definition.

### 3.4 MR review lifecycle (someone else's MR)
```
/review-mr <repo> <iid> [--post]
  glab mr view/diff (read-only) → code-review lenses (deep-reviewer spawn if triggered) →
  compose ranked review → ask before posting (or --post for headless/CI) → glab mr note
  (never glab mr approve — approval stays human, always)
```

## 4. What already satisfies the task's "required architectural principles" (don't rebuild these)

| Principle asked for | Already present as |
|---|---|
| Independent implementer vs. reviewer | `change-implementation` (implementer) vs. `code-review`/`security-review` (reviewer, findings-only, never self-invoked by the implementer) — real separation in the primary flow |
| Independent verifier/test runner | `/ship-task` step 2 runs tests in a **separate delegated subagent** for baseline-vs-diff disambiguation |
| Release auditor role | `completion-audit`, entirely read-only, separate from implementation |
| Human approval gates | Branch-base confirmation, plan approval, and the pre-commit/push STOP gate — three explicit human gates already, not zero |
| Conditional routing | `task-scoping` scopes to relevant repo(s) only; `completion-audit`'s ≥4-ticket/≥2-repo Workflow threshold; `code-review`'s ≥2-repo/>10-file opus escalation |
| Controlled parallelism | `completion-audit`'s per-ticket parallel workers + single conflict-synthesis fan-in |
| Model-tier routing | `docs/rules/model-routing.md`, single source, already exactly the "node contract declares a tier" pattern requested |
| Security gate | `security-review`, deterministic `secret-scan.sh` hard-blocks before any LLM judgment |
| Deterministic enforcement vs. advisory prompting | `hooks/quapp-guard.sh` (blocking) vs. `hooks/java-gate.sh` (advisory) — already a clean split |

**Design implication**: the target graph architecture in `design.md` treats these as existing node
implementations to reference, not replace. The genuine gaps are: (1) no explicit graph/workflow
*document* tying nodes together with conditions, (2) no durable, schema-validated task state, (3) no
numeric retry bounds, (4) no single place that states node contracts (reads/writes/success-criteria/
failure-route) — today that information is scattered across each skill's prose.

## 5. Repository / branch state at audit time (for reference — do not act on without asking)

```
functions/quapp-functions-backend        feature/khactuong.ngohoang/PQF-22349-language-c-support   [dirty: CLAUDE.md modified — GitNexus block appended, unrelated to this task]
functions/quapp-functions-frontend       feature/khactuong.ngohoang/PQF-22350-language-c-support    clean
ai/quapp-ai-mcp                          bugfix/khactuong.ngohoang/websocket-audit-context-session-cache-eviction  clean
ai/quapp-jupyterlab-ai-assistant-ext     feature/khactuong.ngohoang/PQF-22323-ai-suggestion-multi-language  [dirty: untracked junit.xml]
ai/quapp-jupyterlab-s3-ext               develop                                                    clean
migration/quapp-migration                feature/khactuong.ngohoang/PQF-22287-credential-unverified-status  clean
migration/quapp-ai-mcp-migration         develop                                                    clean  [warned: never implement here]
sdk/qapp-common                          bugfix/khactuong.ngohoang/PQF-22346-version-bump-dev7      clean
sdk/quapp-sdk-templates                  feature/khactuong.ngohoang/PQF-22347-PQF-22348-c-templates  clean
.claude (harness itself)                 main                                                       [dirty: rules/java.md modified; rules/java-comment-rules.md untracked]
```
None of this dirty state is touched by this refactor — it belongs to in-progress ticket work
(backend/JupyterLab) and to whatever produced the uncommitted `java.md`/`java-comment-rules.md`
changes just before this session started. **This refactor only adds new files under `.claude/graph/`
and `.claude/refactor/`, plus small additive edits to `.gitignore`, `commands/start-task.md`,
`commands/ship-task.md`, `skills/README.md`, and the workspace root `CLAUDE.md`** — see
`migration.md` for the exact diff list.

## 6. Blockers encountered

None. No destructive action was required to complete discovery, and no ambiguity was found that
couldn't be resolved by reading the code rather than guessing (the task's own instruction: "mark it
Unknown / needs confirmation rather than guessing" — nothing here needed that treatment). Proceeding
to design.
