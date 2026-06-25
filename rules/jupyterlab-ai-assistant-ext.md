# Rules — `ai/quapp-jupyterlab-ai-assistant-ext` (JupyterLab AI assistant)

## ⚠️ Source of truth is `AGENTS.md`
In this repo, **`CLAUDE.md` and `GEMINI.md` are symlinks to `AGENTS.md`** (verified). Edit `AGENTS.md`,
never the symlinks. **Read `AGENTS.md` before changing this extension** — it holds the authoritative,
detailed Do/Don't coding rules (no `console.log`, no `any`, no TODOs/dead code, keep backend and
frontend logic separate, file-scoped validation, naming, plugin/command ID conventions, and a list of
required external JupyterLab docs). This file only summarizes; `AGENTS.md` governs.

## Responsibility
In-IDE AI assistant for Quapp's JupyterLab-based IDE. A `frontend-and-server` extension: a TS/React UI
panel plus a Python (Jupyter) server extension that proxies requests to the **MCP API**
(`quapp-ai-mcp`). It is the IDE-side client of the same AI service the web frontend uses.

## Stack
- JupyterLab **>= 4**. Python pkg `quapp_jupyterlab_ai_assistant` (server extension) + npm pkg
  `quapp-jupyterlab-ai-assistant` (frontend). `requestAPI()` bridges TS → Python. STOMP websockets +
  HTTP client to MCP.

## Structure
- **Python** (`quapp_jupyterlab_ai_assistant/`): `handlers/`, `routes`, `mcp/` + `mcp_http_client.py`
  (MCP HTTP client), `providers/`, `quantum/`, `stomp/` (websockets), `auth/`, `workspace/`, `ai/`,
  `manager.py`, `constants.py`, `endpoint_logger.py`, `logger_config.py`, `tests/`.
- **TypeScript** (`src/`): `index.ts` (plugin entry), `handler.ts`, `services/`, `stores/`, `hooks/`,
  `components/`, `containers/`, `views/`, `layouts/`, `websocket-generate.ts`, `i18n/`, `types.ts`.

## Build / dev (uses `jlpm`, JupyterLab's pinned yarn)
```bash
pip install --editable ".[dev,test]"
jupyter labextension develop . --overwrite
jupyter server extension enable quapp_jupyterlab_ai_assistant
jlpm build        # rebuild TS after every change
jlpm watch        # + `jupyter lab` in another terminal
jlpm test         # Jest (frontend)
pytest -vv -r ap --cov quapp_jupyterlab_ai_assistant   # server tests
```
Per-file validation: `npx tsc --noEmit src/<file>.ts`; `python -m py_compile <file>.py`.
Testing detail in `testing.md`. Release/publish flow in `git-workflow.md`.

## Coding style (frontend TS)
- **No comments and no unit tests when implementing frontend (`src/` TS/React) code.** Write
  self-explanatory code; do **not** add JSDoc, inline, or explanatory comments, and do **not** author
  new Jest specs (`src/__tests__/*.spec.ts(x)`) for frontend changes — unless the user explicitly asks.
- **Only import-struct comments are allowed** — the import-grouping headers (`// libs`, `// types`,
  `// stores`, `// i18n`, `// components`, `// others`, …). Nothing else.
- This **overrides** `AGENTS.md`'s "Add JSDoc for TypeScript" and "write tests" guidance **for frontend
  TS code**. It does not relax the Python server-side rules in `AGENTS.md`. Pre-existing tests still run
  for verification (`jlpm test`).

## Pitfalls
- After any TS change run `jlpm build` (or keep `jlpm watch` running); re-run `labextension develop`
  after reinstalling the Python package.
- Keep backend (Python `routes`) and frontend (TS `src/request`/`handler.ts`) logic separate — don't
  duplicate business logic across the two.
- Talks to ai-mcp `/api/v1` via `mcp_http_client.py` — MCP endpoint/DTO changes need matching edits here.
- **`jlpm` needs a modern Node** — Node 16 is too old and fails confusingly; Homebrew Node 26 is
  known-good. Ensure a modern Node is active before `jlpm build`/`watch`.
