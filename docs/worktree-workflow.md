# Worktree Workflow

- Last reviewed: 2026-09-26

この文書は、`~/dotfiles` 本体を `main` に常駐させたまま、実験用の branch を安全に扱うための運用規則です。

## Background

実 HOME の symlink は `~/dotfiles` 配下の tracked desired state を指します。この working tree は、適用済み desired state の実体であると同時に、branch を切り替えて編集できる Git checkout でもあります。

`main` だけを適用する現在の構成では、`main` を直接編集・commit してかまいません。変更を HOME に反映するときは `bash install.sh` を再実行します。

一方、`~/dotfiles` 本体で別 branch に切り替えると、その branch に無い file を指す HOME 側の symlink が dangling になります。その状態で `install.sh` を実行すると、stale cleanup により dangling link が削除されます。

## Rules

`~/dotfiles` 本体は `main` に常駐させます。`main` 以外の branch で試す作業は、repo 外に作った `git worktree` で行います。

標準の配置は `~/dotfiles-worktrees/<branch>` です。repo 内に `.worktrees/` のような directory を作ると、top-level dotfile の link 対象候補や skip rule と干渉し得るため使いません。

`install.sh`, `uninstall.sh`, `status.sh` は、`DOTPATH=$HOME/dotfiles` の本体 checkout に対して実行します。worktree を `DOTPATH` に指定して install すると、HOME の symlink が一時作業用 worktree を指し、worktree 削除時にリンクが壊れるため禁止です。

適用する構成そのものを切り替える場合 (たとえば archive branch への rollback) だけは、先に `bash uninstall.sh` で link を外してから本体 checkout の branch を切り替え、`bash install.sh` を実行します。

## Command Examples

実験用 branch の worktree を作る例です。

```bash
mkdir -p ~/dotfiles-worktrees
cd ~/dotfiles
git worktree add ~/dotfiles-worktrees/<branch> -b <branch>
cd ~/dotfiles-worktrees/<branch>
```

worktree 内では、installer regression test を実 HOME に触らず実行できます。

```bash
bash scripts/install/test-all.sh --branch <branch>
```

作業を `main` に取り込んだら、本体で merge して HOME を追従させ、worktree を外します。

```bash
cd ~/dotfiles
git merge <branch>
bash install.sh
git worktree remove ~/dotfiles-worktrees/<branch>
```

## Recovery

やむを得ず `~/dotfiles` 本体で別 branch へ切り替えてしまった場合は、`main` へ戻してから installer を再実行します。

```bash
cd ~/dotfiles
git switch main
bash install.sh
bash status.sh
```

branch を戻るだけで dangling symlink は解消します。stale cleanup 済みでリンクが削除されている場合も、`install.sh` が `main` の desired state から再作成します。
