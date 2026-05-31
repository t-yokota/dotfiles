#!/usr/bin/env bash

# Create a machine-local marker after Codex sync output and the skills bundle have
# been regenerated for this dotfiles checkout.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTPATH=${DOTPATH:-$(cd "$SCRIPT_DIR/../.." && pwd)}
STATE_OWNER="dotfiles.profile-ecc.codex-sync"
STATE_FILE="$DOTPATH/.codex/dotfiles-profile-ecc-sync-state.json"

fail() {
    echo "Error: $*" >&2
    return 1
}

check_required_file() {
    local path="$1"
    local label="$2"

    if [ ! -f "$path" ]; then
        fail "missing $label: $path"
    fi
}

check_required_dir() {
    local path="$1"
    local label="$2"

    if [ ! -d "$path" ]; then
        fail "missing $label: $path"
    fi
}

check_file_contains() {
    local path="$1"
    local text="$2"
    local label="$3"

    if ! grep -Fq "$text" "$path"; then
        fail "$label not found in $path"
    fi
}

count_files() {
    local dir="$1"
    local pattern="$2"

    find "$dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null | wc -l | tr -d '[:space:]'
}

count_dirs() {
    local dir="$1"

    find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d '[:space:]'
}

if [ -z "${ECC_REPO:-}" ]; then
    fail "ECC_REPO is required, for example ECC_REPO=/path/to/everything-claude-code"
    exit 1
fi

if ! command -v node >/dev/null 2>&1; then
    fail "node is required to write JSON safely"
    exit 1
fi

if ! DOTPATH=$(cd "$DOTPATH" && pwd); then
    fail "DOTPATH does not exist: $DOTPATH"
    exit 1
fi

if ! ECC_REPO=$(cd "$ECC_REPO" && pwd); then
    fail "ECC_REPO does not exist: $ECC_REPO"
    exit 1
fi

rc=0

check_required_file "$ECC_REPO/scripts/sync-ecc-to-codex.sh" "ECC Codex sync script" || rc=1
check_required_dir "$ECC_REPO/.agents/skills" "ECC Codex skills source" || rc=1

check_required_file "$DOTPATH/.codex/AGENTS.md" "Codex ECC AGENTS.md" || rc=1
check_required_file "$DOTPATH/.codex/config.toml" "Codex config.toml" || rc=1
check_required_file "$DOTPATH/.codex/prompts/ecc-prompts-manifest.txt" \
    "Codex ECC prompts manifest" || rc=1
check_required_file "$DOTPATH/.codex/prompts/ecc-extension-prompts-manifest.txt" \
    "Codex ECC extension prompts manifest" || rc=1
check_required_file "$DOTPATH/.codex/agents/explorer.toml" \
    "Codex ECC explorer agent role" || rc=1
check_required_file "$DOTPATH/.codex/agents/reviewer.toml" \
    "Codex ECC reviewer agent role" || rc=1
check_required_file "$DOTPATH/.codex/agents/docs-researcher.toml" \
    "Codex ECC docs-researcher agent role" || rc=1
check_required_dir "$DOTPATH/.agents/skills/tdd-workflow" \
    "Codex ECC skill tdd-workflow" || rc=1
check_required_dir "$DOTPATH/.agents/skills/security-review" \
    "Codex ECC skill security-review" || rc=1

if [ -f "$DOTPATH/.codex/AGENTS.md" ]; then
    check_file_contains "$DOTPATH/.codex/AGENTS.md" "<!-- BEGIN ECC -->" \
        "Codex ECC marker" || rc=1
fi

if [ "$rc" -ne 0 ]; then
    echo "Codex sync state marker was not written." >&2
    exit 1
fi

GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CODEX_HOME="$DOTPATH/.codex"
AGENTS_HOME="$DOTPATH/.agents"
ECC_REPO_BRANCH=$(git -C "$ECC_REPO" branch --show-current 2>/dev/null || true)
ECC_REPO_COMMIT=$(git -C "$ECC_REPO" rev-parse HEAD 2>/dev/null || true)
if [ -n "$(git -C "$ECC_REPO" status --porcelain 2>/dev/null || true)" ]; then
    ECC_REPO_DIRTY=true
else
    ECC_REPO_DIRTY=false
fi

PROMPTS_COUNT=$(count_files "$DOTPATH/.codex/prompts" "ecc-*.md")
SKILLS_COUNT=$(count_dirs "$DOTPATH/.agents/skills")
GITCONFIG_LOCAL_EXISTS=false
HOOKS_PRE_COMMIT_EXECUTABLE=false
HOOKS_PRE_PUSH_EXECUTABLE=false
HOOKS_PATH=""

[ -f "$DOTPATH/.gitconfig.local" ] && GITCONFIG_LOCAL_EXISTS=true
[ -x "$DOTPATH/.codex/git-hooks/pre-commit" ] && HOOKS_PRE_COMMIT_EXECUTABLE=true
[ -x "$DOTPATH/.codex/git-hooks/pre-push" ] && HOOKS_PRE_PUSH_EXECUTABLE=true
HOOKS_PATH=$(git config --file "$DOTPATH/.gitconfig.local" --get core.hooksPath 2>/dev/null || true)

export STATE_FILE STATE_OWNER GENERATED_AT DOTPATH CODEX_HOME AGENTS_HOME
export ECC_REPO ECC_REPO_BRANCH ECC_REPO_COMMIT ECC_REPO_DIRTY
export PROMPTS_COUNT SKILLS_COUNT GITCONFIG_LOCAL_EXISTS
export HOOKS_PRE_COMMIT_EXECUTABLE HOOKS_PRE_PUSH_EXECUTABLE HOOKS_PATH

if ! node <<'NODE'
const fs = require("fs");
const path = require("path");

const bool = (value) => value === "true";
const number = (value) => Number(value || 0);

const state = {
  schema_version: 1,
  state_owner: process.env.STATE_OWNER,
  generated_at: process.env.GENERATED_AT,
  dotpath: process.env.DOTPATH,
  codex_home: process.env.CODEX_HOME,
  agents_home: process.env.AGENTS_HOME,
  ecc_repo: process.env.ECC_REPO,
  ecc_repo_branch: process.env.ECC_REPO_BRANCH || null,
  ecc_repo_commit: process.env.ECC_REPO_COMMIT || null,
  ecc_repo_dirty: bool(process.env.ECC_REPO_DIRTY),
  sync_script: "scripts/sync-ecc-to-codex.sh",
  skills_source: `${process.env.ECC_REPO}/.agents/skills`,
  observed: {
    prompts_count: number(process.env.PROMPTS_COUNT),
    skills_count: number(process.env.SKILLS_COUNT),
    has_gitconfig_local: bool(process.env.GITCONFIG_LOCAL_EXISTS),
    hooks_path: process.env.HOOKS_PATH || null,
    has_pre_commit_hook: bool(process.env.HOOKS_PRE_COMMIT_EXECUTABLE),
    has_pre_push_hook: bool(process.env.HOOKS_PRE_PUSH_EXECUTABLE)
  },
  codex_sync_surface: [
    ".codex/AGENTS.md",
    ".codex/config.toml",
    ".codex/agents",
    ".codex/prompts",
    ".agents/skills"
  ],
  local_paths: [
    ".codex/dotfiles-profile-ecc-sync-state.json",
    ".codex/backups",
    ".codex/git-hooks",
    ".gitconfig.local"
  ],
  cleanup_notes: [
    "Remove .codex/dotfiles-profile-ecc-sync-state.json when resetting local Codex sync state.",
    "Remove .codex/prompts/ecc-*.md and the ECC prompt manifests before regenerating prompts.",
    "Remove ECC sample role files under .codex/agents only if they came from ECC sync.",
    "Edit .codex/AGENTS.md marker block and .codex/config.toml ECC-added sections manually or restore them from Git history."
  ]
};

fs.mkdirSync(path.dirname(process.env.STATE_FILE), { recursive: true });
fs.writeFileSync(process.env.STATE_FILE, `${JSON.stringify(state, null, 2)}\n`);
NODE
then
    fail "failed to write $STATE_FILE"
    exit 1
fi

echo "Wrote $STATE_FILE"
