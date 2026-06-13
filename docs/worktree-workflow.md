# Worktree Workflow

- Last reviewed: 2026-06-13

この文書は、`~/dotfiles` 本体を適用中の profile branch に常駐させたまま、`main` や `profile/ecc-base` の編集を安全に行うための運用規則です。

## 背景

実 HOME の symlink は `~/dotfiles` 配下の tracked desired state を指します。この working tree は、適用済み desired state の実体であると同時に、branch を切り替えて編集できる Git checkout でもあります。

そのため、編集作業のために `~/dotfiles` 本体を `main` へ切り替えると、profile branch にだけ存在する `.claude/`, `.codex/`, `.agents/` の ECC output が作業ツリーから消え、HOME 側の symlink が dangling になります。その状態で `install.sh` を実行すると、stale cleanup により dangling link が削除されます。

## 運用規則

`~/dotfiles` 本体は、実 HOME に適用している profile branch に常駐させます。`main` や `profile/ecc-base` の編集・commit 作業は、repo 外に作った `git worktree` で行います。

標準の配置は `~/dotfiles-worktrees/<branch>` です。repo 内に `.worktrees/` のような directory を作ると、top-level dotfile の link 対象候補や skip rule と干渉し得るため使いません。

`install.sh`, `uninstall.sh`, `status.sh` は、通常どおり `DOTPATH=$HOME/dotfiles` の本体 checkout に対して実行します。worktree を `DOTPATH` に指定して install すると、HOME の symlink が一時作業用 worktree を指してしまい、worktree 削除時にリンクが壊れるため禁止です。

適用する profile そのものを切り替える場合だけは、本体 checkout で意図的に branch を切り替えてから `bash install.sh` を実行します。F6 が避けるのは、編集や commit のための一時的な checkout 切り替えです。

## Command Examples

`main` の作業用 worktree を作る例です。

```bash
mkdir -p ~/dotfiles-worktrees
git -C ~/dotfiles worktree add ~/dotfiles-worktrees/main main
cd ~/dotfiles-worktrees/main
```

worktree 内では、installer regression test を実 HOME に触らず実行できます。

```bash
bash scripts/install/test-all.sh --branch main
```

作業後、不要になった worktree は次のように外します。

```bash
git -C ~/dotfiles worktree remove ~/dotfiles-worktrees/main
git -C ~/dotfiles worktree list
```

## Merge Back To Active Profile

`main` で共通資産を更新したら、必要に応じて `profile/ecc-base` へ merge し、さらに適用中 profile branch へ merge します。適用中 profile への取り込みは、`~/dotfiles` 本体をその branch に乗せたまま行います。

```bash
cd ~/dotfiles
git branch --show-current
git merge profile/ecc-base
bash install.sh
```

merge により tracked desired state が変わった場合は、`bash install.sh` を再実行して HOME 側の symlink を追従させます。差分確認だけなら `bash install.sh --dry-run` と `bash status.sh` を先に実行します。

## Recovery

やむを得ず `~/dotfiles` 本体で `main` などへ切り替えてしまった場合は、適用 branch へ戻してから installer を再実行します。

```bash
cd ~/dotfiles
git switch profile/ecc/full/home-9M2KERO
bash install.sh
bash status.sh
```

branch を戻るだけで dangling symlink は解消します。stale cleanup 済みでリンクが削除されている場合も、`install.sh` が現在の profile branch の desired state から再作成します。

## F6 Verification

2026-06-13 時点で、`~/dotfiles` 本体は `profile/ecc/full/home-9M2KERO` に残したまま、作業用 worktree から `bash scripts/install/test-all.sh --branch main` を実行する運用を検証対象にしています。worktree は repo 外に作り、`DOTPATH` を worktree に向けた install は行いません。
