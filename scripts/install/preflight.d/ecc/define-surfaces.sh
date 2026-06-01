#!/usr/bin/env bash

# Managed dotfile surface definitions for ECC base/profile branches.

emit_surface() {
    printf 'surface\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"
}

case "${DOTFILES_BRANCH:-}" in
    profile/ecc-base|profile/ecc/*) ;;
    *) exit 0 ;;
esac

emit_surface "$DOTPATH/.claude" "$HOME/.claude" should_skip_claude_entry "Claude Code root config"
emit_surface "$DOTPATH/.claude/.agents" "$HOME/.claude/.agents" should_skip_claude_dot_agents_entry "Claude embedded agent root"
emit_surface "$DOTPATH/.claude/.agents/plugins" "$HOME/.claude/.agents/plugins" should_skip_collection_entry "Claude embedded agent plugins"
emit_surface "$DOTPATH/.claude/.agents/skills" "$HOME/.claude/.agents/skills" should_skip_collection_entry "Claude embedded agent skills"
emit_surface "$DOTPATH/.claude/agents" "$HOME/.claude/agents" should_skip_collection_entry "Claude agents"
emit_surface "$DOTPATH/.claude/commands" "$HOME/.claude/commands" should_skip_collection_entry "Claude commands"
emit_surface "$DOTPATH/.claude/rules" "$HOME/.claude/rules" should_skip_claude_rules_entry "Claude rules root"
emit_surface "$DOTPATH/.claude/rules/ecc" "$HOME/.claude/rules/ecc" should_skip_collection_entry "Claude ECC rules"
emit_surface "$DOTPATH/.claude/skills" "$HOME/.claude/skills" should_skip_claude_skills_entry "Claude skills root"
emit_surface "$DOTPATH/.claude/skills/ecc" "$HOME/.claude/skills/ecc" should_skip_collection_entry "Claude ECC skills"

emit_surface "$DOTPATH/.codex" "$HOME/.codex" should_skip_codex_entry "Codex root config"
emit_surface "$DOTPATH/.codex/agents" "$HOME/.codex/agents" should_skip_collection_entry "Codex agent roles"
emit_surface "$DOTPATH/.codex/prompts" "$HOME/.codex/prompts" should_skip_collection_entry "Codex prompts"

emit_surface "$DOTPATH/.agents" "$HOME/.agents" should_skip_agents_entry "user-level agent root"
emit_surface "$DOTPATH/.agents/skills" "$HOME/.agents/skills" should_skip_collection_entry "user-level Codex skills"
