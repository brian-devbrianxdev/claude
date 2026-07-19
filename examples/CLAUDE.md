# CLAUDE.md — <WORKSPACE NAME> workspace (template)

This is a **fill-in-the-blanks template**, not a file this harness ships pre-populated. Copy it to
the **root of your workspace** (one level above `.claude/`) as `CLAUDE.md` and replace every
`<PLACEHOLDER>`. Run `bash .claude/scripts/doctor.sh` afterward — it checks that this file exists
and has a "Repository Map" heading, which several skills (`task-scoping`, `change-implementation`,
`completion-audit`, `review-mr`) read directly to figure out which repo a task targets.

Keep the section numbers below (`## 2. Repository Map`, `## 5. Most Important Safety Rules`, …) —
`skills/change-implementation/SKILL.md` and others link to "CLAUDE.md §5" by that number. Renumber
consistently if you restructure; a skill pointing at a stale section number is a silent failure
mode, not a loud one.

---

## 1. Workspace Overview

One paragraph: what this product is, who it's for, and the one or two architectural facts a new
contributor needs before touching anything (e.g. "not a monorepo", "N independent services talking
over HTTP", naming quirks like an old vs. new product name still used interchangeably in code).

## 2. Repository Map

The **single most important table in this file** — `task-scoping`, `change-implementation`,
`completion-audit`, and `review-mr` all key off this to map a ticket/task to a repo. One row per
repo in the workspace:

| Repo | Concern | Responsibility (one line) | Stack | Rules |
|------|---------|---------------------------|-------|-------|
| `<path/to/repo-a>` | <e.g. platform> | <one line: what it does> | <framework/lang + version> | `.claude/docs/rules/<repo-a>.md` |
| `<path/to/repo-b>` | <e.g. frontend> | <one line: what it does> | <framework/lang + version> | `.claude/docs/rules/<repo-b>.md` |

Add a row per repo. If a repo has no dedicated rules file yet, link to the nearest general one
instead of leaving the cell blank — an empty cell reads as "no rules exist," not "not written yet."

## 3. Cross-Repo Interaction

How the repos actually talk to each other at runtime — an ASCII diagram works well here. Call out:
- Which repo calls which, over what protocol (REST/WS/SSE/queue/etc.), and via what config var.
- Where the databases are and which migration repo(s) own which schema.
- Whether there's a shared/generated client, or whether contracts are hand-synced on both sides
  (if hand-synced, say so explicitly — that's the fact `change-implementation` needs to remind
  the executor to update the consumer, not just the producer, of a changed DTO/endpoint).

## 4. Where Detailed Rules Live

If you split rules into an always-loaded tier (`.claude/rules/`) and an on-demand tier
(`.claude/docs/rules/`), index both here so a reader knows what's auto-loaded vs. what they need to
open by hand:

| File | Covers |
|------|--------|
| `.claude/rules/workspace.md` | Cross-cutting conventions |
| `.claude/docs/rules/<repo>.md` | Per-repo structure/build/patterns |
| `.claude/rules/testing.md` | Per-repo test commands |
| `.claude/rules/git-workflow.md` | Hosting, branch model, CI/CD |

## 5. Most Important Safety Rules

The load-bearing list — keep it short and concrete, not a restatement of the rules files. Typical
entries:

1. **Not a monorepo** (if true) — never build at the workspace root; `cd` into the specific repo.
2. **Match each repo's toolchain version** (JDK/Node/Python) — see the workspace rules file.
3. Any **hard boundary that must never be crossed silently** (e.g. two separate databases that must
   never share a migration, a schema that must stay backward compatible, an auth surface that must
   never be weakened).
4. **Cross-tier contracts must be kept in sync by hand** if there's no codegen (state this plainly —
   it's the fact that stops a producer-only DTO change from shipping half-done).
5. **Don't modify source unless asked**; follow each repo's existing conventions; run its lint/tests
   before declaring done.
6. Anything else genuinely load-bearing for safety, not just style.
7. When something is genuinely unclear, mark it **"Unknown / needs confirmation"** rather than
   guessing.

## 6. Skills, Commands & Profile

Short pointer paragraph: where the daily lifecycle commands live (`/start-task`, `/ship-task`, …),
where project identity/tracker/VCS specifics live (`.claude/profiles/<project>/profile.md`), and
where the model-routing table lives if you use one (`.claude/docs/rules/model-routing.md`).

---
*Maintenance: this file decays if the repo map, stack versions, or rules paths drift from reality —
treat "Unknown / needs confirmation" as a to-do list, not a permanent state, and update it whenever
architecture, repos, or commands change.*
