---
name: solution-planning
description: Turn a scoped ticket into a solution design, an ordered implementation plan, and an effort/time estimate before any code. Proposes a recommended approach (with alternatives + trade-offs), breaks the work into steps mapped to repos/files, and estimates effort as a range with assumptions and confidence — accounting for mandatory tests, cross-repo contract sync, migrations, review/MR overhead, and a contingency buffer. Use when the user says "plan PQF-123", "how should we solve this", "estimate this ticket", "how long will this take", "re-estimate", or during backlog grooming. No code changes; writes the solution + plan in Vietnamese to the ticket (comment + Original Estimate + Story Points + role label), and optionally breaks the plan into Jira sub-tasks (each with its own label + estimate + self-assignee) when asked.
---

# Solution Planning

Bridges scoping and implementation: given a ticket, decide **how to solve it**, **in what order**, and
**how long it takes**. Builds on [task-scoping](../task-scoping/SKILL.md) (the *where*) and feeds
[change-implementation](../change-implementation/SKILL.md) (the *do*). **Read-only on source — no code
edits.** The one allowed write: post the finished solution + plan as a **comment on the ticket**.

> **Model routing:** opus-class ([`../../docs/rules/model-routing.md`](../../docs/rules/model-routing.md)) —
> weighing alternatives and estimating under ambiguity needs deep reasoning; suggest `/model opus`
> once if the session runs cheaper. The mechanical tail (posting the Jira comment, setting fields)
> is fine at any tier.

**Language:** write the solution + plan **in Vietnamese** (both the chat reply and the ticket comment).
Keep code identifiers, file paths, `path:line` refs, repo/branch names, and technical terms in their
original form — translate the prose, not the symbols.

## When to Use
- "plan PQF-123", "design a solution for this", "estimate this ticket", "how long will this take",
  "break this down" — or sprint/backlog grooming before work starts.
- After `task-scoping`; if scope isn't done yet, run a light scope first (or invoke the skill).

## Workflow Steps
1. **Restate goal + acceptance criteria — and read the comment thread.** Fetch the ticket (Atlassian
   MCP `getJiraIssue`, include `comment` in `fields` so `fields.comment.comments` comes back) or use the
   pasted text. **Always read the existing comments** — other people (PO/BA/devs/QA) discuss, clarify,
   correct, or change scope in the thread below the ticket, and those replies often override or refine
   the original description (e.g. a resolved product question, a changed business rule, an agreed
   approach). Reconcile the description with the thread; if they conflict, the latest comment usually
   wins — call out the discrepancy and any **still-open question** as an Unknown that lowers confidence.
   List the atomic requirements — these are what you plan and estimate against.
2. **Get the scope.** Reuse [task-scoping](../task-scoping/SKILL.md) output (target repo(s), JDK,
   affected files/layers, cross-repo contract/DB impact) or derive it. Cite real `path:line`.
3. **Design the solution.** For a large or ambiguous ticket (Low confidence, conflicting comments,
   wide solution space), offer to run a [grilling](../grilling/SKILL.md) session first — one
   question at a time with recommended answers — before locking the design and estimate.
   Propose a **recommended approach** and, when the solution space is wide,
   **1 alternative** with trade-offs (complexity, risk, blast radius, reversibility). State the
   approach in terms of the real classes/files/endpoints it touches, not just its label — if you name
   a pattern ("repository", "event-driven", "cache-aside"), the next sentence must say which class gets
   created/moved and which class starts calling it. Respect the workspace constraints from
   [`../../rules/`](../../rules/): strict layering, no JPA-entity leakage, `controller/v1/` versioning,
   the correct migration repo, no weakened auth. Note explicit **non-goals** to bound scope.
4. **Break into an ordered plan of concrete steps.** Sequence steps in dependency order; map each to
   repo/files/layer. Every step must let another engineer implement it without asking you anything —
   see [Writing implementation steps](#writing-implementation-steps) for the required structure and
   language rules. Include the work the workspace *forces* and people forget, each written as its own
   concrete step (not a category label):
   - **Tests** (mandatory per `../../rules/java.md`; a bug fix needs a regression test) — **except
     in-scope FE source**, which per [`../../rules/testing.md`](../../rules/testing.md) does not require
     new unit tests: `quapp-functions-frontend` (entire repo) and `quapp-jupyterlab-ai-assistant-ext`'s
     TS/React `src/` code only. Do not add a test-writing step, or pad the estimate, for that portion of
     a ticket. Backend/ai-mcp/migration portions — and the ext's **Python** server-extension portion —
     of the same ticket keep the mandatory-test step. Name the actual test class and the scenario it
     asserts (e.g. "Add `UserServiceTest#returnsEmptyList_whenNoActiveSubscription()`"), not "add tests".
   - **Cross-repo contract sync** — no codegen, so *every* consumer of a changed DTO/route/WS/SSE is a
     separate step, naming the exact consumer file (frontend ↔ backend ↔ ai-mcp ↔ JupyterLab ext).
   - **Migration changeset** in the correct repo if the schema changes (QuaO DB vs AI-MCP DB) — name the
     changelog file and the column/table it adds.
   - **Review + MR + likely revision cycle**, and manual verify where there's no e2e (frontend).
5. **Run the readability gate.** Re-read every step in the plan and ask: *"Would a mid-level engineer
   know exactly what to implement after reading this, with no further questions?"* If any step still
   reads as a category or a quality goal instead of a concrete change, rewrite it before moving on.
6. **Estimate.** Size each work item and roll up to a **range** (optimistic / likely / pessimistic),
   with a **confidence** level driven by how many Unknowns remain. **Always add a contingency buffer**
   for unforeseen work (~10–20% of the working estimate; lean to 20% when confidence is Low) — fold it
   into the impl + resolve-feedback items, not a separate "buffer" sub-task. The **likely** roll-up
   (buffer included) is the number you write back. Estimates are planning ranges with stated
   assumptions — **not commitments**.
7. **Surface risks, assumptions, and unknowns** that would move the estimate, and suggest the next step.
8. **Write back to the ticket (default).** After the plan is complete, do all three via Atlassian MCP
   (skip only if the user says not to):
   a. **Comment** the solution + plan as a Vietnamese comment (`addCommentToJiraIssue`,
      `contentFormat: "markdown"` — use real markdown tables/headings, not Jira-wiki `h3.`/`||`).
   b. **Original Estimate + Story Points** — set both via `editJiraIssue`:
      - `fields.timetracking.originalEstimate` = the **likely** roll-up (buffer included), Jira format
        e.g. `"1d"`/`"4h"`/`"1h 30m"`; **1d = 8h**. Use the likely value, not the optimistic/pessimistic ends.
        **Set `remainingEstimate` in the same `timetracking` object** (= originalEstimate for not-yet-started
        work) — editing originalEstimate alone does NOT auto-update Time Remaining, so on a re-estimate the
        old remaining lingers and looks wrong. (createJiraIssue sets remaining = original automatically.)
      - `fields.customfield_10016` (**"Story point estimate"**, the team's Story Points field for PQF —
        verified via issue-type metadata; `customfield_10028` is NOT on the screen) = **likely hours ÷ 4**
        (the team's scale is **1 SP = 4h**). Round to a whole SP; prefer making the likely estimate a clean
        multiple of 4h so SP and Original Estimate stay consistent (e.g. 12h → 3 SP, 16h → 4 SP). Story
        Points go on the **parent Story only**, never on sub-tasks.
   c. **Role label** — add the label matching the work's discipline. The team's role labels are
      **`Frontend` · `Backend` · `BA` · `QAQC`** (verified convention; capitalized). Pick by the target
      repo(s): FE repo → `Frontend`, Java services/migration → `Backend`, both tiers → both labels.
      Preserve any existing labels (send the full list). Don't invent new label names.
   d. **Sub-tasks (only when the user asks** — e.g. "tạo subtask theo plan", "break this into
      sub-tasks"). Group the implementation plan into a few **meaningful work units** (don't make one
      sub-task per micro-step), create each under the ticket via `createJiraIssue`
      (`issueTypeName: "Sub-task"`, `parent: "<KEY>"`), and on **each** sub-task set its own
      **role label** + **Original Estimate** (`additional_fields: {labels:[…], timetracking:{originalEstimate:"2h"}}`)
      **and assignee** — resolve the current user once via `atlassianUserInfo` and pass its `accountId`
      as `assignee_account_id` on every `createJiraIssue` call (self-assign; sub-tasks don't go out
      unassigned). Make the per-sub-task estimates (buffer included) **sum to the parent's likely
      roll-up**. Don't put Story Points on sub-tasks.
      **The team's verified sub-task pattern** (mirror it): the impl + test work units — **for
      `[FE]` sub-tasks scoped to in-scope FE source (`quapp-functions-frontend`, or
      `quapp-jupyterlab-ai-assistant-ext`'s TS/React `src/`), no separate test work unit** per the
      frontend testing exception (`../../rules/testing.md`); fold any FE verification time into the
      `[FE]` impl sub-task instead — plus a **`[role] Review code`** sub-task, a **`[QA]` verify**
      sub-task (label `QAQC`) where there's
      manual verification, and — **mandatory on every ticket** — a **`[role] Resolve feedback merge
      request`** sub-task that absorbs the ~1 MR-revision round. This **supersedes** the older "fold
      review/MR/verify into impl, don't create sub-tasks for them" guidance — for this team they ARE
      their own sub-tasks.
      Prefix each summary with the discipline tag (`[BE]`/`[FE]`/`[QA]`) the team uses. Use the Jira
      duration format (`"7h"`, `"1h 30m"`, `"30m"`) — decimals like `"1.5h"` are unreliable.
   Never touch worklog or status here — sub-tasks are created in the tracker's default status (To Do);
   `/start-task` moves the specific sub-task being worked on to In Progress when work actually begins.

## Writing implementation steps

The plan exists so another engineer can build the ticket **without talking to you**. A step is only
done being written when it answers all four of these:
1. **What exactly changes?** — a real class, method, file, endpoint, or config key from the scope
   (Step 2), not a category.
2. **Where does it change?** — repo + path + layer.
3. **Why is it needed?** — one line tying it to the requirement, the root cause, or a workspace rule.
4. **What should exist after this step?** — the resulting state, stated as fact.

**Structure every step** with these five fields:
- **Objective** — the one-line goal.
- **Concrete implementation** — the actual work, as imperative sentences naming real classes, methods,
  files, and endpoints. This is the field that matters most; everything else is context for it.
- **Reason** — why, tied to the requirement/root cause/rule.
- **Dependencies** — prior step number(s), or "None".
- **Expected outcome** — the concrete end state, as a short bullet list ("X now exists", "Y no longer
  happens") — not a restated goal.

**Verbs.** Prefer concrete, implementation verbs: Create, Move, Rename, Delete, Extract, Split, Merge,
Replace, Add, Remove, Update, Modify, Register, Inject, Call, Return, Persist, Validate. Treat these as
red flags **unless the same sentence immediately names the concrete change**: Improve, Optimize,
Enhance, Refactor, Introduce, Leverage, Simplify, Strengthen, "decouple responsibilities", "separation
of concerns". "Refactor `SessionService`" is not a step; "Extract `pause()`/`resume()`/`archive()` out
of `SessionService` into a new `SessionLifecycleService`" is.

**Example — not this:**
> Introduce repository abstraction.

**But this:**
> Objective: stop `UserService` from running SQL directly.
> Concrete implementation: Create `UserRepository` in `repository/`. Move every SQL query currently
> inline in `UserService` into it as a method. Update `UserService` to call `UserRepository` instead of
> executing queries.
> Reason: `UserService` currently mixes persistence and business logic, which is what made the PQF-xxxx
> bug hard to isolate.
> Dependencies: None.
> Expected outcome:
> - all database access for users lives in `UserRepository`
> - `UserService` contains only business logic, no SQL.

Apply the same standard to the "forced" steps (tests, contract sync, migration, review) — name the test
method, the consumer file, the changelog file; don't leave them as category labels either.

## Estimation method
- Decompose to work items (per repo/layer/step). Size each: **S ≈ ≤2h · M ≈ ½ day · L ≈ 1–2 days · XL → split it.**
- Add the standing overhead: tests (**not** for in-scope FE source — `quapp-functions-frontend` entirely,
  or `quapp-jupyterlab-ai-assistant-ext`'s TS/React `src/` — see the testing exception above), each
  cross-repo consumer edit, migration, two-JDK build/test, review + ~1 revision round. Don't fold these
  into a single number — list them.
- Add a **contingency buffer** (~10–20%) for unforeseen work on top of the sized items — more when
  confidence is Low. Fold it into the impl + resolve-feedback items; don't make a "buffer" sub-task.
- Roll up: **optimistic** (no surprises) / **likely** (buffer included) / **pessimistic** (unknowns bite).
  Total range in hours and ≈ days.
- **Confidence**: High (criteria clear, paths known, 0–1 unknowns) · Medium · Low (≥3 unknowns or an
  unverified cross-repo contract) — say which and why.
- **Story Points (this team uses them): 1 SP = 4h.** Set `customfield_10016` on the parent =
  likely-hours ÷ 4 (round to a whole SP); prefer a likely estimate that's a clean multiple of 4h so SP ↔
  Original Estimate line up (12h→3, 16h→4). SP on the parent Story only.

## Rules Claude Must Follow
- **Read the ticket's comment thread, not just the description** (Step 1). Discussion below the ticket
  often refines/overrides the original spec; reconcile both, let the latest comment win on conflicts, and
  surface any still-open question as an Unknown.
- **Read-only on source.** Don't modify code; cite evidence at `path:line`; mark anything unverifiable
  **Unknown / needs confirmation** — unknowns *lower confidence and widen the range*, never get hidden.
- **Write the solution + plan in Vietnamese** (chat reply + ticket comment); keep identifiers/paths/
  technical terms in their original form.
- Estimates are ranges + assumptions, not promises. Never give a single hard number without a range.
- One repo at a time; respect the JDK matrix and two-DB split (`../../rules/`).
- A backend/ai-mcp contract change with no matching consumer edit is **extra work**, not free.
- **Every implementation step must be concrete** — see
  [Writing implementation steps](#writing-implementation-steps). Name the real class/method/file it
  touches; a step that only names an architectural goal ("refactor the service boundary", "improve
  cache strategy") is not finished being written. Run the Step 5 readability gate before presenting
  the plan.
- **The Step 8 write-back is the default**: Vietnamese comment + Original Estimate (likely value, buffer
  included) + **Story Points** (`customfield_10016` = likely ÷ 4) + role label
  (`Frontend`/`Backend`/`BA`/`QAQC`, by target repo). Preserve existing labels; don't invent labels. Do
  **not** touch worklog or status unless the user explicitly asks (then `addWorklogToJiraIssue` /
  `transitionJiraIssue`).
- **Every estimate includes a contingency buffer** (~10–20%) folded into the items — never a bare
  surprise-free number.
- **Sub-tasks only on request** (Step 8d). When asked, mirror the team's verified pattern: impl + test
  units + a `Review code` sub-task + a `QA` verify sub-task (label `QAQC`) where relevant + a **mandatory
  `Resolve feedback merge request` sub-task on every ticket**. Each gets its own role label + Original
  Estimate (buffer included) + **assignee (self, via `atlassianUserInfo`)**, summing to the parent
  likely; no Story Points on sub-tasks, and leave status at the tracker default (To Do) — `/start-task`
  owns moving a specific sub-task to In Progress. (This replaces the old "don't create sub-tasks for
  review/MR/verify" rule.)

## Output Format
Render in **Vietnamese** (identifiers/paths/terms stay original), in both the chat reply and the ticket
comment, using this shape:
```
## Plan & Estimate — <ticket / title>
Goal: <1 line>   Acceptance: <bullets>   Non-goals: <bullets>
Scope: <repo(s)> (JDK <…>)   |   from task-scoping

### Solution
Recommended: <approach, 2–4 lines>
Alternative: <approach + why not> (omit if only one sane path)
Trade-offs / key risks: <…>

### Implementation plan
For each step, in dependency order:
Step <n> — <short name>            Repo/files: <repo> · <path(s)>
  Objective: <1 line>
  Concrete implementation: <imperative sentences naming real classes/methods/files/endpoints>
  Reason: <why — requirement / root cause / rule>
  Dependencies: <step #s or "None">
  Expected outcome:
  - <fact 1>
  - <fact 2>

Include the forced steps (tests, cross-repo consumer sync, migration, review/MR) as their own numbered
steps in this same structure — not a side note.

### Estimate
| Work item | Size | Est (h) | Drivers |
|-----------|------|---------|---------|
| …implementation, tests, contract sync, migration, review/MR… |
Total: <opt>–<pess> h  (≈ <n> days, likely <m>)   Confidence: High|Medium|Low — <why>
Assumptions: <…>
Unknowns that change the estimate: <…>

Suggested next: /start-task → change-implementation
```

## Verification Checklist
- [ ] Every acceptance criterion appears in the plan (none dropped).
- [ ] Every step has Objective / Concrete implementation / Reason / Dependencies / Expected outcome,
      names real classes/methods/files (not category labels), and passes the readability gate — a
      mid-level engineer could implement it without asking a clarifying question (Step 5).
- [ ] No step relies on a vague verb (Improve/Optimize/Enhance/Refactor/Introduce/Leverage/Simplify/
      Strengthen) without the same sentence naming the concrete change.
- [ ] Steps mapped to real repos/files; cross-repo consumers + migration repo accounted for.
- [ ] Tests and review/MR included as work items, not assumed free — **except in-scope FE source**
      (`quapp-functions-frontend` entirely, `quapp-jupyterlab-ai-assistant-ext`'s TS/React `src/` only),
      which has no test-writing item per `rules/testing.md`.
- [ ] Estimate is a range with assumptions + confidence; unknowns listed; **contingency buffer included** in likely.
- [ ] No source-code changes made (the only writes are the ticket comment + estimate + Story Points + label + any sub-tasks).
- [ ] Solution + plan written in Vietnamese and posted as a markdown comment on the ticket (Step 8a).
- [ ] Original Estimate (likely, buffer in) **and Story Points (`customfield_10016` = likely ÷ 4)** set (Step 8b); role label applied, existing labels kept (Step 8c).
- [ ] If the user asked for sub-tasks: created under the ticket as meaningful units, each with role label + Original Estimate + **assignee (self)** summing to parent likely, **including a mandatory `Resolve feedback merge request` sub-task** (+ `Review code` and `QA` where relevant); status left at To Do (Step 8d).

## References
- [task-scoping](../task-scoping/SKILL.md) (input: where) · [change-implementation](../change-implementation/SKILL.md)
  (output: build it) · [completion-audit](../completion-audit/SKILL.md) (was it actually done) ·
  [bug-investigation](../bug-investigation/SKILL.md) (for bugs, plan the fix from the root cause).
- [`../../profiles/quapp/profile.md`](../../profiles/quapp/profile.md) · [`../../rules/`](../../rules/)
  (layering, JDK matrix, two DBs, contract sync, `java.md` gate).
