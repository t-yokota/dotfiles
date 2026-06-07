#!/usr/bin/env bash

# profile/ecc/* branches are only safe to expose after each machine has
# recreated the local ECC lifecycle/sync state that is intentionally not
# committed. profile/ecc-base is a tooling/base branch and intentionally skips
# this check.

case "${DOTFILES_BRANCH:-}" in
    profile/ecc-base)
        echo "    - Status: base branch; skip local ECC install-state checks" >&2
        exit 0
        ;;
    profile/ecc/*)
        echo "    - Status: check local ECC install-state for $DOTFILES_BRANCH" >&2
        ;;
    *) exit 0 ;;
esac

check_required_file() {
    local path="$1"
    local label="$2"

    if [ ! -f "$path" ]; then
        echo "Error: missing $label: $path" >&2
        return 1
    fi
}

check_json_string_equals() {
    local path="$1"
    local field="$2"
    local expected="$3"
    local label="$4"

    if ! command -v node >/dev/null 2>&1; then
        echo "Error: node is required to validate $label: $path" >&2
        return 1
    fi

    if ! node - "$path" "$field" "$expected" "$label" <<'NODE'
const fs = require("fs");

const [file, field, expected, label] = process.argv.slice(2);
let data;

try {
  data = JSON.parse(fs.readFileSync(file, "utf8"));
} catch (error) {
  console.error(`Error: invalid JSON for ${label}: ${file}: ${error.message}`);
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
    `Error: ${label} mismatch in ${file}: expected ${field}=${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`
  );
  process.exit(1);
}
NODE
    then
        return 1
    fi
}

check_ecc_claude_state() {
    local rc=0
    local state_file="$DOTPATH/.claude/ecc/install-state.json"

    check_required_file "$state_file" "Claude ECC install-state" || rc=1

    if [ -f "$state_file" ]; then
        check_json_string_equals "$state_file" "schemaVersion" "ecc.install.v1" \
            "Claude ECC install-state schema" || rc=1
        check_json_string_equals "$state_file" "target.id" "claude-home" \
            "Claude ECC install-state target id" || rc=1
        check_json_string_equals "$state_file" "target.root" "$DOTPATH/.claude" \
            "Claude ECC install-state target root" || rc=1
        check_json_string_equals "$state_file" "target.installStatePath" "$state_file" \
            "Claude ECC install-state path" || rc=1
    fi

    if [ "$rc" -ne 0 ]; then
        echo "Run this from the ECC repo before install.sh:" >&2
        echo "  HOME=\"$DOTPATH\" bash ./install.sh --target claude --profile full" >&2
    fi

    return "$rc"
}

check_ecc_codex_state() {
    local rc=0
    local state_file="$DOTPATH/.codex/dotfiles-profile-ecc-sync-state.json"

    # Ignored local marker: proves this machine has run the local Codex setup step.
    check_required_file "$state_file" "Codex ECC local sync marker" || rc=1

    if [ -f "$state_file" ]; then
        check_json_string_equals "$state_file" "state_owner" "dotfiles.profile-ecc.codex-sync" \
            "Codex ECC sync marker owner" || rc=1
        check_json_string_equals "$state_file" "dotpath" "$DOTPATH" \
            "Codex ECC sync marker dotpath" || rc=1
    fi

    if [ "$rc" -ne 0 ]; then
        echo "Run the Codex sync and skills bundle steps, then create the local marker:" >&2
        echo "  export ECC_REPO=\"/path/to/everything-claude-code\"" >&2
        echo "  HOME=\"$DOTPATH\" \\" >&2
        echo "  CODEX_HOME=\"$DOTPATH/.codex\" \\" >&2
        echo "  AGENTS_HOME=\"$DOTPATH/.agents\" \\" >&2
        echo "  ECC_GLOBAL_HOOKS_DIR=\"$DOTPATH/.codex/git-hooks\" \\" >&2
        echo "  GIT_CONFIG_GLOBAL=\"$DOTPATH/.gitconfig.local\" \\" >&2
        echo "  bash \"\$ECC_REPO/scripts/sync-ecc-to-codex.sh\"" >&2
        echo "  mkdir -p \"$DOTPATH/.agents/skills\"" >&2
        echo "  cp -R \"\$ECC_REPO/.agents/skills/.\" \"$DOTPATH/.agents/skills/\"" >&2
        echo "  DOTPATH=\"$DOTPATH\" ECC_REPO=\"\$ECC_REPO\" \\" >&2
        echo "  bash \"$DOTPATH/profiles/ecc/bin/write-codex-sync-state.sh\"" >&2
    fi

    return "$rc"
}

rc=0
check_ecc_claude_state || rc=1
check_ecc_codex_state || rc=1
exit "$rc"
