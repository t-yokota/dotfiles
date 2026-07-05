# ドキュメント品質向上計画 (D-tasks)

- Last reviewed: 2026-07-06
- 前提: [README.md](README.md) の実行規則を先に読むこと

この計画書は、dotfiles のドキュメント群を「読者別に分割され、索引と鮮度規約を持ち、コードと同期している」状態へ引き上げるための task 群です。

## 設計方針

現状の問題は量ではなく構造です。README (296 行) が quickstart・アーキテクチャ・manifest schema reference・roadmap を兼ね、`ecc-dotfiles-manual-install.md` (646 行) が初回 setup と運用 lifecycle を兼ねています。読者を次の 4 類型に分け、文書を対応させます。

| 読者 | 知りたいこと | 対応文書 (改善後) |
|---|---|---|
| 新しい環境で適用したい自分 | 最短の install 手順 | README (縮小版), ecc-dotfiles-manual-install.md (setup 部) |
| profile を設計・変更する自分 | manifest schema・check の仕様 | docs/reference/profile-manifest.md (新規) |
| installer 自体を変更する agent / 自分 | lib 構成・テストの増やし方・規約 | docs/development.md (新規) |
| 運用中にトラブルに遭った自分 | uninstall / regenerate / 状態診断 | docs/ecc-dotfiles-lifecycle.md (分離), status 分類 reference |

**実施順の注意**: D2 (schema reference) は Phase 2 の manifest schema 変更 (R8) と密結合です。R8 を実施する場合は R8 完了後に D2 を書くこと。R8 を見送る場合は現行 schema で書いてよい。それ以外の D-task は独立して着手可能です。

## 実施記録 (2026-06-14)

commit hash は未作成です。最終 commit 作成時に D7 の規則に従って追記します。

| Task | 状態 | 証跡 |
|---|---|---|
| D1 | 完了 | `docs/README.md` を追加し、docs index、鮮度規約、由来規約を明文化。 |
| D2 | R8 連動更新済み | `docs/reference/profile-manifest.md` を追加し、R8 の `skipset-include` schema と manifest の主要規則を反映。D2 の詳細な error catalog / reference 完全化は Phase 3 の継続対象。 |
| D3 | 完了 | `docs/development.md` を追加し、installer architecture、bash 規約、test 追加手順、変更チェックリストを文書化。 |
| D5 | 完了 | `docs/reference/status-classification.md` を追加し、`status.sh` の 6 分類と対処方法を実装準拠で文書化。 |
| D6 | 部分完了 | README を 143 行へ縮小し、詳細仕様を `docs/README.md` / reference / roadmap へ誘導。profile 専用 lifecycle 文書へのリンクは D4 実施後に profile branch 側で反映する。 |

## 実施記録 (2026-07-06)

| Task | 状態 | 証跡 |
|---|---|---|
| D8-1 | 完了 | 指摘 1: 作業中だった top-level README の再構成と `docs/development.md` の profile 作成手順を main へ commit。leaf 固有の `.claude/settings.json` / `.codex/config.toml` は leaf へ commit。指摘 2-3: `worktree-workflow.md` から task ID「F6」参照を除去し、見出しを英語へ統一、作業ログ調の「F6 Verification」節を削除 (検証事実は 03-roadmap の F6 受け入れ基準に記録済み)。指摘 4: 文中 `<br>` は top-level README の 3 箇所のみ残存しており段落分けへ置換。`ecc-application-map.md` / `ecc-dotfiles-manual-install.md` の `<br/>` は mermaid label 内のみで対象なし。指摘 5: `ecc-application-map.md` の cross-link を lifecycle 分離後の構成へ更新し日付を更新 (base 側 commit)。指摘 6: 内容変更した計画文書の `Last reviewed` を 2026-07-06 へ更新。指摘 7: F5 手順 3 に D1 反映済みの注記を追加。 |
| D8-2 | 未着手 | F7 完了後に実施。 |

---

## D1: docs 索引と鮮度規約の導入

- 優先度: 高 / 工数: 小 / 依存: なし
- 対象: `docs/README.md` (新規), 既存 docs 全部の冒頭

### 目的

docs/ に何があり、どれが手書きでどれが生成物由来か、いつ見直されたかを 1 箇所で判定できるようにする。

### 現状

- `docs/` に索引がない。文書は 2 本だが、本計画で増える。
- `Last reviewed` 記載は `ecc-application-map.md` と `ecc-dotfiles-manual-install.md` にあるが規約化されていない。
- `.claude/README.md` や `.claude/PLUGIN_SCHEMA_NOTES.md` は ECC 生成物であり編集禁止だが、その旨がどこにも書かれていない。

### 作業手順

1. `docs/README.md` を新規作成し、次を含める:
   - docs 配下の全文書の一覧表 (文書名 / 1 行説明 / 主読者 / 由来: 手書き or 計画文書 or reference)。
   - 鮮度規約: 「全 docs は冒頭に `Last reviewed: YYYY-MM-DD` を持つ。内容に影響する変更を入れた commit で日付を更新する」。
   - 由来規約: 「`.claude/`, `.codex/`, `.agents/` 配下の README・notes 類は ECC 生成物であり dotfiles 側では編集しない。dotfiles 側で手書き管理する文書は `docs/` と top-level `README.md` のみ」。
2. `docs/ecc-application-map.md`, `docs/ecc-dotfiles-manual-install.md` の `Last reviewed` 表記をこの規約の形式に揃える (既にほぼ準拠。書式だけ統一)。
3. top-level `README.md` の `docs/` の説明行から `docs/README.md` へのリンクを張る。

### 受け入れ基準

- [x] `docs/README.md` が存在し、docs 配下の全 `.md` (improvement-plan 含む) が表に載っている。
- [x] 鮮度規約と由来規約が明文化されている。
- [x] 全 docs の冒頭 3 行以内に `Last reviewed:` がある。

### 検証

```bash
grep -L "Last reviewed" docs/*.md docs/improvement-plan/*.md   # 出力が空であること
```

---

## D2: profile manifest schema reference の分離

- 優先度: 高 / 工数: 中 / 依存: R8 を実施する場合は R8 の後
- 対象: `docs/reference/profile-manifest.md` (新規), top-level `README.md` (縮小)

### 目的

manifest の正確な仕様 (列定義・検証規則・エラー条件) を、README の散文から独立した reference に昇格させる。profile を作る・直す agent が README 全体を読まずに済むようにする。

### 現状

`README.md` の「Profile Manifest Schema」「Managed Dotfile Surfaces」「Branch-Specific Checks」節に仕様が散文で書かれている。一方、実際の検証規則は `scripts/install/lib/profile.sh` にあり、README に書かれていない規則も実装されている (例: profile.tsv の `surfaces`/`skipsets`/`checks` の重複禁止、check script の filename 規約 `check-*.sh|[0-9][0-9]-*.sh`、surface の source/dest が managed root 配下必須、`..`・絶対 path 禁止)。

### 作業手順

1. `scripts/install/lib/profile.sh` の全 `validate_*` 関数と `run_active_profile_install_checks` を読み、実装上の検証規則を完全に列挙する。
2. `docs/reference/profile-manifest.md` を新規作成し、次の構成で書く:
   - `profile.tsv`: 列定義表、`branch` の glob 照合仕様 (`[[ == ]]` の shell glob)、省略時 default (`surfaces.tsv` / `skipsets.tsv` / `checks.d`)、重複禁止規則。
   - `surfaces.tsv`: 6 列の定義表、`entries` / `whole` の挙動差、source/dest の解決規則 (DOTPATH / HOME 相対)、managed root 制約、child surface の implicit skip 挙動 (`should_defer_to_child_surface_entry`)。
   - `skipsets.tsv`: `skipset` / `skipset-include` の列定義表、pattern の glob 仕様、`none` の意味、include の検証規則。
   - `checks.d/`: 実行順 (glob 辞書順)、filename 規約、check script に渡る環境変数 (`DOTPATH`, `DOTFILES_BRANCH`)、非 0 終了で install が停止すること。
   - エラー一覧: `manifest_error` の発生条件を「file:line 形式で停止する」例とともに列挙。
3. top-level `README.md` の該当節を要約 + reference へのリンクに置き換える。README に残すのは「surface とは何か」「entries/whole の使い分けの考え方」の概念説明まで。
4. `docs/README.md` (D1) の索引に追加する。

### 受け入れ基準

- [x] reference に書かれた全規則が `profile.sh` の実装と一致する (実装に無い規則を書かない・実装にある規則を漏らさない)。
- [x] README の schema 節が概念説明 + リンクに縮小され、列定義の重複記載がない。
- [x] `bash scripts/install/test-all.sh` が全 PASS (コード変更はないが確認する)。

### 検証

reference の各規則について、`test-installer.sh` の対応 test case 名を脚注として付記できること (検証規則とテストの対応が取れていることの確認)。対応 test が無い規則を見つけた場合は R7 (テスト分割) の TODO として記録する。

---

## D3: installer developer guide の新規作成

- 優先度: 高 / 工数: 中 / 依存: R1〜R3 実施後に書くのが理想 (構成が変わるため)。先行する場合は R-task 完了時に更新必須
- 対象: `docs/development.md` (新規)

### 目的

installer 自体を変更する agent / 人間向けに、lib 構成・規約・テストの増やし方を文書化する。現状この知識は code comment と git history にしかない。

### 作業手順

1. `docs/development.md` を新規作成し、次を含める:
   - **アーキテクチャ**: entrypoint → lib 読み込み → phase 実行の流れ。`init_installer_state` が初期化する global state 一覧 (`MANAGED_SURFACES`, `MANAGED_SURFACE_MANIFESTS`, `SKIPSET_PATTERNS`, `SKIPSET_INCLUDES`, `KNOWN_SKIPSETS`, `RESERVED_ROOT_ENTRIES`, `ACTIVE_PROFILE_CHECK_DIRS`) と各 lib の責務境界 (common: policy なし helper / profile: manifest 読込と検証 / reconcile: HOME への書き込み全部 / status: read-only 照合)。
   - **bash 規約**: Bash 前提 guard、`set -e` 不採用と明示的 `|| return 1` 方針、4 space indent、`local` 必須、log 関数の契約 (`log_step` のプレフィックス分岐、verbose / dry-run 時のみ出る `log_substep`)。
   - **テストの増やし方**: regression test の case の書き方 (fixture 作成 → 実行 → assert のパターン)、`test-all.sh` / `test-installer.sh` / `test-profile.sh` の役割分担、実 HOME を絶対に触らない原則。R7 実施後は新しい test 構成に合わせる。
   - **変更時のチェックリスト**: log 文言変更時はテストの文言 assert を同時更新、manifest schema 変更時は validate + テスト + D2 reference + README の 4 点同時更新、新しい安全規則は README「Safety Rules」にも反映。
2. `docs/README.md` 索引へ追加。

### 受け入れ基準

- [x] guide のみを読んだ状態で「新しい regression test case を 1 つ追加する」手順が一意に辿れる。
- [x] global state 一覧と lib 責務が実装と一致している。

---

## D4: ecc-dotfiles-manual-install.md の lifecycle 分離

- 優先度: 中 / 工数: 中 / 依存: なし
- 対象: `docs/ecc-dotfiles-manual-install.md` (縮小), `docs/ecc-dotfiles-lifecycle.md` (新規)

### 目的

「新しい環境への初回 install」(読者: setup 中の自分) と「uninstall / regenerate / 更新の運用」(読者: 運用中の自分) を分け、それぞれを短くする。

### 現状

646 行の単一文書。section 1〜11 が setup、section 12〜13 が lifecycle と運用注意。初回 setup 時に lifecycle は読む必要がなく、逆に regenerate 時に setup 全文を再走査することになる。

### 作業手順

1. `docs/ecc-dotfiles-lifecycle.md` を新規作成し、現行文書の section 12 (Uninstall / Regenerate 手順) と section 13 (運用上の注意点) を移設する。冒頭に変数定義 (`DOTPATH`, `ECC_REPO`) を自己完結で再掲する (現行 section 12 が既にこの形を取っているのでそのまま活かす)。
2. ECC upstream の version 更新時の再取り込み手順を、現行各節 (Codex sync regenerate / skills bundle update / Claude installer regenerate) の記述を束ねる形で「Update from upstream ECC」節として lifecycle 側に新設する。新規の手順を発明せず、既存記述の再構成に留める。
3. 元文書は setup までで完結させ、末尾に lifecycle 文書へのリンクを置く。冒頭の Setup checklist は元文書に残す。
4. 両文書の `Last reviewed` を更新し、`docs/README.md` 索引と `docs/ecc-application-map.md` 内の相互リンクを更新する。

### 受け入れ基準

- [ ] 元文書から lifecycle 内容が消え、リンクで辿れる。
- [ ] 移設で手順・コマンド・警告 (特に git hooks の実 HOME 有効化に関する注意) が 1 つも欠落していない。移設前後で `git diff` を取り、削除行がすべて新文書に存在することを確認する。
- [ ] 両文書とも単独で変数定義から手順が再現可能。

---

## D5: status 分類 reference の作成

- 優先度: 中 / 工数: 小 / 依存: なし
- 対象: `docs/reference/status-classification.md` (新規) または D2 reference への併載

### 目的

`status.sh` が出力する linked / missing / conflict / stale / orphaned / skipped の各分類について、判定条件と推奨対処を表で定義する。現状 README に名前しか出てこない。

### 作業手順

1. `scripts/install/lib/status.sh` を読み、各分類の判定条件を実装から正確に抽出する。
2. 分類ごとに「意味 / 判定条件 (実装準拠) / 起きる典型シナリオ / 推奨対処 (install.sh 再実行、手動退避、uninstall など)」の表を作る。
3. README の `status.sh` 説明からリンクする。

### 受け入れ基準

- [x] 6 分類すべてが実装準拠の条件で記載されている。
- [x] 各分類に対処方法が書かれている。

---

## D6: README のスリム化と roadmap 分離

- 優先度: 中 / 工数: 小 / 依存: D2, D5 (リンク先が先に存在すること), 03-roadmap 確定後
- 対象: top-level `README.md`, `docs/improvement-plan/03-roadmap.md`

### 目的

README を「概念 + quickstart + 各文書への入口」に絞る。

### 作業手順

1. 「Future Work」節を削除し、[03-roadmap.md](03-roadmap.md) への参照に置き換える (roadmap の実体は improvement-plan 側で管理する)。
2. D2 で schema 節を、D5 で status 分類の詳細をそれぞれ reference へ移した後の README 全体を通読し、重複・矛盾を解消する。
3. 目次 (見出しリンク) を冒頭に追加する。

### 受け入れ基準

- [x] README が 200 行以下になる。
- [ ] README から docs/README.md・reference 群・lifecycle 文書へすべてリンクが張られている。
- [ ] 削除した情報はすべて移設先に存在する (消失なし)。

---

## D7: 計画文書群の保守規約

- 優先度: 低 / 工数: 小 / 依存: なし (本計画の運用ルール)
- 2026-07-06 改訂: Phase 0〜3 の実運用に合わせて記録方式を「文書冒頭の実施記録表 + 受け入れ基準の checkbox」に一本化する。旧規則の「task 見出しへの (完了: 日付, commit) 追記」は廃止する。

improvement-plan 配下の文書は、task 完了時に次を行う:

1. 各計画書冒頭の「実施記録」表に task の状態と証跡 (実行コマンド・件数・run ID など) を追記し、受け入れ基準の checkbox を更新する。commit hash は commit 作成後に表へ補記する。
2. 実施中に判明した計画との乖離 (やらなかったこと・追加でやったこと・計画自体の変更) も同じ実施記録に残す。
3. 全 Phase 完了後、この improvement-plan は `docs/archive/` へ移動し、恒久的な内容 (規約・reference) は通常 docs へ昇格済みであることを確認する。

---

## D8: ドキュメント整備パス (文体・語彙・鮮度の統一)

- 優先度: 高 / 工数: 中 / 依存: 前半 (D8-1) はなし。後半 (D8-2) は F7 完了後
- 対象: `docs/` 配下の全手書き文書、top-level `README.md`
- 背景: Phase 0〜3 で docs は 2 本から 12 本へ増えた。個々の文書の内容は正確だが、複数の agent / 時期に書かれたため文体・見出し・語彙が揃っていない。**文体の基準は top-level `README.md` の現行の書き方とする** (筆者が通読・調整済みの文書であるため)。

### 文体基準 (top-level README から抽出)

他文書を整備するとき、次を README の現行文体の要点として適用する:

1. 見出しは英語、本文は日本語 + 英語技術用語。文末は「〜します」体。
2. `<br>` による文の連結は使わず、通常の段落分けにする。
3. 段落は「何をするか → なぜそうするか → 詳細への参照」の順で完結させる。コマンド例の前には目的を 1 文置く。
4. 役割の列挙は表 (`| Path | Role |` 形式) を使い、表のセルには説明を詰め込みすぎず、補足は前後の段落に書く。
5. 詳細は reference / 手順書へリンクで誘導し、同じ仕様を 2 箇所に書かない。

### D8-1: F7 に依存しない文書の整備 (今すぐ着手可)

今回のレビュー (2026-07-06) で確認した個別の指摘。各文書の修正時に `Last reviewed` を更新する。

1. **未コミット変更の完了を先行させる**: top-level `README.md` (staged + unstaged) と `docs/development.md` の作業中変更は文体基準そのものなので、まずこの編集を完了・commit してから他文書に着手する。`.claude/settings.json`, `.codex/config.toml` の未コミット変更も所属 branch (leaf) を確認して commit または退避する。
2. **計画語彙の漏出を除去する**: `docs/worktree-workflow.md` が本文で計画 task ID「F6」を 2 回参照している。恒久文書は improvement-plan の task ID に依存しない記述に改める (例: 「F6 が避けるのは〜」→「この運用が避けるのは〜」)。「F6 Verification」節は作業ログ調 (「2026-06-13 時点で〜検証対象にしています」) なので、検証事実は 02/03 の実施記録へ移し、本文からは節ごと削除するか、恒久的な記述 (「この運用は worktree 内から test-all.sh を実行できることを前提とし、検証済みです」程度) に置き換える。
3. **見出し言語の統一**: `docs/worktree-workflow.md` は日本語見出し (「背景」「運用規則」) と英語見出し (「Command Examples」「Recovery」) が混在している。文体基準 1 に従い英語見出しへ統一する (例: Background / Rules / Command Examples / Merge Back To Active Profile / Recovery)。他文書も同様に点検する。
4. **`<br>` の点検**: `docs/ecc-application-map.md`, `docs/ecc-dotfiles-manual-install.md` に旧 README 由来の `<br>` 連結が残っていないか点検し、残っていれば段落分けへ置き換える。表のセル内の改行用途は許容する。
5. **ecc-application-map.md の鮮度確認**: `Last reviewed: 2026-05-30` のまま D4 (lifecycle 分離) 以降の再確認がされていない。lifecycle 文書への cross-link、manual-install の section 番号参照、ECC version 表記が現状と合っているか通読・確認して日付を更新する。
6. **Last reviewed と内容の乖離解消**: `03-roadmap.md` は Phase 再構成 (F7 昇格) 後も日付が古い。内容を変更した計画文書の日付を揃える。
7. **F5 との重複整理**: `docs/README.md` の「Related Reference」節に archive の非適用説明が既にあり、F5 手順 3 と重複している。F5 側の該当手順を「実施済み」として実施記録に注記する。

### D8-2: F7 完了後の再整備

F7 (案B 移行) は `docs/worktree-workflow.md`・top-level README の運用記述・`docs/ecc-dotfiles-manual-install.md` の適用手順を書き換える。F7 完了直後に次を行う:

1. worktree 関連の記述 (本体常駐・DOTPATH 禁止事項・復旧手順) を案B の構造に合わせて全面改訂し、案A 時代の記述が「歴史」としてではなく現行仕様として残らないようにする。
2. F7 の設計文書 (`design/deploy-worktree.md`) のうち恒久的に参照される内容 (deploy 操作の仕様、rollback 手順) を通常 docs へ昇格し、設計文書は計画付属の記録として D7 の archive 対象に含める。
3. `docs/README.md` 索引に新規・改訂文書を反映する。
4. D8-1 の文体基準で新規文書を点検する。

### 受け入れ基準

- [ ] (D8-1) docs 配下の恒久文書に improvement-plan の task ID への依存が残っていない。
- [ ] (D8-1) 全手書き文書の見出し言語・文体が文体基準に沿っている。
- [ ] (D8-1) 全文書の `Last reviewed` が最終内容変更と整合している。
- [ ] (D8-1) 上記指摘 1〜7 それぞれの対応 (実施 or 対象なしの確認) が実施記録に残っている。
- [ ] (D8-2) F7 後の worktree / deploy 関連文書が現行仕様のみを記述している。
- [ ] 文書の変更のみで、コード・テスト・manifest への変更がない (あれば別 task に切り出す)。
