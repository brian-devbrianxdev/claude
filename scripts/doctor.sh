#!/usr/bin/env bash
# scripts/doctor.sh — environment check for the Quapp Claude Code harness.
#
# Run: bash .claude/scripts/doctor.sh
#
# Verifies the dependencies this harness assumes are present (README.md's
# Required/Optional lists) and flags the one thing a fresh clone always
# needs to author itself: the root CLAUDE.md that several skills read for
# the repository map (task-scoping, change-implementation, completion-audit,
# review-mr all key off `CLAUDE.md` → Repository Map — see
# examples/CLAUDE.md for a fill-in-the-blanks template).
#
# Exit code: 0 if no REQUIRED check failed, 1 otherwise. WARN checks
# (optional integrations) never fail the run.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$CLAUDE_DIR/.." && pwd)"

FAIL=0
WARN=0

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL + 1)); }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; WARN=$((WARN + 1)); }

echo "=== Quapp Claude Code harness — environment check ==="
echo "Workspace root: $WORKSPACE_ROOT"
echo ""

echo "-- Required --"

if command -v jq >/dev/null 2>&1; then
  pass "jq installed ($(jq --version 2>/dev/null))"
else
  fail "jq not found — hooks/quapp-guard.sh and hooks/session-start.sh degrade without it. Install: brew install jq"
fi

if command -v git >/dev/null 2>&1; then
  pass "git installed ($(git --version 2>/dev/null))"
else
  fail "git not found."
fi

if command -v glab >/dev/null 2>&1; then
  if glab auth status >/dev/null 2>&1; then
    pass "glab installed and authenticated"
  else
    warn "glab installed but not authenticated for gitlab.citynow.vn — run 'glab auth login'. Required for /ship-task, /review-mr, mr-feedback."
  fi
else
  fail "glab not found — required for MR creation/review (/ship-task, /review-mr, mr-feedback). Install: brew install glab"
fi

java17=0
java21=0
# macOS registry lookup (only finds JDKs symlinked under /Library/Java/JavaVirtualMachines).
if command -v /usr/libexec/java_home >/dev/null 2>&1; then
  /usr/libexec/java_home -v 17 >/dev/null 2>&1 && java17=1
  /usr/libexec/java_home -v 21 >/dev/null 2>&1 && java21=1
fi
# Homebrew keg-only openjdk formulae are NOT registered with java_home by default
# (workspace.md notes this repo's own terminal JAVA_HOME points at a Homebrew openjdk@21) —
# check both Apple Silicon and Intel prefixes directly.
if [ "$java17" = 0 ]; then
  for p in /opt/homebrew/opt/openjdk@17 /usr/local/opt/openjdk@17; do
    [ -x "$p/bin/java" ] && java17=1
  done
fi
if [ "$java21" = 0 ]; then
  for p in /opt/homebrew/opt/openjdk@21 /usr/local/opt/openjdk@21; do
    [ -x "$p/bin/java" ] && java21=1
  done
fi
# Linux fallback: look for common install roots.
if [ "$java17" = 0 ] && compgen -G "/usr/lib/jvm/*17*" >/dev/null 2>&1; then
  java17=1
fi
if [ "$java21" = 0 ] && compgen -G "/usr/lib/jvm/*21*" >/dev/null 2>&1; then
  java21=1
fi
if [ "$java17" = 1 ]; then
  pass "Java 17 available (functions-backend, quapp-migration)"
else
  fail "Java 17 not found via java_home/jvm dirs — required for functions-backend and quapp-migration. Verify manually if you use sdkman/jenv/asdf instead."
fi
if [ "$java21" = 1 ]; then
  pass "Java 21 available (ai-mcp, ai-mcp-migration)"
else
  fail "Java 21 not found via java_home/jvm dirs — required for ai-mcp and ai-mcp-migration. Verify manually if you use sdkman/jenv/asdf instead."
fi

echo ""
echo "-- Repository map dependency --"

ROOT_CLAUDE_MD="$WORKSPACE_ROOT/CLAUDE.md"
if [ -f "$ROOT_CLAUDE_MD" ]; then
  if grep -q "Repository Map" "$ROOT_CLAUDE_MD" 2>/dev/null; then
    pass "Root CLAUDE.md found with a Repository Map section ($ROOT_CLAUDE_MD)"
  else
    warn "Root CLAUDE.md found but no 'Repository Map' heading — task-scoping/change-implementation/completion-audit/review-mr expect one. See examples/CLAUDE.md."
  fi
else
  fail "No root CLAUDE.md at $ROOT_CLAUDE_MD. Several skills (task-scoping, change-implementation, completion-audit, review-mr) read 'CLAUDE.md → Repository Map' to identify which repo a task targets — this file is workspace-specific and is NOT shipped in this harness. Copy examples/CLAUDE.md to $ROOT_CLAUDE_MD and fill in your own repos."
fi

echo ""
echo "-- Optional --"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  pass "Docker available (Testcontainers integration tests can run)"
else
  warn "Docker not available — Testcontainers-based integration tests (ai-mcp, quapp-migration) can't run locally. See rules/testing.md for the Homebrew Postgres fallback."
fi

echo "  INFO  fable model alias, GitNexus MCP, and Atlassian MCP can't be probed from a shell script"
echo "        (they're Claude Code /model and MCP registrations, not CLI binaries)."
echo "        Verify with /model and by listing connected MCP servers inside a session."

echo ""
echo "==========================================="
echo "Results: $FAIL required check(s) failed, $WARN warning(s)"
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "STATUS: FAIL — resolve the FAIL items above before relying on the full lifecycle (/start-task, /ship-task)."
  exit 1
else
  echo "STATUS: OK"
  exit 0
fi
