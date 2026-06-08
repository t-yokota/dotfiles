#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: install.sh must be run with bash. Use: bash install.sh" >&2
    exit 1
fi

usage() {
    cat <<'USAGE'
Usage: bash install.sh [--dry-run|-n]

Options:
  -n, --dry-run  Validate and show planned changes without writing them.
  -h, --help     Show this help.
USAGE
}

INSTALL_DRY_RUN=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        -n|--dry-run)
            INSTALL_DRY_RUN=1
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
for lib in common profile reconcile; do
    lib_path="$INSTALL_LIB_DIR/$lib.sh"
    if [ ! -f "$lib_path" ]; then
        echo "Error: missing installer library: $lib_path" >&2
        exit 1
    fi
    . "$lib_path"
done

if is_dry_run; then
    log_section "Mode"
    log_step "Dry-run mode: no symlink, directory, or cleanup changes will be written by the common installer"
fi

log_section "Preflight"
log_step "Load active profile manifests"
load_active_profile_manifests || exit 1
log_step "Run active profile install checks"
run_active_profile_install_checks || exit 1

log_section "Cleanup"
log_step "Prune stale top-level symlinks"
cleanup_root_symlinks || exit 1
log_step "Prune stale managed dotfile surface symlinks"
cleanup_all_managed_surfaces || exit 1
log_step "Prune orphaned tool-root symlinks"
cleanup_orphaned_tool_root_symlinks || exit 1

log_section "Link Conflict Check"
log_step "Check top-level destination conflicts"
preflight_root_entries || exit 1
log_step "Check managed dotfile surface destination conflicts"
preflight_all_managed_surfaces || exit 1
log_step "Check shell theme destination conflicts"
preflight_shell_themes || exit 1

log_section "Link Top-Level Dotfiles"
log_step "Source: $DOTPATH"
log_step "Target: $HOME"
for f in .??*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    should_skip_root_entry "$(basename "$f")" && continue
    link_managed_entry "$DOTPATH/$f" "$HOME/$f" "$DOTPATH" || exit 1
done

log_section "Link Managed Dotfile Surfaces"
link_all_managed_surfaces || exit 1

log_section "Link Shell Themes"
link_shell_themes || exit 1

if is_dry_run; then
    log_section "Dry-run Result"
    log_result_summary install
    log_step "OK: no conflicts detected; no changes were written by the common installer"
else
    log_section "Install Result"
    log_result_summary install
    log_step "OK: install completed; changes were written by the common installer"
fi
