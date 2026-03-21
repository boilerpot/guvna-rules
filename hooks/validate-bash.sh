#!/usr/bin/env bash
# PreToolUse hook for Bash tool calls.
# Reads JSON from stdin with the command to validate.
# Exit 0 = allow, exit 2 = deny.
#
# Enforces security policy: blocks destructive git ops, secret access,
# eval/exec evasion, and external network calls.
#
# FAIL CLOSED: if input cannot be parsed, the command is denied.

set -euo pipefail

INPUT=$(cat)

# --- Parse command from hook input ---
# Try jq first, fall back to python3, fail closed if neither works
PARSE_OK=false
if command -v jq > /dev/null 2>&1; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) && PARSE_OK=true
elif command -v python3 > /dev/null 2>&1; then
  COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null) && PARSE_OK=true
else
  echo "DENIED by guvna-rules: Cannot parse hook input — neither jq nor python3 available." >&2
  exit 2
fi

if [ "$PARSE_OK" != "true" ] || [ -z "$COMMAND" ]; then
  echo "DENIED by guvna-rules: Could not extract command from hook input." >&2
  exit 2
fi

# --- Load repo-level deny patterns from guvna.yml if present ---
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
GUVNA_YML="$REPO_ROOT/guvna.yml"
RULES_YML="$REPO_ROOT/.guvna-rules.yml"

# Collect additional deny patterns from config files
EXTRA_DENY=()
for cfg in "$GUVNA_YML" "$RULES_YML"; do
  if [ -f "$cfg" ] && command -v grep > /dev/null 2>&1; then
    in_deny=false
    while IFS= read -r line; do
      if echo "$line" | grep -qE '^deny:'; then
        in_deny=true
        continue
      fi
      if $in_deny; then
        if echo "$line" | grep -qE '^\s*-\s+'; then
          pattern=$(echo "$line" | sed -E 's/^\s*-\s+"?//; s/"?\s*$//')
          if [ -n "$pattern" ]; then
            EXTRA_DENY+=("$pattern")
          fi
        else
          in_deny=false
        fi
      fi
    done < "$cfg"
  fi
done

# Check extra deny patterns
for pattern in "${EXTRA_DENY[@]+"${EXTRA_DENY[@]}"}"; do
  if echo "$COMMAND" | grep -qF "$pattern"; then
    echo "DENIED by guvna-rules: command matches deny pattern '$pattern'." >&2
    exit 2
  fi
done

# --- Built-in security rules ---

# Block destructive/remote git commands
# Allow: git push (simple push of current branch to its upstream)
# Block: force push, rebase, reset, restore, cherry-pick, etc.
if echo "$COMMAND" | grep -qE '\bgit\s+push\b.*--force\b'; then
  echo "DENIED by guvna-rules: git push --force is not allowed." >&2
  exit 2
fi

GIT_MUTATE_PATTERN='\bgit\s+(rebase|reset|restore|cherry-pick|revert|clean)\b'
if echo "$COMMAND" | grep -qE "$GIT_MUTATE_PATTERN"; then
  echo "DENIED by guvna-rules: destructive git operation blocked. Use standard git workflow." >&2
  exit 2
fi

# Block gh CLI commands that bypass PR review
if echo "$COMMAND" | grep -qE '\bgh\s+pr\s+(merge|close)\b'; then
  echo "DENIED by guvna-rules: PR merge/close should go through review flow." >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE '\bgh\s+api\b.*\bmerge\b'; then
  echo "DENIED by guvna-rules: PR merges should go through review flow." >&2
  exit 2
fi

# Block access to secret files
# Allow .example/.sample/.template suffixes
if echo "$COMMAND" | grep -qiE '\.(env|pem|key|secret|cert)(\s|$|"|\.|\b)' && \
   ! echo "$COMMAND" | grep -qiE '\.(env|pem|key|secret|cert)\.(example|sample|template)\b'; then
  echo "DENIED by guvna-rules: access to secret/credential files not allowed via Bash." >&2
  exit 2
fi

# Block eval/exec evasion patterns
# Allow: pnpm exec, npx exec, yarn exec (standard package manager usage)
if echo "$COMMAND" | grep -qE '(^|[;&|])\s*eval\s'; then
  echo "DENIED by guvna-rules: eval not allowed." >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE '(^|[;&|])\s*exec\s' && \
   ! echo "$COMMAND" | grep -qE '\b(pnpm|npx|yarn)\b.*\bexec\b'; then
  echo "DENIED by guvna-rules: exec not allowed." >&2
  exit 2
fi

# Block curl to external URLs — localhost only
if echo "$COMMAND" | grep -qE '(^|[;&|]\s*)\bcurl\b'; then
  CMD_NO_LOCAL=$(echo "$COMMAND" | sed -E 's#https?://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])[^ ]*##g')
  if echo "$CMD_NO_LOCAL" | grep -qE 'https?://'; then
    echo "DENIED by guvna-rules: curl to external URLs not allowed. Only localhost permitted." >&2
    exit 2
  fi
  if echo "$COMMAND" | grep -qE '\bcurl\b.*(localhost|127\.0\.0\.1)'; then
    exit 0
  fi
  echo "DENIED by guvna-rules: curl must target localhost." >&2
  exit 2
fi

# Block network tools in subshells/pipes
if echo "$COMMAND" | grep -qE '\$\(.*\b(curl|wget|nc|ncat|socat)\b' || \
   echo "$COMMAND" | grep -qE '`.*\b(curl|wget|nc|ncat|socat)\b' || \
   echo "$COMMAND" | grep -qE '\|\s*(curl|wget|nc|ncat|socat)\b'; then
  echo "DENIED by guvna-rules: network tools in subshells/pipes not allowed." >&2
  exit 2
fi

exit 0
