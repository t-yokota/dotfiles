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
STATUS_SECTION_VISIBLE=0
STATUS_SCOPE_LINKED=0
STATUS_SCOPE_MISSING=0
STATUS_SCOPE_CONFLICT=0
STATUS_SCOPE_STALE=0
STATUS_SCOPE_ORPHANED=0
STATUS_SCOPE_SKIPPED=0
STATUS_SCOPE_EXPECTED=0

status_scope_begin() {
    STATUS_SECTION_VISIBLE=0
    STATUS_SCOPE_LINKED=$STATUS_LINKED
    STATUS_SCOPE_MISSING=$STATUS_MISSING
    STATUS_SCOPE_CONFLICT=$STATUS_CONFLICT
    STATUS_SCOPE_STALE=$STATUS_STALE
    STATUS_SCOPE_ORPHANED=$STATUS_ORPHANED
    STATUS_SCOPE_SKIPPED=$STATUS_SKIPPED
    STATUS_SCOPE_EXPECTED=${#STATUS_EXPECTED_DESTS[@]}
}

status_note() {
    status_emit_summary "$1"
}

status_attention() {
    status_emit_summary "$1"
}

status_verbose_enabled() {
    [ "${STATUS_VERBOSE:-0}" = "1" ]
}

status_info() {
    status_emit_summary "$1"
}

status_emit_summary() {
    local message="$1"

    STATUS_SECTION_VISIBLE=$((STATUS_SECTION_VISIBLE + 1))
    status_summary_step "$message"
}

status_summary_step() {
    local message="$1"

    case "$message" in
        OK:*)
            printf '  '
            color_green "$message"
            printf '\n'
            ;;
        Check:*|Warn:*)
            printf '  '
            color_yellow "$message"
            printf '\n'
            ;;
        Error:*)
            printf '  '
            color_red "$message"
            printf '\n'
            ;;
        "No desired"*)
            printf '  '
            color_gray "$message"
            printf '\n'
            ;;
        *)
            printf '  %s\n' "$message"
            ;;
    esac
}

status_scope_end() {
    local empty_message="$1"
    local summary_label="$2"
    local empty_label="${empty_message%.}"
    local linked_delta=$((STATUS_LINKED - STATUS_SCOPE_LINKED))
    local missing_delta=$((STATUS_MISSING - STATUS_SCOPE_MISSING))
    local conflict_delta=$((STATUS_CONFLICT - STATUS_SCOPE_CONFLICT))
    local stale_delta=$((STATUS_STALE - STATUS_SCOPE_STALE))
    local orphaned_delta=$((STATUS_ORPHANED - STATUS_SCOPE_ORPHANED))
    local skipped_delta=$((STATUS_SKIPPED - STATUS_SCOPE_SKIPPED))
    local expected_delta=$((${#STATUS_EXPECTED_DESTS[@]} - STATUS_SCOPE_EXPECTED))

    if [ "$expected_delta" -eq 0 ] && [ "$skipped_delta" -eq 0 ] && [ "$linked_delta" -eq 0 ] &&
        [ "$missing_delta" -eq 0 ] && [ "$conflict_delta" -eq 0 ] &&
        [ "$stale_delta" -eq 0 ] && [ "$orphaned_delta" -eq 0 ]; then
        status_info "$empty_label (linked: 0, missing: 0, conflicts: 0, skipped: 0)"
        return 0
    fi

    if [ "$missing_delta" -eq 0 ] && [ "$conflict_delta" -eq 0 ] &&
        [ "$stale_delta" -eq 0 ] && [ "$orphaned_delta" -eq 0 ]; then
        status_note "OK: $summary_label (linked: $linked_delta, missing: $missing_delta, conflicts: $conflict_delta, skipped: $skipped_delta)"
        return 0
    fi

    if status_verbose_enabled; then
        status_attention "Check: $summary_label (linked: $linked_delta, missing: $missing_delta, conflicts: $conflict_delta, stale: $stale_delta, orphaned: $orphaned_delta, skipped: $skipped_delta)"
    else
        status_attention "Check: $summary_label (linked: $linked_delta, missing: $missing_delta, conflicts: $conflict_delta, stale: $stale_delta, orphaned: $orphaned_delta, skipped: $skipped_delta); use --verbose to list paths"
    fi
}

status_inventory_scope_end() {
    local stale_delta=$((STATUS_STALE - STATUS_SCOPE_STALE))
    local orphaned_delta=$((STATUS_ORPHANED - STATUS_SCOPE_ORPHANED))

    if [ "$stale_delta" -eq 0 ] && [ "$orphaned_delta" -eq 0 ]; then
        status_note "OK: no unexpected dotfiles-managed links outside current desired state (stale: $stale_delta, orphaned: $orphaned_delta)"
        return 0
    fi

    if status_verbose_enabled; then
        status_attention "Check: unexpected dotfiles-managed links are outside current desired state (stale: $stale_delta, orphaned: $orphaned_delta)"
    else
        status_attention "Check: unexpected dotfiles-managed links are outside current desired state (stale: $stale_delta, orphaned: $orphaned_delta); use --verbose to list paths"
    fi
}

status_mark_expected() {
    STATUS_EXPECTED_DESTS+=("$1")
}

status_is_expected() {
    local path="$1"

    list_contains "$path" "${STATUS_EXPECTED_DESTS[@]}"
}

status_mark_seen_managed() {
    local path="$1"

    list_contains "$path" "${STATUS_SEEN_MANAGED_DESTS[@]}" && return 1

    STATUS_SEEN_MANAGED_DESTS+=("$path")
    return 0
}

status_print() {
    local kind="$1"
    local message="$2"

    case "$kind" in
        linked)
            [ "$STATUS_VERBOSE" -eq 1 ] || return 0
            STATUS_SECTION_VISIBLE=$((STATUS_SECTION_VISIBLE + 1))
            printf '    - '
            color_cyan "linked: $message"
            printf '\n'
            ;;
        missing)
            [ "$STATUS_VERBOSE" -eq 1 ] || return 0
            STATUS_SECTION_VISIBLE=$((STATUS_SECTION_VISIBLE + 1))
            printf '    - '
            color_blue "missing: $message"
            printf '\n'
            ;;
        conflict)
            [ "$STATUS_VERBOSE" -eq 1 ] || return 0
            STATUS_SECTION_VISIBLE=$((STATUS_SECTION_VISIBLE + 1))
            printf '    - '
            color_magenta "conflict: $message"
            printf '\n'
            ;;
        stale)
            [ "$STATUS_VERBOSE" -eq 1 ] || return 0
            STATUS_SECTION_VISIBLE=$((STATUS_SECTION_VISIBLE + 1))
            printf '    - '
            color_magenta "stale: $message"
            printf '\n'
            ;;
        orphaned)
            [ "$STATUS_VERBOSE" -eq 1 ] || return 0
            STATUS_SECTION_VISIBLE=$((STATUS_SECTION_VISIBLE + 1))
            printf '    - '
            color_blue "orphaned: $message"
            printf '\n'
            ;;
        skipped)
            [ "$STATUS_VERBOSE" -eq 1 ] || return 0
            STATUS_SECTION_VISIBLE=$((STATUS_SECTION_VISIBLE + 1))
            printf '    - '
            color_gray "skipped: $message"
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
    if ! path_exists_or_link "$target"; then
        status_record stale "$dest_path -> $target"
    else
        status_record orphaned "$dest_path -> $target"
    fi
}

status_root_entries() {
    local f name

    log_step "Top-level dotfiles"
    status_scope_begin
    for f in .??*; do
        path_exists_or_link "$f" || continue
        name=$(basename "$f")
        should_skip_root_entry "$name" && continue
        status_expected_link "$DOTPATH/$name" "$HOME/$name"
    done
    status_scope_end \
        "No desired top-level dotfile links found." \
        "top-level dotfile links checked"
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
        path_exists_or_link "$f" || continue
        name=$(basename "$f")
        dest="$dest_dir/$name"
        child_source="$source_dir/$name"

        if should_skip_entry "$skipset" "$name"; then
            status_record skipped "$f"
            continue
        fi

        if should_defer_to_child_surface_entry "$source_dir" "$name"; then
            status_record skipped "$f (managed by child surface)"
            continue
        fi

        status_expected_link "$child_source" "$dest"
    done
}

status_whole_surface() {
    local source_path="$1"
    local dest_path="$2"

    path_exists_or_link "$source_path" || return 0
    status_expected_link "$source_path" "$dest_path"
}

status_all_managed_surfaces() {
    local surface strategy source_path dest_path skipset label

    for surface in "${MANAGED_SURFACES[@]}"; do
        IFS=$'\t' read -r strategy source_path dest_path skipset label <<< "$surface"
        log_step "$label"
        status_scope_begin
        case "$strategy" in
            entries) status_entries_surface "$source_path" "$dest_path" "$skipset" ;;
            whole) status_whole_surface "$source_path" "$dest_path" ;;
        esac
        status_scope_end \
            "No desired links found for this surface." \
            "$label checked"
    done
}

status_shell_themes() {
    local theme theme_dest

    log_step "Shell themes"
    status_scope_begin
    if [ ! -d "$OH_MY_ZSH_THEMES" ]; then
        status_record skipped "$OH_MY_ZSH_THEMES does not exist"
        status_scope_end \
            "No shell theme destination directory found." \
            "shell theme links checked"
        return 0
    fi

    for theme in "$DOTPATH"/*.zsh-theme; do
        path_exists_or_link "$theme" || continue
        theme_dest="$OH_MY_ZSH_THEMES/$(basename "$theme")"
        status_expected_link "$theme" "$theme_dest"
    done
    status_scope_end \
        "No desired shell theme links found." \
        "shell theme links checked"
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

    log_step "Unexpected dotfiles-managed links"
    status_scope_begin

    [ -d "$HOME" ] && {
        for dest in "$HOME"/*; do
            path_exists_or_link "$dest" || continue
            status_observe_managed_symlink "$dest"
        done
    }

    for root in "${MANAGED_ROOTS[@]}"; do
        status_scan_dir_symlinks "$HOME/$root"
    done

    status_scan_active_surface_destinations
    status_scan_dir_symlinks "$OH_MY_ZSH_THEMES"
    status_inventory_scope_end
}

status_result_summary() {
    local count_width

    count_width=$(max_count_width "$STATUS_LINKED" "$STATUS_MISSING" "$STATUS_CONFLICT" "$STATUS_STALE" "$STATUS_ORPHANED" "$STATUS_SKIPPED")

    status_result_item "Linked" "$STATUS_LINKED" "expected links already point to this dotfiles checkout" "$count_width"
    status_result_item "Missing" "$STATUS_MISSING" "expected links are absent from HOME" "$count_width"
    status_result_item "Conflicts" "$STATUS_CONFLICT" "expected destinations exist but are not the expected symlinks" "$count_width"
    status_result_item "Stale" "$STATUS_STALE" "unexpected managed links point to missing targets" "$count_width"
    status_result_item "Orphaned" "$STATUS_ORPHANED" "unexpected managed links point to targets outside current desired state" "$count_width"
    status_result_item "Skipped" "$STATUS_SKIPPED" "entries intentionally excluded by skipsets or child surfaces" "$count_width"
}

status_result_item() {
    local label="$1"
    local count="$2"
    local description="$3"
    local count_width="$4"

    log_step "$(printf "%-10s: %${count_width}s (%s)" "$label" "$count" "$description")"
}

status_has_reportable_issues() {
    [ $((STATUS_MISSING + STATUS_CONFLICT + STATUS_STALE + STATUS_ORPHANED)) -ne 0 ]
}

status_result_message() {
    if status_has_reportable_issues; then
        if status_verbose_enabled; then
            log_step "Check: reportable link issues found"
        else
            log_step "Check: reportable link issues found; review with --verbose"
        fi
    else
        log_ok "status checked; no changes were made"
    fi
}
