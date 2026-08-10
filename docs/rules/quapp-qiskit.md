# Rules — sdk/quapp-qiskit

Qiskit **provider library** for the Quapp platform. PyPI name: `quapp-qiskit`.
GitLab: `quapp/platform/quapp-libs/quapp-qiskit`.

Sibling of [`qapp-common`](qapp-common.md): `quapp-common` is the generic runtime, `quapp-qiskit` is the
Qiskit-specific provider/device implementation layered on it.

## ⚠️ Publish branch is `release/qiskit-v1`, not `develop`

This repo breaks the workspace pattern. `origin/HEAD → origin/release/qiskit-v1`, and the CI publish
job (`python -m build` → `twine upload --repository pypi`) is gated on:

```
if: '$CI_COMMIT_BRANCH == "release/qiskit-v1"'
```

**Merging to `release/qiskit-v1` publishes to PyPI.** `develop` here does *not* publish — do not assume
the `qapp-common` "develop auto-publishes" rule applies. Confirm base and target per change.

## ⚠️ Pinned dependency on quapp-common

`pyproject.toml` pins exact versions, e.g. `quapp-common==0.0.11.dev7`, alongside
`qiskit==1.3.2`, `qiskit-aer`, `qiskit-ibm-runtime`, `oqc-qcaas-client`.
Python: `>=3.9,<3.11`.

A breaking change in `quapp-common` **does not reach this library until the pin is bumped**. Publish in
dependency order: `quapp-common` → bump the pin here → `quapp-qiskit`. Version bumps show up as
dedicated `build/bump-*` branches.

## Module map

| Module | Responsibility |
|--------|---------------|
| `factory/` | `QiskitDeviceFactory`, `QiskitProviderFactory`, `QiskitHandlerFactory` |
| `model/provider/` | `IbmCloudProvider`, `IbmQuantumProvider`, `OqcCloudProvider`, `QappQiskitProvider` |
| `model/device/` | matching devices — `IbmCloudDevice`, `IbmQuantumDevice`, `OqcCloudDevice`, `QappQiskitDevice`, base `QiskitDevice` |
| `component/backend/` | `qiskit_invocation.py`, `qiskit_job_fetching.py` |
| `handler/` | `invocation_handler.py`, `job_fetching_handler.py` |
| `async_tasks/` | `qiskit_circuit_export_task.py` |
| `bridge/` | `native_qiskit_bridge.py` — native bridge path (PQF-22441) |

Provider/device pairs are parallel hierarchies — **adding a backend means adding both**, plus wiring in
the corresponding factory.

## Tests
`python -m pytest tests/` — note the `tests/` directory currently holds no committed test modules, so a
green run proves nothing. Add real cases alongside behavior changes; this is a published library, and a
regression ships straight to every function image that installs it.
