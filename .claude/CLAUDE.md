# Claude Code — Operational Preferences

This file is loaded into every Claude Code session via `~/.claude/CLAUDE.md`.
Project-specific `CLAUDE.md` and `.claude/rules/*.md` override these defaults.

## Reference

For deep guidance on Claude Code internals (subagents, skills, hooks, settings,
MCP, memory), the authoritative local reference is at
`~/developments/agent-references/claude-code-best-practice/`. Search there
before relying on training knowledge or external sources.

## Bash command style (permission compatibility)

`settings.json` permission patterns are prefix-matched globs like
`Bash(git *)`. Commands that don't fit them produce unnecessary permission
prompts.

- **Don't use `git -C <path>` flags.** Rely on the current working directory.
  `git -C ...` does not match `Bash(git *)` and triggers prompts.
- **Avoid `&&` chaining for independent commands.** Issue them as parallel
  Bash tool calls. Chained commands are evaluated as a single string and
  bypass per-command permission patterns. Use `&&` only when a later step
  genuinely depends on the earlier one's success.
- Issue parallel tool calls in a single message when commands are
  independent — faster, and each call matches its own permission pattern.
- Prefer ripgrep (`rg`) over `grep` / `find` when available.

## Tool selection

- Prefer Read / Edit / Write over `cat` / `sed` / `awk` / `echo`. Narrow
  exception: small one-off pipes for shell-only operations.
- Use Glob / Grep tools for code search rather than Bash `find` / `grep`.

## Subagents & workflow

- Subagents cannot invoke other subagents via Bash. Use the Agent tool with
  `subagent_type: <name>`.
- Use the official `Plan` agent (read-only) before implementing complex
  features. Use `Explore` for fast multi-file codebase search.
- Run `/compact` at ~50% context usage on long sessions.
- Break subtasks small enough to finish under 50% context.

## Git safety

- Never use `--no-verify` to bypass hooks unless explicitly requested.
- Never `git push --force` to `main` / `master` without explicit user
  confirmation.
- Repository-level commit conventions in repo `CLAUDE.md` override defaults
  here.

## CLAUDE.md authoring

- Keep each `CLAUDE.md` under 200 lines for reliable adherence.
- Prefer `.claude/rules/*.md` with `paths:` frontmatter for category-specific
  rules — they are lazy-loaded only when matching files are touched.
- Configuration hierarchy (high → low precedence):
  managed → CLI args → `.claude/settings.local.json` →
  `.claude/settings.json` → `~/.claude/settings.json`.
