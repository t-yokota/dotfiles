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

INSTALL_LIB_DIR="$DOTPATH/scripts/install/lib"
for lib in common profile; do
    lib_path="$INSTALL_LIB_DIR/$lib.sh"
    if [ ! -f "$lib_path" ]; then
        echo "Error: missing installer library: $lib_path" >&2
        exit 1
    fi
    . "$lib_path"
done

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

detect_branch() {
    if [ -n "$BRANCH" ]; then
        return 0
    fi

    BRANCH=$(cd "$DOTPATH" && get_current_branch)
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
    local match_rc

    if [ -z "$BRANCH" ]; then
        return 0
    fi

    for manifest in "$DOTPATH"/profiles/*/profile.tsv; do
        [ -f "$manifest" ] || continue
        profile_matches_branch "$manifest" "$BRANCH"
        match_rc=$?
        case "$match_rc" in
            0)
                printf '%s\n' "${manifest%/*}"
                ;;
            1)
                ;;
            *)
                return 1
                ;;
        esac
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
    local discovered_profiles
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
        if discovered_profiles=$(discover_active_profiles); then
            while IFS= read -r profile_dir; do
                [ -n "$profile_dir" ] && profile_dirs+=("$profile_dir")
            done <<< "$discovered_profiles"
        else
            rc=1
        fi
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
