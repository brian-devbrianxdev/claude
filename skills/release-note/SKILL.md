---
name: release-note
description: Write a Quapp release note (Production or Staging) on Confluence from Jira tickets — gather done tickets for the release, keep only shipped features and bug fixes that target the released environment, and fill the page in the established Added/Changed/Fixed format. Use when the user says "viết release note", "write the release note", "fill the release note page", or pastes a "[Production]/[Staging] Release note" Confluence link.
---

# Release Note Skill

Fill a **[Production|Staging] Release note DD/MM/YYYY** Confluence page (space `CQSD`) from Jira
tickets, matching the format of previous release notes.

> **Model routing** ([`../../docs/rules/model-routing.md`](../../docs/rules/model-routing.md)):
> sonnet-class. Run inline; the work is gathering + judgment + writing, no fan-out needed.

Atlassian cloudId: `citynow-org.atlassian.net`. Jira project: `PQF`.
GitLab: `GITLAB_HOST=gitlab.citynow.vn` with `glab`.

## Environment model (drives every env-dependent step)

| Release note | Env branch (Java/FE repos) | JupyterLab ext branch | Jira release ticket pattern |
|---|---|---|---|
| `[Production]` | `production` | `publish` | `YYYYMMDD - Release Production` |
| `[Staging]` | `staging` | *none — tag-based repo; confirm with the user which tag/branch shipped* | `YYYYMMDD - Release Staging` |

Determine the **environment** first — from the page title, the user's words, or the linked Jira
release ticket — and use it consistently below. A production release usually promotes what an
earlier staging release contained; a staging release note may therefore legitimately repeat items
that will later appear in a production note. When comparing against "already shipped" (Step 3),
compare against previous notes of the **same environment** only.

## Step 0 — Confirm scope (ask only what's genuinely ambiguous)

Collect before writing:
1. **Target page** — URL or page id of the release note page (usually pre-created, empty
   Added/Changed/Fixed skeleton). If not given, find it:
   `searchConfluenceUsingCql: title ~ "<Production|Staging> Release note" AND space = CQSD ORDER BY created DESC`.
   Confirmed title conventions: `[Production] Release note DD/MM/YYYY` and
   `[Staging] Release note DD/MM/YYYY`. Occasional variants exist — `[<Env>][AI] Release note …`
   (AI-service-only releases) and a sibling `[Staging] Request For Change (RFC) - DD/MM/YYYY`
   page (an RFC, **not** the release note — don't write into it).
2. **Environment** — Production or Staging (see table above).
3. **Ticket scope** — what the user asks for, e.g. "sprint N due DD/MM", "done in month M",
   "of person X and Y". Don't guess a narrower scope than asked; when the user gives a date,
   remember tickets finished the day(s) *before* the release date are usually part of the release.
   The Jira release ticket (`YYYYMMDD - Release <Env>`, e.g. PQF-21608 prod / PQF-21603 stg) marks
   the date and often `blocks`-links the paired release — useful to anchor the window.
4. **People filter** (optional) — if given, filter by `assignee in (...)` using their emails.

## Step 1 — Learn the current format from the previous note

Fetch the most recent previous release note page **of the same environment** with
`getConfluencePage` (`contentFormat: html`). Staging and production notes share the same skeleton
(verified: `[Staging] Release note 24/06/2026` uses the identical Added/Changed/Fixed template).
The established format (since ~06/2026):
- Three `<h2>` sections: **Added / Changed / Fixed**, separated by `<hr>`.
- Each item = one `<p>` paragraph: `<strong>[Area] Short title:</strong> user-facing description.`
- **English**, written for end users/stakeholders — describe behavior, not implementation.
- **No** Jira keys, no GitLab MR links, no tables (older 2026 Q1 notes had links — do not revert).
- Preserve the target page's existing `data-local-id` attributes on headings/hr/first paragraphs;
  new paragraphs need no local id.

## Step 2 — Gather candidate tickets from Jira

Use `searchJiraIssuesUsingJql`. Useful JQL shapes (adapt to the confirmed scope):
- By sprint + due date window:
  `project = PQF AND sprint = "Sprint N" AND duedate >= "<release-1d>" AND duedate <= "<release>"`
- By completion month + people:
  `project = PQF AND assignee in (...) AND issuetype in (Epic, Story, Task, Bug) AND statusCategory = Done AND statusCategoryChangedDate >= "YYYY-MM-01"`
- The `"Release date[Date]"` custom field exists but is typically empty — check it, don't rely on it.

Practicalities:
- **Do not** filter `issuetype` narrowly on the first sweep — check Epic/Story/Task/Bug, then
  sub-tasks of the survivors if a person filter is active (someone's work may live in sub-tasks of
  another owner's story; review-only sub-tasks do **not** justify adding the story).
- Results routinely overflow the tool limit → the output is saved to a file; extract with
  `jq -r '.issues.nodes[] | [.key, .fields.issuetype.name, .fields.status.name, (.fields.duedate // "-"), (.fields.assignee.emailAddress // "?"), .fields.summary] | @tsv'`.
- Fetch `description` (markdown) for the survivors in a second query — needed to write accurate
  entries. `key in (...)` batches this.

## Step 3 — Filter to release-note content

Include only tickets that are **Done** and describe a product change. Exclude:
- **Release-ops / process tickets**: "Release Production/Staging", "… Development Backlog",
  "Test …", QAQC/test-environment tasks, meeting/BA/documentation-process tasks.
- **Refactor / tech-debt** tickets (Strategy-pattern refactors, code-rule cleanups, …) — unless the
  user explicitly wants them.
- **Unfinished** tickets (To Do / In Progress / Review / Reopen). For a **staging** note, a ticket
  still in QA-ish states may nevertheless be deployed to stg — if its MR merged to `staging`,
  flag it to the user instead of silently dropping it.
- Anything already shipped in a previous release note **of the same environment**.

## Step 4 — Bug rule: only fixes targeting the released environment

For every candidate **bug fix**, verify where the fix landed before including it:

```bash
export GITLAB_HOST=gitlab.citynow.vn
glab mr list -R <repo-path> --search "PQF-<key>" --all   # look at the (target) ← (source) column
```

Repo paths: `quapp/platform/quapp-functions-backend`, `quapp/platform/quapp-functions-frontend`,
`quapp/platform/quapp-ai-mcp`, `quapp/platform/quapp-migration`,
`quapp/platform/quapp-ai-mcp-migration`, and **`quapp/platform/quapp-ide/quapp-jupyterlab-ai-assistant-ext`**
(note the extra `quapp-ide/` segment). When unsure, read the local repo's `git remote -v`.

- **Production note** — keep the bug only if an MR targets **`production`** (JupyterLab ext:
  **`publish`**). MRs targeting only `develop`/`staging` ship via a later promotion → drop, with
  the MR evidence in the summary.
- **Staging note** — keep the bug if an MR targets **`staging`** (a fix that also has a
  `production` MR still counts if the staging deploy includes it). `develop`-only MRs → drop.
  JupyterLab ext has no staging branch — ask the user whether the ext is part of that staging
  deploy and which tag carries the fix.
- No MR found under one key: search the summary keywords too, and check sibling repos, before
  concluding.

## Step 5 — Categorize and write

- **Added** — new capability that didn't exist (new integration, new screen/tag, new API docs).
- **Changed** — existing behavior/content changed (visibility rules, quota scope, pagination,
  displayed information updates).
- **Fixed** — bug fixes that pass Step 4 for this environment.

Writing style per item: `<strong>[Area] Outcome-focused title:</strong>` + 1–4 sentences on what the
user can now do / what no longer happens. Merge sibling tickets that are one deliverable
(e.g. a set of per-repo documentation stories → one "[API Documentation] …" item).

## Step 6 — Update the page and report

- `updateConfluencePage` with `contentFormat: html` and a meaningful `versionMessage`.
- Final reply must map **every ticket → its item (or exclusion reason)**, including the MR target
  branches found for bugs, so the user can audit the cut. Offer to add/remove borderline items
  (internal-ish deliverables like API docs, infra trials) rather than silently deciding twice.

## Anti-patterns

❌ Copying Jira summaries verbatim (write user-facing English) · ❌ including Jira keys/MR links in
the page body · ❌ trusting due date alone — status must be Done · ❌ listing a bug in an env note
when its fix never targeted that env's branch · ❌ comparing "already shipped" across different
environments' notes · ❌ dropping the page's existing `data-local-id`s · ❌ inventing a scope the
user didn't ask for without saying so.
