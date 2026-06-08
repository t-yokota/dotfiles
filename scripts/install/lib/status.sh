#!/usr/bin/env bash

# Read-only link inventory: compare active profile desired links with HOME,
# classify existing dotfiles-managed symlinks, and print summary counts.

STATUS_LINKED=${STATUS_LINKED:-0}
STATUS_MISSING=${STATUS_MISSING:-0}
STATUS_CONFLICT=${STATUS_CONFLICT:-0}
STATUS_STALE=${STATUS_STALE:-0}
STATUS_ORPHANED=${STATUS_ORPHANED:-0}
STATUS_SKIPPED=${STATUS_SKIPPED:-0}
STATUS_VERBOSE=${STATUS_VERBOSE:-0}
STATUS_EXPECTED_DESTS=()
STATUS_SEEN_MANAGED_DESTS=()

status_mark_expected() {
    STATUS_EXPECTED_DESTS+=("$1")
}

status_is_expected() {
    local path="$1"
    local entry

    for entry in "${STATUS_EXPECTED_DESTS[@]}"; do
        [ "$entry" = "$path" ] && return 0
    done

    return 1
}

status_mark_seen_managed() {
    local path="$1"
    local entry

    for entry in "${STATUS_SEEN_MANAGED_DESTS[@]}"; do
        [ "$entry" = "$path" ] && return 1
    done

    STATUS_SEEN_MANAGED_DESTS+=("$path")
    return 0
}

status_print() {
    local kind="$1"
    local message="$2"

    case "$kind" in
        linked)
            [ "$STATUS_VERBOSE" -eq 1 ] || return 0
            printf '    - '
            color_green "linked: $message"
            printf '\n'
            ;;
        missing)
            printf '    - '
            color_yellow "missing: $message"
            printf '\n'
            ;;
        conflict)
            printf '    - '
            color_magenta "conflict: $message"
            printf '\n'
            ;;
        stale)
            printf '    - '
            color_magenta "stale: $message"
            printf '\n'
            ;;
        orphaned)
            printf '    - '
            color_yellow "orphaned: $message"
            printf '\n'
            ;;
        skipped)
            [ "$STATUS_VERBOSE" -eq 1 ] || return 0
            printf '    - '
            color_yellow "skipped: $message"
            printf '\n'
            ;;
    esac
}

status_record() {
    local kind="$1"
    local message="$2"

    case "$kind" in
        linked) STATUS_LINKED=$((STATUS_LINKED + 1)) ;;
        missing) STATUS_MISSING=$((STATUS_MISSING + 1)) ;;
        conflict) STATUS_CONFLICT=$((STATUS_CONFLICT + 1)) ;;
        stale) STATUS_STALE=$((STATUS_STALE + 1)) ;;
        orphaned) STATUS_ORPHANED=$((STATUS_ORPHANED + 1)) ;;
        skipped) STATUS_SKIPPED=$((STATUS_SKIPPED + 1)) ;;
    esac

    status_print "$kind" "$message"
}

status_expected_link() {
    local source_path="$1"
    local dest_path="$2"
    local target

    status_mark_expected "$dest_path"

    if [ -L "$dest_path" ]; then
        target=$(readlink "$dest_path")
        if [ "$target" = "$source_path" ]; then
            status_record linked "$dest_path -> $source_path"
        else
            status_record conflict "$dest_path -> $target; expected $source_path"
        fi
        return 0
    fi

    if [ -e "$dest_path" ]; then
        status_record conflict "$dest_path exists and is not the expected symlink to $source_path"
        return 0
    fi

    status_record missing "$dest_path -> $source_path"
}

status_observe_managed_symlink() {
    local dest_path="$1"
    local target

    [ -L "$dest_path" ] || return 0
    is_managed_symlink "$dest_path" "$DOTPATH" || return 0
    status_mark_seen_managed "$dest_path" || return 0
    status_is_expected "$dest_path" && return 0

    target=$(readlink "$dest_path")
    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
        status_record stale "$dest_path -> $target"
    else
        status_record orphaned "$dest_path -> $target"
    fi
}

status_root_entries() {
    local f name

    log_step "Top-level dotfiles"
    for f in .??*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        name=$(basename "$f")
        should_skip_root_entry "$name" && continue
        status_expected_link "$DOTPATH/$name" "$HOME/$name"
    done
}

status_entries_surface() {
    local source_dir="$1"
    local dest_dir="$2"
    local skipset="$3"
    local f name dest child_source

    [ -d "$source_dir" ] || return 0

    if [ -L "$dest_dir" ]; then
        status_record conflict "$dest_dir is a symlink, but entries are expected inside it"
        return 0
    fi

    for f in "$source_dir"/*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        name=$(basename "$f")
        dest="$dest_dir/$name"
        child_source="$source_dir/$name"

        if should_skip_entry "$skipset" "$name"; then
            status_record skipped "$f"
            continue
        fi

        status_expected_link "$child_source" "$dest"
    done
}

status_whole_surface() {
    local source_path="$1"
    local dest_path="$2"

    [ -e "$source_path" ] || [ -L "$source_path" ] || return 0
    status_expected_link "$source_path" "$dest_path"
}

status_all_managed_surfaces() {
    local surface strategy source_path dest_path skipset label

    for surface in "${MANAGED_SURFACES[@]}"; do
        IFS=$'\t' read -r strategy source_path dest_path skipset label <<< "$surface"
        log_step "$label"
        case "$strategy" in
            entries) status_entries_surface "$source_path" "$dest_path" "$skipset" ;;
            whole) status_whole_surface "$source_path" "$dest_path" ;;
        esac
    done
}

status_shell_themes() {
    local theme theme_dest

    log_step "Shell themes"
    if [ ! -d "$OH_MY_ZSH_THEMES" ]; then
        status_record skipped "$OH_MY_ZSH_THEMES does not exist"
        return 0
    fi

    for theme in "$DOTPATH"/*.zsh-theme; do
        [ -e "$theme" ] || [ -L "$theme" ] || continue
        theme_dest="$OH_MY_ZSH_THEMES/$(basename "$theme")"
        status_expected_link "$theme" "$theme_dest"
    done
}

status_scan_dir_symlinks() {
    local dir="$1"
    local dest

    [ -d "$dir" ] || return 0
    while IFS= read -r -d '' dest; do
        status_observe_managed_symlink "$dest"
    done < <(find "$dir" -type l -print0)
}

status_scan_active_surface_destinations() {
    local surface strategy source_path dest_path skipset label

    for surface in "${MANAGED_SURFACES[@]}"; do
        IFS=$'\t' read -r strategy source_path dest_path skipset label <<< "$surface"
        case "$strategy" in
            entries) status_scan_dir_symlinks "$dest_path" ;;
            whole) status_observe_managed_symlink "$dest_path" ;;
        esac
    done
}

status_scan_managed_inventory() {
    local root dest

    log_step "Managed symlink inventory"

    [ -d "$HOME" ] && {
        for dest in "$HOME"/*; do
            [ -e "$dest" ] || [ -L "$dest" ] || continue
            status_observe_managed_symlink "$dest"
        done
    }

    for root in .claude .codex .agents; do
        status_scan_dir_symlinks "$HOME/$root"
    done

    status_scan_active_surface_destinations
    status_scan_dir_symlinks "$OH_MY_ZSH_THEMES"
}

status_result_summary() {
    log_step "Linked: $STATUS_LINKED"
    log_step "Missing: $STATUS_MISSING"
    log_step "Conflicts: $STATUS_CONFLICT"
    log_step "Stale: $STATUS_STALE"
    log_step "Orphaned: $STATUS_ORPHANED"
    log_step "Skipped: $STATUS_SKIPPED"
}
