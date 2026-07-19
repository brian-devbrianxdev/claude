#!/usr/bin/env bash
# scripts/check-markdown-links.sh — verify relative markdown links resolve to real files.
#
# Run: bash .claude/scripts/check-markdown-links.sh
#
# Scans every tracked .md file for [text](path) links. Skips absolute URLs
# (http/https/mailto) and bare same-file anchors (#heading). For everything
# else, resolves the path relative to the linking file's directory (stripping
# any trailing #anchor) and fails if the target doesn't exist. Vendored
# third-party content (plugins/marketplaces/) and retired skills
# (_archived-skills/, explicitly out of discovery and unmaintained per
# README.md) are out of scope. A link that resolves to a path outside this
# .claude/ checkout (e.g. the workspace-root CLAUDE.md or mcp.json some
# skills reference — files this harness expects but doesn't ship, same as
# examples/CLAUDE.md documents) is reported as INFO, not a failure — we
# can't validate a file this repo doesn't contain.
#
# Exit: 0 if every in-repo link resolves, 1 if any is broken.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$CLAUDE_DIR" || exit 1

# Pure-bash path normalizer (resolves "." and ".." segments) using only
# parameter expansion (no arrays) — avoids both GNU realpath's -m flag
# (missing from macOS's BSD realpath) and a bash-3.2 quirk where a quoted
# array-slice reassignment (parts=("${parts[@]:0:N}")) under IFS='/' merges
# elements instead of preserving them (macOS's default /bin/bash is 3.2).
normalize_path() {
  local input result seg rest
  input="$1"
  result=""
  rest="$input"
  while [ -n "$rest" ]; do
    seg="${rest%%/*}"
    case "$rest" in
      */*) rest="${rest#*/}" ;;
      *) rest="" ;;
    esac
    case "$seg" in
      ""|".") : ;;
      "..") result="${result%/*}" ;;
      *) result="$result/$seg" ;;
    esac
  done
  printf '%s' "$result"
}

BROKEN=0
EXTERNAL=0
CHECKED=0

while IFS= read -r -d '' file; do
  dir="$(dirname "$file")"
  # Extract "(path)" out of every [text](path) occurrence, one per line.
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    case "$link" in
      http://*|https://*|mailto:*) continue ;;
      \#*) continue ;;  # same-file anchor, not a file reference
    esac
    target="${link%%#*}"  # strip trailing #anchor before resolving
    [ -z "$target" ] && continue
    resolved="$dir/$target"
    CHECKED=$((CHECKED + 1))
    # Normalize and check whether it escapes this .claude/ checkout entirely
    # (e.g. ../../../mcp.json from a skill three levels deep, or a link that
    # walks up past CLAUDE_DIR) — such a target is workspace-root content
    # this repo intentionally doesn't ship, not a broken in-repo link.
    normalized="$(normalize_path "$CLAUDE_DIR/$dir/$target")"
    if [ -n "$normalized" ] && [ "${normalized#"$CLAUDE_DIR"}" = "$normalized" ]; then
      echo "INFO    $file -> $link  (external dependency outside .claude/, not validated)"
      EXTERNAL=$((EXTERNAL + 1))
      continue
    fi
    if [ ! -e "$resolved" ]; then
      echo "BROKEN  $file -> $link  (resolved: $resolved)"
      BROKEN=$((BROKEN + 1))
    fi
  done < <(grep -oE '\]\([^)[:space:]]+\)' "$file" | sed -E 's/^\]\((.*)\)$/\1/')
done < <(git ls-files -z '*.md' | grep -zv '^plugins/marketplaces/\|^_archived-skills/')

echo ""
echo "Checked $CHECKED relative link(s); $EXTERNAL external (unvalidated); $BROKEN broken."
if [ "$BROKEN" -gt 0 ]; then
  exit 1
fi
exit 0
