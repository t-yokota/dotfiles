#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: uninstall.sh must be run with bash. Use: bash uninstall.sh" >&2
    exit 1
fi

usage() {
    cat <<'USAGE'
Usage: bash uninstall.sh [--dry-run|-n] [--verbose|-v]

Options:
  -n, --dry-run  Show dotfiles-managed symlinks that would be removed without writing changes.
  -v, --verbose  Print detailed remove logs.
  -h, --help     Show this help.
USAGE
}

INSTALL_DRY_RUN=0
INSTALL_VERBOSE=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        -n|--dry-run)
            INSTALL_DRY_RUN=1
            ;;
        -v|--verbose)
            INSTALL_VERBOSE=1
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

uninstall_scope_begin() {
    UNINSTALL_SCOPE_REMOVED=$INSTALL_SUMMARY_REMOVED
    UNINSTALL_SCOPE_WOULD_REMOVE=$INSTALL_SUMMARY_WOULD_REMOVE
}

uninstall_scope_result() {
    local label="$1"
    local removed=$((INSTALL_SUMMARY_REMOVED - UNINSTALL_SCOPE_REMOVED))
    local would_remove=$((INSTALL_SUMMARY_WOULD_REMOVE - UNINSTALL_SCOPE_WOULD_REMOVE))

    if is_dry_run; then
        log_ok "$label checked (planned removals: $would_remove)"
    else
        log_ok "$label completed (removals: $removed)"
    fi
}

DOTPATH=${DOTPATH:-"$HOME/dotfiles"}
OH_MY_ZSH_THEMES=${OH_MY_ZSH_THEMES:-"$HOME/.oh-my-zsh/themes"}

cd "$DOTPATH" || { echo "Error: Could not cd to $DOTPATH"; exit 1; }

# Include hidden managed entries such as .claude/.agents, and make empty globs disappear.
shopt -s nullglob dotglob

INSTALL_LIB_DIR="$DOTPATH/scripts/install/lib"
COMMON_LIB="$INSTALL_LIB_DIR/common.sh"
if [ ! -f "$COMMON_LIB" ]; then
    echo "Error: missing installer library: $COMMON_LIB" >&2
    exit 1
fi
. "$COMMON_LIB"
init_installer_state
load_installer_libraries profile reconcile || exit 1

log_mode_section \
    "Dry-run mode: no symlink changes will be written by the common uninstaller" \
    "Verbose mode: detailed remove logs will be printed"

log_section "Preflight"
log_step "Load active profile manifests"
load_active_profile_manifests || exit 1
log_ok "preflight passed"

log_section "Remove Top-Level Dotfile Links"
uninstall_scope_begin
uninstall_root_symlinks || exit 1
uninstall_scope_result "top-level dotfile links"

log_section "Remove Managed Dotfile Surface Links"
uninstall_scope_begin
log_surface_manifests
uninstall_all_managed_surfaces || exit 1
uninstall_scope_result "managed dotfile surface links"

log_section "Remove Unscoped Tool-Root Links"
uninstall_scope_begin
uninstall_tool_root_symlinks || exit 1
uninstall_scope_result "unscoped tool-root links"

log_section "Remove Shell Theme Links"
uninstall_scope_begin
uninstall_shell_themes || exit 1
uninstall_scope_result "shell theme links"

if is_dry_run; then
    log_section "Dry-run Result"
    log_result_summary uninstall
    log_step "OK: no changes were written by the common uninstaller"
else
    log_section "Uninstall Result"
    log_result_summary uninstall
    log_step "OK: uninstall completed; dotfiles-managed symlinks were removed"
fi
