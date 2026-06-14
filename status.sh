#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: status.sh must be run with bash. Use: bash status.sh" >&2
    exit 1
fi

set -u
# Do not use set -e: status phases intentionally propagate errors with explicit || exit handling.

usage() {
    cat <<'USAGE'
Usage: bash status.sh [--verbose|-v]

Options:
  -v, --verbose  Include linked and skipped entries in the status output.
  -h, --help     Show this help.
USAGE
}

STATUS_VERBOSE=0

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
cli_parse_standard_options status "$@" || exit 1
cli_bootstrap profile reconcile status || exit 1

BRANCH=$(get_current_branch)

if [ "$STATUS_VERBOSE" -eq 1 ]; then
    log_section "Mode"
    log_step "Verbose mode: detailed status paths will be printed"
fi

log_section "Context"
log_step "DOTPATH: $DOTPATH"
log_step "HOME: $HOME"
log_step "Branch: ${BRANCH:-<unknown>}"

log_section "Preflight"
log_step "Load active profile manifests"
load_active_profile_manifests || exit 1
status_summary_step "OK: preflight passed"

log_section "Desired Top-Level Dotfile Links"
status_root_entries

log_section "Desired Managed Dotfile Surface Links"
log_surface_manifests
status_all_managed_surfaces

log_section "Desired Shell Theme Links"
status_shell_themes

log_section "Unexpected Managed Links"
status_scan_managed_inventory

log_section "Status Result"
status_result_summary
status_result_message
