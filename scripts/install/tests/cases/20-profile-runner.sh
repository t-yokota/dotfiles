# shellcheck shell=bash

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

register_test "check ordering by file name" test_check_ordering
register_test "profile smoke runner" test_profile_smoke_runner
register_test "profile smoke runner rejects invalid profile manifest" test_profile_smoke_runner_rejects_invalid_profile_manifest
register_test "aggregate runner runs active profile" test_aggregate_runner_runs_active_profile
register_test "aggregate runner rejects invalid profile manifest" test_aggregate_runner_rejects_invalid_profile_manifest
