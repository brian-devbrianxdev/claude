#!/usr/bin/env bash
# quapp-guard.sh — deterministic guard for the Quapp multi-root workspace.
#
# Registered as a PreToolUse hook (Bash + Edit|Write) in .claude/settings.json.
# Advisory (additionalContext) by default; BLOCKS destructive git commands
# (reset --hard, clean -f, branch -D, checkout/restore ., push --force) and
# edits to the JupyterLab CLAUDE.md / GEMINI.md symlinks.
# Disable entirely with QUAPP_GUARD=off.
#
# Output matches the existing hook convention: a single hookSpecificOutput JSON.

set -u

[ "${QUAPP_GUARD:-on}" = "off" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  # Degraded mode: no jq available — use crude grep to still block the worst cases.
  raw="$(cat)"
  # Block destructive git commands
  if printf '%s' "$raw" | grep -q '"command"'; then
    if printf '%s' "$raw" | grep -Eq '"command"[^}]*git reset --hard'; then
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"quapp-guard: git reset --hard blocked (degraded mode — install jq for full guard)."}}'
      exit 0
    fi
    if printf '%s' "$raw" | grep -Eq '"command"[^}]*git clean -[a-zA-Z]*f'; then
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"quapp-guard: git clean -f blocked (degraded mode — install jq for full guard)."}}'
      exit 0
    fi
    if printf '%s' "$raw" | grep -Eq '"command"[^}]*git branch -D'; then
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"quapp-guard: git branch -D blocked (degraded mode — install jq for full guard)."}}'
      exit 0
    fi
    if printf '%s' "$raw" | grep -Eq '"command"[^}]*git push.*--force' && ! printf '%s' "$raw" | grep -q 'force-with-lease'; then
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"quapp-guard: git push --force blocked (degraded mode — install jq for full guard)."}}'
      exit 0
    fi
    if printf '%s' "$raw" | grep -Eq '"command"[^}]*(git checkout \.|git restore \.)'; then
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"quapp-guard: git checkout/restore . blocked (degraded mode — install jq for full guard)."}}'
      exit 0
    fi
    if printf '%s' "$raw" | grep -Eq '"command"[^}]*rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f[^}]*(\.git|\.env|"/"|'"'"'/'"'"'|~|\\\.)'; then
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"quapp-guard: rm -rf on .git/.env/root/home blocked (degraded mode — install jq for full guard)."}}'
      exit 0
    fi
  fi
  # Block edits to JupyterLab symlinks
  if printf '%s' "$raw" | grep -q 'quapp-jupyterlab-ai-assistant-ext' && printf '%s' "$raw" | grep -Eq '"(CLAUDE|GEMINI)\.md"'; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"quapp-guard: edit to CLAUDE.md/GEMINI.md symlink blocked (degraded mode — install jq for full guard)."}}'
    exit 0
  fi
  exit 0
fi

input="$(cat)"
tool="$(printf '%s' "$input" | jq -r '.tool_name // ""')"

emit_context() {
  jq -n --arg msg "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$msg}}'
  exit 0
}

emit_deny() {
  jq -n --arg msg "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$msg}}'
  exit 0
}

case "$tool" in
  Bash)
    cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"
    cwd="$(printf '%s' "$input" | jq -r '.cwd // ""')"

    # BLOCK: destructive git commands (adapted from mattpocock/skills git-guardrails, MIT).
    # Strip double-quoted strings first so commit message bodies (e.g. -m "... git reset --hard ...")
    # don't produce false positives. Collapse newlines before sed so multi-line -m "..." bodies
    # are treated as one token and fully removed by the [^"]* pattern.
    cmd_unquoted="$(printf '%s' "$cmd" | tr '\n' ' ' | sed 's/"[^"]*"//g')"
    # Normalize git global options (-C <dir>, --git-dir=X, etc.) so they don't bypass subcommand checks.
    # "git -C /path reset --hard" normalizes to "git reset --hard" for the patterns below.
    cmd_git_normalized="$(printf '%s' "$cmd_unquoted" \
      | sed -E 's/git[[:space:]]+((-C[[:space:]]+[^[:space:]]+|--git-dir[^[:space:]]*|--work-tree[^[:space:]]*|--bare|--no-pager|--paginate|-p)[[:space:]]+)*/git /g')"
    # Plain `git push` stays allowed — /ship-task needs it; only history/worktree destroyers deny.
    if printf '%s' "$cmd_unquoted" | grep -Eq '(^|[^[:alnum:]])git[[:space:]]'; then
      if printf '%s' "$cmd_git_normalized" | grep -Eq 'git[[:space:]]+reset[[:space:]]+(-[^ ]+[[:space:]]+)*--hard'; then
        emit_deny "git reset --hard discards uncommitted work. If this is truly intended, ask the user to run it themselves (or use git stash first)."
      fi
      if printf '%s' "$cmd_git_normalized" | grep -Eq 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f'; then
        emit_deny "git clean -f deletes untracked files irreversibly. Ask the user to run it themselves if intended."
      fi
      if printf '%s' "$cmd_git_normalized" | grep -Eq 'git[[:space:]]+branch[[:space:]]+(-[^ ]+[[:space:]]+)*-D([[:space:]]|$)'; then
        emit_deny "git branch -D force-deletes a branch (unmerged work lost). Use -d, or ask the user."
      fi
      if printf '%s' "$cmd_git_normalized" | grep -Eq 'git[[:space:]]+(checkout|restore)[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$|;)'; then
        emit_deny "git checkout/restore . wipes ALL uncommitted changes in the worktree. Restore specific files by path instead, or ask the user."
      fi
      if printf '%s' "$cmd_git_normalized" | grep -Eq 'git[[:space:]]+push([[:space:]]|$)' \
         && printf '%s' "$cmd_git_normalized" | grep -Eq '(^|[[:space:]])(--force|-f)([[:space:]]|$)' \
         && ! printf '%s' "$cmd_git_normalized" | grep -q 'force-with-lease'; then
        emit_deny "git push --force can destroy remote history. If a force push is genuinely needed, use --force-with-lease and confirm with the user first."
      fi
    fi

    # BLOCK: rm -rf on dangerous targets (.git, .env files, /, ., ~ (home), or bare wildcard)
    # Catches combined short flags (-rf/-fr) and long options (--recursive/--force in any order).
    # Boundary is "any non-identifier char" (not just space/;|&`() so an absolute/relative
    # invocation like /bin/rm -rf / or ./rm -rf / still counts as "rm" (mirrors the git boundary
    # below). Allows rm -rf on build dirs (build/, dist/, node_modules/, .gradle/, etc.).
    if printf '%s' "$cmd_unquoted" | grep -Eq \
      '(^|[^[:alnum:]_])rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*)' \
      || printf '%s' "$cmd_unquoted" | grep -Eq \
      '(^|[^[:alnum:]_])rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*(--recursive[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*--force|--force[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*--recursive)'; then
      # Target-matching uses its own normalization: strip quote CHARACTERS (not whole spans, unlike
      # cmd_unquoted above) from the flattened raw command, so a quoted dangerous target — either
      # style, e.g. rm -rf '/' or rm -rf ".git" — still lands adjacent to the flags instead of
      # hiding behind its quotes. Safe to derive from raw $cmd here because the outer gate above
      # already required a bare (non-quoted-span) "rm -rf" to reach this branch, so a quoted
      # non-command string (e.g. a commit message body) can't trigger it.
      cmd_rm_target="$(printf '%s' "$cmd" | tr '\n' ' ' | sed "s/[\"']//g")"
      # End-of-word anchor uses ($|[[:space:]]) — NOT [$] which is a literal dollar in a char class.
      # Skip both short (-rf) and long (--recursive) flags before checking the dangerous target.
      # Dangerous targets: / . ./ .git .env ~ ~/ $HOME * — each must end at whitespace or end of string.
      if printf '%s' "$cmd_rm_target" | grep -Eq \
        'rm[[:space:]]+((-[a-zA-Z]+|--[a-zA-Z][a-zA-Z-]*)[[:space:]]+)*(\/([[:space:]]|$)|\.([[:space:]]|$)|\.\/([[:space:]]|$)|\.git([[:space:]]|$)|\.env([[:space:]]|$)|~([[:space:]]|$)|~\/([[:space:]]|$)|\$HOME([[:space:]]|$)|[*]([[:space:]]|$))'; then
        emit_deny "rm -rf on .git, .env, /, ., ~ (home), or wildcard target is irreversible. Ask the user to run this themselves if truly intended."
      fi
    fi

    # yarn-not-npm: npm used inside the frontend repo
    if printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]])npm([[:space:]]|$)' \
       && printf '%s' "$cwd" | grep -q 'quapp-functions-frontend'; then
      emit_context "quapp-functions-frontend uses yarn, not npm. Use 'yarn ...' — npm breaks Husky and the postinstall 'max setup' wiring."
    fi

    # JDK / root-build sanity on gradle/maven invocations
    if printf '%s' "$cmd" | grep -Eq '(^|[;&|])[[:space:]]*(\./)?(gradlew|mvnw|gradle|mvn)([[:space:];&|]|$)|(^|[;&|])[[:space:]]*bootRun([[:space:];&|]|$)'; then
      # workspace root = nearest ancestor containing a *.code-workspace file
      root=""; d="$cwd"
      while [ -n "$d" ] && [ "$d" != "/" ]; do
        if ls "$d"/*.code-workspace >/dev/null 2>&1; then root="$d"; break; fi
        d="$(dirname "$d")"
      done
      if [ -n "$root" ] && [ "$cwd" = "$root" ]; then
        emit_context "This is a multi-root workspace, not a monorepo — there is no root-level build. cd into the specific repo before running gradle/maven."
      fi

      # required JDK per repo (check ai-mcp-migration before ai-mcp)
      need=""
      case "$cwd" in
        *quapp-functions-backend*) need=17 ;;
        *quapp-migration*)         need=17 ;;
        *quapp-ai-mcp-migration*)  need=21 ;;
        *quapp-ai-mcp*)            need=21 ;;
      esac
      if [ -n "$need" ]; then
        active=""
        case "${JAVA_HOME:-}" in
          *17*) active=17 ;;
          *21*) active=21 ;;
        esac
        [ -z "$active" ] && active="$(java -version 2>&1 | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p' | head -1)"
        if [ -n "$active" ] && [ "$active" != "$need" ]; then
          emit_context "This repo builds with Java $need; the active JDK looks like Java $active — ensure the active JDK is Java $need before building (terminal default is Java 21)."
        fi
      fi
    fi
    ;;

  Edit|Write)
    fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')"

    # BLOCK: writes to .env files (local-only, must never be committed)
    if printf '%s' "$fp" | grep -Eq '(^|/)\.env(\.[a-zA-Z0-9]+)?$' \
       && ! printf '%s' "$fp" | grep -Eq '\.(example|template|sample)$'; then
      emit_deny ".env files are local-only and must never be committed. Set variables via shell export, AWS Secrets Manager, or workspace env config instead."
    fi

    # BLOCK: the JupyterLab ext CLAUDE.md / GEMINI.md are symlinks to AGENTS.md
    if printf '%s' "$fp" | grep -q 'quapp-jupyterlab-ai-assistant-ext' \
       && printf '%s' "$fp" | grep -Eq '/(CLAUDE|GEMINI)\.md$'; then
      emit_deny "In the JupyterLab ext, CLAUDE.md and GEMINI.md are symlinks to AGENTS.md. Edit AGENTS.md instead."
    fi

    # BLOCK: high-confidence hardcoded secret in new content.
    # Override with QUAPP_SECRET_GUARD=off if you intentionally write test fixtures with fake-key patterns.
    if [ "${QUAPP_SECRET_GUARD:-on}" = "on" ]; then
      content="$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // ""')"
      if printf '%s' "$content" | grep -Eq '(AKIA[0-9A-Z]{16}|ghp_[0-9A-Za-z]{20,}|sk_live_[0-9A-Za-z]+|-----BEGIN [A-Z ]*PRIVATE KEY-----)'; then
        emit_deny "This change contains a pattern that looks like a hardcoded secret (AWS key, GitHub token, Stripe live key, or private key). Quapp secrets come from AWS Secrets Manager / env — never commit keys. Set QUAPP_SECRET_GUARD=off to override for intentional test fixtures."
      fi
    fi
    ;;
esac

exit 0
