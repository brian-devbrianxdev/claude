# .claude — Quapp Claude Code harness

Version-controlled Claude Code configuration for the **Quapp** multi-repo workspace
(CITYNOW Co. Ltd.). Tracks the reusable skill system, workspace rules, the project profile,
and deterministic guards. Runtime state and local secrets are git-ignored.

## Layout
| Path | What it is |
|------|-----------|
| `skills/` | 16 capability-named skills (see `skills/README.md`) |
| `commands/` | Lifecycle and review commands: `/start-task`, `/ship-task`, `/review-mr`, `/handoff` (all pinned to sonnet) |
| `agents/` | Model-pinned subagents: `deep-reviewer` (opus), `drafter` (haiku), `engineering-advisor` (fable, scarce/manual-only) — see `docs/rules/model-routing.md` and `MODEL_ROUTING.md` |
| `rules/` | Workspace rules (layering, JDK matrix, two DBs, contract sync, the Java gate, **model routing** — `docs/rules/model-routing.md`) |
| `profiles/quapp/` | Project identity (tracker key, GitLab host, branch model) |
| `hooks/` | `quapp-guard.sh` — accidental-destruction guardrail (blocks destructive git commands and symlink edits; not a security sandbox — bypassable via absolute paths or shell wrappers) · `java-gate.sh` — Java coding-standards reminder |
| `settings.json` | Shared hooks + theme (machine-local perms live in the git-ignored `settings.local.json`) |
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
  with `opus` or change its frontmatter as documented in `MODEL_ROUTING.md`

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
