#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: install.sh must be run with bash. Use: bash install.sh" >&2
    exit 1
fi

usage() {
    cat <<'USAGE'
Usage: bash install.sh [--dry-run|-n] [--verbose|-v]

Options:
  -n, --dry-run  Validate and show planned changes without writing them.
  -v, --verbose  Print detailed link, remove, and skip logs.
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
    "Dry-run mode: no symlink, directory, or cleanup changes will be written by the common installer" \
    "Verbose mode: detailed link, remove, and skip logs will be printed"

log_section "Preflight"
log_step "Load active profile manifests"
load_active_profile_manifests || exit 1
log_step "Run active profile install checks"
run_active_profile_install_checks || exit 1
log_ok "preflight passed"

log_section "Cleanup"
cleanup_removed_before=$INSTALL_SUMMARY_REMOVED
cleanup_would_remove_before=$INSTALL_SUMMARY_WOULD_REMOVE
log_step "Prune stale top-level symlinks"
cleanup_root_symlinks || exit 1
log_step "Prune stale managed dotfile surface symlinks"
cleanup_all_managed_surfaces || exit 1
log_step "Prune orphaned managed-root symlinks"
cleanup_orphaned_managed_root_symlinks || exit 1
cleanup_removed=$((INSTALL_SUMMARY_REMOVED - cleanup_removed_before))
cleanup_would_remove=$((INSTALL_SUMMARY_WOULD_REMOVE - cleanup_would_remove_before))
if is_dry_run; then
    log_ok "cleanup checked (planned removals: $cleanup_would_remove)"
else
    log_ok "cleanup completed (removals: $cleanup_removed)"
fi

log_section "Link Conflict Check"
log_step "Check top-level destination conflicts"
preflight_root_entries || exit 1
log_step "Check managed dotfile surface destination conflicts"
preflight_all_managed_surfaces || exit 1
log_step "Check shell theme destination conflicts"
preflight_shell_themes || exit 1
log_ok "no destination conflicts found"

log_section "Link Top-Level Dotfiles"
root_linked_before=$INSTALL_SUMMARY_LINKED
root_would_link_before=$INSTALL_SUMMARY_WOULD_LINK
log_step "Source: $DOTPATH"
log_step "Target: $HOME"
for f in .??*; do
    path_exists_or_link "$f" || continue
    should_skip_root_entry "$(basename "$f")" && continue
    link_managed_entry "$DOTPATH/$f" "$HOME/$f" "$DOTPATH" || exit 1
done
root_linked=$((INSTALL_SUMMARY_LINKED - root_linked_before))
root_would_link=$((INSTALL_SUMMARY_WOULD_LINK - root_would_link_before))
if is_dry_run; then
    log_ok "top-level dotfiles reconciled (planned links: $root_would_link)"
else
    log_ok "top-level dotfiles reconciled (links: $root_linked)"
fi

log_section "Link Managed Dotfile Surfaces"
log_surface_manifests
surface_linked_before=$INSTALL_SUMMARY_LINKED
surface_would_link_before=$INSTALL_SUMMARY_WOULD_LINK
surface_removed_before=$INSTALL_SUMMARY_REMOVED
surface_would_remove_before=$INSTALL_SUMMARY_WOULD_REMOVE
surface_skipped_before=$INSTALL_SUMMARY_SKIPPED
link_all_managed_surfaces || exit 1
surface_linked=$((INSTALL_SUMMARY_LINKED - surface_linked_before))
surface_would_link=$((INSTALL_SUMMARY_WOULD_LINK - surface_would_link_before))
surface_removed=$((INSTALL_SUMMARY_REMOVED - surface_removed_before))
surface_would_remove=$((INSTALL_SUMMARY_WOULD_REMOVE - surface_would_remove_before))
surface_skipped=$((INSTALL_SUMMARY_SKIPPED - surface_skipped_before))
if is_dry_run; then
    log_ok "managed dotfile surfaces reconciled (planned links: $surface_would_link, planned removals: $surface_would_remove, skips: $surface_skipped)"
else
    log_ok "managed dotfile surfaces reconciled (links: $surface_linked, removals: $surface_removed, skips: $surface_skipped)"
fi

log_section "Link Shell Themes"
theme_linked_before=$INSTALL_SUMMARY_LINKED
theme_would_link_before=$INSTALL_SUMMARY_WOULD_LINK
theme_skipped_before=$INSTALL_SUMMARY_SKIPPED
link_shell_themes || exit 1
theme_linked=$((INSTALL_SUMMARY_LINKED - theme_linked_before))
theme_would_link=$((INSTALL_SUMMARY_WOULD_LINK - theme_would_link_before))
theme_skipped=$((INSTALL_SUMMARY_SKIPPED - theme_skipped_before))
if is_dry_run; then
    log_ok "shell themes reconciled (planned links: $theme_would_link, skips: $theme_skipped)"
else
    log_ok "shell themes reconciled (links: $theme_linked, skips: $theme_skipped)"
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
