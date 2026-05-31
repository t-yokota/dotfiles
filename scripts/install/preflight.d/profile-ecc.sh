#!/usr/bin/env bash

# profile/ecc/* branches are only safe to expose after each machine has
# recreated the local ECC lifecycle/sync state that is intentionally not
# committed. profile/ecc-base is a tooling/base branch and intentionally skips
# this check.

emit_surface() {
    printf 'surface\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"
}

emit_surfaces() {
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
}

case "${DOTFILES_INSTALL_MODE:-}" in
    surfaces)
        case "${DOTFILES_BRANCH:-}" in
            profile/ecc-base|profile/ecc/*) emit_surfaces ;;
        esac
        exit 0
        ;;
esac

case "${DOTFILES_BRANCH:-}" in
    profile/ecc/*) ;;
    *) exit 0 ;;
esac

check_required_file() {
    local path="$1"
    local label="$2"

    if [ ! -f "$path" ]; then
        echo "Error: missing $label: $path" >&2
        return 1
    fi
}

check_file_contains_fixed() {
    local path="$1"
    local text="$2"
    local label="$3"

    if ! grep -Fq "$text" "$path"; then
        echo "Error: $label not found in $path" >&2
        return 1
    fi
}

is_exact_managed_symlink() {
    local link_path="$1"
    local expected_target="$2"

    [ -L "$link_path" ] || return 1
    [ "$(readlink "$link_path")" = "$expected_target" ]
}

check_ecc_claude_state() {
    local rc=0

    check_required_file "$DOTPATH/.claude/ecc/install-state.json" \
        "Claude ECC install-state" || rc=1

    if [ "$rc" -ne 0 ]; then
        echo "Run this from the ECC repo before install.sh:" >&2
        echo "  HOME=\"$DOTPATH\" bash ./install.sh --target claude --profile full" >&2
    fi

    return "$rc"
}

check_ecc_claude_package_surface() {
    local rel_path="$1"
    local source_path="$DOTPATH/$rel_path"
    local dest_path="$HOME/$rel_path"

    [ -e "$source_path" ] || [ -L "$source_path" ] || return 0

    if [ -e "$dest_path" ] || [ -L "$dest_path" ]; then
        if ! is_exact_managed_symlink "$dest_path" "$source_path"; then
            echo "Error: $dest_path already exists, but $rel_path is managed as a whole ECC package directory." >&2
            echo "Move the existing local path aside, or merge its intended contents into $source_path before rerunning install.sh." >&2
            return 1
        fi
    fi
}

check_ecc_claude_surfaces() {
    local rc=0

    # These surfaces are version-aligned ECC package output from the Claude
    # manual installer. They should be exposed as whole directories, not merged
    # entry-by-entry with user-local content.
    check_ecc_claude_package_surface ".claude/hooks" || rc=1
    check_ecc_claude_package_surface ".claude/scripts" || rc=1
    check_ecc_claude_package_surface ".claude/mcp-configs" || rc=1

    return "$rc"
}

check_ecc_codex_state() {
    local rc=0
    local state_file="$DOTPATH/.codex/dotfiles-profile-ecc-sync-state.json"

    # Ignored local marker: proves this machine has run the local Codex setup step.
    check_required_file "$state_file" "Codex ECC local sync marker" || rc=1

    if [ -f "$state_file" ]; then
        check_file_contains_fixed "$state_file" \
            '"state_owner": "dotfiles.profile-ecc.codex-sync"' \
            "Codex ECC sync marker owner" || rc=1
        check_file_contains_fixed "$state_file" \
            "\"dotpath\": \"$DOTPATH\"" \
            "Codex ECC sync marker dotpath" || rc=1
    fi

    if [ "$rc" -ne 0 ]; then
        echo "Run the Codex sync and skills bundle steps, then create the local marker:" >&2
        echo "  export ECC_REPO=\"/path/to/everything-claude-code\"" >&2
        echo "  HOME=\"$DOTPATH\" \\" >&2
        echo "  CODEX_HOME=\"$DOTPATH/.codex\" \\" >&2
        echo "  AGENTS_HOME=\"$DOTPATH/.agents\" \\" >&2
        echo "  ECC_GLOBAL_HOOKS_DIR=\"$DOTPATH/.codex/git-hooks\" \\" >&2
        echo "  GIT_CONFIG_GLOBAL=\"$DOTPATH/.gitconfig.local\" \\" >&2
        echo "  bash \"\$ECC_REPO/scripts/sync-ecc-to-codex.sh\"" >&2
        echo "  mkdir -p \"$DOTPATH/.agents/skills\"" >&2
        echo "  cp -R \"\$ECC_REPO/.agents/skills/.\" \"$DOTPATH/.agents/skills/\"" >&2
        echo "  DOTPATH=\"$DOTPATH\" ECC_REPO=\"\$ECC_REPO\" \\" >&2
        echo "  bash \"$DOTPATH/scripts/install/write-profile-ecc-codex-sync-state.sh\"" >&2
    fi

    return "$rc"
}

echo "Checking ECC local state for branch $DOTFILES_BRANCH"
rc=0
check_ecc_claude_state || rc=1
check_ecc_claude_surfaces || rc=1
check_ecc_codex_state || rc=1
exit "$rc"
