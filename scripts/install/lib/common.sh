#!/usr/bin/env bash

# Shared policy-free utilities: logging, manifest lines, branch, and path helpers.

INSTALL_SUMMARY_LINKED=${INSTALL_SUMMARY_LINKED:-0}
INSTALL_SUMMARY_WOULD_LINK=${INSTALL_SUMMARY_WOULD_LINK:-0}
INSTALL_SUMMARY_REMOVED=${INSTALL_SUMMARY_REMOVED:-0}
INSTALL_SUMMARY_WOULD_REMOVE=${INSTALL_SUMMARY_WOULD_REMOVE:-0}
INSTALL_SUMMARY_SKIPPED=${INSTALL_SUMMARY_SKIPPED:-0}
INSTALL_SUMMARY_REMOVE_PATHS=()
INSTALL_VERBOSE=${INSTALL_VERBOSE:-0}
MANAGED_ROOTS=(.claude .codex .agents)

init_installer_state() {
    # shellcheck disable=SC2034 # Shared state read by sourced installer libraries.
    MANAGED_SURFACES=()
    MANAGED_SURFACE_MANIFESTS=()
    # shellcheck disable=SC2034 # Shared state read by sourced installer libraries.
    SKIPSET_PATTERNS=()
    # shellcheck disable=SC2034 # Shared state read by sourced installer libraries.
    SKIPSET_INCLUDES=()
    # shellcheck disable=SC2034 # Shared state read by sourced installer libraries.
    KNOWN_SKIPSETS=()
    # shellcheck disable=SC2034 # Shared state read by sourced installer libraries.
    RESERVED_ROOT_ENTRIES=()
    # shellcheck disable=SC2034 # Shared state read by sourced installer libraries.
    ACTIVE_PROFILE_CHECK_DIRS=()
}

load_installer_libraries() {
    local lib lib_path

    for lib in "$@"; do
        lib_path="$INSTALL_LIB_DIR/$lib.sh"
        if [ ! -f "$lib_path" ]; then
            echo "Error: missing installer library: $lib_path" >&2
            return 1
        fi
        # shellcheck disable=SC1090 # lib_path is validated from INSTALL_LIB_DIR at runtime.
        . "$lib_path"
    done
}

list_contains() {
    local needle="$1"
    local entry
    shift

    for entry in "$@"; do
        [ "$entry" = "$needle" ] && return 0
    done

    return 1
}

path_exists_or_link() {
    [ -e "$1" ] || [ -L "$1" ]
}

is_managed_root() {
    list_contains "$1" "${MANAGED_ROOTS[@]}"
}

add_managed_surface_manifest() {
    local path="$1"

    [ -n "$path" ] || return 0
    list_contains "$path" "${MANAGED_SURFACE_MANIFESTS[@]}" && return 0

    MANAGED_SURFACE_MANIFESTS+=("$path")
}

surface_manifest_summary() {
    local manifest summary=""

    if [ "${#MANAGED_SURFACE_MANIFESTS[@]}" -eq 0 ]; then
        printf '%s' '<none>'
        return 0
    fi

    for manifest in "${MANAGED_SURFACE_MANIFESTS[@]}"; do
        if [ -z "$summary" ]; then
            summary="$manifest"
        else
            summary="$summary, $manifest"
        fi
    done

    printf '%s' "$summary"
}

log_surface_manifests() {
    log_step "Surface manifests: $(surface_manifest_summary)"
}

managed_root_summary() {
    local root summary=""

    if [ "${#MANAGED_ROOTS[@]}" -eq 0 ]; then
        printf '%s' '<none>'
        return 0
    fi

    for root in "${MANAGED_ROOTS[@]}"; do
        if [ -z "$summary" ]; then
            summary="$root"
        else
            summary="$summary, $root"
        fi
    done

    printf '%s' "$summary"
}

log_managed_roots() {
    log_step "Scan roots: $(managed_root_summary)"
}

summary_increment() {
    case "$1" in
        linked) INSTALL_SUMMARY_LINKED=$((INSTALL_SUMMARY_LINKED + 1)) ;;
        would_link) INSTALL_SUMMARY_WOULD_LINK=$((INSTALL_SUMMARY_WOULD_LINK + 1)) ;;
        removed) INSTALL_SUMMARY_REMOVED=$((INSTALL_SUMMARY_REMOVED + 1)) ;;
        would_remove) INSTALL_SUMMARY_WOULD_REMOVE=$((INSTALL_SUMMARY_WOULD_REMOVE + 1)) ;;
        skipped) INSTALL_SUMMARY_SKIPPED=$((INSTALL_SUMMARY_SKIPPED + 1)) ;;
    esac
}

summary_scope_begin() {
    SUMMARY_SCOPE_LINKED=$INSTALL_SUMMARY_LINKED
    SUMMARY_SCOPE_WOULD_LINK=$INSTALL_SUMMARY_WOULD_LINK
    SUMMARY_SCOPE_REMOVED=$INSTALL_SUMMARY_REMOVED
    SUMMARY_SCOPE_WOULD_REMOVE=$INSTALL_SUMMARY_WOULD_REMOVE
    SUMMARY_SCOPE_SKIPPED=$INSTALL_SUMMARY_SKIPPED
}

summary_scope_delta() {
    case "$1" in
        linked) printf '%s\n' $((INSTALL_SUMMARY_LINKED - ${SUMMARY_SCOPE_LINKED:-0})) ;;
        would_link) printf '%s\n' $((INSTALL_SUMMARY_WOULD_LINK - ${SUMMARY_SCOPE_WOULD_LINK:-0})) ;;
        removed) printf '%s\n' $((INSTALL_SUMMARY_REMOVED - ${SUMMARY_SCOPE_REMOVED:-0})) ;;
        would_remove) printf '%s\n' $((INSTALL_SUMMARY_WOULD_REMOVE - ${SUMMARY_SCOPE_WOULD_REMOVE:-0})) ;;
        skipped) printf '%s\n' $((INSTALL_SUMMARY_SKIPPED - ${SUMMARY_SCOPE_SKIPPED:-0})) ;;
        *) printf '%s\n' 0 ;;
    esac
}

summary_scope_remove_ok() {
    local label="$1"

    if is_dry_run; then
        log_ok "$label checked (planned removals: $(summary_scope_delta would_remove))"
    else
        log_ok "$label completed (removals: $(summary_scope_delta removed))"
    fi
}

summary_mark_remove_path() {
    local path="$1"

    list_contains "$path" "${INSTALL_SUMMARY_REMOVE_PATHS[@]}" && return 1

    INSTALL_SUMMARY_REMOVE_PATHS+=("$path")
    return 0
}

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

color_gray() {
    color_text "$(printf '\033[90m')" "$1"
}

color_cyan() {
    color_text "$(printf '\033[36m')" "$1"
}

color_magenta() {
    color_text "$(printf '\033[35m')" "$1"
}

color_red() {
    color_text "$(printf '\033[31m')" "$1"
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
            printf '  '
            color_green "$1"
            printf '\n'
            ;;
        Dry-run*)
            printf -- '- '
            color_yellow "$1"
            printf '\n'
            ;;
        Skip:*)
            printf '  '
            color_gray "$1"
            printf '\n'
            ;;
        Error:*)
            printf '  '
            color_red "$1"
            printf '\n'
            ;;
        Check:*|Warn:*)
            printf '  '
            color_yellow "$1"
            printf '\n'
            ;;
        *)
            printf -- '- %s\n' "$1"
            ;;
    esac
}

is_verbose() {
    [ "${INSTALL_VERBOSE:-0}" = "1" ]
}

should_log_detail() {
    is_verbose
}

log_ok() {
    log_step "OK: $1"
}

log_mode_section() {
    local dry_run_message="$1"
    local verbose_message="$2"

    if ! is_dry_run && ! is_verbose; then
        return 0
    fi

    log_section "Mode"
    if is_dry_run; then
        log_step "$dry_run_message"
    fi
    if is_verbose; then
        log_step "$verbose_message"
    fi
}

log_substep() {
    case "$1" in
        "Would remove"*)
            should_log_detail || return 0
            printf '    - '
            color_magenta "$1"
            printf '\n'
            ;;
        Would*)
            should_log_detail || return 0
            printf '    - '
            color_cyan "$1"
            printf '\n'
            ;;
        Skip*)
            should_log_detail || return 0
            printf '    - '
            color_gray "$1"
            printf '\n'
            ;;
        Remove*)
            should_log_detail || return 0
            printf '    - '
            color_magenta "$1"
            printf '\n'
            ;;
        *)
            should_log_detail || return 0
            printf '  - %s\n' "$1"
            ;;
    esac
}

count_and_log_skip() {
    local style="$1"
    local message="$2"

    summary_increment skipped

    case "$style" in
        step) log_step "$message" ;;
        substep) log_substep "$message" ;;
        *)
            echo "Error: unknown skip log style: $style" >&2
            return 1
            ;;
    esac
}

# Action-specific log helpers update counters without message-prefix coupling.
log_link() {
    summary_increment linked
    is_verbose || return 0
    printf '    - '
    color_cyan "Create symlink: $1 -> $2"
    printf '\n'
}

log_would_link() {
    summary_increment would_link
    is_verbose || return 0
    printf '    - '
    color_cyan "Would create symlink: $1 -> $2"
    printf '\n'
}

log_result_summary() {
    local mode="${1:-install}"
    local label_width=9
    local count_width

    case "$mode" in
        uninstall)
            if is_dry_run; then
                label_width=17
                count_width=$(max_count_width "$INSTALL_SUMMARY_WOULD_REMOVE")
                log_result_item "Planned removals" "$INSTALL_SUMMARY_WOULD_REMOVE" "$label_width" "$count_width"
            else
                count_width=$(max_count_width "$INSTALL_SUMMARY_REMOVED")
                log_result_item "Removals" "$INSTALL_SUMMARY_REMOVED" "$label_width" "$count_width"
            fi
            ;;
        *)
            if is_dry_run; then
                label_width=17
                count_width=$(max_count_width "$INSTALL_SUMMARY_WOULD_LINK" "$INSTALL_SUMMARY_WOULD_REMOVE" "$INSTALL_SUMMARY_SKIPPED")
                log_result_item "Planned links" "$INSTALL_SUMMARY_WOULD_LINK" "$label_width" "$count_width"
                log_result_item "Planned removals" "$INSTALL_SUMMARY_WOULD_REMOVE" "$label_width" "$count_width"
            else
                count_width=$(max_count_width "$INSTALL_SUMMARY_LINKED" "$INSTALL_SUMMARY_REMOVED" "$INSTALL_SUMMARY_SKIPPED")
                log_result_item "Links" "$INSTALL_SUMMARY_LINKED" "$label_width" "$count_width"
                log_result_item "Removals" "$INSTALL_SUMMARY_REMOVED" "$label_width" "$count_width"
            fi
            log_result_item "Skips" "$INSTALL_SUMMARY_SKIPPED" "$label_width" "$count_width"
            ;;
    esac
}

log_result_item() {
    local label="$1"
    local count="$2"
    local label_width="$3"
    local count_width="$4"

    log_step "$(printf "%-${label_width}s: %${count_width}s" "$label" "$count")"
}

max_count_width() {
    local width=1
    local count

    for count in "$@"; do
        [ "${#count}" -gt "$width" ] && width=${#count}
    done

    printf '%s' "$width"
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
