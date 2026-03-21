#!/usr/bin/env bash
# InstructionsLoaded hook — fires when CLAUDE.md is loaded.
# Scans for referenced file paths and warns about missing files.

# Drain stdin to avoid EPIPE
cat > /dev/null 2>/dev/null || true

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"

if [ ! -f "$CLAUDE_MD" ]; then
  exit 0
fi

# Extract backtick-quoted file paths from CLAUDE.md
MISSING=0
while IFS= read -r ref; do
  [[ "$ref" == *"*"* ]] && continue
  [[ "$ref" == *"/"* ]] || continue

  full_path="$REPO_ROOT/$ref"
  if [ ! -f "$full_path" ] && [ ! -d "$full_path" ]; then
    echo "CLAUDE.md references '$ref' but file not found" >&2
    MISSING=$((MISSING + 1))
  fi
done < <(grep -oE '`[^`]+\.(md|ts|json|sh)`' "$CLAUDE_MD" | tr -d '`' | sort -u)

if [ "$MISSING" -gt 0 ]; then
  echo "$MISSING stale doc reference(s) in CLAUDE.md" >&2
fi

exit 0
