# shellcheck shell=bash

TEST_NAMES=()
TEST_FUNCTIONS=()
TEST_CASE_FILES=()

log() {
    printf '[install-test] %s\n' "$*"
}

show_output() {
    local label="$1"
    local output="$2"

    log "BEGIN $label"
    sed 's/^/  | /' "$output"
    log "END $label"
}

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    log "PASS: $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    log "FAIL: $1"
}

write_file() {
    local path="$1"
    local content="$2"

    mkdir -p "$(dirname "$path")" || return 1
    printf '%s\n' "$content" > "$path"
}

copy_installer_files() {
    local fixture="$1"

    cp "$REPO_ROOT/install.sh" "$fixture/install.sh" || return 1
    cp "$REPO_ROOT/uninstall.sh" "$fixture/uninstall.sh" || return 1
    cp "$REPO_ROOT/status.sh" "$fixture/status.sh" || return 1
    mkdir -p "$fixture/scripts/install" || return 1
    cp -R "$REPO_ROOT/scripts/install/lib" "$fixture/scripts/install/lib" || return 1
    cp "$REPO_ROOT/scripts/install/test-profile.sh" "$fixture/scripts/install/test-profile.sh" || return 1
}

copy_test_all_runner_files() {
    local fixture="$1"

    mkdir -p "$fixture/scripts/install/lib" "$fixture/profiles/test/bin" || return 1
    write_file "$fixture/install.sh" \
'#!/usr/bin/env bash
exit 0' || return 1
    write_file "$fixture/uninstall.sh" \
'#!/usr/bin/env bash
exit 0' || return 1
    write_file "$fixture/status.sh" \
'#!/usr/bin/env bash
exit 0' || return 1
    cp "$REPO_ROOT/scripts/install/lib/common.sh" "$fixture/scripts/install/lib/common.sh" || return 1
    cp "$REPO_ROOT/scripts/install/lib/profile.sh" "$fixture/scripts/install/lib/profile.sh" || return 1
    cp "$REPO_ROOT/scripts/install/lint.sh" "$fixture/scripts/install/lint.sh" || return 1
    cp "$REPO_ROOT/scripts/install/test-all.sh" "$fixture/scripts/install/test-all.sh" || return 1
    write_file "$fixture/scripts/install/test-installer.sh" \
'#!/usr/bin/env bash
printf "fake installer\n"' || return 1
    write_file "$fixture/profiles/test/bin/test-profile.sh" \
'#!/usr/bin/env bash
printf "fake profile branch=%s\n" "${DOTFILES_BRANCH:-}"' || return 1
}

write_test_profile() {
    local fixture="$1"
    local profile_dir="$fixture/profiles/test"

    mkdir -p "$profile_dir" || return 1
    write_file "$profile_dir/profile.tsv" \
"branch	$TEST_BRANCH
branch	profile/test/*
skipsets	skipsets.tsv
surfaces	surfaces.tsv
checks	checks.d" || return 1
    write_file "$profile_dir/skipsets.tsv" \
"# kind	name	pattern
skipset	managed-root	cache
skipset	managed-root	sessions
skipset	managed-root	*.log" || return 1
    write_file "$profile_dir/surfaces.tsv" \
"# kind	strategy	source	dest	skipset	label
surface	entries	.codex	.codex	managed-root	Test managed root
surface	entries	.codex/items	.codex/items	none	Test managed-root items
surface	whole	.codex/package	.codex/package	none	Test managed-root package" || return 1
}

make_fixture() {
    local fixture="$1"

    mkdir -p "$fixture/profiles" || return 1
    copy_installer_files "$fixture" || return 1
    write_test_profile "$fixture" || return 1
}

setup_fixture() {
    local fixture="$1"
    local home="$2"

    make_fixture "$fixture" || return 1
    mkdir -p "$home" || return 1
}

run_install() {
    local fixture="$1"
    local home="$2"
    local branch="$3"
    local output="$4"

    run_install_args "$fixture" "$home" "$branch" "$output"
}

run_install_args() {
    local fixture="$1"
    local home="$2"
    local branch="$3"
    local output="$4"
    local rc
    shift 4

    HOME="$home" \
    DOTPATH="$fixture" \
    DOTFILES_BRANCH="$branch" \
    OH_MY_ZSH_THEMES="$home/.oh-my-zsh/themes" \
        bash "$fixture/install.sh" "$@" > "$output" 2>&1
    rc=$?

    if [ "$VERBOSE" -eq 1 ]; then
        show_output "$branch install log" "$output"
    fi

    return "$rc"
}

run_uninstall() {
    local fixture="$1"
    local home="$2"
    local branch="$3"
    local output="$4"

    run_uninstall_args "$fixture" "$home" "$branch" "$output"
}

run_uninstall_args() {
    local fixture="$1"
    local home="$2"
    local branch="$3"
    local output="$4"
    local rc
    shift 4

    HOME="$home" \
    DOTPATH="$fixture" \
    DOTFILES_BRANCH="$branch" \
    OH_MY_ZSH_THEMES="$home/.oh-my-zsh/themes" \
        bash "$fixture/uninstall.sh" "$@" > "$output" 2>&1
    rc=$?

    if [ "$VERBOSE" -eq 1 ]; then
        show_output "$branch uninstall log" "$output"
    fi

    return "$rc"
}

run_status() {
    local fixture="$1"
    local home="$2"
    local branch="$3"
    local output="$4"

    run_status_args "$fixture" "$home" "$branch" "$output"
}

run_status_args() {
    local fixture="$1"
    local home="$2"
    local branch="$3"
    local output="$4"
    local rc
    shift 4

    HOME="$home" \
    DOTPATH="$fixture" \
    DOTFILES_BRANCH="$branch" \
    OH_MY_ZSH_THEMES="$home/.oh-my-zsh/themes" \
        bash "$fixture/status.sh" "$@" > "$output" 2>&1
    rc=$?

    if [ "$VERBOSE" -eq 1 ]; then
        show_output "$branch status log" "$output"
    fi

    return "$rc"
}

assert_symlink_target() {
    local path="$1"
    local expected="$2"
    local actual

    [ -L "$path" ] || {
        log "Expected symlink: $path"
        return 1
    }

    actual=$(readlink "$path")
    if [ "$actual" != "$expected" ]; then
        log "Expected $path -> $expected, got $actual"
        return 1
    fi
}

assert_regular_dir() {
    local path="$1"

    [ -d "$path" ] && [ ! -L "$path" ] || {
        log "Expected real directory: $path"
        return 1
    }
}

assert_absent() {
    local path="$1"

    [ ! -e "$path" ] && [ ! -L "$path" ] || {
        log "Expected absent path: $path"
        return 1
    }
}

assert_file_equals() {
    local path="$1"
    local expected="$2"
    local actual

    [ -f "$path" ] || {
        log "Expected file: $path"
        return 1
    }

    actual=$(tr -d '\r' < "$path")
    if [ "$actual" != "$expected" ]; then
        log "Expected $path content [$expected], got [$actual]"
        return 1
    fi
}

assert_file_contains() {
    local path="$1"
    local text="$2"

    grep -Fq "$text" "$path" || {
        log "Expected $path to contain: $text"
        return 1
    }
}

assert_file_not_contains() {
    local path="$1"
    local text="$2"

    if grep -Fq "$text" "$path"; then
        log "Expected $path not to contain: $text"
        return 1
    fi
}

register_test() {
    local name="$1"
    local fn="$2"

    TEST_NAMES+=("$name")
    TEST_FUNCTIONS+=("$fn")
    TEST_CASE_FILES+=("${CURRENT_CASE_FILE:-unknown}")
}

source_test_cases() {
    local case_file

    for case_file in "$SCRIPT_DIR"/tests/cases/*.sh; do
        CURRENT_CASE_FILE=$(basename "$case_file")
        # shellcheck source=/dev/null
        . "$case_file"
    done
    unset CURRENT_CASE_FILE
}

filter_matches_test() {
    local filter="$1"
    local name="$2"
    local case_file="$3"
    local case_id="${case_file%.sh}"

    # shellcheck disable=SC2053 # --case filters are intentionally Bash globs.
    [[ "$name" == $filter ]] ||
        [[ "$case_file" == $filter ]] ||
        [[ "$case_id" == $filter ]] ||
        [[ "$case_file:$name" == $filter ]] ||
        [[ "$case_id:$name" == $filter ]]
}

should_run_test() {
    local name="$1"
    local case_file="$2"
    local filter

    if [ "${#CASE_FILTERS[@]}" -eq 0 ]; then
        return 0
    fi

    for filter in "${CASE_FILTERS[@]}"; do
        if filter_matches_test "$filter" "$name" "$case_file"; then
            return 0
        fi
    done

    return 1
}

run_test() {
    local name="$1"
    local fn="$2"

    if "$fn"; then
        pass "$name"
    else
        fail "$name"
    fi
}

run_registered_tests() {
    local index
    local selected_count=0

    log "Workspace: $TEST_ROOT"

    for index in "${!TEST_NAMES[@]}"; do
        if should_run_test "${TEST_NAMES[$index]}" "${TEST_CASE_FILES[$index]}"; then
            selected_count=$((selected_count + 1))
            run_test "${TEST_NAMES[$index]}" "${TEST_FUNCTIONS[$index]}"
        fi
    done

    if [ "${#CASE_FILTERS[@]}" -ne 0 ] && [ "$selected_count" -eq 0 ]; then
        log "No tests matched --case filter(s): ${CASE_FILTERS[*]}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    log "Passed: $PASS_COUNT"
    log "Failed: $FAIL_COUNT"

    if [ "$FAIL_COUNT" -ne 0 ]; then
        exit 1
    fi
}
