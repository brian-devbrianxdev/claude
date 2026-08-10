# Rules — tools/quapp-python-compliance-guard

Standalone **FastAPI** service that validates user-submitted quantum-function code before the platform
accepts it. GitLab: `quapp/platform/quapp-tools/quapp-python-compliance-guard`.

> **This is where code validation lives — not in `quapp-functions-backend`.** A syntax or
> handler-contract validation bug is fixed *here*, even though the symptom surfaces in the backend.

## Shape

Flat, single-module service — `main.py` (all logic) + `messages.py` (i18n message catalog).
No `src/` layout, no framework layering. Docker + `k8s/` manifests, deployed like the Java services.

| Path | Role |
|------|------|
| `main.py` | FastAPI app, parsers, validation rules, endpoints |
| `messages.py` | `get_messages()` — user-facing validation messages |
| `test_main.py` | pytest suite (the repo's only tests) |

## API

| Endpoint | Purpose |
|----------|---------|
| `POST /api/v1/validate` | Validate a code file; returns `ValidationResponse` |
| `GET /healthcheck` | Liveness probe |

Request body is capped at `MAX_BODY_SIZE` (1 MB).

## Parsers & supported languages

`SUPPORTED_LANGUAGES` in `main.py` is the gate. Python is parsed with the stdlib `ast`; everything else
with **tree-sitter** grammars pinned in `requirements.txt`:

| Language | Parser |
|----------|--------|
| `python` | stdlib `ast` |
| `javascript` | `tree-sitter-javascript` |
| `qsharp` | `tree-sitter-qsharp` |

Check `SUPPORTED_LANGUAGES` on the branch you're working from — it changes as languages are added.

Beyond syntax, it checks the **handler contract** — that `processing` / `post_processing` entry points
exist with the accepted naming variants (`postProcessing`, `PostProcessing`, `post_processing`).

## ⚠️ Language support must land here too

Adding a new language to the platform is **not** done when the backend and templates support it —
a language this service doesn't know is not meaningfully validated, and the gap is easy to miss
because it does not surface as an obvious failure downstream.

Always add the grammar + `SUPPORTED_LANGUAGES` entry **in the same release** as the platform-side
support, and verify end-to-end rather than assuming a passing create-function call means the code
was checked.

## Adding a language
1. Add the `tree-sitter-<lang>` grammar to `requirements.txt` (pin the version).
2. Build its `Language`/`Parser` pair at module scope in `main.py`, next to the existing ones.
3. Add the name to `SUPPORTED_LANGUAGES`.
4. Implement the syntax-error path and the handler-contract check for that language.
5. Add messages to `messages.py` and cases to `test_main.py`.

## Branch model & CI
Standard for this workspace: `develop` / `staging` / `production`, stages `build → deploy`
(Docker image → GitLab registry → `kubectl apply` of `k8s/`). Same branch-base rule as everywhere —
confirm the base per fix; never default to `develop` (see [git-workflow.md](../../rules/git-workflow.md)).

## Tests
`python -m pytest test_main.py` (no Docker needed). Every validation-rule change needs a case here —
this repo is Python, so the frontend test exception in
[testing.md](../../rules/testing.md) does **not** apply.
