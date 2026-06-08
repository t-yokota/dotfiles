#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: uninstall.sh must be run with bash. Use: bash uninstall.sh" >&2
    exit 1
fi

usage() {
    cat <<'USAGE'
Usage: bash uninstall.sh [--dry-run|-n]

Options:
  -n, --dry-run  Show dotfiles-managed symlinks that would be removed without writing changes.
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
    log_step "Dry-run mode: no symlink changes will be written by the common uninstaller"
fi

log_section "Preflight"
log_step "Load active profile manifests"
load_active_profile_manifests || exit 1

log_section "Uninstall"
log_step "Remove top-level dotfiles symlinks"
uninstall_root_symlinks || exit 1
log_step "Remove managed dotfile surface symlinks"
uninstall_all_managed_surfaces || exit 1
log_step "Remove tool-root symlinks"
uninstall_tool_root_symlinks || exit 1
log_step "Remove shell theme symlinks"
uninstall_shell_themes || exit 1

if is_dry_run; then
    log_section "Dry-run Result"
    log_result_summary uninstall
    log_step "OK: no changes were written by the common uninstaller"
else
    log_section "Uninstall Result"
    log_result_summary uninstall
    log_step "OK: uninstall completed; dotfiles-managed symlinks were removed"
fi
