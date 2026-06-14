# コードリファクタリング計画 (R-tasks)

- Last reviewed: 2026-06-14
- 前提: [README.md](README.md) の実行規則 (特に「検証」「安全規則」「コーディング規約」) を先に読むこと

この計画書は installer 一式 (entrypoint, `scripts/install/`, `profiles/*/bin/`) のリファクタリング指示書です。R1〜R7 は**外部から観測できる振る舞い (出力・exit code・作成される symlink) を変えない**ことを原則とし、R8〜R10 は振る舞い変更を含みます。

すべての R-task に共通する完了条件:

- `bash scripts/install/test-all.sh` 全 PASS。
- `bash install.sh --dry-run`, `bash uninstall.sh --dry-run`, `bash status.sh` の出力が変更前と一致する (振る舞い非変更 task の場合)。実行前に 3 コマンドの出力をファイルに保存し、実行後に diff を取ること。
- shellcheck 警告を増やさない (R5 導入後)。

## 実施記録 (2026-06-14)

commit hash は未作成です。最終 commit 作成時に D7 の規則に従って追記します。

| Task | 状態 | 証跡 |
|---|---|---|
| R5 | 完了 | `scripts/install/lint.sh` を追加し、`test-all.sh` に lint phase と `--no-lint` を追加。`shellcheck 0.9.0` で `bash scripts/install/lint.sh --verbose` が PASS。 |
| R6 | remote 部分確認 | `.github/workflows/verify.yml` を追加し、`workflow_dispatch` も有効化。matrix は `main` / `profile/ecc-base`。`main` / `profile/ecc-base` / leaf branch を origin へ push 済み。GitHub Actions run `27484468897` (`head_branch=main`) は success、job `Installer (main)` / `Installer (profile/ecc-base)` も success。API 確認時点で `head_branch=profile/ecc-base` / leaf の run は未発生のため、profile branch 自体の remote green は未確認。 |
| R1 | 完了 | `scripts/install/lib/cli.sh` を追加し、3 entrypoint の option parsing / bootstrap を共通化。 |
| R2 | 完了 | `summary_scope_begin`, `summary_scope_delta`, `summary_scope_remove_ok` を追加し、entrypoint の before/after counter 重複を削除。 |
| R3 | 完了 | `log_step` / `log_substep` から prefix 文字列による skip counter 副作用を削除し、`count_and_log_skip` へ明示化。`log_link` / `log_would_link` は action-specific counter helper として comment 付きで維持。 |
| R11 | 完了 | dry-run と verbose を分離。`--dry-run` 単体は summary 中心、`--dry-run --verbose` は個別 path を表示。README と tests 更新済み。 |
| R7 | 完了 | `test-installer.sh` を `tests/harness.sh` と `tests/cases/*.sh` へ分割。`--case <glob>` 部分実行を追加。最大 file は `harness.sh` 355 行。 |
| R8 | 完了 | `skipset-include` schema を追加し、ECC skipsets を 117 行から 65 行へ削減。旧新 skip 判定は現 checkout の managed-root entry 29 件で一致。 |
| R9 | 完了 | detached HEAD / branch 不明時に警告を出し、profile なし install として続行する test を追加。 |
| R10 | 完了 | `install.sh`, `uninstall.sh`, `status.sh` に `set -u` を追加し、`set -e` 不採用理由を comment 化。 |
| R4 | 見送り完了 | R2/R3/R8/R5 shellcheck 対応後の `common.sh` は 449 行。R4 の基準「450 行を下回っているなら分割せず完了」に従い、`log.sh` 分離は行わない。 |

R7 の case 分類:

| Case file | 主な test |
|---|---|
| `10-install-basic.sh` | base profile entry、whole surface、child surface skip、shell theme、CRLF manifest、managed root top-level skip |
| `20-profile-runner.sh` | check ordering、profile smoke runner、aggregate runner |
| `30-reconcile.sh` | unmanaged conflict、stale symlink cleanup、inactive profile cleanup |
| `40-output-uninstall.sh` | verbose output、uninstall、uninstall dry-run |
| `50-status.sh` | status inventory、status verbose |
| `60-manifest-validation.sh` | invalid manifest、surface validation、skipset include validation、detached HEAD warning |
| `70-cli-dry-run.sh` | help、unknown option、install dry-run、dry-run conflict |

最終確認で実行した代表コマンド:

- `bash scripts/install/test-all.sh`
- `bash scripts/install/test-all.sh --branch main`
- `bash scripts/install/test-all.sh --branch profile/ecc-base`
- `bash scripts/install/lint.sh --verbose`
- `bash scripts/install/test-installer.sh --case '60-*'`
- `bash scripts/install/test-installer.sh --case '*dry-run*'`
- `bash install.sh --dry-run`
- `bash uninstall.sh --dry-run`
- `bash status.sh`
- `git diff --check`

---

## R5: shellcheck / lint の導入

- 優先度: 最高 (他の全 R-task の前に実施) / 工数: 小〜中 / 依存: なし / 振る舞い: 非変更
- 対象: `scripts/install/lint.sh` (新規), `scripts/install/test-all.sh`, 既存 shell script 全部

### 目的

以後のリファクタリングを静的検査の保護下で行う。

### 作業手順

1. shellcheck の有無を確認する (`command -v shellcheck`)。WSL2 / Ubuntu なら `apt install shellcheck`。CI でも使うため version を記録する。
2. `scripts/install/lint.sh` を新規作成する:
   - 対象: `install.sh`, `uninstall.sh`, `status.sh`, `scripts/install/**/*.sh`, `profiles/*/bin/*.sh`, `profiles/*/checks.d/*.sh`。
   - `shellcheck --shell=bash --external-sources` で実行。lib は entrypoint から source される前提のため、`# shellcheck source=` directive を必要箇所に追加する。
   - shellcheck 未 install の環境では「SKIP (shellcheck not found)」を出して exit 0 にする (test-all.sh を壊さないため)。ただし CI では必ず install して実行する。
3. 初回実行で出る指摘を分類する:
   - 実害のある指摘 (quoting 漏れ、未定義変数参照の可能性) → 修正する。
   - 設計意図による指摘 (例: SC2034 未使用に見える変数、SC2086 で意図的 word splitting がもしあれば) → 行単位の `# shellcheck disable=SCxxxx` + 理由 comment で抑制する。file 全体抑制は使わない。
   - **修正が振る舞いを変えないことをテストで確認しながら 1 種類ずつ commit する。**
4. `test-all.sh` の先頭 phase として lint を組み込む (`--no-lint` で skip 可能にしてもよい)。
5. (任意) `shfmt -i 4 -ci` での format 検査。既存 style と差が大きい場合は導入を見送り、その判断を実施記録に残す。

### 受け入れ基準

- [x] `bash scripts/install/lint.sh` が exit 0。
- [x] 抑制 directive にはすべて理由 comment が付いている。
- [x] `test-all.sh` 経由で lint が実行される。

---

## R6: CI workflow の導入

- 優先度: 最高 / 工数: 小 / 依存: R5 / 振る舞い: 非変更
- 対象: `.github/workflows/verify.yml` (新規)

### 目的

push / PR ごとに regression test と lint を自動実行する。remote は GitHub (`origin`) 前提。

### 作業手順

1. `.github/workflows/verify.yml` を作成する:
   - trigger: `push` (branches: `main`, `profile/**`, `integrate/**`) と `pull_request`。
   - manual trigger: `workflow_dispatch`。GitHub UI から `profile/ecc-base` / leaf branch を選んで確認できるようにする。
   - runner: `ubuntu-latest`。step: checkout → `sudo apt-get install -y shellcheck` → `bash scripts/install/lint.sh` → `bash scripts/install/test-all.sh --branch main`。
   - `test-all.sh` は branch に応じて profile smoke test を選ぶため、CI では `--branch` を明示する。さらに matrix で `--branch profile/ecc-base` も実行し、profile 検出経路を検証する。
   - 注意: `profile/ecc/*` branch の smoke test は ECC local state (install-state, sync marker) を要求し CI では満たせない。`test-profile.sh` がこの場合にどう振る舞うか確認し、CI で fail するなら `profile/ecc/*` への push では smoke test を skip する分岐を workflow 側に置く (テスト側の挙動は変えない)。
2. workflow file は `main` に commit し、profile branch へ merge で降ろす。
3. push して Actions の成功を確認する。

### 受け入れ基準

- [x] `workflow_dispatch` が定義され、GitHub UI から manual run の入口を持つ。
- [x] `main` への push で CI が走り green。
- [x] `main` run の matrix job として `Installer (main)` / `Installer (profile/ecc-base)` が green。
- [ ] `profile/ecc-base` を `head_branch` にした CI run が green。
- [x] CI 失敗時に lint と test のどちらで落ちたか log から判別できる。

---

## R1: entrypoint bootstrap の共通化

- 優先度: 高 / 工数: 中 / 依存: R5, R6 / 振る舞い: 非変更
- 対象: `scripts/install/lib/cli.sh` (新規), `install.sh`, `uninstall.sh`, `status.sh`

### 目的

3 entrypoint にコピーされている bash guard・`--dry-run/--verbose/--help` parsing・`DOTPATH` 初期化・`cd`・`shopt`・lib 読み込みを 1 箇所にする。

### 現状

`install.sh:1-59`, `uninstall.sh`, `status.sh` がほぼ同文の前段 (約 60 行) を持つ。差分は usage 文言、`uninstall.sh` の dry-run 説明文言、`status.sh` に dry-run option がない可能性 (実装を確認すること)。

### 作業手順

1. まず 3 entrypoint の前段を並べて diff し、**実際の差分を確定する** (status.sh の option 構成は未確認のため必ず読む)。
2. `scripts/install/lib/cli.sh` を新規作成し、次を提供する:
   - `cli_parse_standard_options "$@"`: `-n/--dry-run`, `-v/--verbose`, `-h/--help`, 不明 option エラーを処理。usage 本文は呼び出し側が `usage()` を定義して渡す (entrypoint ごとの文言差を維持)。dry-run を受け付けない entrypoint 向けに受理 option を絞れる形にする。
   - `cli_bootstrap`: `DOTPATH` / `OH_MY_ZSH_THEMES` 初期化、`cd "$DOTPATH"`、`shopt -s nullglob dotglob`、`init_installer_state`、追加 lib 読み込み。
   - 注意: bash guard (`BASH_VERSION` check) と `common.sh` の存在確認 + source は cli.sh 読み込み前に必要なので entrypoint に残す。ここは共通化できない旨を comment で明記する。
3. 3 entrypoint を書き換え、各 entrypoint は「guard → common.sh source → cli.sh 経由 bootstrap → phase 実行」だけにする。
4. `--help` 出力・不明 option 時の exit code (1) と stderr 出力がすべて変更前と一致することを確認する (`test-installer.sh` に help / unknown option の case があるので必ず通す)。

### 受け入れ基準

- [x] 3 entrypoint から重複した parsing loop が消えている。
- [ ] `bash install.sh --help`, `bash uninstall.sh --help`, `bash status.sh --help` の出力が変更前と byte 一致。
- [x] test-all.sh 全 PASS。

---

## R2: section summary scope の共通化

- 優先度: 中 / 工数: 小 / 依存: R1 / 振る舞い: 非変更 (出力一致)
- 対象: `scripts/install/lib/common.sh`, `install.sh`, `uninstall.sh`

### 目的

`install.sh` で 4 回繰り返される「counter 退避 → 処理 → 差分計算 → log_ok」パターンと、`uninstall.sh` の `uninstall_scope_begin` / `uninstall_scope_result` を統一する。

### 作業手順

1. `common.sh` に scope helper を追加する。案:
   - `summary_scope_begin`: 全 counter (`LINKED`, `WOULD_LINK`, `REMOVED`, `WOULD_REMOVE`, `SKIPPED`) を `SUMMARY_SCOPE_*` に退避。
   - `summary_scope_delta <counter名>`: 差分を出力。
   - `summary_scope_ok <template...>`: dry-run / 通常で文言を切り替えて `log_ok` する。文言 template は現行出力 (例: `cleanup checked (planned removals: N)`) を**そのまま再現**できる設計にする。汎用化しすぎて文言が変わるくらいなら、文言は呼び出し側に残して差分計算だけ helper にする。
2. `install.sh` の 4 箇所 (Cleanup / Top-Level / Surfaces / Themes) と `uninstall.sh` を helper 使用に書き換え、`uninstall_scope_*` を削除する。
3. 通常 / dry-run / verbose の 3 mode で出力 diff が空であることを確認する。

### 受け入れ基準

- [x] before/after counter 変数 (`cleanup_removed_before` など) が entrypoint から消えている。
- [ ] 3 mode の出力が変更前と一致。test-all.sh 全 PASS。

---

## R3: logging と counting の分離

- 優先度: 中 / 工数: 中 / 依存: R1, R2 / 振る舞い: 非変更 (出力・件数一致)
- 対象: `scripts/install/lib/common.sh` と全呼び出し側

### 目的

`log_step` / `log_substep` が `Skip:` / `Skip*` プレフィックスの文字列マッチで `summary_increment skipped` する副作用を除去する。現状では log 文言の変更が skip 件数を静かに変える。

### 作業手順

1. `common.sh` の `log_step` / `log_substep` から `summary_increment skipped` を取り除く。
2. skip を計上している全呼び出し箇所を `grep -n '"Skip' install.sh uninstall.sh status.sh scripts/install/lib/*.sh` で列挙し、それぞれを明示的な `count_and_log_skip` (新設: `summary_increment skipped` + 旧表示と同一の出力) に置き換える。
   - 注意: `link_shell_themes` の `log_step "Skip: $OH_MY_ZSH_THEMES does not exist"` のような「skip 件数に数えるべきでない情報表示」が混ざっていないか、現行の件数仕様を test 出力で確定してから置換する。**現行件数を正とする** (件数仕様の変更はこの task では行わない)。
3. 同様に `log_link` / `log_would_link` 内の `summary_increment` も検討するが、これらは専用関数で文言マッチではないため、副作用 comment を付けて現状維持でよい (判断を実施記録に残す)。
4. skip 件数が出る test case (verbose / summary 系) を全部通し、件数が一致することを確認する。

### 受け入れ基準

- [x] log 関数内に文字列プレフィックス判定による counter 増加が存在しない。
- [ ] 全 mode で skip 件数・出力が変更前と一致。test-all.sh 全 PASS。

---

## R11: dry-run と verbose の分離 (振る舞い変更)

- 優先度: 中 / 工数: 中 / 依存: R3 (log 関数の整理後に行う) / 振る舞い: **変更あり** (dry-run の既定出力が簡潔になる)
- 対象: `scripts/install/lib/common.sh`, `install.sh` / `uninstall.sh` の usage 文言, top-level `README.md`, テスト

### 目的

現状、dry-run では verbose 指定の有無にかかわらず必ず詳細ログが表示される。dry-run (何を書くかの判定モード) と verbose (出力の詳細度) は独立した軸なので分離し、`--dry-run` 単体では section ごとの件数 + Result summary のみ、`--dry-run --verbose` で従来どおりの詳細 (個々の Would create / Would remove / Skip 行) を表示する形にする。

### 現状の結合点 (実装確認済み)

| 箇所 | 現状の挙動 |
|---|---|
| `common.sh` `should_log_detail()` | `is_verbose \|\| is_dry_run` — dry-run が詳細表示を強制する結合の中心 |
| `common.sh` `log_would_link()` | gating なしで常に出力する (対になる `log_link` は `is_verbose` で gate されており非対称) |
| `common.sh` `log_substep()` | `Would remove*` / `Would*` / `Skip*` / `Remove*` 分岐がすべて `should_log_detail` で gate |
| `install.sh` usage | `--dry-run` の説明が "Validate and show planned changes" と詳細表示を含意 |
| top-level README | 「`--dry-run` の場合は、書き込み予定を確認するために詳細ログも表示します」と明文化されている |
| `test-installer.sh` | dry-run case が詳細行 (`Would create symlink:` 等) を assert している可能性が高い (要確認) |

### 設計

- `should_log_detail()` を `is_verbose` のみに変更する。これにより `log_substep` の全分岐が verbose でのみ出る。
- `log_would_link` を `log_link` と対称にする: `summary_increment would_link` は常に行い、出力は `is_verbose` のときのみ。
- 件数計上 (`summary_increment` / `INSTALL_SUMMARY_*`) は一切変えない。dry-run 単体でも section の `OK: ... (planned links: N, planned removals: M, skips: K)` と Result summary は従来どおり出るため、「何件書く予定か」は非 verbose でも分かる。個々の path を知りたいときに `-nv` を使う、という整理にする。
- `log_mode_section` の dry-run 通知メッセージは維持する。あわせて dry-run 単体時の通知文言に「詳細は --verbose を併用」の 1 文を加える (例: `Use --verbose to list each planned change.`)。
- エラー出力 (conflict 検出など `Error:` 系) は detail gating の対象外であることを変更しない。dry-run 非 verbose でも conflict は従来どおり停止 + 表示される。

### 作業手順

1. 変更前に 4 mode (`-n`, `-nv`, `-v`, 指定なし) × 3 command (install / uninstall / status) の出力をファイルに保存する。status.sh が `should_log_detail` / dry-run 概念をどう使っているかはこの時点で確認する (status は read-only のため dry-run option 自体を持たない可能性が高い。その場合 status は影響なしと実施記録に書く)。
2. テストを先に更新する (TDD):
   - 既存 dry-run case のうち詳細行を assert しているものを特定し、「dry-run 単体では詳細行が出ない」assert に書き換える (`assert_file_not_contains "Would create symlink:"` 相当)。
   - 新規 case を追加する: 「dry-run 単体は件数 summary のみ」「`--dry-run --verbose` は従来の詳細をすべて含む」「dry-run 単体でも planned 件数が正しい」「dry-run 単体でも conflict error は表示・停止する」。install と uninstall の両方に対して用意する。
   - RED を確認する。
3. `common.sh` を設計どおり変更する (`should_log_detail`, `log_would_link`, mode 通知文言)。
4. usage 文言 (`install.sh`, `uninstall.sh`) と top-level README の該当文 (Install 節の dry-run 説明) を新挙動に合わせて更新する。
5. GREEN を確認し、保存しておいた 4 mode 出力と比較して「`-v` / `-nv` / 指定なしの出力が変更前と一致し、`-n` 単体のみ詳細行が消えている」ことを確認する。
6. D2 / D3 を実施済みの場合は該当記述も更新する (未実施ならこの task の変更が反映された状態で書かれるため不要)。

### 受け入れ基準

- [x] `-n` 単体で個別の Would / Skip 行が出ず、件数 summary と Result は従来どおり出る。
- [x] `-nv` の出力が変更前の `-n` と同等 (mode 通知の文言差を除く)。
- [x] `-v` と指定なしの出力は変更前と一致する。
- [x] dry-run 非 verbose でも conflict 検出・manifest validation error は従来どおり表示され停止する。
- [x] usage / README の dry-run 説明が新挙動と一致する。
- [x] test-all.sh 全 PASS (更新・追加 case 含む)。

---

## R7: regression test の分割

- 優先度: 中 / 工数: 大 / 依存: R5, R6 (CI で守られた状態で行う) / 振る舞い: 非変更 (test 結果の意味を維持)
- 対象: `scripts/install/test-installer.sh` (1065 行) → `scripts/install/tests/` (新規構成)

### 目的

31 case が 1 file に詰まった構成を、case 単位の file + 共有 harness に分割し、case の追加・特定 case のみの実行を容易にする。

### 設計

外部 framework (bats-core) は採用しない。依存ゼロの現方針を維持し、hand-rolled harness を整理する。

```text
scripts/install/
  test-installer.sh          # 互換 entrypoint (harness を呼ぶだけに縮小)
  tests/
    harness.sh               # fixture 作成・assert 関数・PASS/FAIL 集計
    cases/
      10-install-basic.sh
      20-conflict.sh
      30-cleanup.sh
      40-uninstall.sh
      50-status.sh
      60-manifest-validation.sh
      70-cli-options.sh
      ...
```

### 作業手順

1. 現行 `test-installer.sh` を読み、31 case を列挙して上記分類へ割り当てる表を作る (実施記録に残す)。fixture 構築 helper と assert helper を特定する。
2. `tests/harness.sh` に helper を移設する。case file は「`run_case <名前> <関数>`」形式で harness に登録する規約とする。
3. case を **1 分類ずつ** 移設し、移設のたびに新旧両方を実行して PASS 数の合計が 31 のまま変わらないことを確認する。一括移設はしない。
4. `test-installer.sh` は `tests/` 配下を辞書順に source して全 case を実行する互換 entrypoint として残す。`--case <glob>` で実行 case を絞れる option を追加する (新機能だが test 専用のため可)。`--verbose` の既存挙動は維持する。
5. `test-all.sh` からの呼び出しが無変更で動くことを確認する。
6. D3 (development guide) のテスト節を新構成に合わせて更新する。

### 受け入れ基準

- [x] 全 31 case が新構成で PASS し、case 名の出力が従来と対応付く。
- [x] `bash scripts/install/test-installer.sh --case '60-*'` のような部分実行ができる。
- [x] 単一 file が 400 行を超えない。

---

## R8: manifest schema の重複削減 (振る舞い変更)

- 優先度: 中 / 工数: 大 / 依存: R7 (テスト追加が容易になってから) / 振る舞い: **変更あり** (schema 拡張)
- 対象: `scripts/install/lib/profile.sh`, `profiles/ecc/skipsets.tsv`, `profiles/ecc/surfaces.tsv`, テスト, D2 reference, README

### 目的

`skipsets.tsv` で同一の runtime-state pattern 群が 6 skipset にコピーされている重複 (約 120 行) を、skipset 合成機構で解消する。

### 設計

`skipsets.tsv` に `skipset-include` kind を追加する:

```text
skipset	common-runtime	logs
skipset	common-runtime	backups
skipset	common-runtime	cache
...
skipset-include	claude-root	common-runtime
skipset	claude-root	ecc
skipset	claude-root	projects
...
```

- 意味: `claude-root` は `common-runtime` の全 pattern を取り込み、固有 pattern を追記する。
- 検証規則: include 先の名前が定義済みであること (前方参照は invalid として file:line で停止)、自己 include・循環 include は invalid、include の重複は invalid。
- `surfaces.tsv` の dest 省略 (dest=source default) も候補だが、列位置 schema が崩れ validation が曖昧になるため**採用しない**。この判断を D2 reference に「dest は明示必須」と記載する。

### 作業手順

1. **テストを先に書く** (TDD): `60-manifest-validation` 系に「include が pattern を合成する」「未定義 include は file:line エラー」「循環 include はエラー」「include 重複はエラー」の case を追加し、RED を確認する。
2. `profile.sh` に `validate_skipsets_line` の `skipset-include` 分岐と、`add_skip_pattern` ベースの合成 (include 時に対象 skipset の既存 pattern をコピー、または参照解決) を実装する。実装は「読み込み時に展開してフラットな `SKIPSET_PATTERNS` に落とす」方式とし、`should_skip_entry` は無変更とする。
3. テスト GREEN を確認する。
4. `profiles/ecc/skipsets.tsv` を `common-runtime` (+ 必要なら `credential-state` など意味単位) を使う形に書き換える。**書き換え前後で skip 対象が完全一致することを機械的に検証する**: 一時 script で旧 / 新 manifest それぞれを load し、managed root 配下の実 entry 一覧に対する `should_skip_entry` の結果を比較する。
5. `bash install.sh --dry-run` の planned links / skips 件数が書き換え前と一致することを確認する。
6. D2 reference・README の schema 記述を更新する。

### 受け入れ基準

- [x] 新規 test case が GREEN、既存 31 case も PASS。
- [x] 旧新 manifest の skip 判定が全 entry で一致した証跡 (比較 script の出力) を実施記録に残す。
- [x] `skipsets.tsv` の行数が概ね半減する。
- [x] reference / README が新 schema を反映している。

---

## R9: detached HEAD / branch 不明時の警告 (振る舞い変更)

- 優先度: 低 / 工数: 小 / 依存: なし / 振る舞い: **変更あり** (警告出力の追加)
- 対象: `scripts/install/lib/profile.sh` (`load_active_profile_manifests`), `install.sh` 系出力, テスト

### 目的

`get_current_branch` が空 (detached HEAD 等) のとき、現在は profile 読み込みが無言で skip され、ECC profile branch を detached で checkout した場合に preflight なしで「profile なし install」が走り得る。これを明示的な警告にする。

### 作業手順

1. `load_active_profile_manifests` / `run_active_profile_install_checks` の branch 空時に `log_step "Warn: current branch is unknown (detached HEAD?); no profile will be applied"` を出す (exit はしない。`main` 相当の素の install は許容する)。
2. detached HEAD fixture での test case を追加する (fixture repo で `git checkout --detach` し、警告文言と「profile が適用されないこと」を assert)。
3. README の Installer Flow 節に 1 行追記する。

### 受け入れ基準

- [x] detached HEAD で警告が出て、install 自体は profile なしで完走する。
- [x] 新 test case GREEN、既存全 PASS。

---

## R10: `set -u` の段階的導入

- 優先度: 低 / 工数: 中 / 依存: R1〜R3 完了後 / 振る舞い: 非変更 (バグがなければ)
- 対象: 3 entrypoint, `scripts/install/lib/*.sh`

### 目的

未定義変数参照を実行時に検出する。`profiles/ecc/bin/check-local-state.sh` は既に `set -u` を採用しており、installer 本体と方針が割れている。

### 作業手順

1. entrypoint 先頭 (guard 直後) に `set -u` を追加する。`set -e` / `set -o pipefail` は導入しない (既存のエラーハンドリング設計と衝突するため。理由を comment で明記)。
2. test-all.sh 全 mode (通常 / dry-run / verbose / help / 不明 option) を実行し、unbound variable エラーを潰す。既存 code は `${VAR:-default}` を多用しているため影響は小さい見込みだが、空配列展開 (`"${ARRAY[@]}"` は bash 4.4+ で安全) の動作を WSL の bash version で確認する。
3. CI (ubuntu-latest の bash) でも green を確認する。

### 受け入れ基準

- [x] 全 entrypoint が `set -u` 下で全 test PASS。
- [x] `set -e` 不採用の理由が code comment 化されている。

---

## R4: common.sh の分割 (任意)

- 優先度: 低 (任意) / 工数: 小 / 依存: R2, R3 / 振る舞い: 非変更
- 対象: `scripts/install/lib/common.sh` (397 行)

R2 / R3 で summary 系が整理された後、`common.sh` を `log.sh` (色・log 関数) と `common.sh` (state・path・manifest 行 helper) に分けるか判断する。**分割は 2 file まで**とし、それ以上の細分化はしない。R2 / R3 後に common.sh が 450 行を下回っているなら分割せず、判断を実施記録に残して完了としてよい。
