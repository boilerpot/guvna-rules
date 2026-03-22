# guvna-rules

Claude Code plugin for agent governance. Blocks unsafe commands, enforces policy, auto-formats, and typechecks edits.

Works standalone or paired with the [guvna](https://github.com/boilerpot/guvna) GitHub App for full PR-level enforcement.

## Install

Add as a custom marketplace, then install:

```bash
claude plugin marketplace add boilerpot/guvna-rules
claude plugin install guvna-rules@guvna-rules
```

Or load per-session:

```bash
claude --plugin-dir /path/to/guvna-rules
```

## What it does

### Security (PreToolUse:Bash)

| Rule | Blocked |
|------|---------|
| Destructive git | `git push --force`, `git rebase`, `git reset`, `git restore`, `git clean` |
| PR bypass | `gh pr merge`, `gh pr close`, direct API merges |
| Secret access | `.env`, `.pem`, `.key`, `.secret`, `.cert` (templates allowed) |
| Eval/exec | `eval`, standalone `exec` (pnpm/npx/yarn exec allowed) |
| External network | `curl`/`wget`/`nc` to non-localhost URLs |
| Custom deny | Patterns from `guvna.yml` and `.guvna-rules.yml` |

### Code quality (PostToolUse:Edit|Write)

- **Prettier** — auto-formats after edits (disable: `prettier: false`)
- **TypeScript** — scoped typecheck after `.ts`/`.tsx` edits (disable: `typecheck: false`)

### Doc validation (InstructionsLoaded)

- Scans `CLAUDE.md` for backtick-quoted file paths and warns about missing references.

## Configuration

### `guvna.yml` (shared with guvna GitHub App)

```yaml
protected:
  - ".github/workflows/**"
  - "src/auth/**"
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
guvna-rules (this plugin)       guvna (GitHub App)
  gates coding sessions           gates pull requests
  blocks unsafe commands          risk classification
  enforces deny patterns          review enforcement
  auto-format + typecheck         reviewer auto-request
```

Both read `guvna.yml`. The plugin enforces during coding; the App enforces at PR time.

## License

MIT
