---
description: Close a ticket — review, test per repo, commit with the PQF footer, push, open the MR to the correct target, transition the Jira issue, and log work on the matching [BE]/[FE] sub-task (creating it with the Backend/Frontend label if missing). Owns the closing half of the task lifecycle (absorbs the former jira-feature / jira-bugfix finish).
argument-hint: [PQF-<key>]
model: sonnet
---

# /ship-task

Closing ritual for a ticket. **Orchestration only — sequences the skills + the gates no single skill
owns.** Reads project identity from [`../profiles/quapp/profile.md`](../profiles/quapp/profile.md).
Runs on **sonnet**; individual review lenses escalate per
[`../docs/rules/model-routing.md`](../docs/rules/model-routing.md) (deep lenses → opus subagent; security is
always opus-class).

## Steps

1. **Review.** Invoke **`code-review`** on the working diff (correctness + project-rules: cross-repo
   contract sync, migration-repo placement, JDK, layering, secrets). For input handling / queries /
   auth, also run **`security-review`**. Resolve Blocker/Major before continuing.
2. **Test per repo.** For each touched repo, run its command from `../rules/testing.md` with the
   repo's JDK; a bug fix needs a regression test. **Report real results — never claim green unrun.**
   If failures look pre-existing (not in the diff's files), **delegate the baseline check to one
   `general-purpose` subagent (model: sonnet)** — stash, run the failing classes on the clean tree,
   pop, report — instead of doing the stash/run/pop round-trips inline (each inline call re-reads
   the full conversation context).
3. **STOP gate.** If any test fails or any review Blocker/Major is unresolved, **STOP — do not commit,
   push, or open an MR.** Report what is red and wait.
4. **Commit.** Use the **`commit`** skill (conventional format). The PQF key (from `$ARGUMENTS` or the
   branch name) **must be in the footer**.
5. **Push + MR.** Push with `-u` and open the MR via **GitLab push options** (`glab`). MR **title** =
   short description of the work; **description** = `Task: <jira-url>` only. The MR **target follows
   the confirmed branch base** (chosen at `/start-task` — never `develop` by default).
6. **Transition the ticket** (if MCP connected): move to the review/done state via
   `getTransitionsForJiraIssue` → `transitionJiraIssue`. Skip silently if Jira isn't available.
7. **Log work on the matching sub-task** (if MCP connected; skip silently otherwise):
   a. **Pick the discipline** from the repo(s) actually touched: `quapp-functions-frontend` /
      JupyterLab-ext TS → **`[FE]` / label `Frontend`**; Java services + migration repos →
      **`[BE]` / label `Backend`**. Both tiers → log each side on its own sub-task.
   b. **Find the sub-task**: `getJiraIssue` on the parent (include `subtasks`) and match by
      discipline prefix + work type — implementation work goes on the `[BE]`/`[FE]` impl sub-task,
      MR-revision work on `[…] Resolve feedback merge request`. If more than one plausibly matches, ask.
   c. **No match → create it**: `createJiraIssue` (`issueTypeName: "Sub-task"`, `parent: "<KEY>"`),
      summary prefixed `[BE]`/`[FE]`, `additional_fields: {labels: ["Backend"|"Frontend"], timetracking:
      {originalEstimate: "<time>"}}`. No Story Points on sub-tasks (`solution-planning` Step 7d pattern).
   d. **Log the time**: `addWorklogToJiraIssue` on the sub-task with the time actually spent, Jira
      duration format (`"2h"`, `"1h 30m"` — no decimals). **Confirm the amount with the user first**
      unless they already stated it — never invent hours.
8. **Summarize.** Files/repos touched, test results, MR link, ticket state, work logged (sub-task +
   time), and any cross-repo consumer follow-ups still owed.

## Output
A reviewed, tested, committed, pushed change with an MR to the correct target, an updated ticket with
work logged on the right `[BE]`/`[FE]` sub-task, plus a short ship summary.
