# 実装タスク再計画 (Roadmap)

- Last reviewed: 2026-06-14
- 前提: [README.md](README.md) の実行規則、[01-documentation.md](01-documentation.md)、[02-refactoring.md](02-refactoring.md)

この計画書は、リファクタリング (R-tasks)・ドキュメント (D-tasks)・機能拡張 (F-tasks) を依存関係順に統合した実行 roadmap です。top-level README の旧「Future Work」(ECC profile の Claude/Codex 選択適用、main↔profile 同期補助) は F1 / F2 としてここに吸収します。

## Phase 構成と実行順

```text
Phase 0  ガード整備            F6 worktree運用 → R5 lint → R6 CI → D1 docs索引
Phase 1  振る舞い非変更リファクタ R1 → R2 → R3 → R11 → R7 (並行可: R9, R10) (任意: R4)
Phase 2  manifest schema 進化   R8
Phase 3  ドキュメント再構成      D3 → D2 → D5 → D4 → D6
Phase 4  branch反映と案B移行   main/profile/ecc-base反映 → F7 (案B 移行)
Phase 5  機能拡張              F1 → F3 → F2
Phase 6  周辺整理              F4, F5, D7 (計画文書の archive)
```

原則:

- **Phase 0 を最初に完了させる。** 以後のすべての変更が CI で守られる。特に F6 (worktree 運用) は最初に確立する: 本計画の commit の多くは `main` 宛てであり、F6 なしで `~/dotfiles` 本体を `main` へ checkout すると適用中 profile の runtime surface が壊れる (詳細は F6 の背景を参照)。
- **branch 切り替えの運用は案A (作業用 worktree 分離) を現在の正とする。** `~/dotfiles` 本体は適用中の profile branch に常駐させ、`main` などでの作業は worktree で行う。リファクタリングが問題ないことを確認し、内容を `main` / `profile/ecc-base` / leaf branch へ反映したら、次 task は案B (deploy worktree) への移行とする。
- **profile の考え方は `main` でも理解できる状態にする。** `main` は concrete な ECC profile 資産を持たなくても、dotfiles の思想、profile branch 戦略、managed root / surface / manifest schema、worktree 運用、installer 開発規約を共通 docs として持つ。ECC 固有の manifest・manual・生成物は `profile/ecc-base` 以降で管理する。
- Phase 1 の R1→R2→R3 は順序依存。R7 は R1〜R3 と独立だが、R8 より先に終えること (R8 はテスト追加を前提とするため)。
- Phase 3 は Phase 2 完了後に行う (schema reference の二度書き防止)。ただし D1 (索引) と D3 (developer guide) の骨子は先行してよい。
- 各 Phase 完了時に `bash scripts/install/test-all.sh` 全 PASS + CI green + 実 HOME での `bash install.sh --dry-run` / `bash status.sh` 無異常を確認してから次へ進む。

## Task 一覧

| ID | 内容 | Phase | 優先度 | 工数 | 依存 | 振る舞い変更 |
|---|---|---|---|---|---|---|
| F6 | worktree 運用の導入 (案A) | 0 | 最高 | 小 | - | なし (運用変更) |
| R5 | shellcheck / lint 導入 | 0 | 最高 | 小〜中 | - | なし |
| R6 | CI workflow 導入 | 0 | 最高 | 小 | R5 | なし |
| D1 | docs 索引・鮮度規約 | 0 | 高 | 小 | - | - |
| R1 | entrypoint bootstrap 共通化 | 1 | 高 | 中 | R5,R6 | なし |
| R2 | section summary scope 共通化 | 1 | 中 | 小 | R1 | なし |
| R3 | logging / counting 分離 | 1 | 中 | 中 | R2 | なし |
| R11 | dry-run と verbose の分離 | 1 | 中 | 中 | R3 | あり (dry-run 既定出力の簡潔化) |
| R7 | regression test 分割 | 1 | 中 | 大 | R5,R6 | なし |
| R9 | detached HEAD 警告 | 1 | 低 | 小 | - | あり (警告追加) |
| R10 | `set -u` 導入 | 1 | 低 | 中 | R1-R3 | なし |
| R4 | common.sh 分割 (任意) | 1 | 低 | 小 | R2,R3 | なし |
| R8 | skipset include による重複削減 | 2 | 中 | 大 | R7 | あり (schema 拡張) |
| D3 | installer developer guide | 3 | 高 | 中 | R1-R3,R7 | - |
| D2 | manifest schema reference 分離 | 3 | 高 | 中 | R8 | - |
| D5 | status 分類 reference | 3 | 中 | 小 | - | - |
| D4 | manual-install の lifecycle 分離 | 3 | 中 | 中 | - | - |
| D6 | README スリム化・roadmap 分離 | 3 | 中 | 小 | D2,D5 | - |
| F7 | deploy worktree (案B) への移行 | 4 | 最高 | 大 | branch反映完了,F6 | あり (適用構造変更) |
| F1 | ECC profile: Claude / Codex 選択適用 | 5 | 高 | 中 | Phase 4 完了 | あり |
| F3 | profile scaffolding script | 5 | 中 | 中 | R8,D2 | なし (新規追加) |
| F2 | main ↔ profile branch 同期補助 | 5 | 中 | 大 | Phase 4 完了 | なし (新規追加) |
| F4 | ECC upstream 更新チェック helper | 6 | 低 | 中 | D4 | なし (新規追加) |
| F5 | top-level dotfiles 刷新 | 6 | 低 | 小 | - | あり (shell 設定) |
| D7 | 計画文書の保守・archive | 6 | 低 | 小 | 全完了 | - |

R / D task の詳細指示は各計画書を参照。以下は F-task の詳細指示書です。

---

## F6: worktree 運用の導入 (案A)

- Phase 0 / 優先度: 最高 (本計画の他 task に先行) / 工数: 小 / 依存: なし / 振る舞い: なし (運用変更。installer コードは変更しない)
- 対象: `docs/worktree-workflow.md` (新規), top-level `README.md` (Branch Strategy 節), `docs/README.md` 索引 (D1 実施後)

### 背景 (課題)

実 HOME の symlink はすべて `~/dotfiles` という単一 working tree を指す。この working tree は「適用済み desired state の実体」と「branch を切り替えて編集する作業場所」を兼ねているため、`main` へ checkout すると:

1. tracked な ECC output が作業ツリーから消え、HOME の symlink が dangling になる。`main` 作業中、Claude / Codex の runtime surface が壊れる。
2. その状態で `install.sh` を実行すると、stale cleanup が dangling link を削除する。profile branch へ戻った後に `install.sh` の再実行が必要になる。

### 設計 (案A)

`~/dotfiles` 本体は**適用中の profile branch に常駐**させ、他 branch の作業は `git worktree` で別 directory に出す。

本体での branch 切り替えを全面禁止するのではない点に注意する。「適用する profile を変える」ための意図的な切り替え (`git switch <profile-branch>` → `bash install.sh`) は現行設計どおり本体で行う正当な操作であり、`docs/ecc-dotfiles-manual-install.md` の手順とも整合する。F6 が禁止するのは「編集・commit 作業のための一時的な checkout」(特に `main` / `profile/ecc-base`) を本体で行うことだけである。この区別を docs に明記すること。

- worktree の配置は **repo の外** とする。標準: `~/dotfiles-worktrees/<branch名のslug>` (例: `~/dotfiles-worktrees/main`)。
  - repo 内 (`~/dotfiles/.worktrees/` など) は採用しない: top-level の `.??*` glob によって installer の link 対象候補になり、skip list の追加が必要になるため。repo 外なら installer は一切関知しない。
- git は同一 branch の二重 checkout を禁止するため、適用中 branch が worktree 側で誤って checkout される事故は構造的に起きない。
- main → profile への取り込みは、`~/dotfiles` 側で適用中 branch に乗ったまま `git merge` (例: `git merge profile/ecc-base`) で行う。checkout の切り替えは発生しない。merge により tracked desired state が変わった場合は `bash install.sh` を再実行して HOME を追従させる。
- `install.sh` / `uninstall.sh` / `status.sh` は `DOTPATH` 既定値 (`$HOME/dotfiles`) の通り **本体 checkout に対してのみ**実行する。worktree を `DOTPATH` に指定して install することは禁止する (HOME の link が worktree を指してしまい、worktree 削除で全 link が壊れるため)。
- `scripts/install/test-all.sh` は worktree 内からの実行を許容する (`/tmp` fixture に独立した checkout を作る設計のため本体に影響しない)。F6 の作業中に worktree 内から 1 回実行し、全 PASS することを確認して docs に明記する。

### 作業手順

1. `docs/worktree-workflow.md` を新規作成し、次を含める:
   - 上記の課題 (なぜ `~/dotfiles` で branch を切り替えてはいけないか) の説明。
   - 運用規則: 本体は適用 branch 常駐 / 他 branch 作業は worktree / DOTPATH を worktree に向けない / merge による取り込み手順 / merge 後の `install.sh` 再実行。
   - コマンド例: `git worktree add ~/dotfiles-worktrees/main main`, 作業後の `git worktree remove`, 一覧 (`git worktree list`)。
   - やむを得ず本体で branch を切り替えた場合の復旧手順: 適用 branch へ戻り `bash install.sh` を再実行する (戻るだけで dangling は解消し、prune 済みなら install.sh が再作成する)。
2. top-level `README.md` の Branch Strategy 節に、この運用の要約 (3〜4 文) と `docs/worktree-workflow.md` へのリンクを追加する。
3. 実際に `~/dotfiles-worktrees/main` を作成し、worktree 内から `bash scripts/install/test-all.sh --branch main` が全 PASS することを確認する (確認結果を実施記録に残す)。
4. 以後の本計画の `main` 宛て commit はすべてこの worktree で行う。

### 受け入れ基準

- [x] `docs/worktree-workflow.md` が存在し、課題・規則・コマンド例・復旧手順を含む。
- [x] top-level README から参照されている。
- [ ] `~/dotfiles` の checkout branch を変えずに、worktree 経由で `main` へ commit できることを実証済み。
- [ ] 適用中 profile の HOME symlink が main 作業の前後で一切変化しない (`bash status.sh` の出力比較で確認)。

### 補足 (helper script の扱い)

worktree 作成・掃除の補助 script (`scripts/worktree/`) は本 task では作らない。`git worktree` の素のコマンドで運用が成立することを確認し、定型化の必要を感じた時点で別 task として起案する (判断を実施記録に残す)。

---

## F1: ECC profile — Claude / Codex の選択適用

- Phase 5 / 優先度: 高 / 工数: 中 / 依存: Phase 4 完了 (テスト分割済みだと case 追加が容易)
- 対象: `profiles/ecc/checks.d/10-local-state.sh`, `profiles/ecc/bin/check-local-state.sh`, `docs/ecc-dotfiles-manual-install.md`, テスト

### 目的 (旧 Future Work 1)

現在の ECC profile は Claude (install-state) と Codex (sync marker + skills bundle) の両方の local state が揃っていないと `profile/ecc/*` branch で install できない。「最低どちらか一方の desired state が準備されていれば適用可能」にし、Claude だけ / Codex だけの環境を許容する。

### 前提となる実装事実 (実装前に必ず再確認)

- 共通 installer は source が存在しない surface を既に黙って skip する (`link_all_managed_surfaces` の `path_exists_or_link "$source_path" || continue`、preflight の `[ -d "$source_path" ] || continue`)。つまり**共通 installer 側の変更は不要の見込み**で、変更点は profile check 側に閉じる。
- `profiles/ecc/checks.d/10-local-state.sh` と `profiles/ecc/bin/check-local-state.sh` が現在「両方必須」をどう判定しているかを精読し、Claude 系 check と Codex 系 check の境界を特定する。

### 設計

- 判定単位を「tool group」(claude / codex) に分ける。
  - Claude group ready 条件: `.claude/ecc/install-state.json` が存在し、この checkout の `.claude` を指す (現行条件を流用)。
  - Codex group ready 条件: `.codex/dotfiles-profile-ecc-sync-state.json` が現行条件を満たし、`.agents/skills` bundle が存在する (現行条件を流用)。
- check の合格条件を「両 group ready」から「**少なくとも 1 group ready**」に変える。
  - ready でない group は `Warn:` として明示し、「その group の surface は dotfiles 側 source が無ければ skip され、HOME に出ない」ことを log に出す。
  - **重要な安全条件**: group が not-ready なのに dotfiles 側に当該 group の tracked output が存在する場合 (例: 別環境の branch を checkout して install-state だけ無い場合) は、従来どおり **FAIL で停止**する。not-ready 許容は「output も state も無い」場合だけにする。これにより「未セットアップの ECC surface を実 HOME に出さない」という現行の保護目的を維持する。
- 明示制御が欲しい場合に備え、環境変数 `DOTFILES_ECC_TOOLS=claude,codex|claude|codex` で要求 group を固定できるようにする (未設定時は auto = 1 group 以上)。check script 内だけで完結し、共通 installer には手を入れない。

### 作業手順

1. 2 つの check script を精読し、Claude / Codex 判定箇所の現状を実施記録に書き出す。
2. テストを先に書く: profile smoke test (`profiles/ecc/bin/test-profile.sh` / `scripts/install/test-profile.sh`) の fixture で「Claude のみ ready」「Codex のみ ready」「両方 not-ready (FAIL)」「not-ready だが tracked output あり (FAIL)」の case を追加する。fixture の作り方は既存 smoke test の手法に従う。
3. `10-local-state.sh` と `check-local-state.sh` を上記設計どおり書き換える。両 script の判定ロジックが乖離しないよう、可能なら共通判定関数を `profiles/ecc/bin/` 配下の共有 file に置き、両方から source する。
4. `docs/ecc-dotfiles-manual-install.md` の該当節 (Setup checklist, section 9-10, 運用上の注意) に「片方のみの環境」の手順と挙動を追記する。
5. test-all.sh 全 PASS、実環境で `bash install.sh --dry-run` の無異常を確認する。

### 受け入れ基準

- [ ] Claude のみ / Codex のみの fixture で install が成功し、もう片方の surface が HOME に出ない。
- [ ] 「state なし + tracked output あり」では従来どおり停止する。
- [ ] 既存の両方 ready 環境 (この環境) で挙動・出力が実質変わらない (警告なし)。
- [ ] docs 更新済み。

---

## F3: profile scaffolding script

- Phase 5 / 優先度: 中 / 工数: 中 / 依存: R8 (最終 schema 確定後), D2
- 対象: `scripts/profile/new-profile.sh` (新規), README / docs

### 目的

README「Branch Strategy」に書かれた「既存 profile を元に別 profile を作る」手順 (profiles/<name>/ 一式コピー → profile.tsv の branch pattern 修正 → smoke test) を script 化し、手作業での移植漏れ (bin/ の補助 script、checks.d/) を防ぐ。

### 作業手順

1. `scripts/profile/new-profile.sh --from ecc --name <new>` を実装する:
   - `profiles/<from>/` を `profiles/<new>/` へコピー (`.git` 等は対象外。profile directory のみ)。
   - `profile.tsv` の branch pattern を `profile/<new>-base`, `profile/<new>/*` に書き換える。
   - `bin/test-profile.sh` 等、profile 名を内包する file を検出して書き換え対象を報告する (自動置換は profile.tsv のみ。bin/ 配下は中身が profile 固有のため、置換候補行を提示して手動修正を促す)。
   - 最後に `bash profiles/<new>/bin/test-profile.sh --branch profile/<new>-base` の実行方法を案内する。
2. `--dry-run` を実装する (コピー・書き換え予定の一覧表示のみ)。
3. regression test に「scaffold した profile が manifest validation を通る」case を追加する。
4. README の該当段落を script 利用の記述に更新する。

### 受け入れ基準

- [ ] scaffold → smoke test までが README の手順どおり 2 コマンドで通る。
- [ ] dry-run が書き込みゼロで計画を表示する。

---

## F2: main ↔ profile branch 同期補助

- Phase 5 / 優先度: 中 / 工数: 大 (設計を含む) / 依存: Phase 4 完了
- 対象: `scripts/profile/sync-status.sh` (新規, read-only) ほか

### 目的 (旧 Future Work 2)

共通資産 (`install.sh`, `scripts/install/`, `docs/`, top-level dotfiles) の変更が `main` → `profile/ecc-base` → `profile/ecc/*` へ merge で流れる運用を補助する。現在は merge 漏れの検出が手動。

### 設計フェーズ (実装前に必ず行い、結果を実施記録に残す)

1. 共通資産 path 集合を定義する (案: `install.sh`, `uninstall.sh`, `status.sh`, `scripts/`, `docs/`, `.gitignore`, `.gitattributes`, top-level dotfiles, `*.zsh-theme`。`profiles/` は profile-base 資産、managed root は profile 資産として除外)。
2. read-only の `sync-status.sh` を先に作る方針とする。自動 merge は行わない (merge 判断は人間 / 上位 agent に残す)。

### 作業手順

1. `scripts/profile/sync-status.sh` を実装する:
   - 引数なしで branch 階層 (`main` → `*-base` → leaf) を git branch 一覧から推定し、各隣接 pair について「上流にあって下流に未 merge の共通資産 commit」を `git log <down>..<up> -- <共通資産 paths>` で一覧する。
   - 出力は section 形式 (既存 log style に合わせる)。未 merge ゼロなら OK 表示。
   - remote 状態は扱わない (local branch のみ。fetch は利用者責務とし、help に明記)。
2. 使い方を README の Branch Strategy 節と docs/README.md に追記する。
3. regression test に fixture repo (main + base + leaf) での検出 case を追加する。

### 受け入れ基準

- [ ] main に共通資産 commit を積んだ fixture で、base / leaf の未 merge として検出される。
- [ ] profile 資産のみの commit は検出されない。
- [ ] 書き込み操作が一切ない (git の read 系 command のみ使用)。

---

## F7: deploy worktree (案B) への移行

- Phase 4 / 優先度: 最高 / 工数: 大 / 依存: リファクタリング反映完了, F6
- 対象: `docs/improvement-plan/design/deploy-worktree.md` (新規), installer / deploy entrypoint, tests, README / docs
- この task は、設計文書を先に作り、検証可能な移行手順に落としてから案Bへ移行する。設計で重大な阻害要因が見つかった場合のみ中止判断を記録する。

### 目的

案A (F6) は「本体 checkout を適用 branch に常駐させる」という運用規約で課題を回避するが、規約違反 (本体での checkout 切り替え) に対する構造的な防御はない。案B は HOME の symlink が指す先を**適用専用 worktree** (例: `~/.dotfiles-active`) に固定し、編集 (本体はどの branch でも自由) と適用 (専用 worktree を意図的に切り替える deploy 操作) を構造的に分離する。

リファクタリングが問題ないことをローカル検証と CI で確認し、共通内容を `main`、profile 内容を `profile/ecc-base`、環境固有内容を leaf branch へ反映したら、この案B移行を次 task とする。

### 設計文書に含めるべき項目 (チェックリスト)

設計文書は少なくとも次を扱うこと。各項目で「現行 (案A) からの変更点」を明示する。

1. **配置と名前**: 適用専用 worktree の path (案: `~/.dotfiles-active`)。HOME 直下の dotfile に見える名前を選ぶ場合、installer 自身の `.??*` glob・managed root 判定と干渉しないことを確認する。
2. **DOTPATH 意味論**: `install.sh` 系の `DOTPATH` は適用専用 worktree を指すことになる。managed symlink 判定 (`is_managed_symlink` の target prefix 照合) が新 path で機能すること、本体 checkout (`~/dotfiles`) を指す旧 link との判別を整理する。
3. **deploy 操作の定義**: 「適用 = 専用 worktree を対象 branch に追従させてから link する」操作を installer のどこに置くか (install.sh の新 phase か、別 entrypoint `deploy.sh` か)。worktree が存在しない場合の初期化、対象 branch の指定方法、git 操作 (fetch / checkout / merge) をどこまで installer が担うか。
4. **ignored local state の所在**: ECC install-state (`.claude/ecc/install-state.json`)・Codex sync marker は working tree 単位で存在する ignored file である。本体で生成した state を適用専用 worktree 側にどう持ち込むか (再生成を要求するか、state の置き場所を worktree 外に移すか)。profile check (`checks.d/10-local-state.sh`) の判定がどちらの tree を見るべきかを定義する。**ここが案B最大の設計論点であることを文書に明記する。**
5. **profile check / smoke test への影響**: `test-profile.sh`, `check-local-state.sh`, F1 で導入した tool group 判定が新構成で成立するか。
6. **移行手順 (案A → 案B)**: 既存 HOME link (target = `~/dotfiles`) の棚卸し → 専用 worktree 初期化 → 再 link → 旧 link cleanup の順序。移行中に runtime surface が壊れる時間を最小化する手順と、各段階での検証 (`status.sh`) を定義する。
7. **rollback 手順**: 案B 適用後に案A へ戻す手順。
8. **F2 との統合**: 同期補助 (`sync-status.sh`) が本体・専用 worktree の 2 tree 構成でどう動くべきか。
9. **テスト計画**: regression test にどんな case を追加するか (deploy 操作の dry-run、専用 worktree 不在時の挙動、旧 link 混在時の cleanup)。
10. **移行判断基準**: 案A 運用で実際に起きた問題 (規約違反の頻度、merge 運用の摩擦) を列挙し、「これらが閾値を超えていなければ案B は実装しない」という判断基準を明文化する。

### 作業手順

1. F6 と branch 反映作業の実施記録を読み、案A 運用で観測された問題を収集する。
2. 上記チェックリストに沿って `docs/improvement-plan/design/deploy-worktree.md` を書く。
3. 移行判断 (実装する / 中止する / 保留) を文書末尾に記録する。中止以外なら、同じ task 内で実装・テスト・docs 更新・実 HOME 移行手順を進める。
4. deploy 操作の実装を行う場合は、先に regression test を追加し、旧 link (`~/dotfiles` target) と新 link (適用専用 worktree target) が混在する移行期を安全に扱えることを確認する。
5. 実 HOME の移行は dry-run / status / rollback 手順を通した後に行う。移行後は新しい zsh session / Codex / Claude の実利用に必要な symlink が欠けていないことを確認する。

### 受け入れ基準

- [ ] 設計文書がチェックリスト 10 項目をすべて扱っている。
- [ ] 移行手順と rollback 手順が段階ごとの検証コマンド付きで書かれている。
- [ ] 実装可否の判断とその根拠が記録されている。
- [ ] 実装する場合、案B の deploy 操作と migration regression test が追加されている。
- [ ] 実 HOME の managed symlink が適用専用 worktree を指し、`bash status.sh` が missing / conflicts / stale / orphaned 0 を報告する。
- [ ] rollback 手順が実行可能であることを dry-run または fixture で確認済み。

---

## F4: ECC upstream 更新チェック helper

- Phase 6 / 優先度: 低 / 工数: 中 / 依存: D4 (lifecycle 文書)
- 対象: `profiles/ecc/bin/check-upstream.sh` (新規)

### 目的

ECC repo (`$ECC_REPO`) の version と、dotfiles 側に取り込み済みの生成物の世代 (install-state / sync marker に記録された情報) を突き合わせ、再取り込みが必要かを read-only で報告する。lifecycle 文書 (D4) の「Update from upstream ECC」手順の入口になる。

### 作業手順

1. `.claude/ecc/install-state.json` と `.codex/dotfiles-profile-ecc-sync-state.json` にどんな version / commit 情報が記録されているかを調査する (write-codex-sync-state.sh の実装と実 file を確認)。記録が無い場合は、まず `write-codex-sync-state.sh` に ECC repo の `git describe` / package.json version を marker へ記録する拡張を行う (こちらが先行 task になる)。
2. `$ECC_REPO` の現在 version と marker 記録を比較し、`up to date` / `update available (X → Y)` / `unknown (marker has no version info)` を報告する script を実装する。
3. lifecycle 文書から参照する。

### 受け入れ基準

- [ ] read-only であり、ECC repo・dotfiles のどちらにも書き込まない。
- [ ] marker に version 情報が無い既存環境でも error にならず unknown を報告する。

---

## F5: top-level dotfiles 刷新

- Phase 6 / 優先度: 低 / 工数: 小 / 依存: なし / 注意: shell 環境の振る舞いが変わるため実機確認必須
- 対象: `.zshrc`, `archive/`

### 目的

`.zshrc` は oh-my-zsh stock template が大半 (148 行中、実効行は約 32 行) で、自分の設定がどれかを判別しにくい。意図のある設定だけを残す。

### 作業手順

1. `.zshrc` から「コメントアウトされた stock template 行」を削除し、実効設定 (ZSH path, `ZSH_THEME="my"`, plugins, alias 等) + 自分で意図して書いた comment のみ残す。**実効行は 1 行も変えない** (削除はコメントと空行のみ)。
2. 適用後、新しい zsh session を起動して theme・plugin・alias が変更前と同一に動くことを確認する (`zsh -i -c 'echo $ZSH_THEME; alias'` の前後比較)。
3. `archive/` (.bashrc, .inputrc) の扱いを決める: installer は `.??*` glob で top-level のみ link するため archive/ は link されない。現状維持でよいが、docs/README.md の索引に「archive は参照用・非適用」と 1 行記載する。
4. `.vimrc` は実用設定のみで構成されており変更不要 (この判断を実施記録に残す)。

### 受け入れ基準

- [ ] `.zshrc` の実効行 diff がゼロ (コメント・空行のみの削減)。
- [ ] 新 shell session で theme / plugin が従来どおり。
- [ ] `bash install.sh --dry-run` に変化なし。

---

## 全体の完了条件 (Definition of Done)

1. 全 task が完了 or 「見送り」判断とその理由が実施記録に残っている。
2. CI が `main` / `profile/ecc-base` で green。
3. 案A の worktree 運用が docs 化され、計画期間中の `main` 宛て commit がすべて worktree 経由で行われている (適用中 profile の HOME symlink が編集作業によって壊れた記録がない)。その後 F7 で案B への移行が完了し、適用専用 worktree を指す HOME symlink が `bash status.sh` で正常確認されている。
4. README が 200 行以下で、docs 索引から全文書に到達できる。
5. `bash scripts/install/test-all.sh` 全 PASS、test case 数が baseline (31) 以上。
6. この improvement-plan が D7 に従い archive されている。
