#!/usr/bin/env bash

# Reconciliation engine: validate destination conflicts, identify symlinks owned
# by this dotfiles checkout, prune stale managed links, and create the desired
# top-level and managed-surface symlinks.

remove_managed_path() {
    local description="$1"
    local path="$2"

    if is_dry_run; then
        log_substep "Would remove $description: $path"
        return 0
    fi

    log_substep "Remove $description: $path"
    rm -f "$path"
}

ensure_directory() {
    local dir="$1"

    [ -d "$dir" ] && return 0

    if is_dry_run; then
        log_substep "Would create directory: $dir"
        return 0
    fi

    mkdir -p "$dir"
}

# A symlink is managed only when it points back into the expected dotfiles source.
is_managed_symlink() {
    local link_path="$1"
    local managed_root="$2"
    local target

    [ -L "$link_path" ] || return 1
    target=$(readlink "$link_path")

    case "$target" in
        "$managed_root"|"$managed_root"/*) return 0 ;;
        *) return 1 ;;
    esac
}

# Detect conflicts before writing so install.sh does not partially apply a profile.
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

# Entry surfaces write links inside this container; writing through an unrelated
# symlink would cross ownership boundaries.
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

check_whole_destination_parent() {
    local dest_path="$1"
    local parent="${dest_path%/*}"

    [ "$parent" = "$dest_path" ] && parent="."

    if [ -L "$parent" ]; then
        echo "Error: $parent is a symlink, but this profile manages a whole entry inside it." >&2
        echo "Move or replace it with a real directory before rerunning install.sh." >&2
        return 1
    fi

    if [ -e "$parent" ] && [ ! -d "$parent" ]; then
        echo "Error: $parent already exists and is not a directory." >&2
        echo "Move or merge it before rerunning install.sh." >&2
        return 1
    fi
}

preflight_root_entries() {
    local f name

    for f in .??*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        name=$(basename "$f")
        should_skip_root_entry "$name" && continue

        check_managed_entry "$HOME/$name" "$DOTPATH" || return 1
    done
}

preflight_managed_entries() {
    local source_dir="$1"
    local dest_dir="$2"
    local skipset="$3"
    local f name

    check_destination_container "$dest_dir" || return 1

    for f in "$source_dir"/*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        name=$(basename "$f")
        should_skip_entry "$skipset" "$name" && continue

        check_managed_entry "$dest_dir/$name" "$source_dir" || return 1
    done
}

preflight_whole_surface() {
    local source_path="$1"
    local dest_path="$2"

    [ -e "$source_path" ] || [ -L "$source_path" ] || return 0

    check_whole_destination_parent "$dest_path" || return 1
    check_managed_entry "$dest_path" "$source_path" || return 1
}

link_managed_entry() {
    local source_path="$1"
    local dest_path="$2"
    local managed_root="$3"

    check_managed_entry "$dest_path" "$managed_root" || return 1

    if is_dry_run; then
        log_would_link "$dest_path" "$source_path"
        return 0
    fi

    ln -snf "$source_path" "$dest_path" || return 1
    log_link "$dest_path" "$source_path"
}

# Cleanup can run even when source_dir no longer exists after a branch switch.
# In that case, managed links under the destination become broken links and
# should be removed so HOME no longer exposes the old profile surface.
cleanup_managed_symlinks() {
    local source_dir="$1"
    local dest_dir="$2"
    local skipset="$3"
    local container_policy="${4:-strict}"
    local name dest target child_source

    if [ "$container_policy" != "allow-container-symlink" ] && [ -L "$dest_dir" ]; then
        if is_managed_symlink "$dest_dir" "$source_dir"; then
            remove_managed_path "managed container symlink" "$dest_dir"
            return 0
        fi

        echo "Error: $dest_dir is a symlink, but this profile manages entries inside it." >&2
        echo "Move or replace it with a real directory before rerunning install.sh." >&2
        return 1
    fi

    [ -d "$dest_dir" ] || return 0

    for dest in "$dest_dir"/*; do
        [ -e "$dest" ] || [ -L "$dest" ] || continue
        name=$(basename "$dest")

        if is_managed_symlink "$dest" "$source_dir"; then
            target=$(readlink "$dest")
            child_source="$source_dir/$name"
            if [ ! -e "$target" ] || { should_skip_entry "$skipset" "$name" && ! is_surface_source "$child_source"; }; then
                remove_managed_path "stale or skipped symlink" "$dest"
            fi
        fi
    done
}

cleanup_whole_surface() {
    local source_path="$1"
    local dest_path="$2"
    local target

    if is_managed_symlink "$dest_path" "$source_path"; then
        target=$(readlink "$dest_path")
        if [ ! -e "$target" ]; then
            remove_managed_path "stale whole-entry symlink" "$dest_path"
        fi
    fi
}

cleanup_root_symlinks() {
    local dest name target

    [ -d "$HOME" ] || return 0

    for dest in "$HOME"/*; do
        [ -e "$dest" ] || [ -L "$dest" ] || continue
        name=$(basename "$dest")

        if is_managed_symlink "$dest" "$DOTPATH"; then
            target=$(readlink "$dest")
            if [ ! -e "$target" ] || should_skip_root_entry "$name"; then
                remove_managed_path "stale or reserved top-level symlink" "$dest"
            fi
        fi
    done
}

# Link desired entries while pruning stale or now-skipped managed symlinks.
link_managed_entries() {
    local source_dir="$1"
    local dest_dir="$2"
    local skipset="$3"
    local f name dest child_source

    check_destination_container "$dest_dir" || return 1
    ensure_directory "$dest_dir" || return 1

    cleanup_managed_symlinks "$source_dir" "$dest_dir" "$skipset" || return 1

    for f in "$source_dir"/*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        name=$(basename "$f")
        dest="$dest_dir/$name"
        child_source="$source_dir/$name"

        if should_skip_entry "$skipset" "$name"; then
            log_substep "Skip runtime or separately managed entry: $f"
            if is_managed_symlink "$dest" "$source_dir" && ! is_surface_source "$child_source"; then
                remove_managed_path "previously linked skipped entry" "$dest"
            fi
            continue
        fi

        link_managed_entry "$f" "$dest" "$source_dir" || return 1
    done
}

link_whole_surface() {
    local source_path="$1"
    local dest_path="$2"
    local parent="${dest_path%/*}"

    [ -e "$source_path" ] || [ -L "$source_path" ] || return 0

    check_whole_destination_parent "$dest_path" || return 1
    ensure_directory "$parent" || return 1
    link_managed_entry "$source_path" "$dest_path" "$source_path" || return 1
}

cleanup_all_managed_surfaces() {
    local surface strategy source_path dest_path skipset label

    for surface in "${MANAGED_SURFACES[@]}"; do
        IFS=$'\t' read -r strategy source_path dest_path skipset label <<< "$surface"
        case "$strategy" in
            entries) cleanup_managed_symlinks "$source_path" "$dest_path" "$skipset" || return 1 ;;
            whole) cleanup_whole_surface "$source_path" "$dest_path" || return 1 ;;
        esac
    done
}

preflight_all_managed_surfaces() {
    local surface strategy source_path dest_path skipset label

    for surface in "${MANAGED_SURFACES[@]}"; do
        IFS=$'\t' read -r strategy source_path dest_path skipset label <<< "$surface"
        case "$strategy" in
            entries)
                [ -d "$source_path" ] || continue
                preflight_managed_entries "$source_path" "$dest_path" "$skipset" || return 1
                ;;
            whole)
                preflight_whole_surface "$source_path" "$dest_path" || return 1
                ;;
        esac
    done
}

link_all_managed_surfaces() {
    local surface strategy source_path dest_path skipset label

    for surface in "${MANAGED_SURFACES[@]}"; do
        IFS=$'\t' read -r strategy source_path dest_path skipset label <<< "$surface"
        [ -e "$source_path" ] || [ -L "$source_path" ] || continue
        log_step "$label"
        log_substep "Strategy: $strategy"
        log_substep "Source: $source_path"
        log_substep "Target: $dest_path"
        case "$strategy" in
            entries) link_managed_entries "$source_path" "$dest_path" "$skipset" || return 1 ;;
            whole) link_whole_surface "$source_path" "$dest_path" || return 1 ;;
        esac
    done
}
