# guvna-rules

Claude Code plugin for agent governance. Blocks unsafe commands, enforces protected paths, auto-formats and typechecks edits.

Part of the [guvna](https://github.com/boilerpot/guvna) governance platform. Works standalone or paired with the guvna GitHub App for full PR-level enforcement.

## Install

```bash
claude plugin add boilerpot/guvna-rules
```

Or add to your project's `.claude/plugins.json`:
```json
{
  "plugins": [
    { "git": "https://github.com/boilerpot/guvna-rules" }
  ]
}
```

## What it does

### Security hooks (PreToolUse:Bash)

| Rule | What's blocked |
|------|---------------|
| Destructive git | `git push --force`, `git rebase`, `git reset`, `git restore`, `git clean` |
| PR bypass | `gh pr merge`, `gh pr close`, direct API merges |
| Secret access | `.env`, `.pem`, `.key`, `.secret`, `.cert` files (templates allowed) |
| Eval/exec | `eval`, standalone `exec` (package manager exec allowed) |
| External network | `curl`/`wget`/`nc` to non-localhost URLs |
| Custom deny | Patterns from `guvna.yml` and `.guvna-rules.yml` |

### Code quality hooks (PostToolUse:Edit|Write)

- **Prettier** — auto-formats supported files after edits
- **TypeScript** — runs typecheck scoped to the edited package

### Doc validation (InstructionsLoaded)

- Scans `CLAUDE.md` for referenced file paths and warns about missing files

## Configuration

### `guvna.yml` (shared with guvna GitHub App)

```yaml
protected:
  - ".github/workflows/**"
  - "src/auth/**"
  - "migrations/**"
reviewers:
  - security-team
deny:
  - "docker run"
  - "sudo"
```

### `.guvna-rules.yml` (plugin-specific)

```yaml
prettier: true
typecheck: true
typecheck-command: "pnpm typecheck"
deny:
  - "rm -rf"
```

## Skills

| Skill | Type | Description |
|-------|------|-------------|
| `guvna-policy` | model-invoked | Governance rules injected into model context |
| `/guvna-init` | user-invoked | Create starter `guvna.yml` for your repo |
| `/guvna-check` | user-invoked | Audit governance setup and find gaps |

## Architecture

```
guvna-rules (this plugin)     guvna (GitHub App)
  ├── gates coding sessions     ├── gates pull requests
  ├── blocks unsafe commands    ├── risk classification
  ├── enforces deny patterns    ├── review enforcement
  └── auto-format/typecheck     └── reviewer auto-request
```

Both read from `guvna.yml` for shared policy. The plugin enforces during coding; the App enforces at PR time.

## License

MIT
