# Rules — GitNexus (code knowledge graph)

**Single source of truth for how skills use GitNexus in this workspace.** Skills link here instead of
restating tool usage. GitNexus is an MCP server + per-repo knowledge graph (symbols, calls, imports,
routes, processes) that replaces blind grep-crawling for navigation, tracing, and impact questions.

## What's indexed

All **6 repos** are indexed individually — each has its own `.gitnexus/` directory and registry entry
(this is not a monorepo; there is **no workspace-root index**). Repo names in tool calls = folder names:
`quapp-functions-backend`, `quapp-functions-frontend`, `quapp-ai-mcp`,
`quapp-jupyterlab-ai-assistant-ext`, `quapp-migration`, `quapp-ai-mcp-migration`.

- Embeddings are **off** (no semantic search); PDG/taint layers (`--pdg`) are **not built** — `explain`
  and `pdg_query` will report "no taint/PDG layer" unless someone runs `analyze --pdg`.
- The migration repos' graphs are tiny (mostly SQL changelogs) — GitNexus adds little there; plain
  file reads are fine.

## Freshness (check before trusting results)

The index is a snapshot of one commit + branch (visible in `gitnexus://repo/{name}/context` and
`node .gitnexus/run.cjs status`). It goes **stale after a commit, merge, or branch switch** in that repo.
- Stale → run `node .gitnexus/run.cjs analyze` **inside that repo** (regenerates in place).
- Uncommitted working-tree edits are *not* in the graph — combine `detect_changes` (graph-aware diff
  impact) with `git diff` for review of in-flight work.
- MCP connection note: the server entry in `~/.claude.json` must launch with a modern Node
  (Homebrew Node 26, `/opt/homebrew/opt/node@26/bin/node`); the default nvm Node 16 crashes it.

## Which tool for which phase

| Phase / question | Tool(s) | Instead of |
|------------------|---------|-----------|
| Scope a ticket — "where does this live?" | `query` (concept → flows), `gitnexus://repo/{name}/clusters` | broad grep across `src/` |
| Understand a symbol before editing | `context` (360° refs + processes) | reading every caller by hand |
| Root-cause a bug — "how does A reach B?" | `trace` (shortest CALLS path), `context` | manually chaining callers |
| Blast radius — "what breaks if I change X?" | `impact` (depth 1–3 + confidence) | grep for the name |
| Review a diff / pre-MR | `detect_changes` (git-diff impact), `impact` on changed symbols | eyeballing consumers |
| REST route ↔ consumer mapping | `route_map`, `api_impact`, `shape_check` | hand-matching services ↔ controllers |
| Rename / move / extract | `rename` (coordinated multi-file edits), `impact` first | find-and-replace |
| Anything structural the tools don't cover | `cypher` (read `gitnexus://repo/{name}/schema` first) | — |

Full tool reference + workflows live in the **global `gitnexus-*` skills** (`gitnexus-guide`,
`gitnexus-exploring`, `gitnexus-debugging`, `gitnexus-impact-analysis`, `gitnexus-refactoring`,
`gitnexus-cli`) — load the one matching the task.

## Cross-repo caveat (important in this workspace)

Each graph stops at its repo boundary. **A frontend→backend or ext→ai-mcp contract is invisible to a
single-repo `impact`/`trace` call** — no multi-repo group is configured (`group_list` is empty), so
cross-tier contract sync remains a **manual check** per `workspace.md` ("no generated client").
GitNexus helps per side: `route_map`/`api_impact` on the provider repo, `query`/`context` on the
consumer repo — then reconcile by hand. Never let a clean single-repo `impact` result be claimed as
proof that a DTO/route change is safe across tiers.

## Rules

1. **Prefer graph queries over blind grep** for navigation/tracing/impact in the 4 code repos; fall
   back to grep/Glob when the graph lacks the answer (config files, YAML, SQL, comments).
2. **Check freshness first** (`gitnexus://repo/{name}/context`) when results will drive a decision;
   re-analyze after switching branches — an index built on another branch silently lies.
3. GitNexus output is **evidence to verify, not proof**: confidence-tagged edges can be wrong; confirm
   at `file:line` by reading the code before reporting a finding (matches the code-review rule).
4. Cross-tier impact is out of graph scope — see the caveat above; keep the manual contract-sync check.
5. `rename` proposes edits — review them like any diff (approval gate in `change-implementation` still
   applies; no source edits before plan approval).
6. Don't run `analyze` mid-flight of someone else's long task, and never at the workspace root — always
   inside one repo.
7. **Subagents with a restricted `tools:` list cannot call GitNexus MCP tools** — `deep-reviewer` and
   `drafter` (Read/Grep/Glob/Bash only) have no graph access, and the CLI has no query commands. When
   spawning them, run `impact`/`detect_changes`/`trace` in the orchestrator first and paste the relevant
   output into the prompt. Workflow agents (default type) *can* load GitNexus tools via ToolSearch.
