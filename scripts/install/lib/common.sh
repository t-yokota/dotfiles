#!/usr/bin/env bash

# Shared installer utilities with no profile-specific policy: logging, ignored
# manifest lines, branch lookup, and path normalization helpers.

color_enabled() {
    if [ -n "${FORCE_COLOR:-}" ] && [ "${FORCE_COLOR:-}" != "0" ]; then
        return 0
    fi

    [ -z "${NO_COLOR:-}" ] || return 1
    [ "${TERM:-}" = "dumb" ] && return 1
    [ -t 1 ]
}

color_text() {
    local color="$1"
    local text="$2"
    local reset

    if color_enabled; then
        reset=$(printf '\033[0m')
        printf '%b%s%b' "$color" "$text" "$reset"
    else
        printf '%s' "$text"
    fi
}

color_blue() {
    color_text "$(printf '\033[34m')" "$1"
}

color_green() {
    color_text "$(printf '\033[32m')" "$1"
}

color_cyan() {
    color_text "$(printf '\033[36m')" "$1"
}

color_magenta() {
    color_text "$(printf '\033[35m')" "$1"
}

color_yellow() {
    color_text "$(printf '\033[33m')" "$1"
}

log_section() {
    printf '\n'
    color_blue "== $1 =="
    printf '\n'
}

log_step() {
    case "$1" in
        OK:*)
            printf -- '- '
            color_green "$1"
            printf '\n'
            ;;
        Dry-run*|Skip:*)
            printf -- '- '
            color_yellow "$1"
            printf '\n'
            ;;
        *)
            printf -- '- %s\n' "$1"
            ;;
    esac
}

log_substep() {
    case "$1" in
        Would*|Skip*)
            printf '    - '
            color_yellow "$1"
            printf '\n'
            ;;
        Remove*)
            printf '    - '
            color_magenta "$1"
            printf '\n'
            ;;
        *)
            printf '  - %s\n' "$1"
            ;;
    esac
}

log_link() {
    printf '    - '
    color_cyan "Link: $1 -> $2"
    printf '\n'
}

log_would_link() {
    printf '    - '
    color_yellow "Would link: $1 -> $2"
    printf '\n'
}

is_dry_run() {
    [ "${INSTALL_DRY_RUN:-0}" = "1" ]
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
