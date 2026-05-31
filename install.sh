#!/usr/bin/env bash

DOTPATH=~/dotfiles
OH_MY_ZSH_THEMES=~/.oh-my-zsh/themes

cd "$DOTPATH" || { echo "Error: Could not cd to $DOTPATH"; exit 1; }

# Include hidden managed entries such as .claude/.agents, and make empty globs disappear.
shopt -s nullglob dotglob

MANAGED_SURFACES=()

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
        "$managed_root"|"$managed_root"/*) return 0 ;;
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
        # Runtime extension collections are managed as their own surfaces below,
        # so local entries can coexist with dotfiles-managed entries. Profile-owned
        # package directories such as hooks, scripts, and mcp-configs stay whole here.
        .agents|agents|commands|rules|skills)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Claude's embedded .agents tree contains its own extension collections.
should_skip_claude_dot_agents_entry() {
    case "$1" in
        skills|plugins|logs|backups|cache|caches|tmp|sessions|.credentials.json|credentials.json|config.json|models_cache.json|session_index.jsonl|*.log|*.db|*.sqlite|*.sqlite-wal|*.sqlite-shm)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ECC rules and skills use an ecc namespace. Manage that namespace one level
# deeper so non-ECC local namespaces can sit beside it.
should_skip_claude_rules_entry() {
    case "$1" in
        ecc|logs|backups|cache|caches|tmp|*.log|*.db|*.sqlite|*.sqlite-wal|*.sqlite-shm)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

should_skip_claude_skills_entry() {
    case "$1" in
        ecc|logs|backups|cache|caches|tmp|*.log|*.db|*.sqlite|*.sqlite-wal|*.sqlite-shm)
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
        auth.json|sessions|logs|backups|git-hooks|ecc-install-state.json|dotfiles-*-sync-state.json|history.jsonl|cache|caches|tmp|plugins|plugin-cache|.credentials.json|credentials.json|config.json|models_cache.json|session_index.jsonl|*.log|*.db|*.sqlite|*.sqlite-wal|*.sqlite-shm)
            return 0
            ;;
        # Codex role and prompt collections are managed one level deeper.
        agents|prompts)
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
        # User-level skills are managed as a collection surface below.
        skills)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Collection surfaces normally have no runtime-state names at their own entry
# level; each child is a desired file/directory unless a parent skip list catches it.
should_skip_collection_entry() {
    return 1
}

add_managed_surface() {
    local source_dir="$1"
    local dest_dir="$2"
    local skip_fn="$3"
    local label="$4"

    if ! declare -F "$skip_fn" >/dev/null; then
        echo "Error: unknown surface skip function: $skip_fn" >&2
        return 1
    fi

    MANAGED_SURFACES+=("$source_dir"$'\t'"$dest_dir"$'\t'"$skip_fn"$'\t'"$label")
}

load_branch_surfaces() {
    local branch
    local hook
    local line kind source_dir dest_dir skip_fn label
    local surface_output

    # Profile hooks may opt in by printing tab-separated "surface" rows when
    # DOTFILES_INSTALL_MODE=surfaces. Normal preflight still runs later.
    branch=$(git branch --show-current 2>/dev/null || true)
    [ -n "$branch" ] || return 0

    for hook in "$DOTPATH"/scripts/install/preflight.d/*.sh; do
        [ -f "$hook" ] || continue
        if ! surface_output=$(
            DOTPATH="$DOTPATH" DOTFILES_BRANCH="$branch" DOTFILES_INSTALL_MODE="surfaces" bash "$hook"
        ); then
            echo "Error: failed to load managed surfaces from $hook" >&2
            return 1
        fi

        while IFS= read -r line; do
            [ -n "$line" ] || continue
            IFS=$'\t' read -r kind source_dir dest_dir skip_fn label <<< "$line"
            [ "$kind" = "surface" ] || continue
            add_managed_surface "$source_dir" "$dest_dir" "$skip_fn" "$label" || return 1
        done <<< "$surface_output"
    done
}

# Branch-specific preflight scripts opt in by inspecting DOTFILES_BRANCH.
run_branch_preflight_scripts() {
    local branch
    local hook
    local rc=0

    branch=$(git branch --show-current 2>/dev/null || true)
    [ -n "$branch" ] || return 0

    for hook in "$DOTPATH"/scripts/install/preflight.d/*.sh; do
        [ -f "$hook" ] || continue
        echo "Running branch preflight $hook"
        DOTPATH="$DOTPATH" DOTFILES_BRANCH="$branch" bash "$hook" || rc=1
    done

    return "$rc"
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

# Managed surfaces write links inside this container. It must be absent or a real
# directory; writing through an unrelated symlink would cross ownership boundaries.
check_destination_container() {
    local dest_dir="$1"

    if [ -L "$dest_dir" ]; then
        echo "Error: $dest_dir is a symlink, but this profile manages entries inside it." >&2
        echo "Move or replace it with a real directory before rerunning install.sh." >&2
        return 1
    fi

    if [ -e "$dest_dir" ] && [ ! -d "$dest_dir" ]; then
        echo "Error: $dest_dir already exists and is not a directory." >&2
        echo "Move or merge it before rerunning install.sh." >&2
        return 1
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

    check_destination_container "$dest_dir" || return 1

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
    local container_policy="${4:-strict}"
    local name dest target

    if [ "$container_policy" != "allow-container-symlink" ] && [ -L "$dest_dir" ]; then
        if is_managed_symlink "$dest_dir" "$source_dir"; then
            echo "Removing managed container symlink $dest_dir"
            rm -f "$dest_dir"
            return 0
        fi

        echo "Error: $dest_dir is a symlink, but this profile manages entries inside it." >&2
        echo "Move or replace it with a real directory before rerunning install.sh." >&2
        return 1
    fi

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

    check_destination_container "$dest_dir" || return 1

    # Keep user-created runtime files in the destination tree, but ensure the directory exists.
    mkdir -p "$dest_dir"

    # Cleanup pass: prune only symlinks that this script owns.
    cleanup_managed_symlinks "$source_dir" "$dest_dir" "$skip_fn" || return 1

    for f in "$source_dir"/*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        name=$(basename "$f")
        dest="$dest_dir/$name"

        # Skip tool-generated state and child collection roots. Child collections
        # are handled by their own managed surface entries.
        if "$skip_fn" "$name"; then
            echo "Skipping runtime or separately managed entry $f"
            # If an older install linked this skipped entry, remove only that managed link.
            if is_managed_symlink "$dest" "$source_dir"; then
                rm -f "$dest"
            fi
            continue
        fi

        # Desired entry: expose the dotfiles-managed source at the tool's HOME path.
        link_managed_entry "$f" "$dest" "$source_dir" || return 1
    done
}

cleanup_all_managed_surfaces() {
    local surface source_dir dest_dir skip_fn label

    # Cleanup runs in the order provided by profile hooks. Parent surfaces should
    # come before child collections so old whole-directory links are pruned first.
    for surface in "${MANAGED_SURFACES[@]}"; do
        IFS=$'\t' read -r source_dir dest_dir skip_fn label <<< "$surface"
        cleanup_managed_symlinks "$source_dir" "$dest_dir" "$skip_fn" || return 1
    done
}

preflight_all_managed_surfaces() {
    local surface source_dir dest_dir skip_fn label

    for surface in "${MANAGED_SURFACES[@]}"; do
        IFS=$'\t' read -r source_dir dest_dir skip_fn label <<< "$surface"
        [ -d "$source_dir" ] || continue
        preflight_managed_entries "$source_dir" "$dest_dir" "$skip_fn" || return 1
    done
}

link_all_managed_surfaces() {
    local surface source_dir dest_dir skip_fn label

    for surface in "${MANAGED_SURFACES[@]}"; do
        IFS=$'\t' read -r source_dir dest_dir skip_fn label <<< "$surface"
        [ -d "$source_dir" ] || continue
        echo "Creating symbolic links for $label in $dest_dir"
        link_managed_entries "$source_dir" "$dest_dir" "$skip_fn" || return 1
    done
}

echo "Checking for non-managed symlink conflicts"
load_branch_surfaces || exit 1
run_branch_preflight_scripts || exit 1

# Prune stale top-level dotfile symlinks before preflight so branch removals do
# not turn into false conflicts on the next install run.
cleanup_managed_symlinks "$DOTPATH" "$HOME" should_skip_root_entry allow-container-symlink || exit 1

preflight_root_entries || exit 1

# Prune old symlinks for every managed surface before conflict detection. This
# also moves older links toward the current surface layout.
cleanup_all_managed_surfaces || exit 1
preflight_all_managed_surfaces || exit 1

echo "Creating symbolic links for .dotfiles in $DOTPATH"
# Link ordinary top-level dotfiles. Tool profile directories are handled below so
# runtime state such as sessions, caches, and install-state can stay local.
for f in .??*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    should_skip_root_entry "$(basename "$f")" && continue
    link_managed_entry "$DOTPATH/$f" "$HOME/$f" "$DOTPATH" || exit 1
done

# Tool roots stay as real HOME directories. Runtime extension collections are
# symlinked entry-by-entry, while profile-owned package directories remain whole entries.
link_all_managed_surfaces || exit 1

# Dotfiles theme support: expose custom oh-my-zsh themes if that installation is present.
if [ -d "$OH_MY_ZSH_THEMES" ]; then
    echo "Creating symbolic links for .zsh-theme files in $OH_MY_ZSH_THEMES"
    for theme in "$DOTPATH"/*.zsh-theme; do
        ln -snfv "$theme" "$OH_MY_ZSH_THEMES/$(basename "$theme")"
    done
else
    echo "Directory $OH_MY_ZSH_THEMES does not exist. Skipping theme linking."
fi
