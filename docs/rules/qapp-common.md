# Rules — sdk/qapp-common

Shared Python runtime library for the Quapp quantum platform.
PyPI name: `quapp-common`. Current version: `0.0.13.dev5`.
GitLab: `quapp/platform/quapp-libs/qapp-common`. Branch: `develop` (auto-publish on push).

## What it provides

| Module area | Responsibility |
|-------------|---------------|
| `async_tasks/` | `AsyncInvocationTask` — runs handlers in a thread pool, returns immediate response |
| `component/` | `SubprocessBridge` — bridges Python orchestration ↔ JS/Q# handler subprocess |
| `factory/` | Provider/device factory (`DeviceFactory`, `ProviderFactory`) |
| `handler/` | `JobManager` — cross-process job registry (atomic add/update/get, pub-sub) |
| `model/` | Standard `Event`, `Result`, `Success`, `Error` models for async responses |
| `util/` | `dispatch()` (subprocess runner), `adapt()` (circuit format converter), `serialize()` |
| `enum/` | `Language` (PYTHON / JAVASCRIPT / QSHARP), `Sdk` (QISKIT / BRAKET / …) |
| `config/` | Logging + configuration utilities |

## Subprocess bridge contract (JS/Q# templates)

Python sends one of:
- `{"action": "processing", "input": {...}}` → handler returns circuit/problem description
- `{"action": "post_processing", "job_result": {...}}` → handler transforms provider result

Handler must write `{"status": "success", "result": <...>}` to stdout.
**Do not change this contract** without coordinating with all `quapp-sdk-templates` templates.

## Publish flow (CI: `.gitlab-ci.yml`)
- Push to `develop` → CI builds (`python -m build`) → `twine upload --repository pypi`.
- **`develop` is the publish trigger** — merging unreviewed code here auto-ships to PyPI.
- Bump `version` in `pyproject.toml` before merging anything that changes public API.

## Dependencies (key)
`loguru`, `requests`, `numpy`, `qiskit`, `pennylane`, `qibo`, `dimod`, `qulacs`, `pytket`,
`starlette` (from v0.0.11.dev7), `pylatexenc`, `matplotlib`.

## Build / test
```bash
python -m build          # build wheel
python -m pytest tests/  # run tests
```

## Safety notes
- This library is consumed by every function template and live function Docker image at runtime.
  A breaking change in `dispatch()` / `adapt()` / `serialize()` will break all multi-language templates.
- `JobManager` uses atomic file I/O for cross-process safety — do not replace with in-memory state.
- The `develop` branch publishes automatically — treat it as a protected branch even if GitLab doesn't enforce it.
