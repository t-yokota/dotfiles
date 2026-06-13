# shellcheck shell=bash

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
    assert_file_not_contains "$output" "Would create symlink" || return 1
    assert_file_not_contains "$output" "Would remove symlink: $home/.codex/items/removed.txt -> $fixture/.codex/items/removed.txt" || return 1
    assert_file_contains "$output" "Planned links    :" || return 1
    assert_file_contains "$output" "Planned removals :" || return 1
    assert_file_contains "$output" "Skips            :" || return 1
    assert_file_contains "$output" "no changes were written" || return 1
    assert_absent "$home/.zshrc" || return 1
    assert_absent "$home/.codex/items/current.txt" || return 1
    assert_symlink_target "$home/.codex/items/removed.txt" "$fixture/.codex/items/removed.txt" || return 1
}

test_dry_run_verbose_reports_details() {
    local fixture="$TEST_ROOT/dry-run-verbose-fixture"
    local home="$TEST_ROOT/dry-run-verbose-home"
    local output="$TEST_ROOT/dry-run-verbose-output.log"

    setup_fixture "$fixture" "$home" || return 1
    mkdir -p "$home/.codex/items" "$fixture/.codex/items" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/.codex/items/current.txt" "current" || return 1
    ln -s "$fixture/.codex/items/removed.txt" "$home/.codex/items/removed.txt" || return 1

    run_install_args "$fixture" "$home" "$TEST_BRANCH" "$output" --dry-run --verbose || return 1

    assert_file_contains "$output" "Dry-run mode" || return 1
    assert_file_contains "$output" "Verbose mode" || return 1
    assert_file_contains "$output" "Would create symlink" || return 1
    assert_file_contains "$output" "Would remove symlink: $home/.codex/items/removed.txt -> $fixture/.codex/items/removed.txt" || return 1
    assert_file_contains "$output" "Planned links    :" || return 1
    assert_file_contains "$output" "Planned removals :" || return 1
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
    assert_file_not_contains "$output" "Would create symlink" || return 1
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

    assert_file_not_contains "$output" "Would create symlink" || return 1
    assert_file_contains "$output" "shell themes reconciled (planned links: 1" || return 1
    assert_absent "$home/.oh-my-zsh/themes/my.zsh-theme" || return 1
}

test_dry_run_conflict_reports_error() {
    local fixture="$TEST_ROOT/dry-run-conflict-fixture"
    local home="$TEST_ROOT/dry-run-conflict-home"
    local output="$TEST_ROOT/dry-run-conflict-output.log"

    setup_fixture "$fixture" "$home" || return 1
    mkdir -p "$home/.codex/items" "$fixture/.codex/items" || return 1
    write_file "$fixture/.codex/items/example.txt" "managed item" || return 1
    write_file "$home/.codex/items/example.txt" "local item" || return 1

    if run_install_args "$fixture" "$home" "$TEST_BRANCH" "$output" --dry-run; then
        log "Dry-run unexpectedly succeeded despite unmanaged conflict"
        return 1
    fi

    assert_file_contains "$output" "already exists and is not a dotfiles-managed symlink" || return 1
    assert_file_contains "$output" "Move or merge it before rerunning install.sh." || return 1
}

register_test "help does not install" test_help_does_not_install
register_test "unknown option fails" test_unknown_option_fails
register_test "dry-run does not write" test_dry_run_does_not_write
register_test "dry-run verbose reports details" test_dry_run_verbose_reports_details
register_test "short dry-run option does not write" test_short_dry_run_option_does_not_write
register_test "shell theme dry-run does not write" test_shell_theme_dry_run_does_not_write
register_test "dry-run conflict reports error" test_dry_run_conflict_reports_error
