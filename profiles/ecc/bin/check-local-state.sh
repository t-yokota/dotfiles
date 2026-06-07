#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: check-local-state.sh must be run with bash. Use: bash profiles/ecc/bin/check-local-state.sh" >&2
    exit 1
fi

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROFILE_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
DOTPATH=${DOTPATH:-$(cd "$PROFILE_DIR/../.." && pwd)}
BRANCH=${DOTFILES_BRANCH:-}
ECC_REPO=${ECC_REPO:-}
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

usage() {
    cat <<'USAGE'
Usage: bash profiles/ecc/bin/check-local-state.sh [--branch <branch>] [--dotpath <dir>] [--ecc-repo <dir>]

Options:
  --branch <branch>   Branch name to evaluate. Defaults to the current dotfiles branch.
  --dotpath <dir>     Dotfiles checkout to inspect. Defaults to this repository.
  --ecc-repo <dir>    ECC repository to inspect. Defaults to ECC_REPO if set.
  -h, --help          Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --branch)
            if [ "$#" -lt 2 ]; then
                echo "Error: --branch requires a value" >&2
                exit 1
            fi
            BRANCH="$2"
            shift
            ;;
        --dotpath)
            if [ "$#" -lt 2 ]; then
                echo "Error: --dotpath requires a value" >&2
                exit 1
            fi
            DOTPATH="$2"
            shift
            ;;
        --ecc-repo)
            if [ "$#" -lt 2 ]; then
                echo "Error: --ecc-repo requires a value" >&2
                exit 1
            fi
            ECC_REPO="$2"
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
    shift
done

log() {
    printf '[ecc-check] %s\n' "$*"
}

section() {
    printf '\n== %s ==\n' "$*"
}

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    log "PASS: $1"
}

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    log "WARN: $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    log "FAIL: $1"
}

check_file() {
    local path="$1"
    local label="$2"

    if [ -f "$path" ]; then
        pass "$label: $path"
    else
        fail "missing $label: $path"
    fi
}

check_dir() {
    local path="$1"
    local label="$2"

    if [ -d "$path" ]; then
        pass "$label: $path"
    else
        fail "missing $label: $path"
    fi
}

check_file_contains() {
    local path="$1"
    local text="$2"
    local label="$3"

    if [ ! -f "$path" ]; then
        fail "missing $label: $path"
        return 1
    fi

    if grep -Fq "$text" "$path"; then
        pass "$label: $path"
    else
        fail "$label not found in $path"
    fi
}

check_json_string_equals() {
    local path="$1"
    local field="$2"
    local expected="$3"
    local label="$4"

    if [ ! -f "$path" ]; then
        fail "missing $label: $path"
        return 1
    fi

    if ! command -v node >/dev/null 2>&1; then
        fail "node is required to validate $label: $path"
        return 1
    fi

    if node - "$path" "$field" "$expected" "$label" <<'NODE'
const fs = require("fs");

const [file, field, expected, label] = process.argv.slice(2);
let data;

try {
  data = JSON.parse(fs.readFileSync(file, "utf8"));
} catch (error) {
  console.error(`invalid JSON for ${label}: ${error.message}`);
  process.exit(1);
}

const actual = field.split(".").reduce((value, key) => {
  if (value && Object.prototype.hasOwnProperty.call(value, key)) {
    return value[key];
  }
  return undefined;
}, data);

if (actual !== expected) {
  console.error(
    `expected ${field}=${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`
  );
  process.exit(1);
}
NODE
    then
        pass "$label: $field"
    else
        fail "$label mismatch in $path"
    fi
}

detect_branch() {
    if [ -n "$BRANCH" ]; then
        return 0
    fi

    BRANCH=$(git -C "$DOTPATH" branch --show-current 2>/dev/null || true)
}

normalize_paths() {
    local dotpath_input="$DOTPATH"

    if ! DOTPATH=$(cd "$dotpath_input" 2>/dev/null && pwd); then
        echo "Error: DOTPATH does not exist: $dotpath_input" >&2
        exit 1
    fi

    if [ -n "$ECC_REPO" ]; then
        local ecc_repo_input="$ECC_REPO"
        if ! ECC_REPO=$(cd "$ecc_repo_input" 2>/dev/null && pwd); then
            echo "Error: ECC_REPO does not exist: $ecc_repo_input" >&2
            exit 1
        fi
    fi
}

check_baseline() {
    section "Baseline"
    check_file "$DOTPATH/.claude/CLAUDE.md" "Claude user memory baseline"
    check_file "$DOTPATH/.claude/settings.json" "Claude user settings baseline"
    check_file "$DOTPATH/.codex/config.toml" "Codex config baseline"
}

check_ecc_repo_source() {
    section "ECC Repository"

    if [ -z "$ECC_REPO" ]; then
        warn "ECC_REPO is not set; skip ECC repository source checks"
        return 0
    fi

    check_file "$ECC_REPO/scripts/sync-ecc-to-codex.sh" "ECC Codex sync script"
    check_dir "$ECC_REPO/.agents/skills" "ECC Codex skills source"
}

check_claude_output() {
    local state_file="$DOTPATH/.claude/ecc/install-state.json"

    section "Claude Install State"
    if [ -f "$state_file" ]; then
        check_json_string_equals "$state_file" "schemaVersion" "ecc.install.v1" \
            "Claude ECC install-state schema"
        check_json_string_equals "$state_file" "target.id" "claude-home" \
            "Claude ECC install-state target id"
        check_json_string_equals "$state_file" "target.root" "$DOTPATH/.claude" \
            "Claude ECC install-state target root"
        check_json_string_equals "$state_file" "target.installStatePath" "$state_file" \
            "Claude ECC install-state path"
    else
        fail "missing Claude ECC install-state: $state_file"
    fi

    section "Claude Desired Output"
    check_file "$DOTPATH/.claude/AGENTS.md" "Claude ECC AGENTS.md"
    check_dir "$DOTPATH/.claude/.agents" "Claude embedded agent root"
    check_dir "$DOTPATH/.claude/agents" "Claude agents"
    check_dir "$DOTPATH/.claude/commands" "Claude commands"
    check_dir "$DOTPATH/.claude/rules/ecc" "Claude ECC rules"
    check_dir "$DOTPATH/.claude/skills/ecc" "Claude ECC skills"
}

check_codex_output() {
    section "Codex Sync Output"
    check_file_contains "$DOTPATH/.codex/AGENTS.md" "<!-- BEGIN ECC -->" \
        "Codex ECC marker block"
    check_file "$DOTPATH/.codex/config.toml" "Codex config.toml"
    check_file "$DOTPATH/.codex/prompts/ecc-prompts-manifest.txt" \
        "Codex ECC prompts manifest"
    check_file "$DOTPATH/.codex/prompts/ecc-extension-prompts-manifest.txt" \
        "Codex ECC extension prompts manifest"
    check_file "$DOTPATH/.codex/agents/explorer.toml" \
        "Codex ECC explorer agent role"
    check_file "$DOTPATH/.codex/agents/reviewer.toml" \
        "Codex ECC reviewer agent role"
    check_file "$DOTPATH/.codex/agents/docs-researcher.toml" \
        "Codex ECC docs-researcher agent role"

    section "Codex Skills Bundle"
    check_dir "$DOTPATH/.agents/skills" "Codex skills root"
    check_dir "$DOTPATH/.agents/skills/tdd-workflow" "Codex ECC skill tdd-workflow"
    check_dir "$DOTPATH/.agents/skills/security-review" "Codex ECC skill security-review"
}

check_codex_marker() {
    local state_file="$DOTPATH/.codex/dotfiles-profile-ecc-sync-state.json"

    section "Codex Local Marker"
    if [ -f "$state_file" ]; then
        check_json_string_equals "$state_file" "state_owner" "dotfiles.profile-ecc.codex-sync" \
            "Codex ECC sync marker owner"
        check_json_string_equals "$state_file" "dotpath" "$DOTPATH" \
            "Codex ECC sync marker dotpath"
    else
        fail "missing Codex ECC local sync marker: $state_file"
    fi
}

print_next_steps() {
    if [ "$FAIL_COUNT" -eq 0 ]; then
        return 0
    fi

    section "Suggested Next Steps"
    log "Run or rerun the missing setup steps from docs/ecc-dotfiles-manual-install.md."
    log "Claude: HOME=\"$DOTPATH\" bash ./install.sh --target claude --profile full"
    log "Codex: HOME=\"$DOTPATH\" CODEX_HOME=\"$DOTPATH/.codex\" AGENTS_HOME=\"$DOTPATH/.agents\" bash scripts/sync-ecc-to-codex.sh"
    log "Skills: cp -R \"\$ECC_REPO/.agents/skills/.\" \"$DOTPATH/.agents/skills/\""
    log "Marker: DOTPATH=\"$DOTPATH\" ECC_REPO=\"\$ECC_REPO\" bash \"$DOTPATH/profiles/ecc/bin/write-codex-sync-state.sh\""
}

main() {
    local rc=0

    normalize_paths
    detect_branch

    section "Context"
    log "DOTPATH: $DOTPATH"
    log "Branch: ${BRANCH:-<not detected>}"
    log "ECC_REPO: ${ECC_REPO:-<not set>}"

    check_baseline

    case "$BRANCH" in
        profile/ecc-base)
            section "Local State"
            pass "base branch intentionally skips ECC install-state checks"
            ;;
        profile/ecc/*)
            check_ecc_repo_source
            check_claude_output
            check_codex_output
            check_codex_marker
            ;;
        *)
            section "Local State"
            warn "branch does not activate ECC profile local-state checks"
            ;;
    esac

    section "Summary"
    log "Passed: $PASS_COUNT"
    log "Warnings: $WARN_COUNT"
    log "Failed: $FAIL_COUNT"

    print_next_steps

    [ "$FAIL_COUNT" -eq 0 ] || rc=1
    return "$rc"
}

main "$@"
