# CLAUDE.md

Personal defaults loaded into every Claude Code session via `~/.claude/CLAUDE.md`. Keep it short: add a line only when Claude gets something wrong twice, and turn anything that must always hold into a hook instead.

## Preferences

- No emojis in code, comments, or documentation.
- Commit messages follow conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`) without a Co-Authored-By trailer.
- Never paste secrets (API keys, tokens, passwords, JWTs) into output; redact them from logs.

## Bash command style

Permission rules in `settings.json` are prefix-matched globs such as `Bash(git *)`. Commands that don't fit them cause needless permission prompts.

- Don't use `git -C <path>`; rely on the working directory.
- Don't chain independent commands with `&&`; issue them as parallel tool calls. Use `&&` only when a later step depends on the earlier one succeeding.
- Prefer `rg` over `grep` / `find` when available.
