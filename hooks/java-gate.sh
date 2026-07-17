#!/usr/bin/env bash
# java-gate.sh — Java coding-standards reminder for the Quapp workspace.
#
# Registered as a PreToolUse and PostToolUse hook (Edit|Write) in .claude/settings.json.
# Emits an advisory context message when a .java file is being edited.
# Disable entirely with QUAPP_JAVA_GATE=off.

set -u

[ "${QUAPP_JAVA_GATE:-on}" = "off" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  echo "Quapp Java gate skipped: jq is not installed." >&2
  exit 0
fi

event="${HOOK_EVENT_NAME:-PreToolUse}"
input="$(cat)"

# Determine file path from pre or post tool-use payload
fp="$(printf '%s' "$input" | jq -r '
  .tool_input.file_path //
  .tool_input.new_string //
  .tool_response.filePath //
  "" ')"

# Only act on .java files
case "$fp" in
  *.java) ;;
  *) exit 0 ;;
esac

case "$event" in
  PreToolUse)
    msg="Java gate (.claude/rules/java.md): no redundant comments (allowed only for non-obvious invariants, workarounds, security/compatibility rationale), tests mandatory, review gate before commit."
    ;;
  PostToolUse)
    msg="Before committing .java changes: run affected tests + code-review gate (.claude/rules/java.md)."
    ;;
  *)
    exit 0
    ;;
esac

jq -n --arg msg "$msg" --arg event "$event" \
  '{hookSpecificOutput:{hookEventName:$event,additionalContext:$msg}}'
exit 0
