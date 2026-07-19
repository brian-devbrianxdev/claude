#!/usr/bin/env bash
# scripts/check-frontmatter.sh — validate YAML frontmatter on skills/agents/commands.
#
# Run: bash .claude/scripts/check-frontmatter.sh
#
# Checks (deliberately simple grep-based checks, not a real YAML parser —
# good enough to catch a missing/misnamed field, which is the actual
# recurring failure mode when a skill or agent is renamed):
#   skills/*/SKILL.md   — has `name:` (matching the skill's directory name)
#                          and a non-empty `description:`
#   agents/*.md          — has `name:` (matching the filename), `description:`,
#                          `model:`, and `tools:`
#   commands/*.md         — has a non-empty `description:` (name comes from
#                          the filename, not a frontmatter field)
#
# Exit: 0 if everything checked out, 1 if any file failed a check.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$CLAUDE_DIR" || exit 1

FAIL=0

# Extract the frontmatter block (between the first two "---" lines) of a file.
frontmatter() {
  awk 'NR==1 && $0!="---"{exit} NR==1{next} /^---$/{exit} {print}' "$1"
}

# Pull a "key: value" field's value out of a frontmatter block (single-line values only).
field() {
  printf '%s\n' "$1" | grep -m1 -E "^${2}:" | sed -E "s/^${2}:[[:space:]]*//"
}

check_skill() {
  local file="$1" dirname fm name desc
  dirname="$(basename "$(dirname "$file")")"
  fm="$(frontmatter "$file")"
  if [ -z "$fm" ]; then
    echo "FAIL  $file — no frontmatter block found (expected --- ... --- at top)"
    FAIL=$((FAIL + 1))
    return
  fi
  name="$(field "$fm" "name")"
  desc="$(field "$fm" "description")"
  if [ -z "$name" ]; then
    echo "FAIL  $file — missing 'name:' in frontmatter"
    FAIL=$((FAIL + 1))
  elif [ "$name" != "$dirname" ]; then
    echo "FAIL  $file — frontmatter name '$name' does not match directory '$dirname'"
    FAIL=$((FAIL + 1))
  fi
  if [ -z "$desc" ]; then
    echo "FAIL  $file — missing or empty 'description:' in frontmatter"
    FAIL=$((FAIL + 1))
  fi
}

check_agent() {
  local file="$1" base fm name desc model tools
  base="$(basename "$file" .md)"
  fm="$(frontmatter "$file")"
  if [ -z "$fm" ]; then
    echo "FAIL  $file — no frontmatter block found"
    FAIL=$((FAIL + 1))
    return
  fi
  name="$(field "$fm" "name")"
  desc="$(field "$fm" "description")"
  model="$(field "$fm" "model")"
  tools="$(field "$fm" "tools")"
  [ -z "$name" ] && { echo "FAIL  $file — missing 'name:'"; FAIL=$((FAIL + 1)); }
  [ -n "$name" ] && [ "$name" != "$base" ] && { echo "FAIL  $file — frontmatter name '$name' does not match filename '$base'"; FAIL=$((FAIL + 1)); }
  [ -z "$desc" ] && { echo "FAIL  $file — missing or empty 'description:'"; FAIL=$((FAIL + 1)); }
  [ -z "$model" ] && { echo "FAIL  $file — missing 'model:' (agents must pin a model — see docs/rules/model-routing.md)"; FAIL=$((FAIL + 1)); }
  [ -z "$tools" ] && { echo "FAIL  $file — missing 'tools:' (agents must declare an explicit tool allowlist)"; FAIL=$((FAIL + 1)); }
}

check_command() {
  local file="$1" fm desc
  fm="$(frontmatter "$file")"
  if [ -z "$fm" ]; then
    echo "FAIL  $file — no frontmatter block found"
    FAIL=$((FAIL + 1))
    return
  fi
  desc="$(field "$fm" "description")"
  [ -z "$desc" ] && { echo "FAIL  $file — missing or empty 'description:'"; FAIL=$((FAIL + 1)); }
}

for f in skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  check_skill "$f"
done

for f in agents/*.md; do
  [ -f "$f" ] || continue
  check_agent "$f"
done

for f in commands/*.md; do
  [ -f "$f" ] || continue
  check_command "$f"
done

echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "STATUS: FAIL ($FAIL issue(s))"
  exit 1
else
  echo "STATUS: OK — all skill/agent/command frontmatter valid"
  exit 0
fi
