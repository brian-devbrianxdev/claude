#!/usr/bin/env python3
"""Generate GitNexus group manifest links (frontend -> backend/ai-mcp HTTP contracts).

GitNexus's built-in TS consumer detection only recognizes axios/fetch call sites,
so the UmiJS `request` wrapper in quapp-functions-frontend yields zero consumer
contracts and `group sync` produces no cross-links. This script closes that gap
deterministically: it reads the frontend's single endpoint-constant registry,
matches each path against the provider contracts extracted from the backend /
ai-mcp indexes, and writes the matches into the group.yaml `links:` section.

Re-run after `gitnexus analyze` on any member repo, then `gitnexus group sync quapp`.
Idempotent: regenerates the whole links list on every run.

Path normalization contract (verify if matching drops sharply):
  - frontend requestBaseURL = ${BASE_URL}/api/v1; backend serves /api (servlet
    context) + /v1/... mappings -> frontend "/X" matches provider "/v1/X".
  - `${...}` template and `:name` placeholder segments -> `{param}` (GitNexus's
    normalized form); query strings are stripped before matching.
Endpoints whose params are appended at the call site (not in the constant)
only match their static prefix form and are reported as unmatched — that
residue stays a manual check.
"""

import json
import re
import sys
from pathlib import Path

import yaml

WORKSPACE = Path(__file__).resolve().parents[2]
ENDPOINTS_FILE = (
    WORKSPACE
    / "functions/quapp-functions-frontend/src/constants/endpoints/index.ts"
)
GROUP_DIR = Path.home() / ".gitnexus/groups/quapp"
CONTRACTS = GROUP_DIR / "contracts.json"
GROUP_YAML = GROUP_DIR / "group.yaml"

FRONTEND = "platform/frontend"
PROVIDER_REPOS = ("platform/backend", "ai/mcp")


def frontend_paths():
    text = ENDPOINTS_FILE.read_text(encoding="utf-8")
    paths = {}
    for name, raw in re.findall(
        r'([A-Z][A-Z0-9_]*)\s*=\s*[`"\']([^`"\']+)[`"\']', text
    ):
        if not raw.startswith("/"):
            continue
        norm = raw.split("?")[0]
        norm = re.sub(r"\$\{[^}]+\}", "{param}", norm)
        norm = re.sub(r"(?<=/):[A-Za-z_][A-Za-z0-9_]*", "{param}", norm)
        paths[name] = "/v1" + norm
    return paths


def provider_routes():
    data = json.loads(CONTRACTS.read_text(encoding="utf-8"))
    routes = {}
    for c in data["contracts"]:
        if c["role"] != "provider" or c["repo"] not in PROVIDER_REPOS:
            continue
        # test-source controllers (backend src/test) are not real API surface
        if c["symbolRef"]["filePath"].startswith("src/test/"):
            continue
        _, method, path = c["contractId"].split("::", 2)
        routes.setdefault(path, []).append((method, c["repo"]))
    return routes


def main():
    endpoints = frontend_paths()
    routes = provider_routes()

    links, matched = [], set()
    for name, path in sorted(endpoints.items()):
        for method, repo in sorted(routes.get(path, [])):
            links.append(
                {
                    "from": FRONTEND,
                    "to": repo,
                    "type": "http",
                    "contract": f"{method}::{path}",
                    "role": "consumer",
                }
            )
            matched.add(name)

    config = yaml.safe_load(GROUP_YAML.read_text(encoding="utf-8"))
    config["links"] = links
    GROUP_YAML.write_text(
        yaml.safe_dump(config, sort_keys=False, allow_unicode=True),
        encoding="utf-8",
    )

    unmatched = sorted(set(endpoints) - matched)
    print(f"endpoints: {len(endpoints)}  matched: {len(matched)}  links: {len(links)}")
    if unmatched:
        print(f"unmatched ({len(unmatched)}): " + ", ".join(unmatched[:20]))
        if len(unmatched) > 20:
            print(f"  ... and {len(unmatched) - 20} more")
    print("next: gitnexus group sync quapp")
    return 0


if __name__ == "__main__":
    sys.exit(main())
