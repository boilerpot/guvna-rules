---
name: guvna-init
description: Create a starter guvna.yml configuration for this repository
user_invocable: true
---

# /guvna-init

Create governance configuration for this repository.

## Steps

1. Check if `guvna.yml` already exists in the repo root. If it does, show its contents and ask if the user wants to update it.

2. Analyze the repository to suggest sensible defaults:
   - Look for `.github/workflows/` → add to protected paths
   - Look for `migrations/` or `prisma/` → add to protected paths
   - Look for `src/auth/` or similar auth directories → add to protected paths
   - Look for `.env*` files → add to protected paths
   - Check for TypeScript (tsconfig.json) → enable typecheck
   - Check for prettier config → enable prettier

3. Generate `guvna.yml` with:
```yaml
# guvna — governance configuration
# Shared between guvna GitHub App (PR review) and guvna-rules plugin (session enforcement)
# Docs: https://github.com/boilerpot/guvna-rules

protected:
  # Add paths that require review before changes
  - ".github/workflows/**"

reviewers:
  # GitHub usernames or teams to request review from
  - []
```

4. Optionally generate `.guvna-rules.yml` with plugin-specific settings:
```yaml
# guvna-rules plugin configuration
prettier: true
typecheck: true
# typecheck-command: "pnpm typecheck"
# deny:
#   - "rm -rf"
```

5. Show the user what was created and suggest next steps (install guvna GitHub App, customize protected paths).
