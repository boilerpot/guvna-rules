#!/usr/bin/env bash
# PostToolUse:Bash — triggers after git commit commands.
# Backgrounds an independent code review using a configurable provider.
# Output goes to /tmp/review-<sha>.md and, if a PR exists, posts as a PR comment.
# Returns immediately — never pollutes the context window.
#
# Supported providers:
#   codex  — `codex review --commit <sha>` (OpenAI)
#   claude — `claude --print "Review commit <sha>: <diff>"` (Anthropic)
#
# Configure in .guvna-rules.yml:
#   review: true
#   review-provider: codex | claude    # default: auto-detect
#   review-model: "o3"                 # optional, provider-specific

set -euo pipefail

INPUT=$(cat 2>/dev/null || true)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Only fire on git commit (not amend)
if ! echo "$COMMAND" | grep -qE '\bgit\s+commit\b'; then
  exit 0
fi
if echo "$COMMAND" | grep -qE '\b--amend\b'; then
  exit 0
fi

# Read config
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RULES_YML="$REPO_ROOT/.guvna-rules.yml"
PROVIDER=""
MODEL=""

if [ -f "$RULES_YML" ]; then
  # Check both old (codex-review) and new (review) config names
  if grep -qE '^\s*(codex-)?review:\s*false' "$RULES_YML" 2>/dev/null; then
    exit 0
  fi
  PROVIDER=$(grep -oP '^\s*review-provider:\s*\K\S+' "$RULES_YML" 2>/dev/null || echo "")
  MODEL=$(grep -oP '^\s*review-model:\s*"\K[^"]+' "$RULES_YML" 2>/dev/null || \
          grep -oP "^\s*review-model:\s*'\K[^']+" "$RULES_YML" 2>/dev/null || \
          grep -oP '^\s*review-model:\s*\K\S+' "$RULES_YML" 2>/dev/null || echo "")
  # Support old config names
  if [ -z "$PROVIDER" ]; then
    PROVIDER=$(grep -oP '^\s*codex-review-model:\s*\K\S+' "$RULES_YML" 2>/dev/null && echo "codex" || echo "")
  fi
  if [ -z "$MODEL" ]; then
    MODEL=$(grep -oP '^\s*codex-review-model:\s*"\K[^"]+' "$RULES_YML" 2>/dev/null || \
            grep -oP '^\s*codex-review-model:\s*\K\S+' "$RULES_YML" 2>/dev/null || echo "")
  fi
fi

# Auto-detect provider if not configured
if [ -z "$PROVIDER" ]; then
  if command -v codex > /dev/null 2>&1; then
    PROVIDER="codex"
  elif command -v claude > /dev/null 2>&1; then
    PROVIDER="claude"
  else
    exit 0  # no review tool available
  fi
fi

# Verify chosen provider exists
if ! command -v "$PROVIDER" > /dev/null 2>&1; then
  exit 0
fi

SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
if [ -z "$SHA" ]; then
  exit 0
fi

SHORT_SHA=$(git rev-parse --short HEAD 2>/dev/null)
REVIEW_FILE="/tmp/review-${SHORT_SHA}.md"

# Background the review
(
  REVIEW_OUTPUT=""

  case "$PROVIDER" in
    codex)
      MODEL_FLAG=""
      if [ -n "$MODEL" ]; then
        MODEL_FLAG="-c model=\"$MODEL\""
      fi
      REVIEW_OUTPUT=$(eval codex review --commit "$SHA" $MODEL_FLAG 2>&1) || true
      ;;
    claude)
      DIFF=$(git show "$SHA" --stat --patch 2>/dev/null | head -500)
      MODEL_FLAG=""
      if [ -n "$MODEL" ]; then
        MODEL_FLAG="--model $MODEL"
      fi
      REVIEW_OUTPUT=$(eval claude $MODEL_FLAG --print \"Review this commit for bugs, security issues, and correctness. Be concise. Commit: $SHA\" --no-input 2>&1 <<< "$DIFF") || true
      ;;
  esac

  if [ -z "$REVIEW_OUTPUT" ]; then
    REVIEW_OUTPUT="No issues found."
  fi

  # Write to temp file
  cat > "$REVIEW_FILE" <<REVIEW_EOF
# Independent Review: ${SHORT_SHA}

**Provider:** ${PROVIDER}${MODEL:+ ($MODEL)}
**Commit:** ${SHA}
**Date:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")

---

${REVIEW_OUTPUT}
REVIEW_EOF

  # Post to PR if one exists
  if command -v gh > /dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    if [ -n "$BRANCH" ]; then
      PR_NUMBER=$(gh pr view "$BRANCH" --json number --jq '.number' 2>/dev/null || echo "")
      if [ -n "$PR_NUMBER" ]; then
        COMMENT_BODY=$(cat <<COMMENT_EOF
### Independent Review — \`${SHORT_SHA}\`
**Provider:** ${PROVIDER}${MODEL:+ ($MODEL)}

${REVIEW_OUTPUT}

---
<sub>Automated review via guvna-rules</sub>
COMMENT_EOF
        )
        gh pr comment "$PR_NUMBER" --body "$COMMENT_BODY" 2>/dev/null || true
      fi
    fi
  fi
) &

echo "Review dispatched (${PROVIDER}${MODEL:+/$MODEL}) for ${SHORT_SHA} → ${REVIEW_FILE}"
exit 0
