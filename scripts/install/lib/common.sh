#!/usr/bin/env bash

# Shared installer utilities with no profile-specific policy: logging, ignored
# manifest lines, branch lookup, and path normalization helpers.

log_section() {
    printf '\n== %s ==\n' "$1"
}

log_step() {
    printf -- '- %s\n' "$1"
}

log_substep() {
    printf '  - %s\n' "$1"
}

log_link() {
    printf '    - Link: %s -> %s\n' "$1" "$2"
}

line_is_ignored() {
    local line="$1"

    [ -z "$line" ] && return 0
    case "$line" in
        \#*) return 0 ;;
        *) return 1 ;;
    esac
}

get_current_branch() {
    if [ -n "${DOTFILES_BRANCH:-}" ]; then
        printf '%s\n' "$DOTFILES_BRANCH"
        return 0
    fi

    git branch --show-current 2>/dev/null || true
}

resolve_dotpath_path() {
    local path="$1"

    case "$path" in
        /*) printf '%s\n' "$path" ;;
        *) printf '%s/%s\n' "$DOTPATH" "${path#./}" ;;
    esac
}

resolve_home_path() {
    local path="$1"

    case "$path" in
        /*) printf '%s\n' "$path" ;;
        *) printf '%s/%s\n' "$HOME" "${path#./}" ;;
    esac
}

root_entry_for_path() {
    local path="${1#./}"

    printf '%s\n' "${path%%/*}"
}
