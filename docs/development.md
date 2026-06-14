# Installer Development Guide

- Last reviewed: 2026-06-14

この guide は、common installer (`install.sh`, `uninstall.sh`, `status.sh`, `scripts/install/`) を変更する人と agent 向けの開発メモです。実 HOME を直接使わず、fixture と dry-run で安全に検証する前提で書いています。

## Architecture

top-level entrypoint は共通して次の順で動きます。

```text
bash guard
set -u
usage 定義
common.sh / cli.sh 読み込み
cli_parse_standard_options
cli_bootstrap
phase 実行
result summary
```

entrypoint 自身に残すものは、bash guard、usage text、entrypoint 固有 phase だけです。`scripts/install/lib/cli.sh` は option parsing、`DOTPATH` / `OH_MY_ZSH_THEMES` 初期化、`cd "$DOTPATH"`、`shopt -s nullglob dotglob`、library 読み込みを担当します。

`init_installer_state` が初期化する global state は次の通りです。

| State | Owner | Purpose |
|---|---|---|
| `MANAGED_SURFACES` | `profile.sh` | active profile の surface 定義。 |
| `MANAGED_SURFACE_MANIFESTS` | `profile.sh` / `common.sh` | status/log に出す surface manifest path。 |
| `SKIPSET_PATTERNS` | `profile.sh` | 展開済み skipset pattern。 |
| `SKIPSET_INCLUDES` | `profile.sh` | `skipset-include` の依存関係。 |
| `KNOWN_SKIPSETS` | `profile.sh` | `surfaces.tsv` から参照可能な skipset 名。 |
| `RESERVED_ROOT_ENTRIES` | `profile.sh` | top-level dotfile link から除外する active profile root。 |
| `ACTIVE_PROFILE_CHECK_DIRS` | `profile.sh` | install preflight で実行する check directory。 |

library の責務境界は次の通りです。

| File | Responsibility |
|---|---|
| `common.sh` | policy を持たない shared helper、path helper、logging、summary counter。 |
| `cli.sh` | top-level entrypoint 共通の option parsing と bootstrap。 |
| `profile.sh` | profile manifest 読み込み、schema validation、branch matching、profile check 実行。 |
| `reconcile.sh` | HOME への書き込みを伴う conflict check、cleanup、symlink 作成・削除。 |
| `status.sh` | read-only の link inventory 照合。HOME へ書き込まない。 |

## Bash Rules

すべて Bash 前提です。entrypoint と test runner は `BASH_VERSION` guard を置きます。

`set -u` は使います。`set -e` / `set -o pipefail` は使いません。installer は phase ごとに `|| return 1` / `|| exit 1` で明示的に error を伝播する設計です。

style は 4 space indent、関数内変数は `local`、path と variable 展開は quote します。manifest は tab 区切りなので、読み込みは `IFS=$'\t' read -r ...` を使います。

logging と counting は分離します。`log_step` / `log_substep` は表示だけを担当し、skip 件数を増やす場合は `count_and_log_skip` を使います。`log_link` / `log_would_link` は action-specific helper なので counter 更新を含みます。

dry-run と verbose は別軸です。`--dry-run` は書き込み判定と summary を出し、個別 path の詳細は `--verbose` を併用したときだけ出します。

## Test Roles

| Command | Role |
|---|---|
| `bash scripts/install/lint.sh` | shellcheck lint。shellcheck が無いローカルでは SKIP して exit 0。CI では install 済みで実行する。 |
| `bash scripts/install/test-installer.sh` | common installer の regression。fixture checkout と fixture HOME だけを使う。 |
| `bash scripts/install/test-installer.sh --case '60-*'` | case file 名または test 名 glob による部分実行。 |
| `bash scripts/install/test-profile.sh --profile profiles/<name> --branch <branch>` | profile manifest と surface が isolated HOME に適用できるかの smoke test。 |
| `bash scripts/install/test-all.sh` | lint、installer regression、active profile smoke test の集約。 |

実 HOME を直接変更する test は書きません。実 HOME に対して確認したい場合は `bash install.sh --dry-run`, `bash uninstall.sh --dry-run`, `bash status.sh` に留めます。

## Adding Regression Cases

installer regression は次の構成です。

```text
scripts/install/test-installer.sh
scripts/install/tests/harness.sh
scripts/install/tests/cases/*.sh
```

新しい case は近い分類の `tests/cases/*.sh` に追加します。分類が増える場合は番号付き file を追加します。file 名は `--case '60-*'` のような部分実行対象になるため、意味が分かる名前にします。

case の基本形:

```bash
test_example_behavior() {
    local fixture="$TEST_ROOT/example-fixture"
    local home="$TEST_ROOT/example-home"
    local output="$TEST_ROOT/example-output.log"

    setup_fixture "$fixture" "$home" || return 1
    write_file "$fixture/.codex/config.toml" "config" || return 1

    run_install "$fixture" "$home" "$TEST_BRANCH" "$output" || return 1

    assert_symlink_target "$home/.codex/config.toml" "$fixture/.codex/config.toml" || return 1
    assert_file_contains "$output" "Install Result" || return 1
}

register_test "example behavior" test_example_behavior
```

fixture の作り方は `setup_fixture` を起点にします。`setup_fixture` は installer entrypoint、`scripts/install/lib/`、test profile manifest を fixture checkout にコピーします。必要な source file や HOME 側 conflict は case 内で明示的に作ります。

assert は harness の helper を優先します。文言を変える場合は、`assert_file_contains` / `assert_file_not_contains` でその文言を見ている case を同時に更新します。

manifest schema を変える場合は、先に `60-manifest-validation.sh` に RED case を追加します。成功系だけでなく、file:line 付き error、未知 kind、重複、循環、path validation などの failure mode も入れます。実装後は [reference/profile-manifest.md](reference/profile-manifest.md) と top-level README の概念説明も更新します。

## Change Checklist

- entrypoint option を変えたら `--help` と unknown option の test を更新する。
- log 文言を変えたら、その文言を assert する regression case を同時に更新する。
- counter を変えたら dry-run / status の summary 件数を確認する。
- manifest schema を変えたら validation、regression test、reference、README を同時に更新する。
- HOME への書き込み範囲を広げない。未管理通常 file は上書きしない。
- cleanup / uninstall の対象は、この checkout を指す managed symlink に限定する。
- 最後に `bash scripts/install/test-all.sh`, `bash install.sh --dry-run`, `bash uninstall.sh --dry-run`, `bash status.sh`, `git diff --check` を実行する。
