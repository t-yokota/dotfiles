#!/usr/bin/env bash

DOTPATH=~/dotfiles
OH_MY_ZSH_THEMES=~/.oh-my-zsh/themes

cd "$DOTPATH" || { echo "Error: Could not cd to $DOTPATH"; exit 1; }

# Include hidden managed entries such as .claude/.agents, and make empty globs disappear.
shopt -s nullglob dotglob

# Only clean symlinks that point back into the managed dotfiles directory.
is_managed_symlink() {
    local link_path="$1"
    local managed_root="$2"
    local target

    # Never clean regular files/directories or symlinks created outside this script.
    [ -L "$link_path" ] || return 1
    target=$(readlink "$link_path")

    # Managed links always point into the matching dotfiles source directory.
    case "$target" in
        "$managed_root"/*) return 0 ;;
        *) return 1 ;;
    esac
}

# Repo-local control files and tool profile directories are handled separately.
should_skip_root_entry() {
    case "$1" in
        .git|.gitignore|.gitconfig.local|.claude|.codex|.agents)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Claude runtime state is machine/session-local, so it stays under ~/.claude.
should_skip_claude_entry() {
    case "$1" in
        # Installer state and Claude runtime/session artifacts stay outside symlink management.
        ecc|projects|session*|history.jsonl|logs|cache|caches|tmp|statsig|todos|plugins|plugin-cache|.credentials.json|credentials.json|config.json|models_cache.json|session_index.jsonl|*.log|*.db|*.sqlite|*.sqlite-wal|*.sqlite-shm)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Codex auth, sessions, backups, and global hook output should not be symlinked.
should_skip_codex_entry() {
    case "$1" in
        # Codex credentials, session state, backups, and generated hooks are machine-local.
        auth.json|sessions|logs|backups|git-hooks|ecc-install-state.json|history.jsonl|cache|caches|tmp|plugins|plugin-cache|.credentials.json|credentials.json|config.json|models_cache.json|session_index.jsonl|*.log|*.db|*.sqlite|*.sqlite-wal|*.sqlite-shm)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# User-level agents state may include skills as desired state plus local runtime data.
should_skip_agents_entry() {
    case "$1" in
        logs|backups|cache|caches|tmp|plugins|plugin-cache|sessions|.credentials.json|credentials.json|config.json|models_cache.json|session_index.jsonl|*.log|*.db|*.sqlite|*.sqlite-wal|*.sqlite-shm)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Detect conflicts before linking so install.sh does not partially apply a profile.
check_managed_entry() {
    local dest_path="$1"
    local managed_root="$2"

    if [ -e "$dest_path" ] || [ -L "$dest_path" ]; then
        if ! is_managed_symlink "$dest_path" "$managed_root"; then
            echo "Error: $dest_path already exists and is not a dotfiles-managed symlink." >&2
            echo "Move or merge it before rerunning install.sh." >&2
            return 1
        fi
    fi
}

# Check ordinary top-level dotfiles before writing; managed tool directories are
# skipped here because their contents need per-entry runtime-state filtering.
preflight_root_entries() {
    local f name

    for f in .??*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        name=$(basename "$f")
        should_skip_root_entry "$name" && continue

        check_managed_entry "$HOME/$name" "$DOTPATH" || return 1
    done
}

# Check desired entries inside one managed tool directory before creating any
# symlink, so a conflict does not leave the HOME tree partially updated.
preflight_managed_entries() {
    local source_dir="$1"
    local dest_dir="$2"
    local skip_fn="$3"
    local f name

    for f in "$source_dir"/*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        name=$(basename "$f")
        "$skip_fn" "$name" && continue

        check_managed_entry "$dest_dir/$name" "$source_dir" || return 1
    done
}

# Replace only symlinks owned by this dotfiles checkout; never write inside
# pre-existing real directories such as ~/.claude/agents.
link_managed_entry() {
    local source_path="$1"
    local dest_path="$2"
    local managed_root="$3"

    check_managed_entry "$dest_path" "$managed_root" || return 1

    ln -snfv "$source_path" "$dest_path"
}

# Cleanup can run even when source_dir no longer exists after a branch switch.
# In that case, managed links under the destination become broken links and should
# be removed so the real HOME no longer exposes the old profile surface.
cleanup_managed_symlinks() {
    local source_dir="$1"
    local dest_dir="$2"
    local skip_fn="$3"
    local name dest target

    [ -d "$dest_dir" ] || return 0

    for dest in "$dest_dir"/*; do
        # Broken symlinks fail -e, so keep the -L check.
        [ -e "$dest" ] || [ -L "$dest" ] || continue
        name=$(basename "$dest")

        if is_managed_symlink "$dest" "$source_dir"; then
            target=$(readlink "$dest")
            # Remove links whose source disappeared after a branch switch, or links that are
            # now classified as runtime state by the skip list.
            if [ ! -e "$target" ] || "$skip_fn" "$name"; then
                echo "Removing stale or skipped symlink $dest"
                rm -f "$dest"
            fi
        fi
    done
}

# Link desired entries while pruning stale or now-skipped managed symlinks.
link_managed_entries() {
    local source_dir="$1"
    local dest_dir="$2"
    local skip_fn="$3"
    local f name dest

    # Keep user-created runtime files in the destination tree, but ensure the directory exists.
    mkdir -p "$dest_dir"

    # Cleanup pass: prune only symlinks that this script owns.
    cleanup_managed_symlinks "$source_dir" "$dest_dir" "$skip_fn"

    for f in "$source_dir"/*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        name=$(basename "$f")
        dest="$dest_dir/$name"

        # Skip tool-generated state even if an install/sync command placed it under dotfiles.
        if "$skip_fn" "$name"; then
            echo "Skipping generated/runtime state $f"
            # If an older install linked this generated/runtime artifact, remove only that managed link.
            if is_managed_symlink "$dest" "$source_dir"; then
                rm -f "$dest"
            fi
            continue
        fi

        # Desired entry: expose the dotfiles-managed source at the tool's HOME path.
        link_managed_entry "$f" "$dest" "$source_dir" || return 1
    done
}

echo "Checking for non-managed symlink conflicts"
# Prune stale top-level dotfile symlinks before preflight so branch removals do
# not turn into false conflicts on the next install run.
cleanup_managed_symlinks "$DOTPATH" "$HOME" should_skip_root_entry

preflight_root_entries || exit 1

# If a branch removes an entire managed surface, there is no source directory for
# link_managed_entries to process. Still prune HOME links that point into the old
# dotfiles source tree.
if [ ! -d "$DOTPATH/.claude" ]; then
    cleanup_managed_symlinks "$DOTPATH/.claude" "$HOME/.claude" should_skip_claude_entry
fi

if [ ! -d "$DOTPATH/.codex" ]; then
    cleanup_managed_symlinks "$DOTPATH/.codex" "$HOME/.codex" should_skip_codex_entry
fi

if [ ! -d "$DOTPATH/.agents" ]; then
    cleanup_managed_symlinks "$DOTPATH/.agents" "$HOME/.agents" should_skip_agents_entry
fi

if [ -d "$DOTPATH/.claude" ]; then
    preflight_managed_entries "$DOTPATH/.claude" "$HOME/.claude" should_skip_claude_entry || exit 1
fi

if [ -d "$DOTPATH/.codex" ]; then
    preflight_managed_entries "$DOTPATH/.codex" "$HOME/.codex" should_skip_codex_entry || exit 1
fi

if [ -d "$DOTPATH/.agents" ]; then
    preflight_managed_entries "$DOTPATH/.agents" "$HOME/.agents" should_skip_agents_entry || exit 1
fi

echo "Creating symbolic links for .dotfiles in $DOTPATH"
# Link ordinary top-level dotfiles. Tool profile directories are handled below so
# runtime state such as sessions, caches, and install-state can stay local.
for f in .??*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    should_skip_root_entry "$(basename "$f")" && continue
    link_managed_entry "$DOTPATH/$f" "$HOME/$f" "$DOTPATH" || exit 1
done

# Claude Code config — symlink files individually to preserve runtime state
# (sessions/, projects/, history.jsonl, etc. live under ~/.claude/)
if [ -d "$DOTPATH/.claude" ]; then
    echo "Creating symbolic links for Claude Code config in $HOME/.claude"
    link_managed_entries "$DOTPATH/.claude" "$HOME/.claude" should_skip_claude_entry || exit 1
fi

# Codex config — symlink files individually to preserve runtime state
# (auth.json, sessions/, logs, state databases, etc. live under ~/.codex/)
if [ -d "$DOTPATH/.codex" ]; then
    echo "Creating symbolic links for Codex config in $HOME/.codex"
    link_managed_entries "$DOTPATH/.codex" "$HOME/.codex" should_skip_codex_entry || exit 1
fi

# User-level Codex skills live under ~/.agents/skills; link entries individually so
# future runtime/cache directories under ~/.agents are not pulled into dotfiles.
if [ -d "$DOTPATH/.agents" ]; then
    echo "Creating symbolic links for user-level agent assets in $HOME/.agents"
    link_managed_entries "$DOTPATH/.agents" "$HOME/.agents" should_skip_agents_entry || exit 1
fi

# Dotfiles theme support: expose custom oh-my-zsh themes if that installation is present.
if [ -d "$OH_MY_ZSH_THEMES" ]; then
    echo "Creating symbolic links for .zsh-theme files in $OH_MY_ZSH_THEMES"
    for theme in "$DOTPATH"/*.zsh-theme; do
        ln -snfv "$theme" "$OH_MY_ZSH_THEMES/$(basename "$theme")"
    done
else
    echo "Directory $OH_MY_ZSH_THEMES does not exist. Skipping theme linking."
fi
