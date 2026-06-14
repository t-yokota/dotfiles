#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: install.sh must be run with bash. Use: bash install.sh" >&2
    exit 1
fi

set -u
# Do not use set -e: installer phases intentionally propagate errors with explicit || exit handling.

usage() {
    cat <<'USAGE'
Usage: bash install.sh [--dry-run|-n] [--verbose|-v]

Options:
  -n, --dry-run  Validate planned changes without writing them.
  -v, --verbose  Print detailed link, remove, and skip logs.
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
cli_parse_standard_options install "$@" || exit 1
cli_bootstrap profile reconcile || exit 1

log_mode_section \
    "Dry-run mode: no symlink, directory, or cleanup changes will be written by the common installer. Use --verbose to list each planned change." \
    "Verbose mode: detailed link, remove, and skip logs will be printed"

log_section "Preflight"
log_step "Load active profile manifests"
load_active_profile_manifests || exit 1
log_step "Run active profile install checks"
run_active_profile_install_checks || exit 1
log_ok "preflight passed"

log_section "Cleanup"
summary_scope_begin
log_step "Prune stale top-level symlinks"
cleanup_root_symlinks || exit 1
log_step "Prune stale managed dotfile surface symlinks"
cleanup_all_managed_surfaces || exit 1
log_step "Prune orphaned managed-root symlinks"
cleanup_orphaned_managed_root_symlinks || exit 1
summary_scope_remove_ok "cleanup"

log_section "Link Conflict Check"
log_step "Check top-level destination conflicts"
preflight_root_entries || exit 1
log_step "Check managed dotfile surface destination conflicts"
preflight_all_managed_surfaces || exit 1
log_step "Check shell theme destination conflicts"
preflight_shell_themes || exit 1
log_ok "no destination conflicts found"

log_section "Link Top-Level Dotfiles"
summary_scope_begin
log_step "Source: $DOTPATH"
log_step "Target: $HOME"
for f in .??*; do
    path_exists_or_link "$f" || continue
    should_skip_root_entry "$(basename "$f")" && continue
    link_managed_entry "$DOTPATH/$f" "$HOME/$f" "$DOTPATH" || exit 1
done
if is_dry_run; then
    log_ok "top-level dotfiles reconciled (planned links: $(summary_scope_delta would_link))"
else
    log_ok "top-level dotfiles reconciled (links: $(summary_scope_delta linked))"
fi

log_section "Link Managed Dotfile Surfaces"
log_surface_manifests
summary_scope_begin
link_all_managed_surfaces || exit 1
if is_dry_run; then
    log_ok "managed dotfile surfaces reconciled (planned links: $(summary_scope_delta would_link), planned removals: $(summary_scope_delta would_remove), skips: $(summary_scope_delta skipped))"
else
    log_ok "managed dotfile surfaces reconciled (links: $(summary_scope_delta linked), removals: $(summary_scope_delta removed), skips: $(summary_scope_delta skipped))"
fi

log_section "Link Shell Themes"
summary_scope_begin
link_shell_themes || exit 1
if is_dry_run; then
    log_ok "shell themes reconciled (planned links: $(summary_scope_delta would_link), skips: $(summary_scope_delta skipped))"
else
    log_ok "shell themes reconciled (links: $(summary_scope_delta linked), skips: $(summary_scope_delta skipped))"
fi

if is_dry_run; then
    log_section "Dry-run Result"
    log_result_summary install
    log_step "OK: no conflicts detected; no changes were written by the common installer"
else
    log_section "Install Result"
    log_result_summary install
    log_step "OK: install completed; changes were written by the common installer"
fi
