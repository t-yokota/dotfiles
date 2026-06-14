# shellcheck shell=bash

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

test_skipset_include_composes_patterns() {
    local fixture="$TEST_ROOT/skipset-include-fixture"
    local home="$TEST_ROOT/skipset-include-home"
    local output="$TEST_ROOT/skipset-include-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/profiles/test/skipsets.tsv" \
"# kind	name	pattern
skipset	common-runtime	cache
skipset	common-runtime	*.log
skipset-include	codex-root	common-runtime
skipset	codex-root	auth.json" || return 1
    write_file "$fixture/profiles/test/surfaces.tsv" \
"# kind	strategy	source	dest	skipset	label
surface	entries	.codex	.codex	codex-root	Codex root" || return 1
    write_file "$fixture/.codex/config.toml" "config" || return 1
    write_file "$fixture/.codex/cache/session.json" "cache" || return 1
    write_file "$fixture/.codex/debug.log" "log" || return 1
    write_file "$fixture/.codex/auth.json" "{}" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$output" || return 1

    assert_symlink_target "$home/.codex/config.toml" "$fixture/.codex/config.toml" || return 1
    assert_absent "$home/.codex/cache" || return 1
    assert_absent "$home/.codex/debug.log" || return 1
    assert_absent "$home/.codex/auth.json" || return 1
}

test_unknown_skipset_include_fails() {
    local fixture="$TEST_ROOT/unknown-skipset-include-fixture"
    local home="$TEST_ROOT/unknown-skipset-include-home"
    local output="$TEST_ROOT/unknown-skipset-include-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/profiles/test/skipsets.tsv" \
"# kind	name	pattern
skipset-include	codex-root	missing-runtime" || return 1

    if run_install "$fixture" "$home" "$TEST_BRANCH" "$output"; then
        log "Install unexpectedly succeeded despite unknown skipset include"
        return 1
    fi

    assert_file_contains "$output" "invalid installer manifest" || return 1
    assert_file_contains "$output" "$fixture/profiles/test/skipsets.tsv:2:" || return 1
    assert_file_contains "$output" "skipset-include references unknown skipset: missing-runtime" || return 1
}

test_cyclic_skipset_include_fails() {
    local fixture="$TEST_ROOT/cyclic-skipset-include-fixture"
    local home="$TEST_ROOT/cyclic-skipset-include-home"
    local output="$TEST_ROOT/cyclic-skipset-include-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/profiles/test/skipsets.tsv" \
"# kind	name	pattern
skipset	alpha	cache
skipset-include	beta	alpha
skipset-include	alpha	beta" || return 1

    if run_install "$fixture" "$home" "$TEST_BRANCH" "$output"; then
        log "Install unexpectedly succeeded despite cyclic skipset include"
        return 1
    fi

    assert_file_contains "$output" "invalid installer manifest" || return 1
    assert_file_contains "$output" "$fixture/profiles/test/skipsets.tsv:4:" || return 1
    assert_file_contains "$output" "skipset-include would create a cycle: alpha -> beta" || return 1
}

test_self_skipset_include_fails() {
    local fixture="$TEST_ROOT/self-skipset-include-fixture"
    local home="$TEST_ROOT/self-skipset-include-home"
    local output="$TEST_ROOT/self-skipset-include-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/profiles/test/skipsets.tsv" \
"# kind	name	pattern
skipset-include	alpha	alpha" || return 1

    if run_install "$fixture" "$home" "$TEST_BRANCH" "$output"; then
        log "Install unexpectedly succeeded despite self skipset include"
        return 1
    fi

    assert_file_contains "$output" "invalid installer manifest" || return 1
    assert_file_contains "$output" "$fixture/profiles/test/skipsets.tsv:2:" || return 1
    assert_file_contains "$output" "skipset-include cannot include itself: alpha" || return 1
}

test_duplicate_skipset_include_fails() {
    local fixture="$TEST_ROOT/duplicate-skipset-include-fixture"
    local home="$TEST_ROOT/duplicate-skipset-include-home"
    local output="$TEST_ROOT/duplicate-skipset-include-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/profiles/test/skipsets.tsv" \
"# kind	name	pattern
skipset	common-runtime	cache
skipset-include	codex-root	common-runtime
skipset-include	codex-root	common-runtime" || return 1

    if run_install "$fixture" "$home" "$TEST_BRANCH" "$output"; then
        log "Install unexpectedly succeeded despite duplicate skipset include"
        return 1
    fi

    assert_file_contains "$output" "invalid installer manifest" || return 1
    assert_file_contains "$output" "$fixture/profiles/test/skipsets.tsv:4:" || return 1
    assert_file_contains "$output" "duplicate skipset include: codex-root includes common-runtime" || return 1
}

test_detached_head_warns_no_profile() {
    local fixture="$TEST_ROOT/detached-head-fixture"
    local home="$TEST_ROOT/detached-head-home"
    local output="$TEST_ROOT/detached-head-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.zshrc" "zsh" || return 1

    git -C "$fixture" init -q || return 1
    git -C "$fixture" config user.email "test@example.invalid" || return 1
    git -C "$fixture" config user.name "Installer Test" || return 1
    git -C "$fixture" add . || return 1
    git -C "$fixture" commit -qm "fixture" || return 1
    git -C "$fixture" checkout -q --detach HEAD || return 1

    if ! HOME="$home" \
        DOTPATH="$fixture" \
        OH_MY_ZSH_THEMES="$home/.oh-my-zsh/themes" \
        bash "$fixture/install.sh" --dry-run > "$output" 2>&1
    then
        [ "$VERBOSE" -eq 1 ] && show_output "detached HEAD install log" "$output"
        return 1
    fi

    assert_file_contains "$output" "Warn: current branch is unknown (detached HEAD?); no profile will be applied" || return 1
    assert_file_contains "$output" "top-level dotfiles reconciled (planned links: 1)" || return 1
    assert_absent "$home/.zshrc" || return 1
}

register_test "invalid manifest fails" test_invalid_manifest_fails
register_test "duplicate profile manifest kind fails" test_duplicate_profile_manifest_kind_fails
register_test "invalid surface path fails" test_invalid_surface_path_fails
register_test "surface outside managed root fails" test_surface_outside_managed_root_fails
register_test "skipset include composes patterns" test_skipset_include_composes_patterns
register_test "unknown skipset include fails" test_unknown_skipset_include_fails
register_test "cyclic skipset include fails" test_cyclic_skipset_include_fails
register_test "self skipset include fails" test_self_skipset_include_fails
register_test "duplicate skipset include fails" test_duplicate_skipset_include_fails
register_test "detached HEAD warns no profile" test_detached_head_warns_no_profile
