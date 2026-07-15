---
allowed-tools: Bash(glab mr view:*), Bash(glab mr diff:*), Bash(glab mr note:*), Bash(glab api:*), Bash(git log:*), Bash(git diff:*), Bash(git fetch:*), Task, Read, Glob, Grep, AskUserQuestion
description: Review an open GitLab MR (any Quapp repo) with the code-review lenses and optionally post the findings as an MR note
argument-hint: <repo> <mr-iid-or-url> [--post]
model: sonnet
---

# /review-mr

Review a **merge request already open on GitLab** — someone else's MR, or one pushed earlier —
without needing the branch checked out. Complements `/ship-task` (which reviews the local working
diff *before* the MR exists) and `mr-feedback` (which resolves reviewer threads on your own MR).
Ported from the claude-cookbooks `review-pr` / `review-pr-ci` commands to GitLab + this workspace.

## Arguments

- `$1` — target repo: a repo folder name (`quapp-functions-backend`, `quapp-ai-mcp`, …) or path.
  Omitted + an MR URL given → derive the repo from the URL path.
- `$2` — MR IID (e.g. `412`) or full `gitlab.citynow.vn` MR URL.
- `--post` — post the review as an MR note **without asking** (headless/CI use). Without it,
  always ask before posting.

## Steps

1. **Resolve the repo dir** (this is a multi-root workspace — every `glab`/`git` command runs
   *inside* that repo). Map the repo name to `functions/`, `ai/`, or `migration/` per the root
   `CLAUDE.md` repo table.
2. **Gather context** (read-only):
   ```sh
   glab mr view <iid>          # title, description, source/target branch, state
   glab mr diff <iid>          # the full diff to review
   ```
   Note the **target branch**: per `git-workflow.md` it must be `staging` or `production` —
   an MR targeting `develop` is itself a Major finding unless the user confirms it's intended.
3. **Review the diff** with the **`code-review`** skill lenses (correctness + project-rules
   always; add concurrency / performance / api-contract / architecture when the diff touches
   them). Per `docs/rules/model-routing.md`: deep lenses and any security-relevant change run in
   **one `deep-reviewer` agent** (opus) fed with the diff text — the agent has no GitNexus access,
   so run `impact`/cross-repo checks yourself first. Cross-repo contract sync (frontend ↔ backend
   ↔ ai-mcp DTOs/routes) stays a mandatory check — the graph can't see it.
4. **Compose the review** in this format (findings ranked, `file:line` references):

   ```
   ## MR Review — <repo>!<iid>

   **Recommendation:** APPROVE | REQUEST_CHANGES | COMMENT

   ### Summary
   <1-2 sentences: what the MR does>

   ### Blocker / Major
   - <finding> (`file:line`)

   ### Minor / Suggestions
   - <finding> (`file:line`)

   ### Notes
   - <positive observations, follow-ups owed in consumer repos>
   ```

   Empty sections are omitted. Recommendation mapping: any Blocker/Major → `REQUEST_CHANGES`;
   only minors → `COMMENT`; clean → `APPROVE`.
5. **Post (gated).** Show the user the composed review first. With `--post`, or after the user
   confirms, post it:
   ```sh
   glab mr note <iid> -m "<review body>"
   ```
   **Never** call `glab mr approve` / `--approve` — approval stays a human action on GitLab.
   If the user declines posting, just leave the review in the conversation.

## Headless / CI usage

The same command works non-interactively from a GitLab CI job or cron:
`claude -p "/review-mr quapp-functions-backend 412 --post"`. A CI job needs a runner with
`claude` + `glab` authenticated for `gitlab.citynow.vn` and an `ANTHROPIC_API_KEY` CI variable —
adding that job to a repo's `.gitlab-ci.yml` is a per-repo infra change; propose it, don't
apply it unasked.

## Output

A ranked, file:line-referenced review with an explicit recommendation, optionally posted as a
note on the MR (never an approval).
