---
description: Close a ticket — review, test per repo, commit with the PQF footer, push, open the MR to the correct target, and transition the Jira issue. Owns the closing half of the task lifecycle (absorbs the former jira-feature / jira-bugfix finish).
argument-hint: [PQF-<key>]
model: sonnet
---

# /ship-task

Closing ritual for a ticket. **Orchestration only — sequences the skills + the gates no single skill
owns.** Reads project identity from [`../profiles/quapp/profile.md`](../profiles/quapp/profile.md).
Runs on **sonnet**; individual review lenses escalate per
[`../rules/model-routing.md`](../rules/model-routing.md) (deep lenses → opus subagent; security is
always opus-class).

## Steps

1. **Review.** Invoke **`code-review`** on the working diff (correctness + project-rules: cross-repo
   contract sync, migration-repo placement, JDK, layering, secrets). For input handling / queries /
   auth, also run **`security-review`**. Resolve Blocker/Major before continuing.
2. **Test per repo.** For each touched repo, run its command from `../rules/testing.md` with the
   repo's JDK; a bug fix needs a regression test. **Report real results — never claim green unrun.**
3. **STOP gate.** If any test fails or any review Blocker/Major is unresolved, **STOP — do not commit,
   push, or open an MR.** Report what is red and wait.
4. **Commit.** Use the **`commit`** skill (conventional format). The PQF key (from `$ARGUMENTS` or the
   branch name) **must be in the footer**.
5. **Push + MR.** Push with `-u` and open the MR via **GitLab push options** (`glab`). MR **title** =
   short description of the work; **description** = `Task: <jira-url>` only. The MR **target follows
   the confirmed branch base** (chosen at `/start-task` — never `develop` by default).
6. **Transition the ticket** (if MCP connected): move to the review/done state via
   `getTransitionsForJiraIssue` → `transitionJiraIssue`. Skip silently if Jira isn't available.
7. **Summarize.** Files/repos touched, test results, MR link, ticket state, and any cross-repo
   consumer follow-ups still owed.

## Output
A reviewed, tested, committed, pushed change with an MR to the correct target and an updated ticket,
plus a short ship summary.
