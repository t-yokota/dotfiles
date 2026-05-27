# ECC User-Level CLAUDE.md

This is the user-level Claude Code baseline for the `profile/ecc` dotfiles profile.

User-level configs apply globally across all projects. Use for:
- Personal coding preferences
- Universal rules you always want enforced
- Links to your modular rules

---

## Core Philosophy

You are Claude Code. I use specialized agents and skills for complex tasks.

**Key Principles:**
1. **Agent-First**: Delegate to specialized agents for complex work
2. **Parallel Execution**: Use Task tool with multiple agents when possible
3. **Plan Before Execute**: Use Plan Mode for complex operations
4. **Test-Driven**: Write tests before implementation
5. **Security-First**: Never compromise on security

---

## Modular Rules

Detailed ECC guidelines are installed under `~/.claude/rules/ecc/`.
Common rules live in `~/.claude/rules/ecc/common/`; language and framework rules live in sibling directories such as `typescript/`, `python/`, `web/`, and `swift/`.

| Rule File | Contents |
|-----------|----------|
| `~/.claude/rules/ecc/common/security.md` | Security checks, secret management |
| `~/.claude/rules/ecc/common/coding-style.md` | Immutability, file organization, error handling |
| `~/.claude/rules/ecc/common/testing.md` | TDD workflow, verification expectations |
| `~/.claude/rules/ecc/common/git-workflow.md` | Commit format, PR workflow |
| `~/.claude/rules/ecc/common/agents.md` | Agent orchestration, when to use which agent |
| `~/.claude/rules/ecc/common/patterns.md` | API response, repository patterns |
| `~/.claude/rules/ecc/common/performance.md` | Model selection, context management |
| `~/.claude/rules/ecc/common/hooks.md` | Hooks system |
| `~/.claude/rules/ecc/common/code-review.md` | Review focus and quality gates |
| `~/.claude/rules/ecc/common/development-workflow.md` | Development workflow |

---

## Available Agents

Located in `~/.claude/agents/`:

| Agent | Purpose |
|-------|---------|
| planner | Feature implementation planning |
| architect | System design and architecture |
| tdd-guide | Test-driven development |
| code-reviewer | Code review for quality/security |
| security-reviewer | Security vulnerability analysis |
| build-error-resolver | Build error resolution |
| e2e-runner | Playwright E2E testing |
| refactor-cleaner | Dead code cleanup |
| doc-updater | Documentation updates |

---

## Personal Preferences

### Privacy
- Always redact logs; never paste secrets (API keys/tokens/passwords/JWTs)
- Review output before sharing - remove any sensitive data

### Code Style
- No emojis in code, comments, or documentation
- Prefer immutability - never mutate objects or arrays
- Many small files over few large files
- 200-400 lines typical, 800 max per file

### Git
- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`
- Always test locally before committing
- Small, focused commits

### Testing
- TDD: Write tests first
- 80% minimum coverage
- Unit + integration + E2E for critical flows

### Knowledge Capture
- Personal debugging notes, preferences, and temporary context → auto memory
- Team/project knowledge (architecture decisions, API changes, implementation runbooks) → follow the project's existing docs structure
- If the current task already produces the relevant docs, comments, or examples, do not duplicate the same knowledge elsewhere
- If there is no obvious project doc location, ask before creating a new top-level doc

---

## Editor Integration

I use Zed as my primary editor:
- Agent Panel for file tracking
- CMD+Shift+R for command palette
- Vim mode enabled

---

## Success Metrics

You are successful when:
- All tests pass (80%+ coverage)
- No security vulnerabilities
- Code is readable and maintainable
- User requirements are met

---

**Philosophy**: Agent-first design, parallel execution, plan before action, test before code, security always.
