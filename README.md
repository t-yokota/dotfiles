# dotfiles

個人用 dotfiles です。自分で書いた設定だけを `main` に置き、`main` をそのまま実 HOME に適用します。

このリポジトリは単なる設定ファイルの置き場ではなく、自分の作業環境で様々なポリシーを切り替えながら試すことができる土台になっています。特に AI agent のツールはベストプラクティスが変わり続けるため、管理対象は薄く保ちます。外部 tool が生成・配布する skill や rule 群は commit せず、必要ならその tool の plugin 機構で導入します。

`.claude/`, `.codex/`, `.agents/` 等のディレクトリには各ツールの runtime state が含まれるため、本 dotfiles では managed root として扱います。root 全体を HOME に symlink せず、credential、cache、session などの runtime state は実 HOME 側に残した上で、再現したい desired state だけを dotfiles 側で管理します。

これにより、ベストプラクティスへの追従、複数の policy の切り替え、試行錯誤を git の履歴として扱えるようにします。

## Contents

- [Branch Strategy](#branch-strategy)
- [Repository Layout](#repository-layout)
- [Installer Flow](#installer-flow)
- [How to Install](#how-to-install)
- [Managed Dotfile Surfaces](#managed-dotfile-surfaces)
- [Safety Rules](#safety-rules)
- [Roadmap](#roadmap)

## Branch Strategy

`~/dotfiles` 本体は `main` に常駐させ、`main` の desired state を実 HOME に適用します。`profiles/base/` はすべての branch で有効な profile で、`.claude/` と `.codex/` の個人設定を HOME へ link します。

`main` は直接編集してかまいません。実験用の branch を試したい場合は repo 外の `git worktree` で作業し、`DOTPATH` を worktree に向けて `install.sh` を実行しません。詳しくは [docs/worktree-workflow.md](docs/worktree-workflow.md) を参照します。

以前は `main` → `profile/ecc-base` → `profile/ecc/<environment>` の branch 積層で ECC の生成物を管理していました。この構成は [docs/improvement-plan/design/slim-base.md](docs/improvement-plan/design/slim-base.md) の方針で廃止し、旧 branch は `archive/` 配下に残しています。

別の profile を追加する場合は、`profiles/<name>/` に `profile.tsv`, `surfaces.tsv`, `skipsets.tsv`, 必要なら `checks.d/` と `bin/test-profile.sh` を置きます。具体的な作成・検証手順は [docs/development.md](docs/development.md) を参照します。

## Repository Layout

このリポジトリでは、portable な top-level dotfiles、共通 installer、profile manifest、agent tool の個人設定を管理します。

| Path | Role |
|---|---|
| `install.sh`, `uninstall.sh`, `status.sh` | この dotfiles の entrypoint。HOME へ symlink する / symlink を外す / symlink の状態を確認する。 |
| `scripts/install/lib/` | CLI bootstrap、profile manifest loader、reconcile engine、status reporter。 |
| `scripts/install/test-*.sh` | 実 HOME を触らない regression / profile smoke test。 |
| `profiles/<name>/` | `profile.tsv`, `surfaces.tsv`, `skipsets.tsv`, `checks.d/`, `bin/`。`profiles/base/` は全 branch で有効。 |
| `.claude/`, `.codex/` | managed root。自分で書いた agent tool の設定だけを置き、profile manifest の surface 単位で HOME に出す。 |
| `docs/` | 詳細な仕様・手順・reference。索引は [docs/README.md](docs/README.md)。 |

installer を変更する場合は、構成とテスト追加手順を [docs/development.md](docs/development.md) で確認します。

## Installer Flow

`install.sh` は、本ディレクトリ `DOTPATH=~/dotfiles` を起点に、現在 checkout されている branch の desired state を実 HOME に symlink します。実 HOME 側の通常ファイルは上書きせず、cleanup / uninstall はこの dotfiles checkout が作った symlink だけを対象にします。

大きな流れは Preflight → Cleanup → Link Conflict Check → Link Top-Level Dotfiles → Link Managed Dotfile Surfaces → Link Shell Themes です。詳細な責務分担、global state、test case の追加手順は [docs/development.md](docs/development.md) を参照します。

`.git`, `.github`, `.gitignore`, `.gitconfig.local`, `.claude`, `.codex`, `.agents` は top-level symlink 対象から外します。`.claude`, `.codex`, `.agents` は managed root として扱い、profile が有効な場合だけ surface 定義に従って必要な entry を HOME に出します。

## How to Install

適用したい branch を checkout した状態で、Bash から installer を実行します。`install.sh` は Bash 前提のため、`sh install.sh` では実行せず、誤って Bash 以外から起動された場合は早期に終了します。

```bash
cd ~/dotfiles
bash install.sh
```

実際に symlink を作る前に作成予定を確認したい場合は、`--dry-run` または短縮形の `-n` を使います。dry-run では directory 作成、symlink 作成、cleanup を書き込みません。リンク作成先の path まで個別に確認したい場合は `--verbose` を併用します。

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

現在の desired state と実 HOME の link 状態を確認したい場合は、`status.sh` を使います。`status.sh` は read-only で、実 HOME への書き込みはありません。作成済み / 未作成の link や conflict の path まで個別に確認したい場合は、`--verbose` または短縮形の `-v` を使います。結果の分類内容は [docs/reference/status-classification.md](docs/reference/status-classification.md) を参照してください。

```bash
bash status.sh
bash status.sh --verbose
```

installer や profile を変更するときの検証方法、個別 test の実行方法は [docs/development.md](docs/development.md) を参照します。

## Managed Dotfile Surfaces

managed dotfile surface は、managed root 配下にある source を、実 HOME 配下のどの dest へ、どの粒度で symlink するかを宣言する単位です。managed root directory 自体は実 HOME 側に残し、credential、cache、session などの runtime state は HOME-local な実体として保持します。再現したい entry だけを dotfiles 側の desired state として管理し、実 HOME 側へ symlink します。

主な strategy は、directory 内の entry を個別に symlink する `entries` と、file / directory 自体を 1 つの package として symlink する `whole` です。

### Profile Manifest Schema

manifest schema の詳細は [docs/reference/profile-manifest.md](docs/reference/profile-manifest.md) に分離しています。ここでは `profiles/<name>/` に配置する最小構造だけを示します。

```text
profile.tsv    profile を有効にする branch pattern と、使用する manifest / check の path
surfaces.tsv   managed root 配下の source を、entries / whole のどちらで HOME 内の dest へ symlink するか
skipsets.tsv   entries surface から除外して実 HOME に残す entry 名 pattern と、pattern 群の共有関係
checks.d/      profile 適用前に実行する branch-specific check
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
