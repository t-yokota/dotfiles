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
    cp "$REPO_ROOT/uninstall.sh" "$fixture/uninstall.sh" || return 1
    cp "$REPO_ROOT/status.sh" "$fixture/status.sh" || return 1
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

test_base_profile_entry_links() {
    local fixture="$TEST_ROOT/base-fixture"
    local home="$TEST_ROOT/base-home"
    local output="$TEST_ROOT/base-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/.gitconfig" "gitconfig" || return 1
    write_file "$fixture/.gitignore" "ignored" || return 1
    write_file "$fixture/.gitconfig.local" "local" || return 1
    write_file "$fixture/.codex/config.toml" "config" || return 1
    write_file "$fixture/.codex/settings.json" "{}" || return 1
    write_file "$fixture/.codex/cache/session.json" "{}" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$output" || return 1

    assert_symlink_target "$home/.zshrc" "$fixture/.zshrc" || return 1
    assert_symlink_target "$home/.gitconfig" "$fixture/.gitconfig" || return 1
    assert_regular_dir "$home/.codex" || return 1
    assert_symlink_target "$home/.codex/config.toml" "$fixture/.codex/config.toml" || return 1
    assert_symlink_target "$home/.codex/settings.json" "$fixture/.codex/settings.json" || return 1
    assert_absent "$home/.codex/cache" || return 1
    assert_absent "$home/.gitignore" || return 1
    assert_absent "$home/.gitconfig.local" || return 1
    assert_file_contains "$output" "Install Result" || return 1
    assert_file_contains "$output" "Links    :" || return 1
    assert_file_contains "$output" "Removals :" || return 1
    assert_file_contains "$output" "Skips    :" || return 1
    assert_file_contains "$output" "OK: install completed; changes were written by the common installer" || return 1
}

test_whole_surfaces_and_child_entries() {
    local fixture="$TEST_ROOT/whole-fixture"
    local home="$TEST_ROOT/whole-home"
    local output="$TEST_ROOT/whole-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.codex/items/example.txt" "item" || return 1
    write_file "$fixture/.codex/package/manifest.json" "{}" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$output" || return 1

    assert_regular_dir "$home/.codex" || return 1
    assert_regular_dir "$home/.codex/items" || return 1
    assert_symlink_target "$home/.codex/items/example.txt" "$fixture/.codex/items/example.txt" || return 1
    assert_symlink_target "$home/.codex/package" "$fixture/.codex/package" || return 1
}

test_child_surfaces_are_implicit_skips() {
    local fixture="$TEST_ROOT/implicit-child-surface-fixture"
    local home="$TEST_ROOT/implicit-child-surface-home"
    local output="$TEST_ROOT/implicit-child-surface-output.log"
    local status_output="$TEST_ROOT/implicit-child-surface-status-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.codex/items/example.txt" "item" || return 1
    write_file "$fixture/.codex/package/manifest.json" "{}" || return 1

    run_install_args "$fixture" "$home" "$TEST_BRANCH" "$output" --verbose || return 1
    run_status_args "$fixture" "$home" "$TEST_BRANCH" "$status_output" --verbose || return 1

    assert_regular_dir "$home/.codex" || return 1
    assert_regular_dir "$home/.codex/items" || return 1
    assert_symlink_target "$home/.codex/items/example.txt" "$fixture/.codex/items/example.txt" || return 1
    assert_symlink_target "$home/.codex/package" "$fixture/.codex/package" || return 1
    assert_file_contains "$output" "Skip child surface entry: $fixture/.codex/items" || return 1
    assert_file_contains "$output" "Skip child surface entry: $fixture/.codex/package" || return 1
    assert_file_contains "$status_output" "skipped: $fixture/.codex/items (managed by child surface)" || return 1
    assert_file_contains "$status_output" "skipped: $fixture/.codex/package (managed by child surface)" || return 1
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

test_crlf_profile_manifests_load() {
    local fixture="$TEST_ROOT/crlf-manifest-fixture"
    local home="$TEST_ROOT/crlf-manifest-home"
    local output="$TEST_ROOT/crlf-manifest-output.log"

    setup_fixture "$fixture" "$home" || return 1
    printf 'branch\t%s\r\nskipsets\tskipsets.tsv\r\nsurfaces\tsurfaces.tsv\r\nchecks\tchecks.d\r\n' "$TEST_BRANCH" > "$fixture/profiles/test/profile.tsv" || return 1
    printf '# kind\tname\tpattern\r\nskipset\tmanaged-root\tcache\r\n' > "$fixture/profiles/test/skipsets.tsv" || return 1
    printf '# kind\tstrategy\tsource\tdest\tskipset\tlabel\r\nsurface\tentries\t.codex\t.codex\tmanaged-root\tTest managed root\r\n' > "$fixture/profiles/test/surfaces.tsv" || return 1
    write_file "$fixture/.codex/config.toml" "config" || return 1
    write_file "$fixture/.codex/cache/session.json" "cache" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$output" || return 1

    assert_symlink_target "$home/.codex/config.toml" "$fixture/.codex/config.toml" || return 1
    assert_absent "$home/.codex/cache" || return 1
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

test_managed_roots_are_not_top_level_links_without_profile() {
    local fixture="$TEST_ROOT/managed-root-skip-fixture"
    local home="$TEST_ROOT/managed-root-skip-home"
    local output="$TEST_ROOT/managed-root-skip-output.log"

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
    write_file "$fixture/.codex/config.toml" "config" || return 1
    write_file "$fixture/.codex/items/example.txt" "item" || return 1
    write_file "$fixture/.codex/package/manifest.json" "{}" || return 1

    if ! DOTPATH="$fixture" bash "$fixture/scripts/install/test-profile.sh" \
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

    if DOTPATH="$fixture" bash "$fixture/scripts/install/test-profile.sh" \
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
    mkdir -p "$home/.codex/items" || return 1
    write_file "$fixture/.codex/items/example.txt" "managed item" || return 1
    write_file "$home/.codex/items/example.txt" "local item" || return 1

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
    mkdir -p "$home/.codex/items" "$fixture/.codex/items" || return 1
    write_file "$fixture/.codex/items/current.txt" "current" || return 1
    ln -s "$fixture/.codex/items/removed.txt" "$home/.codex/items/removed.txt" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$output" || return 1

    assert_absent "$home/.codex/items/removed.txt" || return 1
    assert_symlink_target "$home/.codex/items/current.txt" "$fixture/.codex/items/current.txt" || return 1
}

test_inactive_profile_managed_root_cleanup() {
    local fixture="$TEST_ROOT/inactive-profile-fixture"
    local home="$TEST_ROOT/inactive-profile-home"
    local profile_output="$TEST_ROOT/inactive-profile-profile-output.log"
    local main_output="$TEST_ROOT/inactive-profile-main-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/profiles/test/skipsets.tsv" \
"# kind	name	pattern
skipset	claude-root	agents" || return 1
    write_file "$fixture/profiles/test/surfaces.tsv" \
"# kind	strategy	source	dest	skipset	label
surface	entries	.claude	.claude	claude-root	Claude root
surface	entries	.claude/agents	.claude/agents	none	Claude agents" || return 1
    write_file "$fixture/.claude/AGENTS.md" "managed agents" || return 1
    write_file "$fixture/.claude/CLAUDE.md" "base memory" || return 1
    write_file "$fixture/.claude/settings.json" "{}" || return 1
    write_file "$fixture/.claude/agents/reviewer.md" "managed reviewer" || return 1
    write_file "$home/.claude/.credentials.json" "local credential" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$profile_output" || return 1

    assert_symlink_target "$home/.claude/AGENTS.md" "$fixture/.claude/AGENTS.md" || return 1
    assert_symlink_target "$home/.claude/CLAUDE.md" "$fixture/.claude/CLAUDE.md" || return 1
    assert_symlink_target "$home/.claude/settings.json" "$fixture/.claude/settings.json" || return 1
    assert_regular_dir "$home/.claude/agents" || return 1
    assert_symlink_target "$home/.claude/agents/reviewer.md" "$fixture/.claude/agents/reviewer.md" || return 1
    assert_file_equals "$home/.claude/.credentials.json" "local credential" || return 1

    rm "$fixture/.claude/AGENTS.md" "$fixture/.claude/agents/reviewer.md" || return 1
    run_install_args "$fixture" "$home" "main" "$main_output" --verbose || return 1

    assert_absent "$home/.claude/AGENTS.md" || return 1
    assert_symlink_target "$home/.claude/CLAUDE.md" "$fixture/.claude/CLAUDE.md" || return 1
    assert_symlink_target "$home/.claude/settings.json" "$fixture/.claude/settings.json" || return 1
    assert_absent "$home/.claude/agents/reviewer.md" || return 1
    assert_regular_dir "$home/.claude" || return 1
    assert_regular_dir "$home/.claude/agents" || return 1
    assert_file_equals "$home/.claude/.credentials.json" "local credential" || return 1
    assert_file_contains "$main_output" "Remove symlink: $home/.claude/AGENTS.md -> $fixture/.claude/AGENTS.md" || return 1
}

test_install_verbose_reports_details() {
    local fixture="$TEST_ROOT/install-verbose-fixture"
    local home="$TEST_ROOT/install-verbose-home"
    local quiet_output="$TEST_ROOT/install-quiet-output.log"
    local verbose_output="$TEST_ROOT/install-verbose-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/.codex/config.toml" "config" || return 1
    write_file "$fixture/.codex/cache/session.json" "cache" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$quiet_output" || return 1
    run_install_args "$fixture" "$home" "$TEST_BRANCH" "$verbose_output" -v || return 1

    assert_file_contains "$quiet_output" "Install Result" || return 1
    assert_file_contains "$quiet_output" "OK: preflight passed" || return 1
    assert_file_contains "$quiet_output" "Surface manifests: $fixture/profiles/test/surfaces.tsv" || return 1
    assert_file_contains "$quiet_output" "OK: top-level dotfiles reconciled (links:" || return 1
    assert_file_contains "$quiet_output" "OK: managed dotfile surfaces reconciled (links:" || return 1
    assert_file_not_contains "$quiet_output" "Create symlink:" || return 1
    assert_file_not_contains "$quiet_output" "Skip runtime or separately managed entry" || return 1
    assert_file_contains "$verbose_output" "Verbose mode" || return 1
    assert_file_contains "$verbose_output" "OK: top-level dotfiles reconciled (links:" || return 1
    assert_file_contains "$verbose_output" "OK: managed dotfile surfaces reconciled (links:" || return 1
    assert_file_contains "$verbose_output" "Create symlink:" || return 1
    assert_file_contains "$verbose_output" "Skip runtime or separately managed entry" || return 1
}

test_uninstall_removes_managed_symlinks() {
    local fixture="$TEST_ROOT/uninstall-fixture"
    local home="$TEST_ROOT/uninstall-home"
    local install_output="$TEST_ROOT/uninstall-install-output.log"
    local uninstall_output="$TEST_ROOT/uninstall-output.log"

    setup_fixture "$fixture" "$home" || return 1
    mkdir -p "$home/.oh-my-zsh/themes" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/.gitconfig" "gitconfig" || return 1
    write_file "$fixture/.codex/config.toml" "config" || return 1
    write_file "$fixture/.codex/items/example.txt" "item" || return 1
    write_file "$fixture/.codex/package/manifest.json" "{}" || return 1
    write_file "$fixture/my.zsh-theme" "theme" || return 1
    write_file "$home/.codex/local.txt" "local" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$install_output" || return 1
    run_uninstall "$fixture" "$home" "$TEST_BRANCH" "$uninstall_output" || return 1

    assert_absent "$home/.zshrc" || return 1
    assert_absent "$home/.gitconfig" || return 1
    assert_absent "$home/.codex/config.toml" || return 1
    assert_absent "$home/.codex/items/example.txt" || return 1
    assert_absent "$home/.codex/package" || return 1
    assert_absent "$home/.oh-my-zsh/themes/my.zsh-theme" || return 1
    assert_regular_dir "$home/.codex" || return 1
    assert_regular_dir "$home/.codex/items" || return 1
    assert_file_equals "$home/.codex/local.txt" "local" || return 1
    assert_file_contains "$uninstall_output" "Uninstall Result" || return 1
    assert_file_contains "$uninstall_output" "Removals :" || return 1
    assert_file_contains "$uninstall_output" "OK: uninstall completed" || return 1
}

test_uninstall_verbose_reports_details() {
    local fixture="$TEST_ROOT/uninstall-verbose-fixture"
    local quiet_home="$TEST_ROOT/uninstall-verbose-quiet-home"
    local verbose_home="$TEST_ROOT/uninstall-verbose-detail-home"
    local quiet_install_output="$TEST_ROOT/uninstall-verbose-quiet-install-output.log"
    local verbose_install_output="$TEST_ROOT/uninstall-verbose-detail-install-output.log"
    local quiet_output="$TEST_ROOT/uninstall-quiet-output.log"
    local verbose_output="$TEST_ROOT/uninstall-verbose-output.log"

    setup_fixture "$fixture" "$quiet_home" || return 1
    mkdir -p "$verbose_home" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/.codex/config.toml" "config" || return 1

    run_install "$fixture" "$quiet_home" "$TEST_BRANCH" "$quiet_install_output" || return 1
    run_install "$fixture" "$verbose_home" "$TEST_BRANCH" "$verbose_install_output" || return 1
    run_uninstall "$fixture" "$quiet_home" "$TEST_BRANCH" "$quiet_output" || return 1
    run_uninstall_args "$fixture" "$verbose_home" "$TEST_BRANCH" "$verbose_output" --verbose || return 1

    assert_file_contains "$quiet_output" "Uninstall Result" || return 1
    assert_file_contains "$quiet_output" "OK: preflight passed" || return 1
    assert_file_contains "$quiet_output" "Remove Managed Dotfile Surface Links" || return 1
    assert_file_contains "$quiet_output" "Surface manifests: $fixture/profiles/test/surfaces.tsv" || return 1
    assert_file_contains "$quiet_output" "OK: top-level dotfile links completed (removals:" || return 1
    assert_file_contains "$quiet_output" "OK: managed dotfile surface links completed (removals:" || return 1
    assert_file_not_contains "$quiet_output" "Remove symlink" || return 1
    assert_file_contains "$verbose_output" "Verbose mode" || return 1
    assert_file_contains "$verbose_output" "OK: top-level dotfile links completed (removals:" || return 1
    assert_file_contains "$verbose_output" "OK: managed dotfile surface links completed (removals:" || return 1
    assert_file_contains "$verbose_output" "Remove symlink: $verbose_home/.zshrc -> $fixture/.zshrc" || return 1
}

test_uninstall_dry_run_does_not_write() {
    local fixture="$TEST_ROOT/uninstall-dry-run-fixture"
    local home="$TEST_ROOT/uninstall-dry-run-home"
    local install_output="$TEST_ROOT/uninstall-dry-run-install-output.log"
    local uninstall_output="$TEST_ROOT/uninstall-dry-run-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/.codex/config.toml" "config" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$install_output" || return 1
    run_uninstall_args "$fixture" "$home" "$TEST_BRANCH" "$uninstall_output" --dry-run || return 1

    assert_file_contains "$uninstall_output" "Dry-run mode" || return 1
    assert_file_contains "$uninstall_output" "Would remove symlink: $home/.zshrc -> $fixture/.zshrc" || return 1
    assert_file_contains "$uninstall_output" "Planned removals :" || return 1
    assert_file_contains "$uninstall_output" "no changes were written" || return 1
    assert_symlink_target "$home/.zshrc" "$fixture/.zshrc" || return 1
    assert_symlink_target "$home/.codex/config.toml" "$fixture/.codex/config.toml" || return 1
}

test_uninstall_dry_run_deduplicates_managed_root_surface() {
    local fixture="$TEST_ROOT/uninstall-dedup-fixture"
    local home="$TEST_ROOT/uninstall-dedup-home"
    local install_output="$TEST_ROOT/uninstall-dedup-install-output.log"
    local uninstall_output="$TEST_ROOT/uninstall-dedup-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/profiles/test/surfaces.tsv" \
"# kind	strategy	source	dest	skipset	label
surface	entries	.claude	.claude	none	Claude root" || return 1
    write_file "$fixture/.claude/CLAUDE.md" "claude" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$install_output" || return 1
    run_uninstall_args "$fixture" "$home" "$TEST_BRANCH" "$uninstall_output" --dry-run || return 1

    assert_file_contains "$uninstall_output" "Planned removals : 1" || return 1
    assert_symlink_target "$home/.claude/CLAUDE.md" "$fixture/.claude/CLAUDE.md" || return 1
}

test_status_reports_link_inventory() {
    local fixture="$TEST_ROOT/status-fixture"
    local home="$TEST_ROOT/status-home"
    local output="$TEST_ROOT/status-output.log"
    local verbose_output="$TEST_ROOT/status-verbose-issues-output.log"

    setup_fixture "$fixture" "$home" || return 1
    mkdir -p "$home/.codex/items" "$home/.oh-my-zsh/themes" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/.gitconfig" "gitconfig" || return 1
    write_file "$fixture/.codex/config.toml" "config" || return 1
    write_file "$fixture/.codex/items/example.txt" "item" || return 1
    write_file "$fixture/.codex/cache/session.json" "cache" || return 1
    write_file "$fixture/.codex/package/manifest.json" "{}" || return 1
    write_file "$fixture/my.zsh-theme" "theme" || return 1

    ln -s "$fixture/.zshrc" "$home/.zshrc" || return 1
    write_file "$home/.codex/items/example.txt" "local conflict" || return 1
    ln -s "$fixture/.codex/removed.txt" "$home/.codex/removed.txt" || return 1
    ln -s "$fixture/.codex/cache" "$home/.codex/cache" || return 1

    run_status "$fixture" "$home" "$TEST_BRANCH" "$output" || return 1
    run_status_args "$fixture" "$home" "$TEST_BRANCH" "$verbose_output" --verbose || return 1

    assert_file_contains "$output" "Status Result" || return 1
    assert_file_contains "$output" "Desired Managed Dotfile Surface Links" || return 1
    assert_file_contains "$output" "Unexpected Managed Links" || return 1
    assert_file_contains "$output" "Surface manifests: $fixture/profiles/test/surfaces.tsv" || return 1
    assert_file_contains "$output" "Linked    :" || return 1
    assert_file_contains "$output" "Missing   :" || return 1
    assert_file_contains "$output" "Conflicts :" || return 1
    assert_file_contains "$output" "Stale     :" || return 1
    assert_file_contains "$output" "Orphaned  :" || return 1
    assert_file_contains "$output" "Skipped   :" || return 1
    assert_file_contains "$output" "expected links already point to this dotfiles checkout" || return 1
    assert_file_contains "$output" "expected links are absent from HOME" || return 1
    assert_file_contains "$output" "expected destinations exist but are not the expected symlinks" || return 1
    assert_file_contains "$output" "unexpected managed links point to missing targets" || return 1
    assert_file_contains "$output" "unexpected managed links point to targets outside current desired state" || return 1
    assert_file_contains "$output" "entries intentionally excluded by skipsets or child surfaces" || return 1
    assert_file_contains "$output" "Check: top-level dotfile links checked" || return 1
    assert_file_contains "$output" "Check: Test managed root checked" || return 1
    assert_file_contains "$output" "Check: unexpected dotfiles-managed links are outside current desired state" || return 1
    assert_file_contains "$output" "Check: reportable link issues found; review with --verbose" || return 1
    assert_file_not_contains "$output" "missing: $home/.gitconfig" || return 1
    assert_file_not_contains "$output" "conflict: $home/.codex/items/example.txt" || return 1
    assert_file_not_contains "$output" "stale: $home/.codex/removed.txt" || return 1
    assert_file_not_contains "$output" "orphaned: $home/.codex/cache" || return 1
    assert_file_contains "$verbose_output" "Verbose mode" || return 1
    assert_file_contains "$verbose_output" "missing: $home/.gitconfig" || return 1
    assert_file_contains "$verbose_output" "conflict: $home/.codex/items/example.txt" || return 1
    assert_file_contains "$verbose_output" "stale: $home/.codex/removed.txt" || return 1
    assert_file_contains "$verbose_output" "orphaned: $home/.codex/cache" || return 1
    assert_file_contains "$verbose_output" "Check: reportable link issues found" || return 1
    assert_file_not_contains "$verbose_output" "review with --verbose" || return 1
    assert_symlink_target "$home/.zshrc" "$fixture/.zshrc" || return 1
    assert_symlink_target "$home/.codex/removed.txt" "$fixture/.codex/removed.txt" || return 1
}

test_status_verbose_reports_linked_and_skipped() {
    local fixture="$TEST_ROOT/status-verbose-fixture"
    local home="$TEST_ROOT/status-verbose-home"
    local output="$TEST_ROOT/status-verbose-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/.codex/cache/session.json" "cache" || return 1
    ln -s "$fixture/.zshrc" "$home/.zshrc" || return 1

    run_status_args "$fixture" "$home" "$TEST_BRANCH" "$output" --verbose || return 1

    assert_file_contains "$output" "linked:" || return 1
    assert_file_contains "$output" "skipped:" || return 1
    assert_file_contains "$output" "No desired links found for this surface (linked: 0, missing: 0, conflicts: 0, skipped: 0)" || return 1
    assert_file_contains "$output" "OK: no unexpected dotfiles-managed links outside current desired state (stale: 0, orphaned: 0)" || return 1
    assert_file_contains "$output" "OK: status checked; no changes were made" || return 1
}

test_invalid_manifest_fails() {
    local fixture="$TEST_ROOT/invalid-manifest-fixture"
    local home="$TEST_ROOT/invalid-manifest-home"
    local output="$TEST_ROOT/invalid-manifest-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/profiles/test/surfaces.tsv" \
"# kind	strategy	source	dest	skipset	label
surface	entries	.codex	.codex	missing-skipset	Broken surface" || return 1

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
surface	entries	../outside	.codex	managed-root	Broken source path" || return 1

    if run_install "$fixture" "$home" "$TEST_BRANCH" "$output"; then
        log "Install unexpectedly succeeded despite invalid surface path"
        return 1
    fi

    assert_file_contains "$output" "invalid installer manifest" || return 1
    assert_file_contains "$output" "surface source must be a relative path inside DOTPATH" || return 1
}

test_surface_outside_managed_root_fails() {
    local fixture="$TEST_ROOT/outside-managed-root-fixture"
    local home="$TEST_ROOT/outside-managed-root-home"
    local output="$TEST_ROOT/outside-managed-root-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/profiles/test/surfaces.tsv" \
"# kind	strategy	source	dest	skipset	label
surface	entries	.config/my-tool	.config/my-tool	none	Outside managed root" || return 1

    if run_install "$fixture" "$home" "$TEST_BRANCH" "$output"; then
        log "Install unexpectedly succeeded despite surface outside managed roots"
        return 1
    fi

    assert_file_contains "$output" "invalid installer manifest" || return 1
    assert_file_contains "$output" "surface source root must be one of managed roots: .claude, .codex, .agents" || return 1
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
    mkdir -p "$home/.codex/items" "$fixture/.codex/items" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/.codex/items/current.txt" "current" || return 1
    ln -s "$fixture/.codex/items/removed.txt" "$home/.codex/items/removed.txt" || return 1

    run_install_args "$fixture" "$home" "$TEST_BRANCH" "$output" --dry-run || return 1

    assert_file_contains "$output" "Dry-run mode" || return 1
    assert_file_contains "$output" "Would create symlink" || return 1
    assert_file_contains "$output" "Would remove symlink: $home/.codex/items/removed.txt -> $fixture/.codex/items/removed.txt" || return 1
    assert_file_contains "$output" "Planned links    :" || return 1
    assert_file_contains "$output" "Planned removals :" || return 1
    assert_file_contains "$output" "Skips            :" || return 1
    assert_file_contains "$output" "no changes were written" || return 1
    assert_absent "$home/.zshrc" || return 1
    assert_absent "$home/.codex/items/current.txt" || return 1
    assert_symlink_target "$home/.codex/items/removed.txt" "$fixture/.codex/items/removed.txt" || return 1
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

    assert_file_contains "$output" "Would create symlink" || return 1
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
run_test "child surfaces are implicit skips" test_child_surfaces_are_implicit_skips
run_test "shell theme links" test_shell_theme_links
run_test "shell theme conflict fails" test_shell_theme_conflict_fails
run_test "managed roots are not top-level links without profile" test_managed_roots_are_not_top_level_links_without_profile
run_test "CRLF profile manifests load" test_crlf_profile_manifests_load
run_test "check ordering by file name" test_check_ordering
run_test "profile smoke runner" test_profile_smoke_runner
run_test "profile smoke runner rejects invalid profile manifest" test_profile_smoke_runner_rejects_invalid_profile_manifest
run_test "aggregate runner runs active profile" test_aggregate_runner_runs_active_profile
run_test "aggregate runner rejects invalid profile manifest" test_aggregate_runner_rejects_invalid_profile_manifest
run_test "unmanaged entry conflict" test_unmanaged_entry_conflict
run_test "stale managed symlink cleanup" test_stale_managed_symlink_cleanup
run_test "inactive profile managed-root cleanup" test_inactive_profile_managed_root_cleanup
run_test "install verbose reports details" test_install_verbose_reports_details
run_test "uninstall removes managed symlinks" test_uninstall_removes_managed_symlinks
run_test "uninstall verbose reports details" test_uninstall_verbose_reports_details
run_test "uninstall dry-run does not write" test_uninstall_dry_run_does_not_write
run_test "uninstall dry-run deduplicates managed-root surface" test_uninstall_dry_run_deduplicates_managed_root_surface
run_test "status reports link inventory" test_status_reports_link_inventory
run_test "status verbose reports linked and skipped" test_status_verbose_reports_linked_and_skipped
run_test "invalid manifest fails" test_invalid_manifest_fails
run_test "duplicate profile manifest kind fails" test_duplicate_profile_manifest_kind_fails
run_test "invalid surface path fails" test_invalid_surface_path_fails
run_test "surface outside managed root fails" test_surface_outside_managed_root_fails
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
