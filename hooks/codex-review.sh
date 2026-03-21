#!/usr/bin/env bash
# PostToolUse:Bash — triggers after git commit commands.
# Backgrounds a `codex review` of the new commit.
# Output goes to /tmp/codex-review-<sha>.md and, if a PR exists, posts as a PR comment.
# Returns immediately with a one-liner — never pollutes the context window.

set -euo pipefail

INPUT=$(cat 2>/dev/null || true)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

# Only fire on git commit commands (not amend — that's a separate review)
if ! echo "$COMMAND" | grep -qE '\bgit\s+commit\b'; then
  exit 0
fi

# Don't fire on commit --amend (the commit hasn't changed meaningfully)
if echo "$COMMAND" | grep -qE '\b--amend\b'; then
  exit 0
fi

# Check codex is available
if ! command -v codex > /dev/null 2>&1; then
  exit 0
fi

# Check .guvna-rules.yml — codex-review can be disabled
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RULES_YML="$REPO_ROOT/.guvna-rules.yml"
if [ -f "$RULES_YML" ]; then
  if grep -qE '^\s*codex-review:\s*false' "$RULES_YML" 2>/dev/null; then
    exit 0
  fi
fi

# Get the commit SHA that was just created
SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
if [ -z "$SHA" ]; then
  exit 0
fi

SHORT_SHA=$(git rev-parse --short HEAD 2>/dev/null)
REVIEW_FILE="/tmp/codex-review-${SHORT_SHA}.md"

# Background the review — this script returns immediately
(
  # Run codex review on the commit
  REVIEW_OUTPUT=$(codex review --commit "$SHA" 2>&1) || true

  if [ -z "$REVIEW_OUTPUT" ]; then
    REVIEW_OUTPUT="No issues found."
  fi

  # Write to temp file
  cat > "$REVIEW_FILE" <<REVIEW_EOF
# Codex Review: ${SHORT_SHA}

**Commit:** ${SHA}
**Date:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")

---

${REVIEW_OUTPUT}
REVIEW_EOF

  # If a PR exists for this branch, post as a comment
  if command -v gh > /dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    if [ -n "$BRANCH" ]; then
      PR_NUMBER=$(gh pr view "$BRANCH" --json number --jq '.number' 2>/dev/null || echo "")
      if [ -n "$PR_NUMBER" ]; then
        COMMENT_BODY=$(cat <<COMMENT_EOF
### Codex Review — \`${SHORT_SHA}\`

${REVIEW_OUTPUT}

---
<sub>Automated review by codex via guvna-rules</sub>
COMMENT_EOF
        )
        gh pr comment "$PR_NUMBER" --body "$COMMENT_BODY" 2>/dev/null || true
      fi
    fi
  fi
) &

echo "Codex review dispatched for ${SHORT_SHA} → ${REVIEW_FILE}"
exit 0
