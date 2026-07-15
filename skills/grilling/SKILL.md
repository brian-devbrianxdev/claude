---
name: grilling
description: Grill the user relentlessly about a plan, decision, or design — one question at a time — until shared understanding is reached. Use when the user wants to stress-test their thinking, says "grill me", "phản biện", "chất vấn", or before locking a large/ambiguous solution plan or estimate.
---

# Grilling

Interview the user relentlessly about every aspect of the plan, decision, or idea until you reach a
shared understanding. Walk down each branch of the decision tree, resolving dependencies between
decisions one by one. For each question, provide your recommended answer.

Ask the questions **one at a time** (use AskUserQuestion where it fits — put your recommendation as
the first option), waiting for feedback on each before continuing. Asking multiple questions at once
is bewildering.

If a **fact** can be found by exploring the environment (codebase, GitNexus graph, Jira ticket, git
history, configs), look it up rather than asking. The **decisions**, though, are the user's — put
each one to them and wait for the answer.

Do not act on the plan until the user confirms shared understanding has been reached.

## Quapp specifics

- When grilling a ticket plan, ground questions in the workspace realities first: which repo(s),
  cross-repo contract impact (frontend ↔ backend ↔ ai-mcp), which migration repo/DB, branch base
  (`staging` vs latest `production`). These are facts to verify, then decision points to confirm.
- Natural pairing: run this **before** `solution-planning` finalizes an estimate, or before
  `change-implementation` starts on anything large or ambiguous.
- End with a short recap: decisions made (one line each) + anything explicitly deferred.

*Adapted from [mattpocock/skills](https://github.com/mattpocock/skills) `grilling` (MIT).*
