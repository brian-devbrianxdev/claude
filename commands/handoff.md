---
description: Compact the current conversation into a handoff document so a fresh session (or another machine) can continue the work without re-deriving context.
argument-hint: [what the next session will focus on]
model: sonnet
---

# /handoff

Write a handoff document summarizing the current conversation so a fresh agent can continue.
Save it **outside the repos** — `~/.claude/projects/-Users-ngohoangkhactuong-Quapp/handoffs/<yyyy-mm-dd>-<slug>.md`
(create the folder if missing) — never inside a Quapp git repo.

## Content rules

- **State, not narrative**: where the work stands now, what is verified done, what is in flight,
  what is blocked and on what. Not a replay of the conversation.
- **Do not duplicate what other artifacts already capture** — reference them instead: PQF ticket
  (`https://citynow-org.atlassian.net/browse/<KEY>`), branch names per repo, MR URLs, commit SHAs,
  file paths (`repo/path:line`). The doc is the index; the artifacts are the content.
- **Quapp context the next session always needs**: ticket key + confirmed branch base, repo(s)
  touched + current branch of each (`git branch --show-current`), test status per repo (real
  results), and any cross-repo contract follow-up still owed.
- **Suggested skills/commands** section: which of this workspace's skills the next session should
  invoke (e.g. resume with `change-implementation`, close with `/ship-task PQF-…`, review someone's
  MR with `/review-mr`).
- **Redact secrets** — no tokens, credentials, or `.env` contents ever.
- If the user passed arguments, treat them as what the next session will focus on and tailor the
  doc to that (drop context irrelevant to it).

End by printing the saved path and a one-line "resume with: …" hint.

*Adapted from [mattpocock/skills](https://github.com/mattpocock/skills) `handoff` (MIT).*
