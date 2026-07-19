# .claude — Quapp Claude Code harness

Version-controlled Claude Code configuration for the **Quapp** multi-repo workspace
(CITYNOW Co. Ltd.). Tracks the reusable skill system, workspace rules, the project profile,
and deterministic guards. Runtime state and local secrets are git-ignored.

> **This is my real, daily-driver harness, published as-is.** `rules/`, `docs/rules/`, and
> `profiles/quapp/` intentionally contain real project identifiers (company name, internal GitLab
> host, repo names, Jira project key, architecture facts) because this config is actively used to
> do real Quapp/CITYNOW engineering work, not a genericized template. None of it is a credential —
> no tokens, keys, passwords, or customer data — but it is real internal naming and infrastructure
> detail, disclosed intentionally rather than accidentally. If you're adapting this harness for
> your own project, treat `skills/` and the harness mechanics (hooks, agents, model routing) as the
> reusable part, and replace `profiles/`, `rules/`, and `docs/rules/` with your own — see
> `examples/CLAUDE.md` and `scripts/doctor.sh` for a starting point.

## Layout
| Path | What it is |
|------|-----------|
| `skills/` | 16 capability-named skills (see `skills/README.md`) |
| `commands/` | Lifecycle and review commands: `/start-task`, `/ship-task`, `/review-mr`, `/handoff` (all pinned to sonnet) |
| `agents/` | Model-pinned subagents: `deep-reviewer` (opus), `drafter` (haiku), `engineering-advisor` (opus, scarce/manual-only; upgradeable to `fable` if available — see frontmatter) — see `docs/rules/model-routing.md` and `docs/architecture/executor-advisor-architecture.md` |
| `rules/` | Workspace rules (layering, JDK matrix, two DBs, contract sync, the Java gate, **model routing** — `docs/rules/model-routing.md`) |
| `profiles/quapp/` | Project identity (tracker key, GitLab host, branch model) |
| `hooks/` | `quapp-guard.sh` — accidental-destruction guardrail (blocks destructive git commands and symlink edits; not a security sandbox, an advisory guard against *accidental* self-inflicted damage — a determined bypass is always possible, see its regression suite in `tests/` for what's covered) · `java-gate.sh` — Java coding-standards reminder |
| `settings.json` | Shared hooks, model pin, and theme. `permissions.defaultMode` is intentionally absent — set it in the git-ignored `settings.local.json` to match your trust level (e.g. `{"permissions":{"defaultMode":"auto"}}`) |
| `scripts/doctor.sh` | Environment check: required/optional deps (`jq`, `glab`, JDKs, Docker) + whether the root `CLAUDE.md` dependency (below) is satisfied. Local-use only, not run in CI (see below) |
| `scripts/check-markdown-links.sh`, `scripts/check-frontmatter.sh` | Repo-internal consistency checks — relative markdown links resolve, skill/agent/command frontmatter is complete and correctly named. Run in CI |
| `examples/CLAUDE.md` | Fill-in-the-blanks template for the root `CLAUDE.md` this harness expects but does not ship (workspace-specific, not reusable config) |
| `.github/workflows/ci.yml` | On every push/PR: guard regression suite, shell syntax + shellcheck, JSON validity, frontmatter/markdown-link checks, gitleaks secret scan. Doesn't run `doctor.sh` — that script diagnoses a real Quapp workspace checkout, which a bare CI runner isn't |
| `_archived-skills/` | Retired skills kept for provenance (out of discovery) |

## Skill architecture
Consolidated from 29 skills to **16** across two passes + post-pass additions — see `skills/README.md` for the full map
and history. Skills are named by capability; all project specifics live in `profiles/` and `rules/`.

## Installation

This repository must be checked out as the `.claude` directory **at the root
of your workspace** — for example `~/projects/quapp/.claude`. Claude Code
loads it as project-level configuration when the workspace root is opened.

Do not install it as `~/.claude`. Hook paths in `settings.json` are anchored
to `$CLAUDE_PROJECT_DIR/.claude/` and will not resolve correctly from a
user-level install.

**This repo does not ship a root `CLAUDE.md`.** `task-scoping`,
`change-implementation`, `completion-audit`, and `review-mr` all read
`CLAUDE.md` → Repository Map (one level above `.claude/`, at your workspace
root) to figure out which repo a task targets — that file is workspace-specific
project knowledge, not reusable harness config. Copy `examples/CLAUDE.md` to
your workspace root and fill in your own repos/rules links.

After cloning, run `bash .claude/scripts/doctor.sh` — it checks for the
required/optional dependencies below plus the root `CLAUDE.md`, and tells you
exactly what's missing before you rely on the full `/start-task`→`/ship-task`
lifecycle.

**Required:**
- Claude Code (latest)
- `jq` — used by all hooks; guards degrade without it (`brew install jq`)
- `git` — version control
- `glab` — GitLab CLI, authenticated to `gitlab.citynow.vn` (`brew install glab`)
- Java 17 and Java 21 — JDK matrix varies per repo (see `rules/workspace.md`)

**Optional:**
- Docker — needed for Testcontainers-based integration tests (`quapp-ai-mcp`)
- GitNexus MCP — enables graph-based code navigation (all 6 repos indexed)
- Atlassian MCP — enables Jira/Confluence integration (`/start-task`, `release-note`)
- `fable` model alias — optional; if unavailable, manually invoke the advisor
  with `opus` or change its frontmatter as documented in `docs/architecture/executor-advisor-architecture.md`

**Verify hooks are running:** open any repo in the workspace, run a command, and
confirm the guard output appears. If silent, check `settings.json` hook paths and
that `jq` is installed.

**Platform support:** macOS and Linux are both supported. `session-start.sh`
uses a portable `stat` wrapper (BSD `stat -f %m` with GNU `stat -c %Y` fallback).

## Not tracked
`settings.local.json`, `sessions/`, `projects/`, `history.jsonl`, `cache/`, `backups/`, `plugins/`,
and other per-machine runtime state (see `.gitignore`).

`policy-limits.json` is also git-ignored — it holds machine-local Claude Code policy restrictions
(remote-control, web-setup, search isolation). Create it from scratch if needed; there is no
template because its contents are security-sensitive and environment-specific.
