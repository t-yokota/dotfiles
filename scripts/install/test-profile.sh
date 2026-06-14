#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: test-profile.sh must be run with bash. Use: bash scripts/install/test-profile.sh --profile profiles/<name>" >&2
    exit 1
fi

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTPATH=${DOTPATH:-$(cd "$SCRIPT_DIR/../.." && pwd)}
PROFILE_INPUT=""
BRANCH=${DOTFILES_BRANCH:-}
VERBOSE=0
KEEP_TMP=0

INSTALL_LIB_DIR="$DOTPATH/scripts/install/lib"
for lib in common profile; do
    lib_path="$INSTALL_LIB_DIR/$lib.sh"
    if [ ! -f "$lib_path" ]; then
        echo "Error: missing installer library: $lib_path" >&2
        exit 1
    fi
    # shellcheck disable=SC1090 # lib_path is validated from INSTALL_LIB_DIR at runtime.
    . "$lib_path"
done

usage() {
    cat <<'USAGE'
Usage: bash scripts/install/test-profile.sh --profile profiles/<name> [--branch <branch>] [--verbose] [--keep-tmp]

Options:
  --profile <dir>    Profile directory to test, such as profiles/ecc.
  --branch <branch>  Test the profile as if this dotfiles branch were checked out.
  -v, --verbose      Print captured install.sh logs.
  --keep-tmp         Keep the temporary HOME fixture for inspection.
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
            PROFILE_INPUT="$2"
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
        --keep-tmp)
            KEEP_TMP=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            case "$1" in
                -*)
                    echo "Error: unknown option: $1" >&2
                    usage >&2
                    exit 1
                    ;;
            esac
            if [ -n "$PROFILE_INPUT" ]; then
                echo "Error: unknown argument: $1" >&2
                usage >&2
                exit 1
            fi
            PROFILE_INPUT="$1"
            ;;
    esac
    shift
done

if [ -z "$PROFILE_INPUT" ]; then
    echo "Error: --profile is required" >&2
    usage >&2
    exit 1
fi

case "$PROFILE_INPUT" in
    /*) profile_path="$PROFILE_INPUT" ;;
    *) profile_path="$DOTPATH/$PROFILE_INPUT" ;;
esac

if ! PROFILE_DIR=$(cd "$profile_path" 2>/dev/null && pwd); then
    echo "Error: profile directory does not exist: $PROFILE_INPUT" >&2
    exit 1
fi

PROFILE_NAME=$(basename "$PROFILE_DIR")
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-profile-test.XXXXXX")
TEST_HOME="$TEST_ROOT/home"

log() {
    printf '[profile-test:%s] %s\n' "$PROFILE_NAME" "$*"
}

fail() {
    echo "Error: $*" >&2
    return 1
}

cleanup() {
    if [ "$KEEP_TMP" -eq 1 ]; then
        log "Kept fixture: $TEST_ROOT"
    else
        rm -rf "$TEST_ROOT"
    fi
}

trap cleanup EXIT

assert_file() {
    local path="$1"
    local label="$2"

    [ -f "$path" ] || fail "missing $label: $path"
}

assert_dir() {
    local path="$1"
    local label="$2"

    [ -d "$path" ] || fail "missing $label: $path"
}

assert_regular_dir() {
    local path="$1"
    local label="$2"

    [ -d "$path" ] && [ ! -L "$path" ] || fail "expected real directory for $label: $path"
}

assert_symlink_target() {
    local path="$1"
    local expected="$2"
    local label="$3"
    local actual

    [ -L "$path" ] || fail "expected symlink for $label: $path" || return 1
    actual=$(readlink "$path")
    [ "$actual" = "$expected" ] || fail "expected $path -> $expected, got $actual"
}

resolve_test_home_path() {
    local rel="$1"

    printf '%s/%s\n' "$TEST_HOME" "$rel"
}

detect_branch() {
    if [ -n "$BRANCH" ]; then
        return 0
    fi

    BRANCH=$(cd "$DOTPATH" && get_current_branch)
    [ -n "$BRANCH" ] || fail "could not detect current branch; pass --branch explicitly"
}

check_profile_branch_patterns() {
    local manifest="$PROFILE_DIR/profile.tsv"
    local expected_base="profile/$PROFILE_NAME-base"
    local expected_env="profile/$PROFILE_NAME/*"
    local has_base=0
    local has_env=0
    local line line_number kind value rest
    local match_rc

    line_number=0
    while IFS= read -r line; do
        line_number=$((line_number + 1))
        line_is_ignored "$line" && continue
        validate_profile_manifest_line "$manifest" "$line_number" "$line" || return 1
        IFS=$'\t' read -r kind value rest <<< "$line"
        [ "$kind" = "branch" ] || continue
        [ "$value" = "$expected_base" ] && has_base=1
        [ "$value" = "$expected_env" ] && has_env=1
    done < "$manifest"

    [ "$has_base" -eq 1 ] || fail "profile.tsv must include: branch	$expected_base" || return 1
    [ "$has_env" -eq 1 ] || fail "profile.tsv must include: branch	$expected_env" || return 1

    profile_matches_branch "$manifest" "$BRANCH"
    match_rc=$?
    case "$match_rc" in
        0) ;;
        1)
            fail "branch does not activate this profile: $BRANCH"
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

profile_manifest_value() {
    local manifest="$1"
    local target_kind="$2"
    local default_value="$3"
    local line kind value rest

    while IFS= read -r line; do
        line_is_ignored "$line" && continue
        IFS=$'\t' read -r kind value rest <<< "$line"
        if [ "$kind" = "$target_kind" ]; then
            printf '%s\n' "$value"
            return 0
        fi
    done < "$manifest"

    printf '%s\n' "$default_value"
}

run_installer_fixture() {
    local output="$TEST_ROOT/install.log"
    local install_script="$DOTPATH/install.sh"

    mkdir -p "$TEST_HOME" || return 1

    HOME="$TEST_HOME" \
    DOTPATH="$DOTPATH" \
    DOTFILES_BRANCH="$BRANCH" \
    OH_MY_ZSH_THEMES="$TEST_HOME/.oh-my-zsh/themes" \
        bash "$install_script" > "$output" 2>&1 || {
            sed 's/^/  | /' "$output" >&2
            return 1
        }

    if [ "$VERBOSE" -eq 1 ]; then
        sed 's/^/  | /' "$output"
    fi
}

check_surface_outputs() {
    local surfaces_rel surfaces_file
    local line kind strategy source_rel dest_rel _skipset label
    local source_path dest_path

    surfaces_rel=$(profile_manifest_value "$PROFILE_DIR/profile.tsv" "surfaces" "surfaces.tsv")
    surfaces_file="$PROFILE_DIR/$surfaces_rel"
    assert_file "$surfaces_file" "surfaces manifest" || return 1

    while IFS= read -r line; do
        line_is_ignored "$line" && continue
        IFS=$'\t' read -r kind strategy source_rel dest_rel _skipset label <<< "$line"
        [ "$kind" = "surface" ] || continue

        source_path=$(resolve_dotpath_path "$source_rel")
        dest_path=$(resolve_test_home_path "$dest_rel")
        [ -e "$source_path" ] || [ -L "$source_path" ] || continue

        case "$strategy" in
            entries)
                assert_regular_dir "$dest_path" "$label" || return 1
                ;;
            whole)
                assert_symlink_target "$dest_path" "$source_path" "$label" || return 1
                ;;
            *)
                fail "unknown surface strategy in $surfaces_file: $strategy"
                return 1
                ;;
        esac
    done < "$surfaces_file"
}

main() {
    local skipsets_rel surfaces_rel

    detect_branch || return 1
    log "DOTPATH: $DOTPATH"
    log "Branch: $BRANCH"
    log "Fixture HOME: $TEST_HOME"

    assert_file "$DOTPATH/install.sh" "installer entrypoint" || return 1
    assert_file "$PROFILE_DIR/profile.tsv" "profile manifest" || return 1

    check_profile_branch_patterns || return 1

    skipsets_rel=$(profile_manifest_value "$PROFILE_DIR/profile.tsv" "skipsets" "skipsets.tsv")
    surfaces_rel=$(profile_manifest_value "$PROFILE_DIR/profile.tsv" "surfaces" "surfaces.tsv")
    assert_file "$PROFILE_DIR/$skipsets_rel" "skipsets manifest" || return 1
    assert_file "$PROFILE_DIR/$surfaces_rel" "surfaces manifest" || return 1

    run_installer_fixture || return 1
    check_surface_outputs || return 1

    log "PASS: profile installs into an isolated HOME fixture"
}

main "$@"
