---
name: merge-conflict-resolution
description: Resolve an in-progress git merge/rebase conflict in a Quapp repo — understand both intents from primary sources, resolve every hunk, re-run the repo's checks, finish the merge. Use when a merge/rebase stops on conflicts, "resolve conflicts", "merge bị conflict", or before/after syncing a branch with staging/production/develop.
---

# Merge Conflict Resolution

Resolve conflicts by **understanding intent, not by picking sides mechanically**. Run everything
inside the one affected repo (multi-root workspace — see [`../../rules/workspace.md`](../../rules/workspace.md)).

## Steps

1. **See the state.** `git status`, `git log --oneline --graph -15`, list conflicting files. Identify
   what is being merged into what, and why (MR sync? base update? release merge?).

2. **Find the primary sources for each conflict.** Understand why *each side* changed: commit
   messages (`git log -L` on the hunk), the MRs (`glab mr list --source-branch ...`), the PQF tickets
   they reference. Don't resolve a hunk whose intent you can't state in one sentence per side.

3. **Resolve each hunk.** Preserve both intents where possible. Where incompatible, pick the one
   matching the merge's stated goal and note the trade-off in the summary. Do **not** invent new
   behavior. Resolve — don't `git merge --abort` — unless the user asks to abort.

4. **Re-run the repo's checks** per [`../../rules/testing.md`](../../rules/testing.md) with the
   repo's JDK (17/21 matrix): typecheck/lint first (frontend: `yarn tsc`), then the affected tests.
   Fix anything the merge broke.

5. **Finish.** Stage everything and commit (a merge commit keeps git's default message + conflict
   list); if rebasing, `git rebase --continue` until done. Verify with `git branch --show-current`
   before committing — checkout can silently land on a protected branch mid-flow.

## Quapp-specific traps

- **Frontend MRs squash-merge into develop.** After your MR merges, the branch is NOT an ancestor of
  develop — verify presence of your change by **content diff** (`git diff origin/develop -- <files>`),
  never by ancestry. When updating a long-lived branch, **merge develop into the branch first** so
  the target's content survives the squash; resolving conflicts in the MR UI or by force-pushing a
  rebase can silently drop the other side.
- **False "local changes would be overwritten" / "not uptodate" with a clean `git status`** — stale
  index stat info, not a real conflict. Fix: `git update-index --force-remove <file>` then
  `git checkout HEAD -- <file>`. Don't diagnose further.
- The workspace guard **denies `git checkout .` / `reset --hard` / `push --force`** — resolve
  file-by-file; if history rewriting is truly needed, hand the command to the user.

*Adapted from [mattpocock/skills](https://github.com/mattpocock/skills) `resolving-merge-conflicts` (MIT), plus workspace lessons.*
