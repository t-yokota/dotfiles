# shellcheck shell=bash

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

register_test "status reports link inventory" test_status_reports_link_inventory
register_test "status verbose reports linked and skipped" test_status_verbose_reports_linked_and_skipped
