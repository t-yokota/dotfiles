# shellcheck shell=bash

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

register_test "unmanaged entry conflict" test_unmanaged_entry_conflict
register_test "stale managed symlink cleanup" test_stale_managed_symlink_cleanup
register_test "inactive profile managed-root cleanup" test_inactive_profile_managed_root_cleanup
