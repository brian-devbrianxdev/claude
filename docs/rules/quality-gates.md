# Rules — Technical-debt / quality gates (Clean-as-You-Code)

Read this when: finishing a Java change (self-review gate), deciding whether a legacy file needs
cleanup as part of an unrelated change, or investigating whether "the pipeline is green" is actually
proof a change is safe. Applies to any repo with a CI-gated merge process — the methodology here is
discovery-first: verify what a gate actually enforces before trusting it.

## Reuse what already exists — don't duplicate it

Before recommending a new static-analysis/quality tool, **check the build file for what's already
configured** (a SonarQube plugin block, a JaCoCo coverage-verification task, an existing Checkstyle/
PMD config). Recommending a new, overlapping tool without checking produces duplicate/conflicting
findings, not additional safety — the discovery pass belongs in "what's already there," and the gap
to fill is usually "this existing tooling isn't documented/known about," not "no tooling exists."

## The critical habit: verify what a gate actually enforces, don't assume

A quality/test job existing in a CI config is not the same as it **blocking** a merge. Concretely
check, for any pipeline you're relying on:
- Does the job's trigger condition (`rules:`/`when:`/branch filter) actually match the branch you
  care about? A condition that looks plausible can be silently wrong — e.g. a rule referencing an
  environment variable value or comparison that never actually evaluates true on a real branch push.
- Is the job marked `allow_failure`/`continue-on-error`? If so, it can fail and the pipeline still
  goes green.
- Does the job even run on every branch (including whatever branch feeds a production deploy), or
  only on one (e.g. only the default branch, skipping the release branches)?

**This is worth checking explicitly, not assuming from the presence of a CI file** — a quality gate
that exists in config but doesn't actually block anything is a common, easy-to-miss failure mode, and
it means the team's own manual self-review discipline (Phase 3/4 of the write-time gate) is the
*actual* safety net, not a formality layered on top of a working one. Treat "run the tests and report
real results" as covering for a possible CI gap, not as redundant busywork — verify which is true for
the specific repo before assuming either way.

## Clean-as-You-Code — scope the gate to new code, not a legacy rewrite demand

Score any quality gate against **new code only**, never the whole codebase — legacy debt is
deliberately out of scope for a merge blocker; it gets fixed opportunistically when a developer
touches that code anyway, not through a dedicated remediation sprint. This is the standard "Clean as
You Code" philosophy (SonarQube popularized the term, but the principle is tool-agnostic).

"New code" baselining options, and which fits which workflow:
- **Reference branch** (diff against a named branch via SCM metadata) — best fit for a
  trunk-based/environment-branch workflow (feature branches merged via PR/MR into a long-lived
  default branch) with no semver-tag convention — this makes "new code" mean exactly the MR diff.
- **Previous version** — fits a workflow with an actual version-bump convention (semver tags at each
  release); don't use this if the repo doesn't tag releases that way.
- **Number of days** — a rolling window, decoupled from actual deploy cadence; use only as a
  fallback when neither of the above fits.
- **Specific analysis/manually pinned snapshot** — viable if release cycles are manually marked
  (e.g. at each promotion to a higher environment), but needs manual upkeep the other options don't.

Operationally, for a self-review (whether or not a CI gate is actually enforcing it):
- Zero new bugs, zero new vulnerabilities introduced by the diff.
- 100% of new security hotspots reviewed (reviewed and consciously accepted or fixed — not
  necessarily "fixed" in every case).
- New/changed logic is tested per the risk-based matrix in the write-time gate — untested new
  business logic is a failure regardless of what an aggregate coverage percentage says.
- No new duplication introduced by copy-paste — check the diff for a block that already exists
  elsewhere before adding a near-copy.
- No new unowned `TODO`/`FIXME` — every one added needs a ticket reference or removal condition
  inline (`// TODO: <ticket/bug ref> - <explanation>`), not a bare marker.

## What "new code" does NOT excuse

Clean-as-You-Code scopes the **gate** to new code — it does not excuse skipping a test for a
*modification* to existing untested logic. If you touch existing untested business logic, the
touched portion is new code and needs a test per the risk-based matrix, even though the surrounding
untested legacy code in the same file stays out of scope for cleanup.

## Coverage — a percentage is not proof of correctness

A coverage number measures execution, not correctness — a test that runs a code path without
asserting its behavior still counts toward it. If a repo has a coverage-verification gate with
excludes for pure data/config/generated code, check whether a newly-added package should be excluded
the same way (genuinely pure data/config) or included (real logic) rather than assuming an existing
exclude pattern already covers it correctly.
