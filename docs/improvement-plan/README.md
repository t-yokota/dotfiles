# Dotfiles Improvement Plan

- Last reviewed: 2026-06-11
- Baseline branch: `profile/ecc/full/home-9M2KERO` (assessment 時点)
- Baseline verification: `bash scripts/install/test-all.sh` → installer regression 31/31 PASS, ECC profile smoke test PASS

この directory は、dotfiles repository 全体の改善計画を、**他の AI agent が単独で実行を引き継げる指示書**として整備したものです。各計画書は task 単位で「目的 / 現状 / 作業手順 / 受け入れ基準 / 検証方法」を持ち、この README が全体の前提・実行規則・依存関係を定義します。

## 計画書の構成

| Document | 内容 |
|---|---|
| [01-documentation.md](01-documentation.md) | ドキュメント品質向上計画 (D-task 群) |
| [02-refactoring.md](02-refactoring.md) | コード全体のリファクタリング計画 (R-task 群) |
| [03-roadmap.md](03-roadmap.md) | リファクタリング反映後の実装タスク再計画 (Phase / F-task 群) |

Task ID は計画全体で一意です (`D1`, `R3`, `F2` など)。依存関係は各 task の `依存:` 行と 03-roadmap.md の Phase 順序で表します。

## 現状評価 (2026-06-11 時点)

実行を引き継ぐ agent は、まずこの評価を前提として読みます。**このリポジトリは健全な状態にあり、本計画は「壊れたものの修理」ではなく「良い基盤の発展」です。**

### 資産インベントリ

```text
install.sh / uninstall.sh / status.sh   共通 installer entrypoint (157 / 117 / 88 行)
scripts/install/lib/
  common.sh    (397行)  log・color・summary counter・path helper
  profile.sh   (479行)  profile manifest loader / validator / check runner
  reconcile.sh (470行)  conflict check・cleanup・symlink 作成 engine
  status.sh    (440行)  read-only link status 照合
scripts/install/
  test-all.sh       (202行)  一括 verification runner
  test-installer.sh (1065行) installer regression test (31 case)
  test-profile.sh   (304行)  profile smoke test 共通 runner
profiles/ecc/
  profile.tsv / surfaces.tsv / skipsets.tsv  ECC profile manifest
  checks.d/10-local-state.sh                 branch-specific preflight check
  bin/check-local-state.sh (342行) / write-codex-sync-state.sh (198行) / test-profile.sh (20行)
docs/
  ecc-application-map.md         ECC × Claude/Codex 配置対応 map
  ecc-dotfiles-manual-install.md ECC manual install 手順書 (646行)
README.md (296行)
.claude/ .codex/ .agents/   managed root (ECC installer / sync の生成物が主体)
.zshrc .vimrc .gitconfig my.zsh-theme   top-level dotfiles
archive/   旧 .bashrc / .inputrc
```

### 強み (維持すべき性質)

- **安全性設計**: 未管理ファイルを上書きしない、cleanup はこの checkout を指す symlink のみ、dry-run 完備。README「Safety Rules」に明文化済み。
- **テスト**: 31 case の regression test + profile smoke test が実 HOME を触らず `/tmp` fixture で動作し、全 PASS。
- **manifest 検証**: TSV manifest の typo・壊れた行・managed root 逸脱を symlink 作成前に file:line 付きで停止。
- **責務分離**: entrypoint / lib / profile 資産 / docs の境界が明確。
- **ドキュメント**: README と docs/ 2 本が背景・手順・図 (mermaid) を備える。

### 弱み (本計画で対処する点)

1. **entrypoint 重複**: `install.sh` / `uninstall.sh` / `status.sh` が bash guard・option parsing・bootstrap をほぼ同文でコピーしている (約 60 行 × 3)。
2. **logging と counting の混在**: `log_step` / `log_substep` が `Skip:` プレフィックスを見て summary counter を増やす副作用を持つ。出力文言の変更が件数計上を壊し得る。また `should_log_detail` が `is_verbose || is_dry_run` であるため dry-run と verbose の軸が結合しており、dry-run では常に詳細ログが出る (`log_would_link` は gating なし)。
3. **section summary の before/after パターン重複**: `install.sh` 内で「カウンタ退避 → 実行 → 差分計算 → log_ok」が 4 回コピーされている。
4. **skipsets.tsv の重複**: 同じ runtime-state pattern 群 (`logs`, `backups`, `cache`, `*.log`, `*.sqlite*` など) が 6 つの skipset にコピーされ、約 120 行が実質同内容。
5. **test-installer.sh の単一巨大ファイル**: 1065 行・31 case が 1 file。case 追加時の見通しが悪い。
6. **lint / CI 不在**: shellcheck・CI workflow がなく、regression test の実行が手動運用。
7. **README の多役化**: quickstart・アーキテクチャ・manifest schema reference・roadmap が 1 file に同居 (296 行)。
8. **docs/ の索引・規約不在**: docs index がなく、`Last reviewed` 規約も暗黙。installer 開発者向けガイド (テストの増やし方・bash 規約) が存在しない。
9. **detached HEAD 時の silent skip**: `get_current_branch` が空を返すと profile 読み込みが無言で skip される。
10. **top-level dotfiles の鮮度**: `.zshrc` は oh-my-zsh stock template のコメントが大半 (148 行中実効 32 行)。
11. **単一 working tree の二役問題**: `~/dotfiles` が「HOME symlink の実体」と「branch を切り替える編集場所」を兼ねるため、`main` へ checkout すると適用中 profile の symlink が dangling になり、その状態で `install.sh` を実行すると prune される。対策として**案A (作業用 worktree 分離) を本計画の正式運用とする** (F6)。`main` などでの作業は `git worktree` で repo 外の作業 directory に出し、`~/dotfiles` 本体は適用中 profile branch に常駐させる。将来の構造的解決 (案B: deploy worktree) は F7 で設計する。

## 実行規則 (全 task 共通)

実行を引き継ぐ agent は、すべての task で以下を厳守します。

### 検証

- 変更前後で必ず `bash scripts/install/test-all.sh` を実行し、全 PASS を確認する。
- installer の挙動変更を含む task は、`bash install.sh --dry-run` と `bash status.sh` で実 HOME に対する差分が意図通りか確認する (どちらも read-only / 書き込みなし)。
- 実 HOME (`$HOME`) を直接変更する検証は行わない。検証は `/tmp` fixture (`test-installer.sh` / `test-profile.sh` の仕組み) で行う。

### 安全規則 (README「Safety Rules」の維持)

- 未管理の通常ファイルを上書きする挙動を導入しない。
- cleanup / uninstall の対象を「この dotfiles checkout を指す symlink」より広げない。
- `entries` surface の link 先 directory・`whole` surface の親 directory は通常 directory であることを要求し続ける。
- credential・cache・runtime state を commit 対象にしない (`.gitignore` と skipsets.tsv の両方で enforce)。

### branch 配置と worktree 運用 (案A)

- 共通 installer (`install.sh`, `scripts/install/`)・共通 docs・top-level dotfiles の変更は **`main` に commit** し、`profile/ecc-base` → `profile/ecc/*` へ merge で降ろす。
- ECC profile 資産 (`profiles/ecc/`) の変更は **`profile/ecc-base`** に commit する。
- 環境固有の生成物 (`.claude/` 配下の ECC output 更新など) は **`profile/ecc/*`** のみ。
- この improvement-plan 自体も共通 docs なので、最終的には `main` に置く。
- **`~/dotfiles` 本体の checkout branch は適用中の profile branch から切り替えない。** `main` / `profile/ecc-base` への commit 作業は `git worktree add ~/dotfiles-worktrees/<branch> <branch>` で作った repo 外の worktree 上で行う (F6 で正式 docs 化。詳細・復旧手順は [03-roadmap.md](03-roadmap.md) の F6 を参照)。`DOTPATH` を worktree に向けて `install.sh` を実行することは禁止。
- worktree 側で積んだ変更を適用環境へ反映する場合は、`~/dotfiles` 本体で適用 branch に乗ったまま merge し (例: `git merge profile/ecc-base`)、tracked desired state が変わったら `bash install.sh` を再実行する。

### 変更してはならないもの

- `.claude/` `.codex/` `.agents/` 配下の **ECC installer / sync 生成物** (agents, commands, skills, rules, hooks, prompts など)。これらは ECC upstream からの生成物であり、手で編集すると再生成時に失われる。手動 baseline として管理しているのは `.claude/CLAUDE.md`, `.claude/settings.json`, `.codex/config.toml` のみ。
- ignore 済みの local state (`.gitconfig.local`, install-state, sync marker, backups)。

### コーディング・ドキュメント規約

- shell script は Bash 前提。既存の style (4 space indent, `local` 宣言, `[ ]` test, 関数 1 責務, 明示的 `|| return 1` / `|| exit 1` によるエラー伝播) を踏襲する。`set -e` は採用しない (既存設計は明示的エラーハンドリング方針)。
- docs は日本語本文 + 英語技術用語の既存スタイル。emoji 不使用。各 doc 冒頭に `Last reviewed: YYYY-MM-DD` を付ける。
- commit は conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`)。1 task 1 commit を基本とし、振る舞いを変えない refactor と振る舞い変更を同一 commit に混ぜない。
- 出力メッセージ (log 文言) を変更する場合、`test-installer.sh` が文言を assert している箇所を確認し、テストも同時に更新する。

## 全体の進め方

詳細は [03-roadmap.md](03-roadmap.md)。要約すると:

1. **Phase 0 — ガード整備**: worktree 運用 (F6, 案A) を最初に確立して `main` 作業を安全にし、lint (shellcheck) と CI を入れて以後の変更を自動検証下に置く。
2. **Phase 1 — コードリファクタリング**: テストが緑のうちに entrypoint 重複・logging 副作用・dry-run/verbose 結合・テスト分割を解消する。
3. **Phase 2 — manifest schema 進化**: skipset 共通化と surface 定義の簡素化。振る舞い変更を含むため Phase 1 完了後。
4. **Phase 3 — ドキュメント再構成**: schema が確定した後に README 分割・reference 整備・developer guide 作成を行う (二度書きを避ける)。
5. **Phase 4 — 機能拡張**: 既存 Future Work (Claude/Codex 選択適用、main↔profile 同期補助) と新規機能 (profile scaffolding)。F2 の運用経験を入力として、案B (deploy worktree) への移行設計を F7 で行う (設計のみ。実装可否はその時点で判断)。
6. **Phase 5 — 周辺整理**: top-level dotfiles の刷新、archive 整理、ECC upstream 更新チェック。
