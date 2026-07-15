#!/usr/bin/env bash
# session-start.sh — environment snapshot for the Quapp multi-root workspace.
#
# Registered as a SessionStart hook (startup|resume) in .claude/settings.json.
# Purely advisory: emits one hookSpecificOutput JSON with a compact snapshot
# (branch per repo, protected-branch/dirty warnings, JDK, Docker, GitNexus
# freshness). Disable entirely with QUAPP_SESSION_CHECK=off.

set -u

[ "${QUAPP_SESSION_CHECK:-on}" = "off" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
[ -d "$root" ] || exit 0

REPOS="functions/quapp-functions-backend functions/quapp-functions-frontend ai/quapp-ai-mcp ai/quapp-jupyterlab-ai-assistant-ext migration/quapp-migration migration/quapp-ai-mcp-migration"

lines=""
warns=""

append_line() { lines="${lines}${lines:+
}$1"; }
append_warn() { warns="${warns}${warns:+
}- $1"; }

for rel in $REPOS; do
  dir="$root/$rel"
  [ -d "$dir/.git" ] || continue
  name="${rel##*/}"

  branch="$(git -C "$dir" branch --show-current 2>/dev/null)"
  [ -z "$branch" ] && branch="(detached)"

  dirty=""
  [ -n "$(git -C "$dir" status --porcelain 2>/dev/null | head -1)" ] && dirty=" [dirty]"

  append_line "$name: $branch$dirty"

  case "$branch" in
    develop|staging|production|publish)
      if [ -n "$dirty" ]; then
        append_warn "$name has uncommitted changes ON PROTECTED BRANCH '$branch' — move work to a feature/bugfix branch before committing."
      else
        append_warn "$name is on '$branch' — never implement here; branch off the confirmed base (staging or latest production, never develop) first."
      fi
      ;;
  esac

  if [ -d "$dir/.gitnexus" ]; then
    head_ts="$(git -C "$dir" log -1 --format=%ct 2>/dev/null)"
    idx_ts="$(find "$dir/.gitnexus" -type f -exec stat -f %m {} + 2>/dev/null | sort -rn | head -1)"
    if [ -n "$head_ts" ] && [ -n "$idx_ts" ] && [ "$idx_ts" -lt "$head_ts" ]; then
      append_warn "$name GitNexus index looks older than HEAD — reanalyze before trusting graph queries."
    fi
  fi
done

jdk=""
case "${JAVA_HOME:-}" in
  *17*) jdk="17" ;;
  *21*) jdk="21" ;;
esac
[ -z "$jdk" ] && jdk="$(java -version 2>&1 | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p' | head -1)"
append_line "Active JDK: ${jdk:-unknown} (backend & quapp-migration need 17; ai-mcp & ai-mcp-migration need 21)"

if ! command -v docker >/dev/null 2>&1; then
  append_line "Docker: not installed — Testcontainers-based tests cannot run; verify via local Homebrew postgres instead."
fi

msg="Quapp workspace snapshot:
$lines"
if [ -n "$warns" ]; then
  msg="$msg

Warnings:
$warns"
fi

jq -n --arg msg "$msg" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$msg}}'
exit 0
