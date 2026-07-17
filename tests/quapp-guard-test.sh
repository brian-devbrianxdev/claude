#!/usr/bin/env bash
# tests/quapp-guard-test.sh — regression suite for hooks/quapp-guard.sh
# Run: bash .claude/tests/quapp-guard-test.sh
# Requires jq for the full-guard path.

set -u

GUARD_SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/hooks/quapp-guard.sh"

if [ ! -f "$GUARD_SCRIPT" ]; then
  echo "ERROR: guard script not found at $GUARD_SCRIPT" >&2
  exit 1
fi

PASS=0
FAIL=0

# ── helpers ──────────────────────────────────────────────────────────────────

# Pipe a Bash tool_use JSON payload through the guard; assert expected decision.
assert_bash() {
  local desc="$1" cmd="$2" expect="$3" cwd="${4:-/some/path}"

  local escaped_cmd escaped_cwd result got_deny
  escaped_cmd="$(printf '%s' "$cmd"  | sed 's/\\/\\\\/g; s/"/\\"/g')"
  escaped_cwd="$(printf '%s' "$cwd"  | sed 's/\\/\\\\/g; s/"/\\"/g')"

  result=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s"}' \
    "$escaped_cmd" "$escaped_cwd" | bash "$GUARD_SCRIPT" 2>/dev/null)

  got_deny=false
  # jq pretty-prints with a space: "permissionDecision": "deny" — use .* to match
  echo "$result" | grep -q '"permissionDecision".*"deny"' && got_deny=true

  if [ "$expect" = "deny" ] && $got_deny; then
    echo "PASS [deny]  $desc"
    PASS=$((PASS + 1))
  elif [ "$expect" = "allow" ] && ! $got_deny; then
    echo "PASS [allow] $desc"
    PASS=$((PASS + 1))
  elif [ "$expect" = "deny" ] && ! $got_deny; then
    echo "FAIL [expected deny, got allow]  $desc"
    echo "     result: $result"
    FAIL=$((FAIL + 1))
  else
    echo "FAIL [expected allow, got deny]  $desc"
    echo "     result: $result"
    FAIL=$((FAIL + 1))
  fi
}

# Pipe an Edit/Write tool_use JSON payload through the guard; assert expected decision.
assert_edit() {
  local desc="$1" path="$2" expect="$3" tool="${4:-Edit}"

  local result got_deny
  result=$(printf '{"tool_name":"%s","tool_input":{"file_path":"%s","old_string":"x","new_string":"y"}}' \
    "$tool" "$path" | bash "$GUARD_SCRIPT" 2>/dev/null)

  got_deny=false
  echo "$result" | grep -q '"permissionDecision".*"deny"' && got_deny=true

  if [ "$expect" = "deny" ] && $got_deny; then
    echo "PASS [deny]  $desc"
    PASS=$((PASS + 1))
  elif [ "$expect" = "allow" ] && ! $got_deny; then
    echo "PASS [allow] $desc"
    PASS=$((PASS + 1))
  elif [ "$expect" = "deny" ] && ! $got_deny; then
    echo "FAIL [expected deny, got allow]  $desc"
    echo "     result: $result"
    FAIL=$((FAIL + 1))
  else
    echo "FAIL [expected allow, got deny]  $desc"
    echo "     result: $result"
    FAIL=$((FAIL + 1))
  fi
}

# ── test matrix ──────────────────────────────────────────────────────────────

echo ""
echo "=== quapp-guard.sh regression suite ==="
echo "Guard: $GUARD_SCRIPT"
echo ""

# ── rm -rf: dangerous targets ─────────────────────────────────────────────────
echo "---- rm -rf: dangerous targets (DENY expected) ----"
assert_bash "rm -rf / (unquoted)"              'rm -rf /'          deny
assert_bash 'rm -rf "/" (quoted slash)'         'rm -rf "/"'        deny
assert_bash "rm -rf . (unquoted dot)"          'rm -rf .'          deny
assert_bash 'rm -rf "." (quoted dot)'          'rm -rf "."'        deny
assert_bash "rm -fr . (reversed flags)"        'rm -fr .'          deny
assert_bash "rm -rf .git (unquoted)"           'rm -rf .git'       deny
assert_bash 'rm -rf ".git" (quoted)'           'rm -rf ".git"'     deny
assert_bash "rm -rf .env (unquoted)"           'rm -rf .env'       deny
assert_bash 'rm -rf ".env" (quoted)'           'rm -rf ".env"'     deny
assert_bash "rm -rf * (wildcard)"              'rm -rf *'          deny
assert_bash "rm --recursive --force /"         'rm --recursive --force /'   deny
assert_bash "rm --force --recursive /"         'rm --force --recursive /'   deny
echo ""

# ── rm -rf: safe targets ──────────────────────────────────────────────────────
echo "---- rm -rf: safe targets (ALLOW expected) ----"
assert_bash "rm -rf build/"             'rm -rf build/'              allow
assert_bash "rm -rf dist/"             'rm -rf dist/'               allow
assert_bash "rm -rf node_modules/"     'rm -rf node_modules/'       allow
assert_bash "rm -rf .gradle/"          'rm -rf .gradle/'            allow
assert_bash "rm -rf ./build/"          'rm -rf ./build/'            allow
assert_bash "rm -rf /tmp/workdir/"     'rm -rf /tmp/workdir/'       allow
assert_bash "rm -f single-file"        'rm -f file.txt'             allow
assert_bash "rm -rf .env.example"      'rm -rf .env.example'        allow
assert_bash "rm -rf .gitignore"        'rm -rf .gitignore'          allow
echo ""

# ── git reset --hard ──────────────────────────────────────────────────────────
echo "---- git reset --hard (DENY expected) ----"
assert_bash "git reset --hard HEAD"                  'git reset --hard HEAD'                    deny
assert_bash "git reset --hard (no ref)"              'git reset --hard'                         deny
assert_bash "git -C /path reset --hard HEAD"         'git -C /path/to/repo reset --hard HEAD'  deny
assert_bash "git --git-dir=.git reset --hard HEAD"   'git --git-dir=.git reset --hard HEAD'    deny
echo ""

echo "---- git reset --hard in commit message (ALLOW expected) ----"
assert_bash "commit message contains reset text"  \
  'git commit -m "describes git reset --hard behavior"'  allow
echo ""

# ── git clean -f ──────────────────────────────────────────────────────────────
echo "---- git clean -f (DENY expected) ----"
assert_bash "git clean -fd"             'git clean -fd'            deny
assert_bash "git clean -f"             'git clean -f'             deny
assert_bash "git -C /repo clean -fd"   'git -C /repo clean -fd'   deny
echo ""

# ── git branch -D ─────────────────────────────────────────────────────────────
echo "---- git branch -D (DENY expected) ----"
assert_bash "git branch -D feature/foo"           'git branch -D feature/foo'          deny
assert_bash "git -C /r branch -D feature/foo"     'git -C /r branch -D feature/foo'    deny
echo ""

# ── git push --force ──────────────────────────────────────────────────────────
echo "---- git push --force (DENY expected) ----"
assert_bash "git push --force origin main"        'git push --force origin main'        deny
assert_bash "git push -f origin main"             'git push -f origin main'             deny
echo ""

echo "---- git push --force-with-lease (ALLOW expected) ----"
assert_bash "git push --force-with-lease"         'git push --force-with-lease origin main'  allow
assert_bash "git push origin main (no force)"     'git push origin main'                      allow
echo ""

# ── git checkout/restore . ────────────────────────────────────────────────────
echo "---- git checkout/restore . (DENY expected) ----"
assert_bash "git checkout ."           'git checkout .'            deny
assert_bash "git restore ."           'git restore .'             deny
assert_bash "git -C /repo checkout ." 'git -C /repo checkout .'   deny
echo ""

# ── .env file writes ──────────────────────────────────────────────────────────
echo "---- .env writes (DENY expected) ----"
assert_edit ".env"              "/project/.env"              deny
assert_edit ".env.local"        "/project/.env.local"        deny
assert_edit ".env.production"   "/project/.env.production"   deny
assert_edit ".env.staging"      "/project/.env.staging"      deny
assert_edit ".env (Write tool)" "/project/.env"              deny Write
echo ""

echo "---- .env template writes (ALLOW expected) ----"
assert_edit ".env.example"   "/project/.env.example"    allow
assert_edit ".env.template"  "/project/.env.template"   allow
assert_edit ".env.sample"    "/project/.env.sample"     allow
echo ""

# ── JupyterLab symlink protection ─────────────────────────────────────────────
echo "---- JupyterLab symlink writes (DENY expected) ----"
assert_edit "CLAUDE.md in jupyterlab ext" \
  "/Quapp/ai/quapp-jupyterlab-ai-assistant-ext/CLAUDE.md" deny
assert_edit "GEMINI.md in jupyterlab ext" \
  "/Quapp/ai/quapp-jupyterlab-ai-assistant-ext/GEMINI.md" deny
echo ""

echo "---- JupyterLab AGENTS.md write (ALLOW expected) ----"
assert_edit "AGENTS.md in jupyterlab ext" \
  "/Quapp/ai/quapp-jupyterlab-ai-assistant-ext/AGENTS.md" allow
echo ""

# ── Misc safe commands ────────────────────────────────────────────────────────
echo "---- Misc safe commands (ALLOW expected) ----"
assert_bash "plain ls"  'ls -la'  allow
assert_bash "gradlew build in backend" \
  './gradlew build' allow \
  "/Users/user/Quapp/functions/quapp-functions-backend"
echo ""

# ── summary ───────────────────────────────────────────────────────────────────
echo "==========================================="
echo "Results: $PASS passed, $FAIL failed"
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "STATUS: FAIL"
  exit 1
else
  echo "STATUS: PASS"
  exit 0
fi
