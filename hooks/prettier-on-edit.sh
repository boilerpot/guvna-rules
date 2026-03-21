#!/usr/bin/env bash
# PostToolUse hook for Edit/Write — runs prettier on the changed file.
# Advisory only: exit 0 regardless of prettier outcome.

set -euo pipefail

# Check if prettier is enabled in .guvna-rules.yml (default: true)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RULES_YML="$REPO_ROOT/.guvna-rules.yml"
if [ -f "$RULES_YML" ]; then
  if grep -qE '^\s*prettier:\s*false' "$RULES_YML" 2>/dev/null; then
    exit 0
  fi
fi

INPUT=$(cat 2>/dev/null || true)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only format files prettier understands
if [[ ! "$FILE_PATH" =~ \.(ts|tsx|js|jsx|json|md|css|scss|html|yaml|yml)$ ]]; then
  exit 0
fi

# Skip node_modules, dist, build artifacts
if [[ "$FILE_PATH" =~ (node_modules|/dist/|/build/) ]]; then
  exit 0
fi

# Check if prettier is available
if ! command -v npx > /dev/null 2>&1; then
  exit 0
fi

npx prettier --write "$FILE_PATH" 2>/dev/null || true

exit 0
