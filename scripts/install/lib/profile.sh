#!/usr/bin/env bash

# Profile manifest support: select active profiles for the current branch, load
# their skipsets/surfaces into installer state, reserve profile-owned top-level
# roots, and run profile-specific install checks.

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

manifest_error() {
    local file="$1"
    local line_number="$2"
    local message="$3"

    echo "Error: invalid installer manifest: $file:$line_number: $message" >&2
    return 1
}

validate_profile_manifest_path() {
    local file="$1"
    local line_number="$2"
    local field_name="$3"
    local path="$4"

    case "$path" in
        /*|..|../*|*/../*|*/..)
            manifest_error "$file" "$line_number" "$field_name must be a relative path inside the profile directory"
            return 1
            ;;
    esac
}

validate_surface_manifest_path() {
    local file="$1"
    local line_number="$2"
    local field_name="$3"
    local path="$4"
    local base_name="$5"

    case "$path" in
        /*|..|../*|*/../*|*/..)
            manifest_error "$file" "$line_number" "$field_name must be a relative path inside $base_name"
            return 1
            ;;
    esac
}

validate_profile_manifest_line() {
    local file="$1"
    local line_number="$2"
    local line="$3"
    local kind value extra

    IFS=$'\t' read -r kind value extra <<< "$line"

    case "$kind" in
        branch|surfaces|skipsets|checks) ;;
        *)
            manifest_error "$file" "$line_number" "unknown profile kind: ${kind:-<empty>}"
            return 1
            ;;
    esac

    if [ -z "$value" ]; then
        manifest_error "$file" "$line_number" "$kind row requires a value"
        return 1
    fi

    if [ -n "$extra" ]; then
        manifest_error "$file" "$line_number" "$kind row has too many columns"
        return 1
    fi

    case "$kind" in
        surfaces|skipsets|checks)
            validate_profile_manifest_path "$file" "$line_number" "$kind" "$value" || return 1
            ;;
    esac
}

validate_skipsets_line() {
    local file="$1"
    local line_number="$2"
    local line="$3"
    local kind name pattern extra

    IFS=$'\t' read -r kind name pattern extra <<< "$line"

    if [ "$kind" != "skipset" ]; then
        manifest_error "$file" "$line_number" "unknown skipsets kind: ${kind:-<empty>}"
        return 1
    fi

    if [ -z "$name" ]; then
        manifest_error "$file" "$line_number" "skipset row requires a name"
        return 1
    fi

    if [ -z "$pattern" ]; then
        manifest_error "$file" "$line_number" "skipset row requires a pattern"
        return 1
    fi

    if [ -n "$extra" ]; then
        manifest_error "$file" "$line_number" "skipset row has too many columns"
        return 1
    fi
}

validate_surfaces_line() {
    local file="$1"
    local line_number="$2"
    local line="$3"
    local kind strategy source_rel dest_rel skipset label extra

    IFS=$'\t' read -r kind strategy source_rel dest_rel skipset label extra <<< "$line"

    if [ "$kind" != "surface" ]; then
        manifest_error "$file" "$line_number" "unknown surfaces kind: ${kind:-<empty>}"
        return 1
    fi

    if [ -z "$strategy" ]; then
        manifest_error "$file" "$line_number" "surface row requires a strategy"
        return 1
    fi

    case "$strategy" in
        entries|whole) ;;
        *)
            manifest_error "$file" "$line_number" "unknown surface strategy: $strategy"
            return 1
            ;;
    esac

    if [ -z "$source_rel" ]; then
        manifest_error "$file" "$line_number" "surface row requires a source"
        return 1
    fi

    if [ -z "$dest_rel" ]; then
        manifest_error "$file" "$line_number" "surface row requires a dest"
        return 1
    fi

    validate_surface_manifest_path "$file" "$line_number" "surface source" "$source_rel" "DOTPATH" || return 1
    validate_surface_manifest_path "$file" "$line_number" "surface dest" "$dest_rel" "HOME" || return 1

    if [ -z "$skipset" ]; then
        manifest_error "$file" "$line_number" "surface row requires a skipset"
        return 1
    fi

    if [ "$skipset" != "none" ] && ! is_known_skipset "$skipset"; then
        manifest_error "$file" "$line_number" "surface row references unknown skipset: $skipset"
        return 1
    fi

    if [ -z "$label" ]; then
        manifest_error "$file" "$line_number" "surface row requires a label"
        return 1
    fi

    if [ -n "$extra" ]; then
        manifest_error "$file" "$line_number" "surface row has too many columns"
        return 1
    fi
}

add_known_skipset() {
    local skipset="$1"
    local entry

    [ -n "$skipset" ] || return 0

    for entry in "${KNOWN_SKIPSETS[@]}"; do
        [ "$entry" = "$skipset" ] && return 0
    done

    KNOWN_SKIPSETS+=("$skipset")
}

is_known_skipset() {
    local skipset="$1"
    local entry

    for entry in "${KNOWN_SKIPSETS[@]}"; do
        [ "$entry" = "$skipset" ] && return 0
    done

    return 1
}

add_skip_pattern() {
    local skipset="$1"
    local pattern="$2"

    [ -n "$skipset" ] || return 0
    [ -n "$pattern" ] || return 0
    add_known_skipset "$skipset"
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
    local line line_number kind pattern rest

    [ -n "$branch" ] || return 1

    line_number=0
    while IFS= read -r line; do
        line_number=$((line_number + 1))
        line_is_ignored "$line" && continue
        validate_profile_manifest_line "$manifest" "$line_number" "$line" || return 2
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
    local line line_number kind name pattern rest

    [ -f "$file" ] || return 0
    log_substep "$file"

    line_number=0
    while IFS= read -r line; do
        line_number=$((line_number + 1))
        line_is_ignored "$line" && continue
        validate_skipsets_line "$file" "$line_number" "$line" || return 1
        IFS=$'\t' read -r kind name pattern rest <<< "$line"
        add_skip_pattern "$name" "$pattern"
    done < "$file"
}

load_surfaces_file() {
    local file="$1"
    local line line_number kind strategy source_rel dest_rel skipset label
    local source_path dest_path root_entry

    [ -f "$file" ] || return 0
    log_substep "$file"

    line_number=0
    while IFS= read -r line; do
        line_number=$((line_number + 1))
        line_is_ignored "$line" && continue
        validate_surfaces_line "$file" "$line_number" "$line" || return 1
        IFS=$'\t' read -r kind strategy source_rel dest_rel skipset label <<< "$line"

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
    local line line_number kind value rest
    local surfaces_file="surfaces.tsv"
    local skipsets_file="skipsets.tsv"
    local checks_dir="checks.d"

    line_number=0
    while IFS= read -r line; do
        line_number=$((line_number + 1))
        line_is_ignored "$line" && continue
        validate_profile_manifest_line "$manifest" "$line_number" "$line" || return 1
        IFS=$'\t' read -r kind value rest <<< "$line"
        case "$kind" in
            surfaces) surfaces_file="$value" ;;
            skipsets) skipsets_file="$value" ;;
            checks) checks_dir="$value" ;;
        esac
    done < "$manifest"

    ACTIVE_PROFILE_CHECK_DIRS+=("$profile_dir/$checks_dir")
    load_skipsets_file "$profile_dir/$skipsets_file" || return 1
    load_surfaces_file "$profile_dir/$surfaces_file" || return 1
}

load_active_profile_manifests() {
    local branch
    local manifest
    local match_rc

    branch=$(get_current_branch)
    [ -n "$branch" ] || return 0

    for manifest in "$DOTPATH"/profiles/*/profile.tsv; do
        [ -f "$manifest" ] || continue
        profile_matches_branch "$manifest" "$branch"
        match_rc=$?
        case "$match_rc" in
            0)
                log_substep "Profile: ${manifest%/*}"
                load_profile_manifest "$manifest" || return 1
                ;;
            1)
                ;;
            *)
                return 1
                ;;
        esac
    done
}

run_active_profile_install_checks() {
    local branch
    local checks_dir
    local hook
    local rc=0

    branch=$(get_current_branch)
    [ -n "$branch" ] || return 0

    for checks_dir in "${ACTIVE_PROFILE_CHECK_DIRS[@]}"; do
        [ -d "$checks_dir" ] || continue
        for hook in "$checks_dir"/*.sh; do
            [ -f "$hook" ] || continue
            case "$(basename "$hook")" in
                check-*.sh|[0-9][0-9]-*.sh) ;;
                *) continue ;;
            esac
            log_substep "$hook"
            DOTPATH="$DOTPATH" DOTFILES_BRANCH="$branch" bash "$hook" || rc=1
        done
    done

    return "$rc"
}
