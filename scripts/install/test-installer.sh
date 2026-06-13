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
CASE_FILTERS=()

usage() {
    cat <<'USAGE'
Usage: bash scripts/install/test-installer.sh [--verbose|-v] [--case <glob>]

Options:
  -v, --verbose   Print captured install.sh logs for each fixture.
  --case <glob>   Run tests whose name or case file matches the glob.
  -h, --help      Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        --case)
            if [ "$#" -lt 2 ]; then
                echo "Error: --case requires a glob" >&2
                usage >&2
                exit 1
            fi
            CASE_FILTERS+=("$2")
            shift 2
            ;;
        --case=*)
            CASE_FILTERS+=("${1#--case=}")
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# shellcheck source=scripts/install/tests/harness.sh
. "$SCRIPT_DIR/tests/harness.sh"

source_test_cases
run_registered_tests
