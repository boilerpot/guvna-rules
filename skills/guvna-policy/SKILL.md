---
name: guvna-policy
description: Agent governance rules — security constraints, protected paths, and coding standards enforced by guvna-rules
---

# Governance Policy

You are operating under guvna-rules governance. These rules are enforced by hooks and must also guide your decisions.

## Security Rules (enforced by hooks)

- **No destructive git ops**: `git push --force`, `git rebase`, `git reset`, `git restore`, `git cherry-pick`, `git clean` are blocked.
- **No PR bypass**: `gh pr merge`, `gh pr close`, `gh api ...merge` are blocked. PRs go through review.
- **No secret access**: Files matching `.env`, `.pem`, `.key`, `.secret`, `.cert` cannot be read via Bash (templates like `.env.example` are allowed).
- **No eval/exec**: `eval` and standalone `exec` are blocked. Package manager exec (`pnpm exec`, `npx exec`) is allowed.
- **No external network**: `curl`, `wget`, `nc` etc. are restricted to localhost only. No external HTTP calls.

## Protected Paths

Check `guvna.yml` in the repo root for protected path patterns. Files matching protected patterns require careful review and should not be modified without explicit approval.

Common protected paths:
- `.github/workflows/**` — CI/CD pipelines
- `*.env` — environment configuration
- Auth/security modules
- Database migrations

## Code Quality (enforced by hooks)

- **Auto-format**: Prettier runs automatically on supported files after edits.
- **Type safety**: TypeScript files are typechecked after edits. Fix errors before committing.

## Working Guidelines

1. Read existing code before modifying it.
2. Keep changes minimal and focused.
3. Follow existing patterns in the codebase.
4. Do not bypass governance hooks or security checks.
5. If a command is blocked, find a safer alternative — do not try to work around the block.

## Configuration

Policy can be customized per-repo:
- `guvna.yml` — protected paths, reviewers, agent permissions (shared with guvna GitHub App)
- `.guvna-rules.yml` — plugin-specific: prettier, typecheck, deny patterns, brain endpoint
