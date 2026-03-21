#!/usr/bin/env bash
# PostToolUse hook for Edit/Write on TypeScript files.
# Runs typecheck scoped to the nearest package to catch errors immediately.
# Advisory only: exit 0 regardless of typecheck outcome.

set -euo pipefail

# Check if typecheck is enabled in .guvna-rules.yml (default: true)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RULES_YML="$REPO_ROOT/.guvna-rules.yml"
TYPECHECK_CMD=""

if [ -f "$RULES_YML" ]; then
  if grep -qE '^\s*typecheck:\s*false' "$RULES_YML" 2>/dev/null; then
    exit 0
  fi
  # Read custom typecheck command
  TYPECHECK_CMD=$(grep -oP '^\s*typecheck-command:\s*"\K[^"]+' "$RULES_YML" 2>/dev/null || \
                  grep -oP "^\s*typecheck-command:\s*'\K[^']+" "$RULES_YML" 2>/dev/null || \
                  grep -oP '^\s*typecheck-command:\s*\K\S.*' "$RULES_YML" 2>/dev/null || echo "")
fi

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || echo "")

# Only check TypeScript files
if [[ ! "$FILE_PATH" =~ \.(ts|tsx)$ ]]; then
  exit 0
fi

# If a custom typecheck command is configured, use it
if [ -n "$TYPECHECK_CMD" ]; then
  OUTPUT=$(cd "$REPO_ROOT" && eval "$TYPECHECK_CMD" 2>&1 | head -20) || true
  if echo "$OUTPUT" | grep -q "error TS"; then
    echo "TypeScript errors found — fix before committing:"
    echo "$OUTPUT" | grep "error TS" | head -5
  fi
  exit 0
fi

# Auto-detect: find the nearest package.json or tsconfig.json
DIR=$(dirname "$FILE_PATH")
PKG_DIR=""
while [ "$DIR" != "/" ] && [ "$DIR" != "." ]; do
  if [ -f "$DIR/tsconfig.json" ] && [ -f "$DIR/package.json" ]; then
    PKG_DIR="$DIR"
    break
  fi
  DIR=$(dirname "$DIR")
done

if [ -z "$PKG_DIR" ]; then
  # Try repo-root level typecheck
  if [ -f "$REPO_ROOT/tsconfig.json" ]; then
    PKG_DIR="$REPO_ROOT"
  else
    exit 0
  fi
fi

# Detect package manager and run typecheck
if [ -f "$PKG_DIR/package.json" ]; then
  # Check if package.json has a typecheck script
  HAS_TYPECHECK=$(jq -r '.scripts.typecheck // empty' "$PKG_DIR/package.json" 2>/dev/null || echo "")

  if [ -n "$HAS_TYPECHECK" ]; then
    # Detect package manager
    if [ -f "$REPO_ROOT/pnpm-lock.yaml" ]; then
      PM="pnpm"
    elif [ -f "$REPO_ROOT/yarn.lock" ]; then
      PM="yarn"
    else
      PM="npm"
    fi

    OUTPUT=$(cd "$PKG_DIR" && $PM run typecheck 2>&1 | head -20) || true
    if echo "$OUTPUT" | grep -q "error TS"; then
      echo "TypeScript errors in $(basename "$PKG_DIR") — fix before committing:"
      echo "$OUTPUT" | grep "error TS" | head -5
    fi
  else
    # No typecheck script — run tsc directly
    OUTPUT=$(cd "$PKG_DIR" && npx tsc --noEmit 2>&1 | head -20) || true
    if echo "$OUTPUT" | grep -q "error TS"; then
      echo "TypeScript errors in $(basename "$PKG_DIR") — fix before committing:"
      echo "$OUTPUT" | grep "error TS" | head -5
    fi
  fi
fi

exit 0
