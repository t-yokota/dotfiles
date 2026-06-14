# shellcheck shell=bash

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
    assert_file_not_contains "$uninstall_output" "Would remove symlink: $home/.zshrc -> $fixture/.zshrc" || return 1
    assert_file_contains "$uninstall_output" "Planned removals :" || return 1
    assert_file_contains "$uninstall_output" "no changes were written" || return 1
    assert_symlink_target "$home/.zshrc" "$fixture/.zshrc" || return 1
    assert_symlink_target "$home/.codex/config.toml" "$fixture/.codex/config.toml" || return 1
}

test_uninstall_dry_run_verbose_reports_details() {
    local fixture="$TEST_ROOT/uninstall-dry-run-verbose-fixture"
    local home="$TEST_ROOT/uninstall-dry-run-verbose-home"
    local install_output="$TEST_ROOT/uninstall-dry-run-verbose-install-output.log"
    local uninstall_output="$TEST_ROOT/uninstall-dry-run-verbose-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$install_output" || return 1
    run_uninstall_args "$fixture" "$home" "$TEST_BRANCH" "$uninstall_output" --dry-run --verbose || return 1

    assert_file_contains "$uninstall_output" "Dry-run mode" || return 1
    assert_file_contains "$uninstall_output" "Verbose mode" || return 1
    assert_file_contains "$uninstall_output" "Would remove symlink: $home/.zshrc -> $fixture/.zshrc" || return 1
    assert_file_contains "$uninstall_output" "Planned removals :" || return 1
    assert_symlink_target "$home/.zshrc" "$fixture/.zshrc" || return 1
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

register_test "install verbose reports details" test_install_verbose_reports_details
register_test "uninstall removes managed symlinks" test_uninstall_removes_managed_symlinks
register_test "uninstall verbose reports details" test_uninstall_verbose_reports_details
register_test "uninstall dry-run does not write" test_uninstall_dry_run_does_not_write
register_test "uninstall dry-run verbose reports details" test_uninstall_dry_run_verbose_reports_details
register_test "uninstall dry-run deduplicates managed-root surface" test_uninstall_dry_run_deduplicates_managed_root_surface
