# Skills

Capability-named, reusable prompts that teach Claude how to work in this workspace. Each skill
folder has a `SKILL.md` (instructions for Claude, loaded on demand); larger skills keep extra
reference files loaded only when their section is needed.

- **Project identity** (tracker key, GitLab host, branch model, git user) →
  [`../profiles/quapp/profile.md`](../profiles/quapp/profile.md).
- **Workspace rules** (layering, JDK matrix, two DBs, contract sync, Java gate) → [`../rules/`](../rules/).
- Skills are named by **capability**, not project or tool — all project specifics live in the profile
  and rules, so the set is portable to another project by swapping those.

## The 13 skills

### Core — write/refactor (auto-pulled while coding)
| Skill | Capability |
|-------|-----------|
| [code-craft](code-craft/) | Clean code + SOLID + design patterns (3 reference files) |
| [spring-stack-patterns](spring-stack-patterns/) | Spring Boot + JPA + logging idioms (3 reference files) |
| [test-authoring](test-authoring/) | JUnit 5 + AssertJ tests |

### Quality — review & validation
| Skill | Capability |
|-------|-----------|
| [code-review](code-review/) | Scoped review: correctness, project-rules, standards, concurrency, performance, api-contract, architecture (7 reference lenses) |
| [security-review](security-review/) | OWASP Top 10, injection, secrets, auth |

### Workflow — lifecycle & analysis
| Skill | Capability |
|-------|-----------|
| [task-scoping](task-scoping/) | Scope a ticket onto the workspace (read-only) |
| [solution-planning](solution-planning/) | Solution design + ordered plan + effort/time estimate (read-only) |
| [change-implementation](change-implementation/) | Guarded, approval-gated implement flow |
| [completion-audit](completion-audit/) | Ticket completeness — 1 ticket or a whole release (+ conflict detection); Workflow fan-out |
| [bug-investigation](bug-investigation/) | Read-only root-cause diagnosis |

### Utility
| Skill | Capability |
|-------|-----------|
| [commit](commit/) | Conventional commit messages |
| [changelog](changelog/) | Changelogs from git commits |
| [mr-feedback](mr-feedback/) | Resolve reviewer threads in a GitLab MR |

### Commands (lifecycle orchestrators) — [`../commands/`](../commands/)
- **`/start-task`** — fetch/create ticket → `task-scoping` → confirm base (STOP) → In Progress → branch.
- **`/ship-task`** — `code-review` → test per repo (STOP if red) → `commit` → push + MR → transition.

The write-time **Java gate** is now a rule: [`../rules/java.md`](../rules/java.md) (no longer a skill).

## How it got here
- **Pass A** merged the knowledge skills → `code-craft` + `spring-stack-patterns`, archived
  `maven-dependency-audit` / `issue-triage` / `java-migration`, and added the project profile.
- **Pass B** collapsed the 7-skill review stack → one scoped `code-review`; merged
  `jira-ticket-audit` + `quapp-release-audit` → `completion-audit`; absorbed `jira-feature` +
  `jira-bugfix` into `/start-task` + `/ship-task`; retired the `java-coding-standards` gate into
  `../rules/java.md`; and renamed every `quapp-*` / tool-named skill to a capability name.
- Result: **29 skills → 12** + 2 commands, no capability lost (except the rarely-used
  `java-migration`, archived under `../_archived-skills/`).

## Adding a new skill
- [ ] No overlap with the 12 above. [ ] Single responsibility, one session.
- [ ] **Capability-named**, not project/tool-named. [ ] Project specifics → `profiles/`, rules → `rules/`.

Then create `<skill-name>/SKILL.md`, add a row above, and link any reference files from `SKILL.md`.

- [Claude Code Skills documentation](https://code.claude.com/docs/en/skills)
