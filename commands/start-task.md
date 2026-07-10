---
description: Open a ticket — fetch/create the Jira issue, scope it, confirm the branch base, move it In Progress, and create a correctly-named branch. Owns the opening half of the task lifecycle (absorbs the former jira-feature / jira-bugfix start).
argument-hint: PQF-<key> [bug|feature] [pasted ticket text]
model: sonnet
---

# /start-task

Opening ritual for a ticket. **Orchestration only — do not write feature code here.**
Runs on **sonnet** (routine lifecycle work — see [`../docs/rules/model-routing.md`](../docs/rules/model-routing.md)).
Reads project identity from [`../profiles/quapp/profile.md`](../profiles/quapp/profile.md)
(tracker key, host, git user, branch model).

## Steps

1. **Capture / create the ticket.** Take the key from `$ARGUMENTS`. **If the Atlassian MCP is
   connected**, fetch it read-only with `getJiraIssue` — include `comment` in `fields` and **read the
   comment thread, not just the description**: PO/BA/dev/QA replies often refine or override the spec
   (on conflict the latest comment usually wins; still-open questions are Unknowns to raise before
   branching). Also note subtasks. If no key but a description is given, offer to create the
   issue (Story for a feature, Bug for a defect) via `createJiraIssue`. **If the MCP is unavailable
   or returns the wrong issue, fall back to the pasted ticket text** — Jira is never required.
   Restate the goal in one line.
2. **Scope it.** Invoke the **`task-scoping`** skill to determine target repo(s), JDK, affected
   files/layers, and cross-repo contract/DB impact. Let the skill do it — don't re-derive here.
3. **Confirm the branch base — STOP and ask.** Per `../rules/git-workflow.md`, the base is `staging`
   or the latest `production` depending on the fix, **never `develop` by default**. Propose the base,
   then **WAIT for explicit confirmation. Do not create the branch until confirmed.**
4. **Propose the branch name** `feature|bugfix/khactuong.ngohoang/PQF-<key>-<short-desc>` (prefix from
   the `bug|feature` arg or the issue type).
5. **Move the ticket In Progress** (if MCP connected): `getTransitionsForJiraIssue` →
   `transitionJiraIssue`. Skip silently if Jira isn't available.
6. **Create the branch** from the confirmed base **inside the target repo** (`cd` into the specific
   repo first — not a monorepo). Multiple repos → create the matching branch in each, or ask which to
   start with.
7. **Hand off.** Tell the user to proceed with **`change-implementation`** (which applies the
   `../rules/java.md` gate). Do not start editing.

## Output
A scope summary (repo / JDK / files / contracts), the confirmed base, the In-Progress ticket, and a
created, correctly-named branch in the right repo — ready to implement.

## Token hygiene
End the summary by recommending the user start the implementation in a **fresh session** (`/clear`)
— all needed state (scope, plan, base) lives on the ticket and the branch, and carrying this
conversation into implementation multiplies context cost on every call.
