# .claude — Quapp Claude Code harness

Version-controlled Claude Code configuration for the **Quapp** multi-repo workspace
(CITYNOW Co. Ltd.). Tracks the reusable skill system, workspace rules, the project profile,
and deterministic guards. Runtime state and local secrets are git-ignored.

## Layout
| Path | What it is |
|------|-----------|
| `skills/` | 13 capability-named skills (see `skills/README.md`) |
| `commands/` | Lifecycle commands: `/start-task`, `/ship-task` (both pinned to sonnet) |
| `agents/` | Model-pinned subagents: `deep-reviewer` (opus), `drafter` (haiku), `engineering-advisor` (fable, scarce/manual-only) — see `docs/rules/model-routing.md` and `MODEL_ROUTING.md` |
| `rules/` | Workspace rules (layering, JDK matrix, two DBs, contract sync, the Java gate, **model routing** — `docs/rules/model-routing.md`) |
| `profiles/quapp/` | Project identity (tracker key, GitLab host, branch model) |
| `hooks/` | `quapp-guard.sh` — deterministic workspace guard |
| `settings.json` | Shared hooks + theme (machine-local perms live in the git-ignored `settings.local.json`) |
| `_archived-skills/` | Retired skills kept for provenance (out of discovery) |

## Skill architecture
Consolidated from 29 skills to **13** across two passes — see `skills/README.md` for the full map
and history. Skills are named by capability; all project specifics live in `profiles/` and `rules/`.

## Not tracked
`settings.local.json`, `sessions/`, `projects/`, `history.jsonl`, `cache/`, `backups/`, `plugins/`,
and other per-machine runtime state (see `.gitignore`).
