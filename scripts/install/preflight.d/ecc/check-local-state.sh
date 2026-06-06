#!/usr/bin/env bash

# profile/ecc/* branches are only safe to expose after each machine has
# recreated the local ECC lifecycle/sync state that is intentionally not
# committed. profile/ecc-base is a tooling/base branch and intentionally skips
# this check.

case "${DOTFILES_BRANCH:-}" in
    profile/ecc-base)
        echo "    - Status: base branch; skip local ECC install-state checks" >&2
        exit 0
        ;;
    profile/ecc/*)
        echo "    - Status: check local ECC install-state for $DOTFILES_BRANCH" >&2
        ;;
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

rc=0
check_ecc_claude_state || rc=1
check_ecc_codex_state || rc=1
exit "$rc"
