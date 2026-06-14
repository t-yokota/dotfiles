# dotfiles

個人用 dotfiles です。共通で使う設定は `main` に置き、特定のツール構成や生成物が必要な場合は profile branch で管理します。

このリポジトリは単なる設定ファイルの置き場ではなく、自分の作業環境で様々なポリシーを切り替えながら試すことができる土台になっています。<br>特に AI agent のツールはベストプラクティスが変わり続ける可能性があるため、ベースは薄く保ち、特定ツールとの連携や agent profile 自体は branch と manifest の単位で切りながら扱います。

`.claude/`, `.codex/`, `.agents/` のような managed root は、directory root 全体を HOME に symlink しません。credential、cache、session などの runtime state は実 HOME 側に残した上で、再現したい desired state だけを managed surface で管理します。<br>これにより、ベストプラクティスへの追従、複数の policy の切り替え、試行錯誤を git の履歴として扱えるようにします。

## Contents

- [Branch Strategy](#branch-strategy)
- [Repository Layout](#repository-layout)
- [Install](#install)
- [Installer Flow](#installer-flow)
- [Managed Dotfile Surfaces](#managed-dotfile-surfaces)
- [Safety Rules](#safety-rules)
- [Roadmap](#roadmap)

## Branch Strategy

`main` は portable な base branch です。共通 dotfiles、共通 installer、共通 ignore rule を置きます。特定環境で生成された tool output や local install state は含めません。<br>profile branch は、top-level dotfile だけでは足りない構成を扱うために使います。profile manifest、branch-specific check、手順書、ツールの desired state などを追加できます。

基本形は次のようにします。

```text
main
profile/<name>-base
profile/<name>/<environment>
```

`*-base` branch は profile の共通構造と手順を置くための branch です。できるだけ portable に保ちます。local path を含む生成物や machine-local な sync marker が必要な場合は、base branch から環境別 branch を切って、その branch で tool installer を実行します。<br>たとえば ECC profile では、`profile/ecc-base` に installer 連携や手順を置き、実際の Claude / Codex 生成物や local sync marker は `profile/ecc/<environment>` 側で管理します。

`~/dotfiles` 本体は、実 HOME に適用中の profile branch に常駐させます。`main` や `profile/ecc-base` の編集・commit 作業は repo 外の `git worktree` で行い、`DOTPATH` を worktree に向けて `install.sh` を実行しません。共通資産を適用環境へ取り込むときは、本体 checkout を適用 branch に乗せたまま merge し、必要に応じて `bash install.sh` を再実行します。詳しい手順と復旧方法は [docs/worktree-workflow.md](docs/worktree-workflow.md) を参照します。

既存 profile を元に別 profile を作る場合は、`profiles/<name>/` を profile の資産として一式コピーします。`profile.tsv`, `surfaces.tsv`, `skipsets.tsv`, `checks.d/` だけでなく、`bin/` に置いた profile-local な補助 script や smoke test も移植対象です。移植後は `profile.tsv` の branch pattern を新しい profile 名に合わせ、`bash profiles/<name>/bin/test-profile.sh --branch profile/<name>-base` で profile が単独で適用可能か確認します。

## Repository Layout

この repository は、portable な top-level dotfiles、共通 installer、profile branch 固有の manifest / check / 補助 script を分けて管理します。

| Path | Role |
|---|---|
| `install.sh`, `uninstall.sh`, `status.sh` | HOME へ symlink する / 外す / 状態を見る entrypoint。 |
| `scripts/install/lib/` | CLI bootstrap、profile manifest loader、reconcile engine、status reporter。 |
| `scripts/install/test-*.sh` | 実 HOME を触らない regression / profile smoke test。 |
| `profiles/<name>/` | profile branch 固有の `profile.tsv`, `surfaces.tsv`, `skipsets.tsv`, `checks.d/`, `bin/`。 |
| `.claude/`, `.codex/`, `.agents/` | managed root。root 全体ではなく、profile manifest の surface 単位で HOME に出す。 |
| `docs/` | 長い仕様・手順・reference。索引は [docs/README.md](docs/README.md)。 |

installer を変更する場合は、構成とテスト追加手順を [docs/development.md](docs/development.md) で確認します。

## Install

適用したい branch を checkout した状態で、Bash から installer を実行します。<br>`install.sh` は Bash 前提です。`sh install.sh` では実行せず、誤って Bash 以外から起動された場合は早期に終了します。

```bash
cd ~/dotfiles
bash install.sh
```

実際に symlink を作る前に確認したい場合は、`--dry-run` または短縮形の `-n` を使います。<br>profile manifest、branch-specific check、cleanup 対象、link conflict、作成予定件数を確認しますが、共通 installer は directory 作成、symlink 作成、cleanup を書き込みません。個々の path まで確認したい場合は `--verbose` を併用します。

```bash
bash install.sh --dry-run
bash install.sh --dry-run --verbose
bash install.sh --verbose
bash install.sh --help
```

現在の dotfiles checkout が実 HOME に作った symlink をまとめて外したい場合は、`uninstall.sh` を使います。`install.sh` と同じく `--dry-run` / `-n` で削除予定だけを確認できます。

```bash
bash uninstall.sh --dry-run
bash uninstall.sh --dry-run --verbose
bash uninstall.sh --verbose
bash uninstall.sh
```

`install.sh` / `uninstall.sh` の通常表示は phase ごとの OK と Result が中心です。link / remove / skip の件数は section ごとの OK と最後の Result に表示されます。link / remove / skip 単位の詳細ログを確認したい場合は、`--verbose` または短縮形の `-v` を使います。`--dry-run` 単体では件数 summary を表示し、`--dry-run --verbose` では個々の予定 path も表示します。

現在の link 状況を確認したい場合は、`status.sh` を使います。`status.sh` は read-only で、実 HOME へ書き込みません。通常表示では section ごとの件数と Result を表示し、個別の path まで確認したい場合は `--verbose` または短縮形の `-v` を使います。分類の意味は [docs/reference/status-classification.md](docs/reference/status-classification.md) を参照します。

```bash
bash status.sh
bash status.sh --verbose
```

installer と active profile の動作確認には、実際の `~/dotfiles` や `$HOME` を変更しない verification script を使います。通常は `test-all.sh` を実行します。

```bash
bash scripts/install/test-all.sh
```

個別 case の実行や test 追加手順は [docs/development.md](docs/development.md) にまとめています。共通 installer だけを確認したい場合は、次の regression test を使います。

```bash
bash scripts/install/test-installer.sh
```

profile smoke test だけを確認する場合は、profile 側の wrapper を実行します。たとえば ECC profile では、その profile 自体が一時 HOME に適用できるかを次のコマンドで確認できます。

```bash
bash profiles/ecc/bin/test-profile.sh
```

## Installer Flow

`install.sh` は `DOTPATH=~/dotfiles` を起点に、現在 checkout されている branch の desired state を実 HOME に symlink します。通常ファイルを上書きせず、cleanup / uninstall はこの dotfiles checkout が作った symlink だけを対象にします。

大きな流れは Preflight → Cleanup → Link Conflict Check → Link Top-Level Dotfiles → Link Managed Dotfile Surfaces → Link Shell Themes です。詳細な責務分担、global state、test case の追加手順は [docs/development.md](docs/development.md) を参照します。

`.git`, `.github`, `.gitignore`, `.gitconfig.local`, `.claude`, `.codex`, `.agents` は top-level symlink 対象から外します。`.claude`, `.codex`, `.agents` は managed root として扱い、profile が有効な場合だけ surface 定義に従って必要な entry を HOME に出します。

## Managed Dotfile Surfaces

managed dotfile surface は、profile branch が managed root 配下の desired state をどの粒度で HOME に出すかを宣言する単位です。root directory 自体は実 HOME に残し、credential、cache、session などの runtime state と dotfiles 管理 entry を共存させます。

主な strategy は、directory 内の entry を個別に symlink する `entries` と、directory / file を package として symlink する `whole` です。manifest schema、検証規則、skipset include、branch-specific checks の詳細は [docs/reference/profile-manifest.md](docs/reference/profile-manifest.md) を参照します。

### Profile Manifest Schema

manifest schema の詳細は [docs/reference/profile-manifest.md](docs/reference/profile-manifest.md) に分離しています。ここでは profile を読む時の最小構造だけを示します。

```text
profile.tsv    branch pattern と関連 manifest path
surfaces.tsv   DOTPATH 側 desired state を HOME へ出す surface 定義
skipsets.tsv   entries surface で除外する entry 名 pattern と include 定義
checks.d/      profile branch 適用前に走る branch-specific check
```

`skipsets.tsv` では `skipset	<name>	<pattern>` に加えて、`skipset-include	<name>	<include-name>` で共通 pattern 群を合成できます。include 先は前方参照できず、自己 include・循環 include・重複 include は invalid です。

## Safety Rules

- `install.sh` は未管理の通常ファイルを上書きしません。
- `uninstall.sh` は、この dotfiles checkout を指す symlink だけを削除します。通常ファイルや directory は削除しません。
- cleanup は、この dotfiles checkout を指す symlink だけを削除します。
- `entries` surface の link 先 directory と `whole` surface の親 directory は、通常 directory である必要があります。未管理 symlink 越しには書き込みません。
- credential、cache、backup、machine-local config といった local / runtime state は shared commit に含めません。

## Roadmap

今後の改善候補は [docs/improvement-plan/03-roadmap.md](docs/improvement-plan/03-roadmap.md) に集約します。共通 dotfiles 基盤、profile 固有の改善、案B deploy worktree 移行、将来の profile 補助 script は roadmap の Phase 順で扱います。
