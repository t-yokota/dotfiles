#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: lint.sh must be run with bash. Use: bash scripts/install/lint.sh" >&2
    exit 1
fi

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTPATH=${DOTPATH:-$(cd "$SCRIPT_DIR/../.." && pwd)}
VERBOSE=0

usage() {
    cat <<'USAGE'
Usage: bash scripts/install/lint.sh [--verbose|-v]

Options:
  -v, --verbose  Print files passed to shellcheck.
  -h, --help     Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=1
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
    shift
done

log() {
    printf '[lint] %s\n' "$*"
}

collect_shell_files() {
    printf '%s\n' \
        "$DOTPATH/install.sh" \
        "$DOTPATH/uninstall.sh" \
        "$DOTPATH/status.sh"

    find "$DOTPATH/scripts/install" -type f -name '*.sh' -print

    if [ -d "$DOTPATH/profiles" ]; then
        find "$DOTPATH/profiles" -type f \( -path '*/bin/*.sh' -o -path '*/checks.d/*.sh' \) -print
    fi
}

if ! command -v shellcheck >/dev/null 2>&1; then
    log "SKIP: shellcheck not found"
    exit 0
fi

mapfile -t shell_files < <(collect_shell_files | sort -u)

if [ "${#shell_files[@]}" -eq 0 ]; then
    log "SKIP: no shell files found"
    exit 0
fi

log "shellcheck: $(shellcheck --version | sed -n 's/^version: //p')"

if [ "$VERBOSE" -eq 1 ]; then
    for shell_file in "${shell_files[@]}"; do
        log "file: ${shell_file#"$DOTPATH"/}"
    done
fi

# Gate on warnings and errors. Informational notes are useful locally but too
# noisy for this repository's source-heavy shell layout.
shellcheck --shell=bash --external-sources --severity=warning "${shell_files[@]}"
