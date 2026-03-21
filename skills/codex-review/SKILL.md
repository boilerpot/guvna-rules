---
name: codex-review
description: Request an independent code review from Codex (runs in background, posts to PR if available)
user_invocable: true
---

# /codex-review

Request an independent code review from another SOTA model via Codex CLI.

## Behavior

Reviews run **out of context** — output goes to a temp file and optionally to a PR comment. This keeps the context window clean.

## Steps

1. Determine what to review based on args or current state:
   - No args + uncommitted changes → `codex review --uncommitted`
   - No args + clean tree → `codex review --commit HEAD`
   - `--base <branch>` → `codex review --base <branch>`
   - `<sha>` → `codex review --commit <sha>`

2. Run the review in the background, writing output to a temp file:
   ```bash
   SHORT=$(git rev-parse --short HEAD)
   codex review --commit HEAD > /tmp/codex-review-${SHORT}.md 2>&1 &
   ```

3. Report only: `"Codex review dispatched → /tmp/codex-review-<sha>.md"`

4. If a PR exists for the current branch, also post results as a PR comment:
   ```bash
   PR=$(gh pr view --json number --jq '.number' 2>/dev/null)
   gh pr comment $PR --body "$(cat /tmp/codex-review-${SHORT}.md)"
   ```

5. Do NOT read the review output into context. If the user asks to see results, tell them the file path or PR comment link.

## Configuration

Disable in `.guvna-rules.yml`:
```yaml
codex-review: false
```
