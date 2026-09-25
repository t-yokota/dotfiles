# External Tool Layers Design (案C)

- Last reviewed: 2026-09-26
- 前提: [README.md](../README.md) の実行規則、[03-roadmap.md](../03-roadmap.md) の F7、[profile-manifest.md](../../reference/profile-manifest.md)、[worktree-workflow.md](../../worktree-workflow.md)、ecc-dotfiles-lifecycle.md (profile branch 系にのみ存在)

> **Superseded (2026-09-26)**: 外部 tool が plugin として配布されるようになったため、本設計は実装しません。後継は [slim-base.md](slim-base.md) (案D) です。本文は履歴として残します。

この文書は、dotfiles を `main` 一本で管理し、ECC などの外部 tool が作る desired state を repo 外の source layer として適用する設計を定義します。生成物の vendoring と branch 積層が生む更新・適用コストをなくし、既存 installer の manifest と安全規則を複数 source root へ一般化します。本文書は [03-roadmap.md](../03-roadmap.md) の F7 が予定していた案B deploy worktree 設計文書の代替です。

## 実施記録 (2026-08-11)

commit hash は最終 commit 作成後に補記します。

| Task | 状態 | 証跡 |
|---|---|---|
| 設計文書作成 | 完了 | 案C の配置、契約、移行、rollback、test、採否判断を S1〜S12 に記録。 |
| Stage 1: installer multi-root 対応 | 未着手 | 実装 task で test-first に実施。 |
| Stage 2: ECC staging root 構築 | 未着手 | 実装 task 完了後に machine-local 作業として実施。 |
| Stage 3: manifest 移設と registry 登録 | 未着手 | 移行 task で実施。 |
| Stage 4: namespace cutover | 未着手 | `.agents`、`.codex`、`.claude` の順に実施。 |
| Stage 5: 個人資産移管と branch archive | 未着手 | cutover 検証後に実施。 |
| Stage 6: main 常駐への切り替え | 未着手 | archive 保全後に実施。 |

## Design Checklist

| # | 項目 | 対応 section |
|---:|---|---|
| 1 | 配置と名前 | S2 |
| 2 | layer model と用語 | S3 |
| 3 | registry・lock | S4 |
| 4 | manifest schema と活性化 | S5 |
| 5 | 衝突規則と所有権 | S6 |
| 6 | merged file 方針 | S7 |
| 7 | ECC lifecycle 対応 | S8 |
| 8 | 移行手順 | S9 |
| 9 | rollback | S10 |
| 10 | テスト計画 | S11 |
| 11 | roadmap 影響 | S12 |
| 12 | 採否判断 | S12 |

## S1. Background and Goals

現行の `main` → `profile/ecc-base` → `profile/ecc/full/home-9M2KERO` は、leaf が base に対して 889 files、150,722 insertions、2 deletions の ECC 生成物を持ちます。実 HOME の symlink が checkout 内の生成物を指すため、branch checkout 事故を避ける F6 worktree 規律が必要です。ECC 更新時には生成物の手動 cleanup、再生成、大規模 commit、branch 間 merge が発生します。

案C は ECC に渡す staging 用 `HOME` を `$DOTPATH` から `~/dotfiles-tools/<tool>/` へ変えます。ECC 側の install、sync、skills copy のコマンドと順序は変えず、生成先だけを git 管理外へ移します。dotfiles は registry と committed manifest から source layer を組み立て、実 HOME へ必要な surface だけを link します。

F7 の checklist 項目 4 は、ignored な install-state と sync marker を deploy worktree へどう持ち込むかを案B最大の設計論点としています。案C は state と生成物を同じ staging root に置くため、state transfer の問題自体をなくします。

本設計の目標は、`main` 一本化、外部生成物の git 外配置、複数 source root の安全な reconcile、lock による再現性、段階移行と完全 rollback です。案B の再検討と ECC installer 側の変更は非目標です。本 task では installer 実装と実 HOME 移行も行いません。

## S2. Placement and Naming

source、manifest、machine-local state を次の場所へ分離します。

| Path | Role |
|---|---|
| `$DOTPATH` (`~/dotfiles`) | 常時有効な base layer。最終的に `main` だけを checkout します。 |
| `~/dotfiles-tools/<tool>/` | tool ごとの staging root。例は `~/dotfiles-tools/ecc/` です。 |
| `~/development/agent-references/everything-claude-code` | ECC upstream clone。staging root とは分離します。 |
| `tools.d/base/` | base layer の committed surface、skipset、check。`base` は予約名です。 |
| `tools.d/<tool>/` | tool layer の committed surface、skipset、check、helper。 |
| `~/.config/dotfiles/tools.conf` | machine-local registry。tool 名と staging root の対応を持ちます。 |
| `tools.d/<tool>/lock.tsv` | upstream と生成手順を固定する committed lock です。 |

upstream clone を staging root として直接 link しません。clone から link すると `git pull` が dotfiles の preflight と `install.sh` を通らずに生きた実 HOME を変更するためです。clone は入力、staging root は生成済み desired state と役割を分けます。

すべての source root は相互に sibling、すなわちどの root も別 root の ancestor または descendant ではない配置を必須とします。`is_managed_symlink` は `scripts/install/lib/reconcile.sh:44-56` で `readlink` 結果を textual prefix 照合し、path を正規化しません。`$DOTPATH` 配下へ tool root を入れると 1 本の link が複数 owner に一致するため、registry 読み込み時に duplicate と入れ子を拒否します。

現行 `profiles/ecc/` の `surfaces.tsv`、`skipsets.tsv`、`checks.d/`、`bin/` は `tools.d/ecc/` へ一式移します。`profile.tsv` は移しません。`tools.d/` という directory 名と `tools.d/base/` の予約は本設計の決定事項です。

registry は machine ごとに staging の有無と絶対 path が異なるため commit しません。manifest と lock は全 machine で共有する policy と再現性契約なので commit します。

## S3. Layer Model and Terminology

installer は base layer と 0 個以上の tool layer を同時に扱います。

| Term | Definition |
|---|---|
| base layer | source root が `$DOTPATH` の常時有効 layer。`tools.d/base/` で managed surface を宣言します。 |
| tool layer | `tools.conf` に登録された staging root と、同名の `tools.d/<tool>/` manifest の組です。 |
| owning root | link source の所属 root。base は `$DOTPATH`、tool は registry の絶対 path です。 |
| destination namespace | 実 HOME 側で installer が管理を許可された `.claude`、`.codex`、`.agents` です。 |

`MANAGED_ROOTS` (`scripts/install/lib/common.sh:12`) は `.claude .codex .agents` を持ちます。これは実 HOME 側のどの名前空間へ書いてよいかを表す destination 軸であり、source root の一覧ではありません。source layer と `MANAGED_ROOTS` を混同しません。

現在の `MANAGED_SURFACES` は absolute source、absolute dest、strategy、skipset、label を保持するため、surface の反復処理はすでに `$DOTPATH` から独立しています。manifest の 6 列は変えず、内部 record の末尾に `owning_root` と `owning_layer` を追加します。reconcile、status、test の consumer はこの帰属情報を衝突報告と ownership 判定に使います。

## S4. Registry and Lock Formats

`tools.conf` は shell code として `source` または `eval` せず、2 列 TSV として読みます。registry 値では `~` を展開しないため、root は展開済み絶対 path を記録します。

```tsv
# tool	staging-root
ecc	/home/yokota/dotfiles-tools/ecc
```

| Field | Contract |
|---|---|
| `tool` | `[a-z0-9][a-z0-9._-]*`、一意、`base` 以外。`tools.d/<tool>/` と対応します。 |
| `staging-root` | canonical な既存 directory の絶対 path。`~`、`.`、`..`、末尾 `/` を許可しません。 |

registry loader は `scripts/install/lib/cli.sh:68` の `cli_bootstrap` に置きます。`HOME` と `DOTPATH` の確定後、manifest 読み込み前に root を canonicalize し、同一 root、`$DOTPATH` を含む相互の ancestor / descendant、未知 tool、重複 tool を symlink 操作前に error にします。

登録済み root が存在しない場合は warn + skip ではなく hard error にします。登録は layer の有効化を意味し、silent skip は desired state の消失や cleanup の誤判断を隠すためです。移動や削除は S6 の lifecycle に従い、先に layer を uninstall してから registry を更新します。

`lock.tsv` も shell code ではなく、kind ごとに検証する TSV とします。

```tsv
tool	ecc
upstream	https://github.com/affaan-m/everything-claude-code.git
commit	1e8c7e7994223e0ff337d1626cd08e04a1ae67ed
generator	claude-home	bash ./install.sh --target claude --profile full	full
generator	codex-sync	bash scripts/sync-ecc-to-codex.sh	sync
generator	skills-bundle	cp -R .agents/skills/. <staging>/.agents/skills/	bundle
```

| Kind | Columns | Meaning |
|---|---|---|
| `tool` | `tool <name>` | manifest directory と registry key を固定します。 |
| `upstream` | `upstream <url>` | fresh clone の取得元を固定します。 |
| `commit` | `commit <40-hex>` | 生成に使う upstream commit を固定します。 |
| `generator` | `generator <id> <command> <profile>` | operator が実行する生成手順と profile を記録します。 |

installer は lock の command を自動実行しません。command は review と手動再生成の宣言です。再現性契約は「lock と空 staging root から fresh install すると、timestamp、backup、ignored runtime state を除く同じ managed surface を再現できる」です。byte 単位の差分や即時 rollback が必要な machine は staging root 内で任意に `git init` できますが、installer はその local repository に関知しません。

## S5. Manifest Schema Evolution and Activation

`surfaces.tsv` は [profile-manifest.md](../../reference/profile-manifest.md) の 6 列を維持します。

```text
surface  entries|whole  <source>  <dest>  <skipset|none>  <label>
```

変えるのは source の解決基準だけです。`resolve_dotpath_path` (`scripts/install/lib/common.sh:427`) を explicit root を受ける `resolve_layer_path` へ一般化し、`load_surfaces_file` (`scripts/install/lib/profile.sh:474`, call site `:490`) が owning root を渡します。base manifest は `$DOTPATH`、tool manifest は registry root を基準に同じ relative source を解決します。

`validate_surface_manifest_path` (`scripts/install/lib/profile.sh:68`) が absolute path と `..` を拒否する規則は維持します。manifest へ machine-local absolute source を書かず、registry だけが絶対 root を持ちます。error 文言を変える場合は `scripts/install/tests/cases/60-manifest-validation.sh:60` の assert を同時に更新します。

現行 ECC manifest は 18 surfaces で、内訳は 15 `entries` と 3 `whole` です。この宣言を列追加なしで `tools.d/ecc/surfaces.tsv` へ移し、source root の解決結果だけを staging 側へ変えます。

`tools.d/base/surfaces.tsv` は `.claude`、`.codex`、`.agents` の広い `entries` surface を持ちません。S7 で列挙する personal baseline だけを file / directory 単位の `whole` surface として宣言し、leaf checkout に残る tracked ECC output を base claimant にしない設計とします。

最終状態では profile subsystem を廃止し、base は常時有効、tool は registry 登録時に有効とします。`profile_matches_branch` (`scripts/install/lib/profile.sh:425`) の branch glob は main 一本化後に意味がないため削除します。`profile.tsv` とその `branch` 行は `tools.d/ecc/` へ移さず、archive refs を確保した Stage 5 で legacy manifest とともに削除します。

Stage 1〜4 は registry file が存在しないか、comment と空行を除く有効な tool 登録が 0 件の場合に legacy profile loader へ fallback し、既存挙動と rollback path を保ちます。壊れた registry 行は 0 件として無視せず hard error にします。1 件以上の registry mode に入った時点では legacy profile を二重 load しません。Stage 3 は `profiles/ecc/` を非活性の migration shadow として残し、Stage 5 で archive refs を確認してから shadow、fallback、profile branch activation code を削除し、final regression を実行します。

既存 skipset の relative pattern と include 規則は維持します。cross-layer conflict を解消する explicit root skip は、同じ layer の child `whole` surface を claimant 展開する前にも適用し、暗黙の優先順位を作らずに descendant claim を抑止できるようにします。この semantic extension は reference 文書と regression test を実装 task で同時更新します。

`checks.d` は現在の `DOTPATH` と `DOTFILES_BRANCH` (`scripts/install/lib/profile.sh:603-604`) に加え、tool check へ `DOTFILES_TOOL_ROOT` と `DOTFILES_TOOL_NAME` を export します。`DOTFILES_BRANCH` は transition 中の互換値で、final state では `main` です。ECC check は root 内 state が not-ready なのに生成物が存在する場合に FAIL し、未セットアップ surface を実 HOME へ出さない現行の保護意味論を root 単位で継承します。

## S6. Conflict Rules and Ownership

cross-layer の manifest 宣言衝突は、すべての desired destination を展開した preflight で hard error にします。exact dest の重複に加え、`whole` surface と別 claimant の ancestor / descendant 関係も衝突です。error は両 claimant の layer 名、owning root、manifest path、source、dest を表示します。

```text
Error: desired destination is claimed by multiple layers: ~/.codex/AGENTS.md
  base (/home/yokota/dotfiles): tools.d/base/surfaces.tsv -> .codex/AGENTS.md
  ecc  (/home/yokota/dotfiles-tools/ecc): tools.d/ecc/surfaces.tsv -> .codex/AGENTS.md
```

解消方法は losing layer の明示的な skipset 追記だけです。manifest 順、registry 順、base 優先などの暗黙 priority と silent shadowing は導入しません。S5 の claimant 展開は explicit root skip を child surface にも適用するため、`entries` と `whole` のどちらも skipset policy で除外できます。

この declaration-level check は完全新規です。現行の `check_managed_entry` (`scripts/install/lib/reconcile.sh:59`) などは filesystem に既存 path があるかだけを調べ、manifest 同士の同一 dest を検出しません。最初の link が作られた後で 2 番目の claimant が未管理 conflict のように見える問題を避けるため、`scripts/install/lib/status.sh:13` の `STATUS_EXPECTED_DESTS` と `:136` の `status_mark_expected` を一般化した desired-dest registry を `install.sh:60-67` の Link Conflict Check に追加します。Link Conflict Check は Cleanup より前へ移し、declaration と filesystem の両検査を write-free preflight として完了してから cleanup します。

単一 source root を仮定する `is_managed_symlink X "$DOTPATH"` は次の 8 箇所です。

| File | Lines | Role |
|---|---|---|
| `scripts/install/lib/reconcile.sh` | 224, 236, 255 | orphan / stale cleanup |
| `scripts/install/lib/reconcile.sh` | 395 | top-level uninstall |
| `scripts/install/lib/reconcile.sh` | 446, 454, 467 | unscoped / theme uninstall |
| `scripts/install/lib/status.sh` | 251 | unexpected managed link inventory |

これらを base と全 registry root の ownership 判定へ一般化します。特に `scripts/install/lib/status.sh:251` を直さない場合、第 2 root への link は `status_observe_managed_symlink` から early return し、stale / orphaned 分類に現れません。

root の lifecycle は「layer を uninstall してから deregister または移動する」です。registry から消えた root は通常 ownership scan の対象外になるため、`status.sh` は canonical `$HOME/dotfiles-tools/` 配下を指す symlink がどの登録 root にも属さない場合に attention を表示します。これは第 7 の分類を増やさず、target が存在しなければ stale、存在すれば orphaned の既存 count に含めて `unregistered tool-root link` と注記します。

namespace-scoped `install.sh` / `uninstall.sh` / `status.sh` を Stage 1 で追加します。`--namespace .agents|.codex|.claude` は migration と診断にだけ scope を絞り、指定なしでは全 layer・全 namespace を reconcile します。uninstall は registry が有効な間に全 owning root を認識し、通常ファイルを削除しない既存安全規則を維持します。

## S7. Merged and Seeded File Policy

symlink だけでは合成できない file と個人 baseline は base layer が所有します。

| Path | Owner | Policy |
|---|---|---|
| `.codex/config.toml` | base | dotfiles が全 file を所有し、ECC add-only merge の変更を review して取り込みます。 |
| `.codex/AGENTS.md` | base | dotfiles が全 file を所有し、ECC 部分だけを marker block で更新します。 |
| `.claude/CLAUDE.md` | base | personal baseline。ECC installer は生成しません。 |
| `.claude/settings.json` | base | personal baseline。ECC hooks は `.claude/hooks/hooks.json` に生成されます。 |
| `.claude/skills/orchestrator-playbook/` | base | tracked 非 ECC skill。directory 単位で所有します。 |
| `.agents/skills/<personal-skill>/` | base | upstream ECC と一致しない個人 skill だけを inventory 後に追加します。 |
| `.gitconfig.local` | machine-local | ignored のまま commit せず、global hooks 等の local state を保持します。 |
| generated collections | tool | agents、commands、rules、hooks、scripts、prompts、ECC skills を staging から link します。 |

初期の `tools.d/base/surfaces.tsv` は、既知の base-owned path だけを次のように宣言します。個人 skill は Stage 5 の inventory で名前が確定したものだけを同じ `whole` 形式で追記します。

```tsv
# kind	strategy	source	dest	skipset	label
surface	whole	.claude/CLAUDE.md	.claude/CLAUDE.md	none	Claude personal instructions
surface	whole	.claude/settings.json	.claude/settings.json	none	Claude personal settings
surface	whole	.codex/config.toml	.codex/config.toml	none	Codex personal config
surface	whole	.codex/AGENTS.md	.codex/AGENTS.md	none	Codex global instructions
surface	whole	.claude/skills/orchestrator-playbook	.claude/skills/orchestrator-playbook	none	Personal orchestrator skill
```

この manifest は source root が leaf の `$DOTPATH` であっても、上記 5 path 以外を走査しません。leaf に残る `.claude/AGENTS.md`、`plugin.json`、ECC agents / commands / rules 等は base claim にならず、tool layer だけが staging から claim します。`.codex/AGENTS.md` と `config.toml` は `tools.d/ecc/skipsets.tsv` で除外するため、Stage 3 の declaration conflict は 0 になります。

ECC Codex sync は staging の seed copy に対して実行します。`.codex/AGENTS.md` の `<!-- BEGIN ECC -->` / `<!-- END ECC -->` block を base file の同 block と置換し、block 外の personal instruction を残します。`.codex/config.toml` は自動逆変換がないため、staging diff から ECC section を base file へ review 付きで反映します。`tools.d/ecc/skipsets.tsv` は `AGENTS.md` と `config.toml` を tool root の `.codex` entries から明示的に除外します。

leaf の archive 前に、`.claude/skills/orchestrator-playbook/` のような tracked 非 ECC asset と `.agents/skills` に混在する個人 skill を upstream ECC tree と照合します。個人 asset は `main` へ移し、`tools.d/base/` の base surface として残します。ECC 由来 asset だけを tool layer に置きます。

## S8. ECC Lifecycle Mapping

ECC の操作は生成先を staging root へ変えるだけです。現行値は full profile 733 copy operations、Codex agent TOML 3 files、prompts 85 files (manifest 2 files を含む)、skills 33 directories です。

| Operation | Current | 案C |
|---|---|---|
| Claude install | `HOME=$DOTPATH bash ./install.sh --target claude --profile full` | `HOME=~/dotfiles-tools/ecc bash ./install.sh --target claude --profile full` |
| Codex sync | 5 env vars を `$DOTPATH` 配下へ設定 | 5 env vars を `~/dotfiles-tools/ecc` 配下へ設定 |
| skills bundle | ECC `.agents/skills/.` を `$DOTPATH/.agents/skills/` へ copy | ECC `.agents/skills/.` を staging `.agents/skills/` へ copy |

Codex sync では次の 5 env vars を同じ staging root へ向けます。

```bash
TOOL_ROOT="$HOME/dotfiles-tools/ecc"
HOME="$TOOL_ROOT" \
CODEX_HOME="$TOOL_ROOT/.codex" \
AGENTS_HOME="$TOOL_ROOT/.agents" \
ECC_GLOBAL_HOOKS_DIR="$TOOL_ROOT/.codex/git-hooks" \
GIT_CONFIG_GLOBAL="$TOOL_ROOT/.gitconfig.local" \
bash scripts/sync-ecc-to-codex.sh
```

skills bundle の生成先を揃えるコマンドは次です。

```bash
mkdir -p "$TOOL_ROOT/.agents/skills"
cp -R "$ECC_REPO/.agents/skills/." "$TOOL_ROOT/.agents/skills/"
```

`.claude/ecc/install-state.json` と `.codex/dotfiles-profile-ecc-sync-state.json` は staging root 内に生成し、dotfiles repo から削除します。現 state にある `/home/yokota/developments/agent-references/everything-claude-code` は存在しない stale path です。実 clone は `/home/yokota/development/agent-references/everything-claude-code` にあり、fresh install が正しい path と pinned commit を state に記録します。

| Lifecycle | 案C の操作先 |
|---|---|
| uninstall / regenerate | ECC installer と cleanup を staging root に対して実行し、その後 dotfiles installer を reconcile します。 |
| Codex cleanup | staging の prompt manifest、agent TOML、sync marker を cleanup し、sync と marker 作成を再実行します。 |
| skills update | staging の `.agents/skills/` へ copy し、個人 skill を混ぜません。 |
| upstream update | lock の pinned commit と upstream clone HEAD を比較し、lock 更新後に fresh regenerate します。 |
| F4 check | `lock.tsv` の pinned commit と clone HEAD の一致を read-only で報告します。 |

現行 lifecycle 文書の uninstall / regenerate / update / cleanup は、`DOTPATH` を `TOOL_ROOT` に読み替えます。案C移行後は恒久文書へ昇格する S12 の文書更新で、branch 操作と生成物 commit の手順を削除します。

## S9. Migration Procedure

移行は Stage 0〜6 を順番に進め、各 stage の検証が通るまで次へ進みません。Stage 4 までは archive branch を触らず、旧構成へ戻せます。

### Stage 0: Preconditions

本 docs task では触らない leaf の `.claude/settings.json` と `.codex/config.toml` を先に leaf へ commit します。次に regression と実 HOME の baseline を保存します。

```bash
cd "$HOME/dotfiles"
git status --short
bash scripts/install/test-all.sh
bash status.sh --verbose > "$HOME/dotfiles-migration-status-before.txt"
git branch --show-current
```

期待値は test 全 PASS、status の missing / conflicts / stale / orphaned が 0、branch が leaf、worktree が clean です。失敗時は修正せず移行を開始しません。

### Stage 1: Implement Multi-Root Installer

`main` で registry loader、base manifest、multi-root ownership、desired-dest conflict、namespace scope を test-first で実装します。`tools.d/base/` と `tools.d/ecc/` も main worktree で作成し、ECC 管理資産は `profile.tsv` を除いて profile branch から取り込み、installer と一緒に main へ commit します。registry 未作成時は legacy fallback により現行挙動を維持します。

```bash
cd "$HOME/dotfiles-worktrees/main"
bash scripts/install/test-installer.sh
bash scripts/install/test-all.sh
test -f tools.d/base/surfaces.tsv
test -f tools.d/ecc/surfaces.tsv
test -f tools.d/ecc/lock.tsv
git diff --check
```

registry なしの既存 40 case と新規 multi-root case が PASS し、実 HOME は変更されないことを確認します。rollback は実装 commit の revert だけで、実 HOME 操作はありません。

### Stage 2: Build ECC Staging Root

空の staging root を作り、lock の pinned commit から ECC を fresh install します。

```bash
export DOTPATH="$HOME/dotfiles"
export ECC_REPO="$HOME/development/agent-references/everything-claude-code"
export TOOL_ROOT="$HOME/dotfiles-tools/ecc"
export MAIN_WORKTREE="$HOME/dotfiles-worktrees/main"
test ! -e "$TOOL_ROOT"
mkdir -p "$TOOL_ROOT/.codex" "$TOOL_ROOT/.agents/skills"
cp "$DOTPATH/.codex/config.toml" "$TOOL_ROOT/.codex/config.toml"
PINNED_COMMIT=$(awk -F '\t' '$1 == "commit" { print $2 }' "$MAIN_WORKTREE/tools.d/ecc/lock.tsv")
test "$(git -C "$ECC_REPO" rev-parse HEAD)" = "$PINNED_COMMIT"
cd "$ECC_REPO"
HOME="$TOOL_ROOT" bash ./install.sh --target claude --profile full
HOME="$TOOL_ROOT" CODEX_HOME="$TOOL_ROOT/.codex" \
AGENTS_HOME="$TOOL_ROOT/.agents" \
ECC_GLOBAL_HOOKS_DIR="$TOOL_ROOT/.codex/git-hooks" \
GIT_CONFIG_GLOBAL="$TOOL_ROOT/.gitconfig.local" \
bash scripts/sync-ecc-to-codex.sh
cp -R "$ECC_REPO/.agents/skills/." "$TOOL_ROOT/.agents/skills/"
```

staging を実 HOME へ link せず、state root、pinned commit、expected collection を確認します。

```bash
git -C "$ECC_REPO" rev-parse HEAD
test -f "$TOOL_ROOT/.claude/ecc/install-state.json"
node -e 'const x = require(process.argv[1]); console.log(x.operations.length)' \
    "$TOOL_ROOT/.claude/ecc/install-state.json"
find "$TOOL_ROOT/.codex/agents" -maxdepth 1 -name '*.toml' -type f | wc -l
find "$TOOL_ROOT/.codex/prompts" -maxdepth 1 -type f | wc -l
find "$TOOL_ROOT/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l
```

期待値は lock commit、733、3、85、33 です。失敗時は registry 未登録のまま staging を隔離し、旧 HOME link を維持します。

### Stage 3: Move Manifests and Register ECC

Stage 1 で main に commit した installer と `tools.d/base/`・`tools.d/ecc/` を、main から leaf へ direct merge して届けます。`profile/ecc-base` は Stage 5 で直後に archive するため、この移行 commit を base 経由で伝播しません。leaf に untracked の `tools.d/` を作らず、Stage 3〜4 は元の `profiles/ecc/` を rollback 専用の migration shadow として変更せず残します。

```bash
MAIN_WORKTREE="$HOME/dotfiles-worktrees/main"
git -C "$MAIN_WORKTREE" status --short
test -f "$MAIN_WORKTREE/tools.d/base/surfaces.tsv"
test -f "$MAIN_WORKTREE/tools.d/ecc/surfaces.tsv"
test -f "$MAIN_WORKTREE/tools.d/ecc/lock.tsv"
cd "$DOTPATH"
git status --short
git merge main
test -f tools.d/base/surfaces.tsv
test -x tools.d/ecc/bin/write-codex-sync-state.sh
bash scripts/install/test-all.sh
DOTFILES_TOOL_ROOT="$TOOL_ROOT" ECC_REPO="$ECC_REPO" \
bash tools.d/ecc/bin/write-codex-sync-state.sh
mkdir -p "$HOME/.config/dotfiles"
if awk -F '\t' '!/^[[:space:]]*(#|$)/ && NF >= 2 { found = 1 } END { exit !found }' \
    "$HOME/.config/dotfiles/tools.conf" 2>/dev/null; then
    echo "Error: migration requires zero active tool registrations" >&2
    exit 1
fi
printf 'ecc\t%s\n' "$TOOL_ROOT" >> "$HOME/.config/dotfiles/tools.conf"
bash status.sh --verbose
```

この時点の status は新 root の missing と旧 `$DOTPATH` link の orphaned を移行対象として表示して構いません。base が S7 の最小 `whole` surface だけを claim し、ECC 側が base-owned file を skip するため declaration conflict は 0 になります。nested root error がなく、migration shadow が二重 load されないことも確認します。rollback は `tools.conf` から `ecc` 行だけを外して有効登録を 0 件に戻し、残した `profiles/ecc/profile.tsv` から legacy fallback を再開します。

### Stage 4: Cut Over Namespaces

影響の小さい `.agents`、`.codex`、`.claude` の順に切り替えます。各 namespace で既知 root の旧 link を scoped uninstall し、base + registered tool の新 desired state を scoped install します。

```bash
cd "$DOTPATH"
for namespace in .agents .codex .claude; do
    bash uninstall.sh --namespace "$namespace"
    bash install.sh --namespace "$namespace"
    bash status.sh --namespace "$namespace" --verbose
done
bash status.sh --verbose
```

各 scoped status と最終 global status で missing / conflicts / stale / orphaned が 0 であることを確認します。通常 file と runtime state は残します。途中失敗時は完了済み namespace を同じ scoped uninstall で外し、`tools.conf` から `ecc` 行だけを外して archive 前の leaf から `bash install.sh` を再実行します。

### Stage 5: Import Personal Assets and Archive Branches

leaf の非 ECC asset を upstream tree と照合し、base surface として `main` へ取り込みます。全 test と status が通った後、local profile branch に `archive/` prefix を付けます。archive refs の旧 `profiles/ecc/` を確認してから main の migration shadow と legacy fallback を削除します。remote branch は変更しません。

```bash
git -C "$DOTPATH" branch --list 'profile/ecc*'
git -C "$DOTPATH" branch -r --list 'origin/profile/ecc*'
git -C "$DOTPATH" diff --name-status profile/ecc-base..profile/ecc/full/home-9M2KERO
bash "$DOTPATH/scripts/install/test-all.sh"
bash "$DOTPATH/status.sh" --verbose
git -C "$DOTPATH" branch -m profile/ecc/full/home-9M2KERO archive/profile/ecc/full/home-9M2KERO
git -C "$HOME/dotfiles-worktrees/profile-ecc-base" branch -m archive/profile/ecc-base
git -C "$DOTPATH" branch --list 'archive/profile/ecc*'
git -C "$DOTPATH" branch -r --list 'origin/profile/ecc*'
git -C "$DOTPATH" show archive/profile/ecc/full/home-9M2KERO:profiles/ecc/profile.tsv >/dev/null
```

個人 asset が main に存在し、archive branch 2 本が local に残り、remote ref が不変であることを確認します。branch rename は point of no easy return ですが、履歴と旧 desired state は失われません。

### Stage 6: Make Main the Active Checkout

Git は同じ branch を複数 worktree へ checkout できないため、main worktree が clean であることを確認して解放します。その後、本体を `main` へ切り替えて全 layer を reconcile します。

```bash
git -C "$HOME/dotfiles-worktrees/main" status --short
git -C "$DOTPATH" worktree remove "$HOME/dotfiles-worktrees/main"
cd "$DOTPATH"
git switch main
bash install.sh
bash status.sh --verbose
bash scripts/install/test-all.sh
```

main checkout、全 test PASS、missing / conflicts / stale / orphaned 0 を確認します。F6 worktree は安全要件ではなく、並行編集時の任意の利便性になります。

## S10. Rollback

rollback は link owner を認識できる registry が残っている間に tool link を外し、その後で旧 branch へ戻します。

| Failure point | Rollback |
|---|---|
| Stage 0 | baseline 不成立の原因を直し、移行を開始しません。 |
| Stage 1 | multi-root 実装 commit を revert し、legacy test を再実行します。 |
| Stage 2 | registry 未登録の staging を隔離または再生成し、実 HOME は触りません。 |
| Stage 3 | `tools.conf` から `ecc` 行だけを外して有効登録を 0 件に戻し、migration shadow の `profiles/ecc/profile.tsv` から旧 desired state を再読込します。 |
| Stage 4 | registry を残したまま切替済み namespace を uninstall し、`ecc` 行を外して有効登録を 0 件に戻してから leaf の旧 installer で再 link します。 |
| Stage 5 | archive branch を元の local 名へ rename するか、archive 名のまま checkout して旧構成を適用します。 |
| Stage 6 | tool layer を uninstall し、archive leaf を checkout して旧 `bash install.sh` を実行します。 |

最終手段では、先に新 installer と registry が全 staging-root link を認識できる状態で次を実行します。

```bash
cd "$DOTPATH"
bash uninstall.sh
git switch archive/profile/ecc/full/home-9M2KERO
bash install.sh
bash status.sh --verbose
```

archive branch を checkout して `bash install.sh` を再実行すれば旧構成に完全復帰できます。archive が旧 manifest と tracked generated output を保存するためです。先に tool link を uninstall しないと、旧 installer は staging-root link を未管理 conflict と判断するため順序を逆にしません。

どの rollback でも `bash status.sh` の missing / conflicts / stale / orphaned 0 と、Stage 0 の baseline 出力との一致を確認します。baseline 差分が残る場合は移行を再開しません。

## S11. Test Plan

`scripts/install/tests/harness.sh` の `copy_installer_files` と `setup_fixture` に registry file 注入、常時有効 base manifest、第 2 staging-root fixture を追加します。fixture は実 HOME と実 registry を使わず、すべて `/tmp` 内で完結させます。

新規 regression case は次を追加します。

- 外部 root からの entries / whole link、cleanup、namespace-scoped uninstall
- cross-layer dest 衝突の hard error と両 claimant 表示
- declaration conflict 時に cleanup や link が部分実行されないこと
- exact dest と `whole` ancestor / descendant 衝突
- explicit skipset による唯一の衝突解消
- 未登録 tool root への link の stale / orphaned attention
- duplicate、ancestor、descendant root と `~` / `..` registry path の拒否
- registered root 欠損の hard error
- lock の pinned commit と clone HEAD の一致 / 不一致
- registry file がない場合と有効登録 0 件の場合の legacy fallback、registry mode の非二重 load

`scripts/install/test-profile.sh:249` の `check_surface_outputs` は `surfaces.tsv` を 6 列固定で読み、`:263` で現行 resolve 関数を呼びます。manifest 列は維持しますが解決基準が変わるため、owning root fixture と同時に更新します。内部 `MANAGED_SURFACES` の追加列を読む reconcile / status helper の test も更新します。

既存 invariant は 7 case files、40 `register_test` の全 PASS です。新規 case を追加しても既存 case の意味と message assert を維持し、最後に `bash scripts/install/test-all.sh` で lint、全 regression、active smoke test を通します。実装時の coverage は unit、integration、migration fixture を含め 80% 以上を要求します。

## S12. Roadmap Impact and Adoption Decision

移行判断は実装より先に次の基準で行います。

1. staging root の fresh install が lock の pinned commit と expected counts を再現します。
2. registry loader が missing / nested / duplicate root を mutation 前に拒否します。
3. desired-dest preflight が全 claimant を表示し、silent shadowing を許しません。
4. namespace cutover と rollback が fixture で検証され、旧構成の baseline へ戻せます。
5. base-owned merged file と個人 asset が tool regeneration で失われません。

この基準を満たす実装計画として、案Cを **実装する** と判断します。案B最大の論点だった ignored local state の移送を staging root 内の自然な配置で解消し、branch propagation と生成物 commit をなくします。新規の multi-root guard は必要ですが、F2 の同期補助を中止し、F6 を任意化し、F4 を lock 比較へ縮小できるため、追加される仕組みより削除できる運用と計画 task が多いことが根拠です。

| Roadmap item | 処遇 |
|---|---|
| F7 | 本設計で supersede します。案B本文は履歴として保持します。 |
| F2 | main と profile branch の同期対象がなくなるため中止します。 |
| F1 | tool ごとの registry 登録 / deregister による per-layer enable へ自然化します。 |
| F4 | lock の pinned commit と upstream clone HEAD の比較へ還元します。 |
| F6 | main 一本化後は任意の worktree 利便性へ降格します。 |
| Phase 0〜3 | test、CI、manifest schema、docs の資産をすべて継続利用します。 |

案C用の受け入れ基準は次です。F7 の案B固有 checkbox は流用しません。

- [x] 設計文書が Design Checklist 12 項目をすべて扱っています。
- [x] 移行手順と rollback 手順が stage ごとの検証コマンド付きで書かれています。
- [x] 実装可否の判断と根拠が記録されています。
- [ ] 実装時に multi-root 対応と regression test が追加されています。
- [ ] 移行後、実 HOME の managed symlink が base または registry 登録 root を指し、`status.sh` の missing / conflicts / stale / orphaned が 0 です。
- [ ] rollback 手順が dry-run または fixture で確認済みです。

移行後、registry / lock schema と ECC lifecycle 対応の恒久的内容は通常 docs へ昇格します。本文書は D7 に従い improvement-plan とともに archive します。D8-2 の対象は `design/deploy-worktree.md` から本文書へ読み替え、top-level README、worktree 文書、manual、lifecycle、reference を main 一本 + external tool layers の現行仕様へ更新します。
