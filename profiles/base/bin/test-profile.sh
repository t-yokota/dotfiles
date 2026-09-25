#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: test-profile.sh must be run with bash. Use: bash profiles/<name>/bin/test-profile.sh" >&2
    exit 1
fi

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROFILE_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DOTPATH=${DOTPATH:-$(cd "$PROFILE_DIR/../.." && pwd)}
RUNNER="$DOTPATH/scripts/install/test-profile.sh"

if [ ! -f "$RUNNER" ]; then
    echo "Error: missing profile test runner: $RUNNER" >&2
    exit 1
fi

exec bash "$RUNNER" --profile "$PROFILE_DIR" "$@"
