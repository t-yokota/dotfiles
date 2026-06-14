#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: uninstall.sh must be run with bash. Use: bash uninstall.sh" >&2
    exit 1
fi

set -u
# Do not use set -e: uninstaller phases intentionally propagate errors with explicit || exit handling.

usage() {
    cat <<'USAGE'
Usage: bash uninstall.sh [--dry-run|-n] [--verbose|-v]

Options:
  -n, --dry-run  Show planned removals without writing changes.
  -v, --verbose  Print detailed remove logs.
  -h, --help     Show this help.
USAGE
}

INSTALL_DRY_RUN=0
INSTALL_VERBOSE=0

DOTPATH=${DOTPATH:-"$HOME/dotfiles"}
INSTALL_LIB_DIR="$DOTPATH/scripts/install/lib"
COMMON_LIB="$INSTALL_LIB_DIR/common.sh"
if [ ! -f "$COMMON_LIB" ]; then
    echo "Error: missing installer library: $COMMON_LIB" >&2
    exit 1
fi
# shellcheck source=scripts/install/lib/common.sh
. "$COMMON_LIB"
# shellcheck source=scripts/install/lib/cli.sh
. "$INSTALL_LIB_DIR/cli.sh"
cli_parse_standard_options uninstall "$@" || exit 1
cli_bootstrap profile reconcile || exit 1

log_mode_section \
    "Dry-run mode: no symlink changes will be written by the common uninstaller. Use --verbose to list each planned removal." \
    "Verbose mode: detailed remove logs will be printed"

log_section "Preflight"
log_step "Load active profile manifests"
load_active_profile_manifests || exit 1
log_ok "preflight passed"

log_section "Remove Top-Level Dotfile Links"
summary_scope_begin
uninstall_root_symlinks || exit 1
summary_scope_remove_ok "top-level dotfile links"

log_section "Remove Managed Dotfile Surface Links"
summary_scope_begin
log_surface_manifests
uninstall_all_managed_surfaces || exit 1
summary_scope_remove_ok "managed dotfile surface links"

log_section "Remove Unscoped Managed Links"
summary_scope_begin
log_managed_roots
uninstall_unscoped_managed_links || exit 1
summary_scope_remove_ok "unscoped managed links"

log_section "Remove Shell Theme Links"
summary_scope_begin
uninstall_shell_themes || exit 1
summary_scope_remove_ok "shell theme links"

if is_dry_run; then
    log_section "Dry-run Result"
    log_result_summary uninstall
    log_step "OK: no changes were written by the common uninstaller"
else
    log_section "Uninstall Result"
    log_result_summary uninstall
    log_step "OK: uninstall completed; dotfiles-managed symlinks were removed"
fi
