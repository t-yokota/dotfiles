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

log_section() {
    printf '\n== %s ==\n' "$1"
}

log_step() {
    printf -- '- %s\n' "$1"
}

log_substep() {
    printf '  - %s\n' "$1"
}

log_link() {
    printf '    - Link: %s -> %s\n' "$1" "$2"
}

line_is_ignored() {
    local line="$1"

    [ -z "$line" ] && return 0
    case "$line" in
        \#*) return 0 ;;
        *) return 1 ;;
    esac
}

get_current_branch() {
    if [ -n "${DOTFILES_BRANCH:-}" ]; then
        printf '%s\n' "$DOTFILES_BRANCH"
        return 0
    fi

    git branch --show-current 2>/dev/null || true
}

resolve_dotpath_path() {
    local path="$1"

    case "$path" in
        /*) printf '%s\n' "$path" ;;
        *) printf '%s/%s\n' "$DOTPATH" "${path#./}" ;;
    esac
}

resolve_home_path() {
    local path="$1"

    case "$path" in
        /*) printf '%s\n' "$path" ;;
        *) printf '%s/%s\n' "$HOME" "${path#./}" ;;
    esac
}

root_entry_for_path() {
    local path="${1#./}"

    printf '%s\n' "${path%%/*}"
}

add_reserved_root_entry() {
    local name="$1"
    local entry

    [ -n "$name" ] || return 0

    for entry in "${RESERVED_ROOT_ENTRIES[@]}"; do
        [ "$entry" = "$name" ] && return 0
    done

    RESERVED_ROOT_ENTRIES+=("$name")
}

is_reserved_root_entry() {
    local name="$1"
    local entry

    for entry in "${RESERVED_ROOT_ENTRIES[@]}"; do
        [ "$entry" = "$name" ] && return 0
    done

    return 1
}

# Repo-local control files are always private to this checkout. Active profile
# source roots are reserved dynamically from the loaded surface manifest.
should_skip_root_entry() {
    case "$1" in
        .git|.gitignore|.gitconfig.local)
            return 0
            ;;
    esac

    is_reserved_root_entry "$1"
}

add_skip_pattern() {
    local skipset="$1"
    local pattern="$2"

    [ -n "$skipset" ] || return 0
    [ -n "$pattern" ] || return 0
    SKIPSET_PATTERNS+=("$skipset"$'\t'"$pattern")
}

should_skip_entry() {
    local skipset="$1"
    local name="$2"
    local entry set pattern

    [ -n "$skipset" ] || return 1
    [ "$skipset" = "none" ] && return 1

    for entry in "${SKIPSET_PATTERNS[@]}"; do
        IFS=$'\t' read -r set pattern <<< "$entry"
        [ "$set" = "$skipset" ] || continue
        if [[ "$name" == $pattern ]]; then
            return 0
        fi
    done

    return 1
}

add_managed_surface() {
    local strategy="$1"
    local source_path="$2"
    local dest_path="$3"
    local skipset="$4"
    local label="$5"

    case "$strategy" in
        entries|whole) ;;
        *)
            echo "Error: unknown managed surface strategy: $strategy" >&2
            return 1
            ;;
    esac

    MANAGED_SURFACES+=("$strategy"$'\t'"$source_path"$'\t'"$dest_path"$'\t'"$skipset"$'\t'"$label")
}

is_surface_source() {
    local source_path="$1"
    local surface strategy surface_source dest_path skipset label

    for surface in "${MANAGED_SURFACES[@]}"; do
        IFS=$'\t' read -r strategy surface_source dest_path skipset label <<< "$surface"
        [ "$surface_source" = "$source_path" ] && return 0
    done

    return 1
}

profile_matches_branch() {
    local manifest="$1"
    local branch="$2"
    local line kind pattern rest

    [ -n "$branch" ] || return 1

    while IFS= read -r line; do
        line_is_ignored "$line" && continue
        IFS=$'\t' read -r kind pattern rest <<< "$line"
        [ "$kind" = "branch" ] || continue
        if [[ "$branch" == $pattern ]]; then
            return 0
        fi
    done < "$manifest"

    return 1
}

load_skipsets_file() {
    local file="$1"
    local line kind skipset pattern rest

    [ -f "$file" ] || return 0
    log_substep "$file"

    while IFS= read -r line; do
        line_is_ignored "$line" && continue
        IFS=$'\t' read -r kind skipset pattern rest <<< "$line"
        [ "$kind" = "skip" ] || continue
        add_skip_pattern "$skipset" "$pattern"
    done < "$file"
}

load_surfaces_file() {
    local file="$1"
    local line kind strategy source_rel dest_rel skipset label
    local source_path dest_path root_entry

    [ -f "$file" ] || return 0
    log_substep "$file"

    while IFS= read -r line; do
        line_is_ignored "$line" && continue
        IFS=$'\t' read -r kind strategy source_rel dest_rel skipset label <<< "$line"
        [ "$kind" = "surface" ] || continue

        source_path=$(resolve_dotpath_path "$source_rel")
        dest_path=$(resolve_home_path "$dest_rel")
        add_managed_surface "$strategy" "$source_path" "$dest_path" "$skipset" "$label" || return 1

        root_entry=$(root_entry_for_path "$source_rel")
        case "$root_entry" in
            .*) add_reserved_root_entry "$root_entry" ;;
        esac
    done < "$file"
}

load_profile_manifest() {
    local manifest="$1"
    local profile_dir="${manifest%/*}"
    local line kind value rest
    local surfaces_file="surfaces.tsv"
    local skipsets_file="skipsets.tsv"

    while IFS= read -r line; do
        line_is_ignored "$line" && continue
        IFS=$'\t' read -r kind value rest <<< "$line"
        case "$kind" in
            surfaces) surfaces_file="$value" ;;
            skipsets) skipsets_file="$value" ;;
        esac
    done < "$manifest"

    load_skipsets_file "$profile_dir/$skipsets_file" || return 1
    load_surfaces_file "$profile_dir/$surfaces_file" || return 1
}

load_active_profile_surfaces() {
    local branch
    local manifest

    branch=$(get_current_branch)
    [ -n "$branch" ] || return 0

    for manifest in "$DOTPATH"/profiles/*/profile.tsv; do
        [ -f "$manifest" ] || continue
        if profile_matches_branch "$manifest" "$branch"; then
            log_substep "Profile: ${manifest%/*}"
            load_profile_manifest "$manifest" || return 1
        fi
    done
}

# Branch-specific install checks opt in by inspecting DOTFILES_BRANCH.
run_branch_install_checks() {
    local branch
    local hook
    local rc=0

    branch=$(get_current_branch)
    [ -n "$branch" ] || return 0

    for hook in "$DOTPATH"/scripts/install/preflight.d/*/check-*.sh; do
        [ -f "$hook" ] || continue
        log_substep "$hook"
        DOTPATH="$DOTPATH" DOTFILES_BRANCH="$branch" bash "$hook" || rc=1
    done

    return "$rc"
}

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

# Entry surfaces write links inside this container. It must be absent or a real
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

# Check ordinary top-level dotfiles before writing; active profile roots are
# skipped here because their contents need profile-specific surface handling.
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

# Replace only symlinks owned by this dotfiles checkout; never write inside
# pre-existing real directories such as ~/.claude/agents.
link_managed_entry() {
    local source_path="$1"
    local dest_path="$2"
    local managed_root="$3"

    check_managed_entry "$dest_path" "$managed_root" || return 1

    ln -snf "$source_path" "$dest_path" || return 1
    log_link "$dest_path" "$source_path"
}

# Cleanup can run even when source_dir no longer exists after a branch switch.
# In that case, managed links under the destination become broken links and should
# be removed so the real HOME no longer exposes the old profile surface.
cleanup_managed_symlinks() {
    local source_dir="$1"
    local dest_dir="$2"
    local skipset="$3"
    local container_policy="${4:-strict}"
    local name dest target child_source

    if [ "$container_policy" != "allow-container-symlink" ] && [ -L "$dest_dir" ]; then
        if is_managed_symlink "$dest_dir" "$source_dir"; then
            log_substep "Remove managed container symlink: $dest_dir"
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
            child_source="$source_dir/$name"
            # Remove links whose source disappeared after a branch switch, or links that are
            # now classified as runtime state by this surface and are not handled by a child surface.
            if [ ! -e "$target" ] || { should_skip_entry "$skipset" "$name" && ! is_surface_source "$child_source"; }; then
                log_substep "Remove stale or skipped symlink: $dest"
                rm -f "$dest"
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
            log_substep "Remove stale whole-entry symlink: $dest_path"
            rm -f "$dest_path"
        fi
    fi
}

cleanup_root_symlinks() {
    local dest name target

    [ -d "$HOME" ] || return 0

    for dest in "$HOME"/*; do
        # Broken symlinks fail -e, so keep the -L check.
        [ -e "$dest" ] || [ -L "$dest" ] || continue
        name=$(basename "$dest")

        if is_managed_symlink "$dest" "$DOTPATH"; then
            target=$(readlink "$dest")
            if [ ! -e "$target" ] || should_skip_root_entry "$name"; then
                log_substep "Remove stale or reserved top-level symlink: $dest"
                rm -f "$dest"
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

    # Keep user-created runtime files in the destination tree, but ensure the directory exists.
    mkdir -p "$dest_dir"

    # Cleanup pass: prune only symlinks that this script owns.
    cleanup_managed_symlinks "$source_dir" "$dest_dir" "$skipset" || return 1

    for f in "$source_dir"/*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        name=$(basename "$f")
        dest="$dest_dir/$name"
        child_source="$source_dir/$name"

        # Skip tool-generated state and child surfaces. Child surfaces are linked
        # by their own manifest rows.
        if should_skip_entry "$skipset" "$name"; then
            log_substep "Skip runtime or separately managed entry: $f"
            # If an older install linked this skipped entry, remove only that managed link.
            if is_managed_symlink "$dest" "$source_dir" && ! is_surface_source "$child_source"; then
                rm -f "$dest"
            fi
            continue
        fi

        # Desired entry: expose the dotfiles-managed source at the tool's HOME path.
        link_managed_entry "$f" "$dest" "$source_dir" || return 1
    done
}

link_whole_surface() {
    local source_path="$1"
    local dest_path="$2"
    local parent="${dest_path%/*}"

    [ -e "$source_path" ] || [ -L "$source_path" ] || return 0

    check_whole_destination_parent "$dest_path" || return 1
    mkdir -p "$parent"
    link_managed_entry "$source_path" "$dest_path" "$source_path" || return 1
}

cleanup_all_managed_surfaces() {
    local surface strategy source_path dest_path skipset label

    # Cleanup runs in the order provided by profile manifests. Parent surfaces should
    # come before child collections so old whole-directory links are pruned first.
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

log_section "Preflight"
log_step "Load active profile surface manifests"
load_active_profile_surfaces || exit 1
log_step "Run branch-specific install checks"
run_branch_install_checks || exit 1

log_section "Cleanup"
# Prune stale top-level dotfile symlinks before preflight so branch removals do
# not turn into false conflicts on the next install run.
log_step "Prune stale top-level symlinks"
cleanup_root_symlinks || exit 1

# Prune old symlinks for every managed dotfile surface before conflict detection. This
# also moves older links toward the current surface layout.
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
# Link ordinary top-level dotfiles. Profile roots are handled below so runtime
# state such as sessions, caches, and install-state can stay local.
for f in .??*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    should_skip_root_entry "$(basename "$f")" && continue
    link_managed_entry "$DOTPATH/$f" "$HOME/$f" "$DOTPATH" || exit 1
done

# Tool roots stay as real HOME directories. Runtime extension collections are
# symlinked entry-by-entry, while profile-owned package directories can be linked whole.
log_section "Link Managed Dotfile Surfaces"
link_all_managed_surfaces || exit 1

# Dotfiles theme support: expose custom oh-my-zsh themes if that installation is present.
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
