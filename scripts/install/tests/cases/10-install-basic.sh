# shellcheck shell=bash

test_base_profile_entry_links() {
    local fixture="$TEST_ROOT/base-fixture"
    local home="$TEST_ROOT/base-home"
    local output="$TEST_ROOT/base-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1
    write_file "$fixture/.gitconfig" "gitconfig" || return 1
    write_file "$fixture/.github/workflows/verify.yml" "ci" || return 1
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
    assert_absent "$home/.github" || return 1
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

register_test "base profile entry links" test_base_profile_entry_links
register_test "whole surfaces and child entries" test_whole_surfaces_and_child_entries
register_test "child surfaces are implicit skips" test_child_surfaces_are_implicit_skips
register_test "shell theme links" test_shell_theme_links
register_test "shell theme conflict fails" test_shell_theme_conflict_fails
register_test "managed roots are not top-level links without profile" test_managed_roots_are_not_top_level_links_without_profile
register_test "CRLF profile manifests load" test_crlf_profile_manifests_load
