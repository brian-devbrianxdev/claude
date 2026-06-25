---
name: mr-feedback
description: Resolve reviewer feedback left in GitLab merge request discussion threads — fetch unresolved threads, apply the requested code change, reply, and resolve each thread. Use when user says "resolve MR feedback", "address review comments", "fix the GitLab MR threads", or "respond to merge request comments".
---

# GitLab MR Feedback Resolution Skill

Work through reviewer feedback on a GitLab Merge Request one discussion thread at a time:
fetch unresolved threads → apply the change → reply → resolve the thread.

## When to Use
- User says "resolve MR feedback" / "address review comments" / "fix the MR threads"
- A GitLab MR has unresolved discussions that need code changes or replies
- After a reviewer requests changes

## Prerequisites

**Required**: GitLab access via one of:
- [`glab`](https://gitlab.com/gitlab-org/cli) CLI (recommended), authenticated (`glab auth status`), or
- GitLab REST API v4 with a token (`GITLAB_TOKEN`) via `curl`, or
- a GitLab MCP server if configured for the session.

> Resolving threads needs the **Developer** role or higher on the project.

### Key API concepts
- A **discussion** is a thread; it has `id` and `resolvable`/`resolved` flags.
- Each discussion holds **notes** (comments). The first note is the original feedback.
- You **reply** by adding a note to the discussion, and **resolve** the discussion as a whole.

REST endpoints (base: `/projects/:id/merge_requests/:mr_iid`):
| Action | Method + path |
|--------|---------------|
| List threads | `GET .../discussions` |
| Reply to a thread | `POST .../discussions/:discussion_id/notes` |
| Resolve a thread | `PUT .../discussions/:discussion_id?resolved=true` |

## Workflow

### Step 1 — Identify the MR
Get project + MR IID from the user, the current branch, or:
```bash
glab mr list --source-branch "$(git branch --show-current)"
```

### Step 2 — Fetch UNRESOLVED threads only
```bash
glab api "projects/:id/merge_requests/:iid/discussions?per_page=100"
```
Filter to discussions where `resolvable == true` and `resolved == false`. For each, capture:
- `discussion.id`
- the first note's `body` (the request), `author`, and `position` (file path + line).

Ignore non-resolvable system notes (label changes, "marked as draft", etc.).

### Step 3 — Triage each thread
Classify the feedback before acting:
| Type | Action |
|------|--------|
| **Code change requested** | Apply the change (Step 4), reply, resolve |
| **Question** | Reply with the answer; resolve only if no change needed |
| **Suggestion (optional)** | Apply if reasonable; otherwise reply with rationale, leave for reviewer |
| **Disagreement** | Reply with reasoning; do NOT resolve — leave for the reviewer to decide |

> Do not blindly resolve. Resolve a thread only when its concern is genuinely addressed.

### Step 4 — Apply the code change
For any Java code change, go through the [rules/java.md](../../rules/java.md)
gate (incl. self-explanatory code / no comments, tests, and the review gate). Make the smallest
change that fully addresses the comment — don't scope-creep beyond the feedback.

### Step 5 — Reply on the thread
Add a note that says what you did, referencing the commit if available:
```bash
glab api -X POST "projects/:id/merge_requests/:iid/discussions/<discussion_id>/notes" \
  -f body="Done in <short-sha> — extracted validation into PluginValidator as suggested."
```
Keep replies short, factual, and specific. One reply per thread.

### Step 6 — Resolve the thread
Only after the reply, and only for addressed threads:
```bash
glab api -X PUT "projects/:id/merge_requests/:iid/discussions/<discussion_id>?resolved=true"
```

### Step 7 — Commit & push
Group the fixes logically (defer wording to [commit](../commit/SKILL.md)); push to the MR's
source branch so the replies/commits line up:
```
fix(review): address MR feedback — extract validation, null-guard scan

Resolves review threads from <reviewer>.
```
Then confirm the pipeline is green.

## Token Optimization
- Fetch all discussions in ONE call; cache the list. Don't re-list after each resolve.
- Only read the file regions referenced by `position`, not whole files.
- Batch independent code changes, then reply+resolve each thread, then a single push.

## Anti-patterns
❌ Resolving a thread without actually addressing it (or without replying).
❌ Resolving threads where you disagreed — leave those for the reviewer.
❌ Re-listing discussions after every action (wastes tokens).
❌ Scope-creeping changes beyond what the comment asked.
✅ Triage → minimal correct change → short factual reply → resolve only when addressed.

## Example
```
> "Resolve the feedback on MR !42"
1. glab api discussions → 5 unresolved threads
2. triage: 3 code changes, 1 question, 1 disagreement
3. apply 3 changes via rules/java.md gate
4. reply + resolve the 3 code threads and the question
5. reply (no resolve) on the disagreement, explaining the trade-off
6. commit, push, confirm pipeline green → report summary
```

## References
- [glab CLI](https://gitlab.com/gitlab-org/cli) · [GitLab Discussions API](https://docs.gitlab.com/ee/api/discussions.html)
- [rules/java.md skill](../../rules/java.md) · [commit skill](../commit/SKILL.md)
