#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: test-installer.sh must be run with bash. Use: bash scripts/install/test-installer.sh" >&2
    exit 1
fi

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")

TEST_BRANCH=profile/test-base
VERBOSE=0
PASS_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'USAGE'
Usage: bash scripts/install/test-installer.sh [--verbose|-v]

Options:
  -v, --verbose   Print captured install.sh logs for each fixture.
  -h, --help      Show this help.
USAGE
}

for arg in "$@"; do
    case "$arg" in
        -v|--verbose)
            VERBOSE=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown option: $arg" >&2
            usage >&2
            exit 1
            ;;
    esac
done

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
    mkdir -p "$fixture/scripts/install" || return 1
    cp -R "$REPO_ROOT/scripts/install/lib" "$fixture/scripts/install/lib" || return 1
    cp "$REPO_ROOT/scripts/install/test-profile.sh" "$fixture/scripts/install/test-profile.sh" || return 1
}

copy_test_all_runner_files() {
    local fixture="$1"

    mkdir -p "$fixture/scripts/install/lib" "$fixture/profiles/test/bin" || return 1
    cp "$REPO_ROOT/scripts/install/lib/common.sh" "$fixture/scripts/install/lib/common.sh" || return 1
    cp "$REPO_ROOT/scripts/install/lib/profile.sh" "$fixture/scripts/install/lib/profile.sh" || return 1
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
skipset	tool-root	cache
skipset	tool-root	sessions
skipset	tool-root	items
skipset	tool-root	package
skipset	tool-root	*.log" || return 1
    write_file "$profile_dir/surfaces.tsv" \
"# kind	strategy	source	dest	skipset	label
surface	entries	.tool	.tool	tool-root	Test tool root
surface	entries	.tool/items	.tool/items	none	Test tool items
surface	whole	.tool/package	.tool/package	none	Test tool package" || return 1
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

test_base_profile_entry_links() {
    local fixture="$TEST_ROOT/base-fixture"
    local home="$TEST_ROOT/base-home"
    local output="$TEST_ROOT/base-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/.gitconfig" "gitconfig" || return 1
    write_file "$fixture/.gitignore" "ignored" || return 1
    write_file "$fixture/.gitconfig.local" "local" || return 1
    write_file "$fixture/.tool/config.toml" "config" || return 1
    write_file "$fixture/.tool/settings.json" "{}" || return 1
    write_file "$fixture/.tool/cache/session.json" "{}" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$output" || return 1

    assert_symlink_target "$home/.zshrc" "$fixture/.zshrc" || return 1
    assert_symlink_target "$home/.gitconfig" "$fixture/.gitconfig" || return 1
    assert_regular_dir "$home/.tool" || return 1
    assert_symlink_target "$home/.tool/config.toml" "$fixture/.tool/config.toml" || return 1
    assert_symlink_target "$home/.tool/settings.json" "$fixture/.tool/settings.json" || return 1
    assert_absent "$home/.tool/cache" || return 1
    assert_absent "$home/.gitignore" || return 1
    assert_absent "$home/.gitconfig.local" || return 1
}

test_whole_surfaces_and_child_entries() {
    local fixture="$TEST_ROOT/whole-fixture"
    local home="$TEST_ROOT/whole-home"
    local output="$TEST_ROOT/whole-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.tool/items/example.txt" "item" || return 1
    write_file "$fixture/.tool/package/manifest.json" "{}" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$output" || return 1

    assert_regular_dir "$home/.tool" || return 1
    assert_regular_dir "$home/.tool/items" || return 1
    assert_symlink_target "$home/.tool/items/example.txt" "$fixture/.tool/items/example.txt" || return 1
    assert_symlink_target "$home/.tool/package" "$fixture/.tool/package" || return 1
}

test_shell_theme_links() {
    local fixture="$TEST_ROOT/theme-fixture"
    local home="$TEST_ROOT/theme-home"
    local output="$TEST_ROOT/theme-output.log"

    setup_fixture "$fixture" "$home" || return 1
    mkdir -p "$home/.oh-my-zsh/themes" || return 1
    write_file "$fixture/my.zsh-theme" "theme" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$output" || return 1

    assert_symlink_target "$home/.oh-my-zsh/themes/my.zsh-theme" "$fixture/my.zsh-theme" || return 1
}

test_shell_theme_conflict_fails() {
    local fixture="$TEST_ROOT/theme-conflict-fixture"
    local home="$TEST_ROOT/theme-conflict-home"
    local output="$TEST_ROOT/theme-conflict-output.log"

    setup_fixture "$fixture" "$home" || return 1
    mkdir -p "$home/.oh-my-zsh/themes" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/my.zsh-theme" "managed theme" || return 1
    write_file "$home/.oh-my-zsh/themes/my.zsh-theme" "local theme" || return 1

    if run_install "$fixture" "$home" "$TEST_BRANCH" "$output"; then
        log "Install unexpectedly succeeded despite shell theme conflict"
        return 1
    fi

    assert_file_contains "$output" "already exists and is not a dotfiles-managed symlink" || return 1
    assert_absent "$home/.zshrc" || return 1
}

test_tool_roots_are_not_top_level_links_without_profile() {
    local fixture="$TEST_ROOT/tool-root-skip-fixture"
    local home="$TEST_ROOT/tool-root-skip-home"
    local output="$TEST_ROOT/tool-root-skip-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/.claude/CLAUDE.md" "claude" || return 1
    write_file "$fixture/.codex/config.toml" "codex" || return 1
    write_file "$fixture/.agents/skills/example/SKILL.md" "skill" || return 1
    mkdir -p "$home/.claude" "$home/.codex" "$home/.agents" || return 1

    run_install "$fixture" "$home" "main" "$output" || return 1

    assert_symlink_target "$home/.zshrc" "$fixture/.zshrc" || return 1
    assert_regular_dir "$home/.claude" || return 1
    assert_regular_dir "$home/.codex" || return 1
    assert_regular_dir "$home/.agents" || return 1
    assert_absent "$home/.claude/CLAUDE.md" || return 1
    assert_absent "$home/.codex/config.toml" || return 1
    assert_absent "$home/.agents/skills" || return 1
}

test_check_ordering() {
    local fixture="$TEST_ROOT/check-fixture"
    local home="$TEST_ROOT/check-home"
    local output="$TEST_ROOT/check-output.log"

    mkdir -p "$fixture/profiles/order/checks.d" "$home" || return 1
    copy_installer_files "$fixture" || return 1

    write_file "$fixture/profiles/order/profile.tsv" \
"branch	test/check-order
checks	checks.d
skipsets	skipsets.tsv
surfaces	surfaces.tsv" || return 1
    write_file "$fixture/profiles/order/skipsets.tsv" "# kind	name	pattern" || return 1
    write_file "$fixture/profiles/order/surfaces.tsv" "# kind	strategy	source	dest	skipset	label" || return 1
    write_file "$fixture/profiles/order/checks.d/20-second.sh" \
"#!/usr/bin/env bash
printf '20\n' >> \"\$HOME/check-order.log\"" || return 1
    write_file "$fixture/profiles/order/checks.d/10-first.sh" \
"#!/usr/bin/env bash
printf '10\n' >> \"\$HOME/check-order.log\"" || return 1

    run_install "$fixture" "$home" "test/check-order" "$output" || return 1
    assert_file_equals "$home/check-order.log" \
"10
20" || return 1
}

test_profile_smoke_runner() {
    local fixture="$TEST_ROOT/profile-runner-fixture"
    local output="$TEST_ROOT/profile-runner-output.log"

    make_fixture "$fixture" || return 1
    write_file "$fixture/.tool/config.toml" "config" || return 1
    write_file "$fixture/.tool/items/example.txt" "item" || return 1
    write_file "$fixture/.tool/package/manifest.json" "{}" || return 1

    if ! bash "$fixture/scripts/install/test-profile.sh" \
        --profile profiles/test \
        --branch "$TEST_BRANCH" > "$output" 2>&1
    then
        [ "$VERBOSE" -eq 1 ] && show_output "profile smoke runner log" "$output"
        return 1
    fi

    if [ "$VERBOSE" -eq 1 ]; then
        show_output "profile smoke runner log" "$output"
    fi

    assert_file_contains "$output" "PASS: profile installs into an isolated HOME fixture" || return 1
}

test_profile_smoke_runner_rejects_invalid_profile_manifest() {
    local fixture="$TEST_ROOT/profile-runner-invalid-manifest-fixture"
    local output="$TEST_ROOT/profile-runner-invalid-manifest-output.log"

    make_fixture "$fixture" || return 1
    write_file "$fixture/profiles/test/profile.tsv" "branch	$TEST_BRANCH	extra" || return 1

    if bash "$fixture/scripts/install/test-profile.sh" \
        --profile profiles/test \
        --branch "$TEST_BRANCH" > "$output" 2>&1
    then
        log "Profile smoke runner unexpectedly succeeded despite invalid profile manifest"
        return 1
    fi

    if [ "$VERBOSE" -eq 1 ]; then
        show_output "profile smoke runner invalid manifest log" "$output"
    fi

    assert_file_contains "$output" "invalid installer manifest" || return 1
}

test_aggregate_runner_runs_active_profile() {
    local fixture="$TEST_ROOT/aggregate-runner-fixture"
    local output="$TEST_ROOT/aggregate-runner-output.log"

    copy_test_all_runner_files "$fixture" || return 1
    write_file "$fixture/profiles/test/profile.tsv" "branch	$TEST_BRANCH" || return 1

    if ! DOTPATH="$fixture" bash "$fixture/scripts/install/test-all.sh" --branch "$TEST_BRANCH" > "$output" 2>&1; then
        [ "$VERBOSE" -eq 1 ] && show_output "aggregate runner log" "$output"
        return 1
    fi

    if [ "$VERBOSE" -eq 1 ]; then
        show_output "aggregate runner log" "$output"
    fi

    assert_file_contains "$output" "fake installer" || return 1
    assert_file_contains "$output" "Run profile smoke test: profiles/test" || return 1
    assert_file_contains "$output" "fake profile branch=$TEST_BRANCH" || return 1
    assert_file_contains "$output" "PASS: all checks completed" || return 1
}

test_aggregate_runner_rejects_invalid_profile_manifest() {
    local fixture="$TEST_ROOT/aggregate-invalid-manifest-fixture"
    local output="$TEST_ROOT/aggregate-invalid-manifest-output.log"

    copy_test_all_runner_files "$fixture" || return 1
    write_file "$fixture/profiles/test/profile.tsv" "branch	$TEST_BRANCH	extra" || return 1

    if DOTPATH="$fixture" bash "$fixture/scripts/install/test-all.sh" --branch "$TEST_BRANCH" > "$output" 2>&1; then
        log "Aggregate runner unexpectedly succeeded despite invalid profile manifest"
        return 1
    fi

    assert_file_contains "$output" "invalid installer manifest" || return 1
    assert_file_contains "$output" "FAIL: one or more checks failed" || return 1
}

test_unmanaged_entry_conflict() {
    local fixture="$TEST_ROOT/conflict-fixture"
    local home="$TEST_ROOT/conflict-home"
    local output="$TEST_ROOT/conflict-output.log"

    setup_fixture "$fixture" "$home" || return 1
    mkdir -p "$home/.tool/items" || return 1
    write_file "$fixture/.tool/items/example.txt" "managed item" || return 1
    write_file "$home/.tool/items/example.txt" "local item" || return 1

    if run_install "$fixture" "$home" "$TEST_BRANCH" "$output"; then
        log "Install unexpectedly succeeded despite unmanaged conflict"
        return 1
    fi

    assert_file_contains "$output" "already exists and is not a dotfiles-managed symlink" || return 1
}

test_stale_managed_symlink_cleanup() {
    local fixture="$TEST_ROOT/stale-fixture"
    local home="$TEST_ROOT/stale-home"
    local output="$TEST_ROOT/stale-output.log"

    setup_fixture "$fixture" "$home" || return 1
    mkdir -p "$home/.tool/items" "$fixture/.tool/items" || return 1
    write_file "$fixture/.tool/items/current.txt" "current" || return 1
    ln -s "$fixture/.tool/items/removed.txt" "$home/.tool/items/removed.txt" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$output" || return 1

    assert_absent "$home/.tool/items/removed.txt" || return 1
    assert_symlink_target "$home/.tool/items/current.txt" "$fixture/.tool/items/current.txt" || return 1
}

test_invalid_manifest_fails() {
    local fixture="$TEST_ROOT/invalid-manifest-fixture"
    local home="$TEST_ROOT/invalid-manifest-home"
    local output="$TEST_ROOT/invalid-manifest-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/profiles/test/surfaces.tsv" \
"# kind	strategy	source	dest	skipset	label
surface	entries	.tool	.tool	missing-skipset	Broken surface" || return 1

    if run_install "$fixture" "$home" "$TEST_BRANCH" "$output"; then
        log "Install unexpectedly succeeded despite invalid manifest"
        return 1
    fi

    assert_file_contains "$output" "invalid installer manifest" || return 1
    assert_file_contains "$output" "references unknown skipset: missing-skipset" || return 1
}

test_duplicate_profile_manifest_kind_fails() {
    local fixture="$TEST_ROOT/duplicate-profile-kind-fixture"
    local home="$TEST_ROOT/duplicate-profile-kind-home"
    local output="$TEST_ROOT/duplicate-profile-kind-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/profiles/test/profile.tsv" \
"branch	$TEST_BRANCH
skipsets	skipsets.tsv
surfaces	surfaces.tsv
surfaces	other-surfaces.tsv
checks	checks.d" || return 1

    if run_install "$fixture" "$home" "$TEST_BRANCH" "$output"; then
        log "Install unexpectedly succeeded despite duplicate profile kind"
        return 1
    fi

    assert_file_contains "$output" "invalid installer manifest" || return 1
    assert_file_contains "$output" "duplicate profile kind: surfaces" || return 1
}

test_invalid_surface_path_fails() {
    local fixture="$TEST_ROOT/invalid-surface-path-fixture"
    local home="$TEST_ROOT/invalid-surface-path-home"
    local output="$TEST_ROOT/invalid-surface-path-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/profiles/test/surfaces.tsv" \
"# kind	strategy	source	dest	skipset	label
surface	entries	../outside	.tool	tool-root	Broken source path" || return 1

    if run_install "$fixture" "$home" "$TEST_BRANCH" "$output"; then
        log "Install unexpectedly succeeded despite invalid surface path"
        return 1
    fi

    assert_file_contains "$output" "invalid installer manifest" || return 1
    assert_file_contains "$output" "surface source must be a relative path inside DOTPATH" || return 1
}

test_help_does_not_install() {
    local fixture="$TEST_ROOT/help-fixture"
    local home="$TEST_ROOT/help-home"
    local output="$TEST_ROOT/help-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1

    run_install_args "$fixture" "$home" "$TEST_BRANCH" "$output" --help || return 1

    assert_file_contains "$output" "Usage: bash install.sh" || return 1
    assert_absent "$home/.zshrc" || return 1
}

test_unknown_option_fails() {
    local fixture="$TEST_ROOT/unknown-option-fixture"
    local home="$TEST_ROOT/unknown-option-home"
    local output="$TEST_ROOT/unknown-option-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1

    if run_install_args "$fixture" "$home" "$TEST_BRANCH" "$output" --unknown; then
        log "Install unexpectedly succeeded despite unsupported option"
        return 1
    fi

    assert_file_contains "$output" "unknown option: --unknown" || return 1
    assert_absent "$home/.zshrc" || return 1
}

test_dry_run_does_not_write() {
    local fixture="$TEST_ROOT/dry-run-fixture"
    local home="$TEST_ROOT/dry-run-home"
    local output="$TEST_ROOT/dry-run-output.log"

    setup_fixture "$fixture" "$home" || return 1
    mkdir -p "$home/.tool/items" "$fixture/.tool/items" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/.tool/items/current.txt" "current" || return 1
    ln -s "$fixture/.tool/items/removed.txt" "$home/.tool/items/removed.txt" || return 1

    run_install_args "$fixture" "$home" "$TEST_BRANCH" "$output" --dry-run || return 1

    assert_file_contains "$output" "Dry-run mode" || return 1
    assert_file_contains "$output" "Would link" || return 1
    assert_file_contains "$output" "Would remove stale or skipped symlink" || return 1
    assert_file_contains "$output" "no changes were written" || return 1
    assert_absent "$home/.zshrc" || return 1
    assert_absent "$home/.tool/items/current.txt" || return 1
    assert_symlink_target "$home/.tool/items/removed.txt" "$fixture/.tool/items/removed.txt" || return 1
}

test_short_dry_run_option_does_not_write() {
    local fixture="$TEST_ROOT/short-dry-run-fixture"
    local home="$TEST_ROOT/short-dry-run-home"
    local output="$TEST_ROOT/short-dry-run-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1

    run_install_args "$fixture" "$home" "$TEST_BRANCH" "$output" -n || return 1

    assert_file_contains "$output" "Dry-run mode" || return 1
    assert_absent "$home/.zshrc" || return 1
}

test_shell_theme_dry_run_does_not_write() {
    local fixture="$TEST_ROOT/theme-dry-run-fixture"
    local home="$TEST_ROOT/theme-dry-run-home"
    local output="$TEST_ROOT/theme-dry-run-output.log"

    setup_fixture "$fixture" "$home" || return 1
    mkdir -p "$home/.oh-my-zsh/themes" || return 1
    write_file "$fixture/my.zsh-theme" "theme" || return 1

    run_install_args "$fixture" "$home" "$TEST_BRANCH" "$output" --dry-run || return 1

    assert_file_contains "$output" "Would link" || return 1
    assert_absent "$home/.oh-my-zsh/themes/my.zsh-theme" || return 1
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

log "Workspace: $TEST_ROOT"
run_test "base profile entry links" test_base_profile_entry_links
run_test "whole surfaces and child entries" test_whole_surfaces_and_child_entries
run_test "shell theme links" test_shell_theme_links
run_test "shell theme conflict fails" test_shell_theme_conflict_fails
run_test "tool roots are not top-level links without profile" test_tool_roots_are_not_top_level_links_without_profile
run_test "check ordering by file name" test_check_ordering
run_test "profile smoke runner" test_profile_smoke_runner
run_test "profile smoke runner rejects invalid profile manifest" test_profile_smoke_runner_rejects_invalid_profile_manifest
run_test "aggregate runner runs active profile" test_aggregate_runner_runs_active_profile
run_test "aggregate runner rejects invalid profile manifest" test_aggregate_runner_rejects_invalid_profile_manifest
run_test "unmanaged entry conflict" test_unmanaged_entry_conflict
run_test "stale managed symlink cleanup" test_stale_managed_symlink_cleanup
run_test "invalid manifest fails" test_invalid_manifest_fails
run_test "duplicate profile manifest kind fails" test_duplicate_profile_manifest_kind_fails
run_test "invalid surface path fails" test_invalid_surface_path_fails
run_test "help does not install" test_help_does_not_install
run_test "unknown option fails" test_unknown_option_fails
run_test "dry-run does not write" test_dry_run_does_not_write
run_test "short dry-run option does not write" test_short_dry_run_option_does_not_write
run_test "shell theme dry-run does not write" test_shell_theme_dry_run_does_not_write

log "Passed: $PASS_COUNT"
log "Failed: $FAIL_COUNT"

if [ "$FAIL_COUNT" -ne 0 ]; then
    exit 1
fi
