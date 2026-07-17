# Executor + Advisor model architecture (this repo only)

Scope: this document describes a routing architecture layered on top of the existing tier system
in [`docs/rules/model-routing.md`](docs/rules/model-routing.md), which remains the **single source
of truth for the skill/command → model tier table** (its own rule 1: "don't restate this table
elsewhere"). This file does not repeat that table — it explains the Executor/Advisor split, when
the new `engineering-advisor` agent should fire, and how to verify/roll it back. It applies only to
the `Quapp` workspace's `.claude/` config (repo-scoped `settings.json` + `agents/`), not to any
other project.

## Architecture

- **Executor — Claude Sonnet 5.** The default model for this repo (`.claude/settings.json` →
  `"model": "sonnet"`). Handles everything in the existing `sonnet` tier: exploration, reads,
  routine implementation, mechanical refactors, tests, docs, running build/lint/test, ordinary
  debugging. This is unchanged from today.
- **Deep reviewer — Claude Opus (`opus` tier, unchanged).** Still auto-spawned by `code-review` /
  `security-review` for the concurrency / architecture / security lenses and large cross-repo
  diffs, exactly as `docs/rules/model-routing.md` already specifies. Nothing about this path
  changes — it stays automatic and stays at `opus`.
- **Advisor — Claude Fable 5, via `.claude/agents/engineering-advisor.md`.** A **separate, scarce
  advisory role** (not simply a "stronger Opus"): read-only (`Read, Grep, Glob` only — no edits,
  no commands), manually invoked by the executor, never auto-spawned. The distinction is *role*, not
  just tier — Opus reviews automatically; Fable advises manually at genuine decision boundaries.
  Eligible only after Opus when at least one hard condition is met (see `engineering-advisor.md`):
  Opus leaves ≥2 viable approaches open, two distinct attempts have failed, the decision has high
  rollback cost, or a final recommendation is needed for genuinely high-risk work.

The key distinction from `opus` escalation: `opus` (`deep-reviewer`) fires automatically whenever
a review lens or diff size crosses a threshold — routine, high-volume escalation. `engineering-advisor`
fires only when the executor reaches a genuine decision boundary per the 4-condition gate in its own
file. **Cross-repo, auth, contract, or concurrency scope alone qualifies for Opus — not Fable.**
Always prefer `deep-reviewer` first; reach for `engineering-advisor` only if Opus findings leave the
decision genuinely open or rollback cost is too high to risk being wrong.

## When to invoke vs. not (examples)

| Situation | Route |
|---|---|
| "Where is the session-timeout logic?" | Executor (Sonnet) — file discovery |
| Fix a null-pointer in a controller with an obvious cause | Executor (Sonnet) |
| Standard CRUD endpoint following existing patterns | Executor (Sonnet) |
| Concurrency/architecture/security lens on a routine diff | `deep-reviewer` (Opus), auto-spawned by `code-review`/`security-review` |
| Two different fixes attempted for a flaky auth bug, still failing | `engineering-advisor` (Fable) |
| Changing a DTO/event contract shared across `functions-backend` ↔ `ai-mcp` ↔ frontend | `deep-reviewer` (Opus) first; escalate to `engineering-advisor` (Fable) only if trade-offs remain unresolved or rollback cost justifies a final Go/No-Go |
| About to do an irreversible broad refactor before commit | `engineering-advisor` (Fable), final review |
| Re-running a test suite after a trivial edit | Executor (Sonnet) |

## Invocation discipline

The executor must not forward the raw task to the advisor. It first builds the evidence packet
described in `engineering-advisor.md` (requested outcome, relevant files/symbols, observed vs.
expected behavior, investigation already done, hypothesis, unresolved decisions, relevant project
rules) and asks a focused question. Advisor output is guidance, not final authority — the executor
verifies every claim against the repository before acting on it.

## How to verify which model an agent used

- Check the agent's frontmatter: `.claude/agents/engineering-advisor.md` → `model: fable`;
  `.claude/agents/deep-reviewer.md` → `model: opus`; `.claude/agents/drafter.md` → `model: haiku`.
- Check the session default: `.claude/settings.json` → `"model": "sonnet"` (this repo only —
  `/model` can still override it for the current session).
- In the transcript/UI, a subagent call shows its resolved model in the task header; if in doubt,
  ask the agent to state its model or check `/status`.

## Limitations and cost trade-offs

- Fable is the most expensive, highest-latency tier available here — every invocation should be
  deliberate. If `engineering-advisor` starts firing on routine work, that's a routing bug, not
  expected behavior — tighten the trigger criteria rather than tolerating it.
- The advisor is read-only by design; it cannot verify its own recommendation against a live test
  run. The executor is always responsible for running validation after implementing the advice.
- This split adds a coordination step (evidence packet → advice → verify → implement) that costs
  more wall-clock time than letting Sonnet proceed directly. Only worth it at genuine decision
  boundaries — see "do not invoke" list in `engineering-advisor.md`.
- Pinning `"model": "sonnet"` in `settings.json` sets the *default* for this repo; it does not
  prevent an explicit `/model` switch mid-session, nor does it change any other repo's settings.

## Environment prerequisite for Fable

`model: fable` in `engineering-advisor.md` requires the `fable` model alias
to be available in the current Claude Code environment. Verify before first use:

```
/model
```

or check that `fable` appears in the model list. If `fable` is not available:
- Use `opus` as a direct fallback — the advisor's read-only contract (`Read`,
  `Grep`, `Glob` only) and response structure remain identical.
- Swap the frontmatter: `model: fable` → `model: opus` in
  `agents/engineering-advisor.md`, or pass `model: "opus"` explicitly in the
  `Agent` tool call.
- The quality difference for this specific read-only advisory role is small;
  the routing criteria and discipline are more important than the model tier.

## Rollback

- To remove the advisor entirely: delete `.claude/agents/engineering-advisor.md`. No other file
  depends on its presence — `docs/rules/model-routing.md` and `README.md` reference it by name but
  degrade gracefully (the row/bullet becomes stale text to prune, not a broken reference).
- To stop pinning Sonnet as the repo default: remove the `"model": "sonnet"` line from
  `.claude/settings.json`; the session will fall back to whatever `/model` or the global default
  resolves to.
- To fully revert this architecture: revert the diffs to `settings.json`,
  `docs/rules/model-routing.md`, `README.md`, and the root `CLAUDE.md`, and delete this file and
  `agents/engineering-advisor.md`. Nothing else in `.claude/` was modified.
