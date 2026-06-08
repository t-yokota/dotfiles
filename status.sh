#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: status.sh must be run with bash. Use: bash status.sh" >&2
    exit 1
fi

usage() {
    cat <<'USAGE'
Usage: bash status.sh [--verbose|-v]

Options:
  -v, --verbose  Include linked and skipped entries in the status output.
  -h, --help     Show this help.
USAGE
}

STATUS_VERBOSE=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        -v|--verbose)
            STATUS_VERBOSE=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

DOTPATH=${DOTPATH:-"$HOME/dotfiles"}
OH_MY_ZSH_THEMES=${OH_MY_ZSH_THEMES:-"$HOME/.oh-my-zsh/themes"}

cd "$DOTPATH" || { echo "Error: Could not cd to $DOTPATH"; exit 1; }

# Include hidden managed entries such as .claude/.agents, and make empty globs disappear.
shopt -s nullglob dotglob

MANAGED_SURFACES=()
SKIPSET_PATTERNS=()
KNOWN_SKIPSETS=()
RESERVED_ROOT_ENTRIES=()
ACTIVE_PROFILE_CHECK_DIRS=()

INSTALL_LIB_DIR="$DOTPATH/scripts/install/lib"
for lib in common profile reconcile status; do
    lib_path="$INSTALL_LIB_DIR/$lib.sh"
    if [ ! -f "$lib_path" ]; then
        echo "Error: missing installer library: $lib_path" >&2
        exit 1
    fi
    . "$lib_path"
done

BRANCH=$(get_current_branch)

log_section "Context"
log_step "DOTPATH: $DOTPATH"
log_step "HOME: $HOME"
log_step "Branch: ${BRANCH:-<unknown>}"

log_section "Preflight"
log_step "Load active profile manifests"
load_active_profile_manifests || exit 1

log_section "Desired Link Status"
status_root_entries
status_all_managed_surfaces
status_shell_themes

log_section "Existing Managed Links"
status_scan_managed_inventory

log_section "Status Result"
status_result_summary
log_step "OK: status checked; no changes were written"
