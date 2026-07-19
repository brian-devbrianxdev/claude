# Changelog

All notable changes to this harness are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are dated milestones in this
repo's own history, reconstructed from `git log`, not a published package with external consumers.

## [1.0.0] - 2026-07-19

First tagged baseline, closing out an external review's findings (guard bypasses, a missing
environment check, model-routing ambiguity, an oversized Fable aside, undisclosed real project
identifiers, two monolithic skill files, no CI).

### Fixed
- `rm -rf` guard bypasses: single-quoted dangerous targets (`rm -rf '/'`), the whole home directory
  (`rm -rf ~`, `rm -rf $HOME`), and invocation via an absolute/relative path (`/bin/rm -rf /`).
  16 new regression cases (67/67 passing, up from 51/51).
- `docs/rules/model-routing.md`: the orchestrator tier's row said "highest available
  (Fable/Opus...)" while `settings.json` actually pins `sonnet` — reworded the row to state the
  resolved behavior up front instead of only in a footnote.
- `docs/reference/writing-great-skills-glossary.md`: a stale self-link (`SKILL.md`, which doesn't
  exist here) pointed at the wrong filename instead of its actual sibling `writing-great-skills.md`.

### Added
- `scripts/doctor.sh` — environment check (jq/git/glab+auth/Java 17+21, including Homebrew
  keg-only openjdk that `java_home` can't see) plus whether the root `CLAUDE.md` dependency is
  satisfied.
- `examples/CLAUDE.md` — fill-in-the-blanks template for the root `CLAUDE.md` several skills read
  for the repository map; this harness never shipped that file (workspace-specific, not reusable).
- `.github/workflows/ci.yml` — guard regression suite, shell syntax + shellcheck, JSON validity,
  frontmatter/markdown-link checks, gitleaks secret scan on every push/PR.
- `scripts/check-markdown-links.sh`, `scripts/check-frontmatter.sh` — the two checks CI runs above.
- A README disclosure note: `rules/`, `docs/rules/`, and `profiles/quapp/` intentionally contain
  real Quapp/CITYNOW identifiers (this is the actual daily-driver harness, not a genericized
  template) — disclosed rather than left to read as accidental exposure.

### Changed
- `docs/architecture/executor-advisor-architecture.md`: trimmed a dedicated "Optional Fable
  upgrade" section and scattered restatements (10 mentions) down to three factual one-liners —
  `opus` is the guaranteed default, an alias swap is a one-line local edit, not an architecture.
- `skills/security-review/SKILL.md` (580 → 103 lines) and `skills/test-authoring/SKILL.md`
  (575 → 115 lines): split into a slim entry point + on-demand `references/` files, matching the
  progressive-disclosure pattern `code-craft`/`spring-stack-patterns` already used. No content
  removed, only relocated.

## [0.4.0] - 2026-07-17

Consolidation day: skill count reduced, model routing formalized, the executor/advisor split
introduced.

### Added
- `engineering-advisor` agent (scarce, manual-only, read-only) and the executor/advisor model
  architecture doc.
- `docs/rules/model-routing.md` as the single source of truth for skill/command → model tier.
- `/review-mr` and `/handoff` commands; secret-scan step added to `/ship-task`.

### Fixed
- Stale docs, broken links, skill-count drift across README/skills, several hook bugs (advisor
  pinning, `rm -rf`/`.env` guard gaps, java-gate path bug, degraded-mode guard, install-path
  rendering), no-comments rule relaxed to no-*redundant*-comments, multi-repo task-scope wording.

## [0.3.0] - 2026-07-10

### Added
- GitNexus knowledge-graph integration across skills and rules (navigation, impact analysis).
- Jira comment-thread analysis feeding ticket scoping/estimation accuracy.
- Comprehensive documentation pass for components and rules.

## [0.2.0] - 2026-07-02

### Added
- `solution-planning` skill (solution design + ordered plan + effort estimate), later refined to
  incorporate ticket comment-thread analysis.

## [0.1.0] - 2026-06-25

### Added
- Initial version-controlled Quapp Claude Code harness.
