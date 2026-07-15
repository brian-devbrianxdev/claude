#!/usr/bin/env bash
# secret-scan.sh — deterministic secret scan for a Quapp repo's uncommitted work.
#
# Bundled with the security-review skill (pattern: skill + deterministic check
# script). Run it from /ship-task BEFORE committing; any BLOCKER finding is a
# commit blocker. LLM review complements this — it does not replace it.
#
# Usage:  secret-scan.sh [repo-dir]        (default: cwd; must be a git repo)
# Scope:  added lines in `git diff HEAD` + all untracked (non-ignored) files.
# Exit:   0 = clean, 1 = BLOCKER finding(s), 2 = usage/not-a-repo.

set -u

repo="${1:-$(pwd)}"
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo: $repo" >&2; exit 2; }

# High-confidence token shapes → BLOCKER
BLOCK_RE='(AKIA[0-9A-Z]{16}|glpat-[0-9A-Za-z_-]{20,}|gh[pousr]_[0-9A-Za-z]{20,}|sk-ant-[0-9A-Za-z_-]{20,}|(sk|rk)_live_[0-9A-Za-z]{16,}|whsec_[0-9A-Za-z]{16,}|xox[bapors]-[0-9A-Za-z-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{15,}\.eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{10,})'
# Suspicious assignments → WARN (judged by reviewer; placeholders excluded below)
WARN_RE='(password|passwd|secret|api[_-]?key|access[_-]?token|client[_-]?secret)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9+/_.!@#-]{8,}'
# Values that are clearly placeholders/env-driven — never flag
ALLOW_RE='(\$\{|\{\{|ENC\(|<[A-Za-z_-]+>|your[_-]|changeme|dummy|example|placeholder|xxxx|System\.getenv|process\.env|os\.environ|secretsmanager|password-stdin)'

blockers=0
warns=0

scan_line() { # $1=file $2=lineno $3=text
  printf '%s' "$3" | grep -Eq "$ALLOW_RE" && return 0
  if printf '%s' "$3" | grep -Eq "$BLOCK_RE"; then
    echo "BLOCKER  $1:$2  high-confidence credential: $(printf '%s' "$3" | cut -c1-120)"
    blockers=$((blockers + 1))
  elif printf '%s' "$3" | grep -Eiq "$WARN_RE"; then
    echo "WARN     $1:$2  suspicious assignment: $(printf '%s' "$3" | cut -c1-120)"
    warns=$((warns + 1))
  fi
}

# 1. Added lines in the uncommitted diff (staged + unstaged), with line numbers
while IFS=$'\t' read -r f n text; do
  [ -n "${f:-}" ] && scan_line "$f" "$n" "$text"
done < <(git -C "$repo" diff HEAD -U0 --no-color 2>/dev/null | awk '
  /^\+\+\+ b\// { file = substr($0, 7); next }
  /^@@/         { split($0, a, "+"); split(a[2], b, /[ ,]/); line = b[1]; next }
  /^\+/ && !/^\+\+\+/ { printf "%s\t%d\t%s\n", file, line, substr($0, 2); line++ }
')

# 2. Untracked files: .env-like files are blockers by name; contents scanned too
while IFS= read -r f; do
  case "$f" in
    .env|*/.env|.env.*|*/.env.*)
      echo "BLOCKER  $f  untracked .env file — never commit; add to .gitignore"
      blockers=$((blockers + 1))
      continue
      ;;
  esac
  file -b --mime "$repo/$f" 2>/dev/null | grep -q charset=binary && continue
  while IFS=: read -r n text; do
    [ -n "${n:-}" ] && scan_line "$f" "$n" "$text"
  done < <(grep -nE "$BLOCK_RE|$WARN_RE" "$repo/$f" 2>/dev/null | head -50)
done < <(git -C "$repo" ls-files --others --exclude-standard 2>/dev/null)

# 3. Tracked .env files staged for commit
while IFS= read -r f; do
  [ -n "$f" ] || continue
  echo "BLOCKER  $f  .env file in the diff — local-only, never commit"
  blockers=$((blockers + 1))
done < <(git -C "$repo" diff HEAD --name-only 2>/dev/null | grep -E '(^|/)\.env(\.|$)')

if [ "$blockers" -eq 0 ] && [ "$warns" -eq 0 ]; then
  echo "secret-scan: clean ($(basename "$repo"))"
  exit 0
fi
echo "secret-scan: $blockers blocker(s), $warns warning(s) in $(basename "$repo")"
[ "$blockers" -gt 0 ] && exit 1
exit 0
