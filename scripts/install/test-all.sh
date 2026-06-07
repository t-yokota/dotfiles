#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: test-all.sh must be run with bash. Use: bash scripts/install/test-all.sh" >&2
    exit 1
fi

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTPATH=${DOTPATH:-$(cd "$SCRIPT_DIR/../.." && pwd)}
BRANCH=${DOTFILES_BRANCH:-}
VERBOSE=0
PROFILE_INPUTS=()

usage() {
    cat <<'USAGE'
Usage: bash scripts/install/test-all.sh [--verbose|-v] [--branch <branch>] [--profile profiles/<name>]

Options:
  --profile <dir>    Run this profile smoke test instead of discovering active profiles.
                     May be passed multiple times.
  --branch <branch>  Branch name used for active profile discovery and profile smoke tests.
  -v, --verbose      Print detailed logs from child test scripts.
  -h, --help         Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --profile)
            if [ "$#" -lt 2 ]; then
                echo "Error: --profile requires a value" >&2
                exit 1
            fi
            PROFILE_INPUTS+=("$2")
            shift
            ;;
        --branch)
            if [ "$#" -lt 2 ]; then
                echo "Error: --branch requires a value" >&2
                exit 1
            fi
            BRANCH="$2"
            shift
            ;;
        -v|--verbose)
            VERBOSE=1
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

log() {
    printf '[test-all] %s\n' "$*"
}

line_is_ignored() {
    case "$1" in
        ""|\#*) return 0 ;;
        *) return 1 ;;
    esac
}

detect_branch() {
    if [ -n "$BRANCH" ]; then
        return 0
    fi

    BRANCH=$(git -C "$DOTPATH" branch --show-current 2>/dev/null || true)
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

resolve_profile_dir() {
    local input="$1"
    local path

    case "$input" in
        /*) path="$input" ;;
        *) path="$DOTPATH/$input" ;;
    esac

    cd "$path" 2>/dev/null && pwd
}

discover_active_profiles() {
    local manifest

    if [ -z "$BRANCH" ]; then
        return 0
    fi

    for manifest in "$DOTPATH"/profiles/*/profile.tsv; do
        [ -f "$manifest" ] || continue
        if profile_matches_branch "$manifest" "$BRANCH"; then
            printf '%s\n' "${manifest%/*}"
        fi
    done
}

run_installer_regression() {
    local args=()

    [ "$VERBOSE" -eq 1 ] && args+=(--verbose)
    log "Run installer regression"
    bash "$DOTPATH/scripts/install/test-installer.sh" "${args[@]}"
}

run_profile_smoke_test() {
    local profile_dir="$1"
    local wrapper="$profile_dir/bin/test-profile.sh"
    local args=()

    if [ ! -f "$wrapper" ]; then
        echo "Error: missing profile smoke test wrapper: $wrapper" >&2
        return 1
    fi

    [ "$VERBOSE" -eq 1 ] && args+=(--verbose)
    log "Run profile smoke test: ${profile_dir#"$DOTPATH"/}"

    if [ -n "$BRANCH" ]; then
        DOTPATH="$DOTPATH" DOTFILES_BRANCH="$BRANCH" bash "$wrapper" "${args[@]}"
    else
        DOTPATH="$DOTPATH" bash "$wrapper" "${args[@]}"
    fi
}

main() {
    local profile_input profile_dir
    local profile_dirs=()
    local rc=0

    detect_branch
    log "DOTPATH: $DOTPATH"
    if [ -n "$BRANCH" ]; then
        log "Branch: $BRANCH"
    else
        log "Branch: <not detected>"
    fi

    run_installer_regression || rc=1

    if [ "${#PROFILE_INPUTS[@]}" -gt 0 ]; then
        for profile_input in "${PROFILE_INPUTS[@]}"; do
            if ! profile_dir=$(resolve_profile_dir "$profile_input"); then
                echo "Error: profile directory does not exist: $profile_input" >&2
                rc=1
                continue
            fi
            profile_dirs+=("$profile_dir")
        done
    else
        while IFS= read -r profile_dir; do
            [ -n "$profile_dir" ] && profile_dirs+=("$profile_dir")
        done < <(discover_active_profiles)
    fi

    if [ "${#profile_dirs[@]}" -eq 0 ]; then
        log "No active profile smoke tests"
    else
        for profile_dir in "${profile_dirs[@]}"; do
            run_profile_smoke_test "$profile_dir" || rc=1
        done
    fi

    if [ "$rc" -eq 0 ]; then
        log "PASS: all checks completed"
    else
        log "FAIL: one or more checks failed"
    fi

    return "$rc"
}

main "$@"
