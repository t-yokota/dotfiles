#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: install.sh must be run with bash. Use: bash install.sh" >&2
    exit 1
fi

DOTPATH=${DOTPATH:-"$HOME/dotfiles"}
OH_MY_ZSH_THEMES=${OH_MY_ZSH_THEMES:-"$HOME/.oh-my-zsh/themes"}

cd "$DOTPATH" || { echo "Error: Could not cd to $DOTPATH"; exit 1; }

# Include hidden managed entries such as .claude/.agents, and make empty globs disappear.
shopt -s nullglob dotglob

MANAGED_SURFACES=()
SKIPSET_PATTERNS=()
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

log_section "Link Conflict Check"
log_step "Check top-level destination conflicts"
preflight_root_entries || exit 1
log_step "Check managed dotfile surface destination conflicts"
preflight_all_managed_surfaces || exit 1

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
if [ -d "$OH_MY_ZSH_THEMES" ]; then
    log_step "Source: $DOTPATH"
    log_step "Target: $OH_MY_ZSH_THEMES"
    for theme in "$DOTPATH"/*.zsh-theme; do
        theme_dest="$OH_MY_ZSH_THEMES/$(basename "$theme")"
        ln -snf "$theme" "$theme_dest" || exit 1
        log_link "$theme_dest" "$theme"
    done
else
    log_step "Skip: $OH_MY_ZSH_THEMES does not exist"
fi
