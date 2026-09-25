# Migration From the ECC Profile

- Last reviewed: 2026-09-26

この文書は、旧構成 (`main` → `profile/ecc-base` → `profile/ecc/<environment>` の branch 積層で ECC の生成物を管理していた構成) を適用している PC を、現在の `main` 一本の構成へ移す手順です。すべての PC の移行が終わり、archive branch による rollback が不要になったら、この文書は削除します。

## Background

2026-09-26 に、dotfiles の管理対象を自分で書いた設定だけに絞りました。ECC などの外部 tool は Claude Code / Codex の plugin として配布されるようになり、生成物を dotfiles に commit する理由がなくなったためです。モデルの性能向上により、常時ロードされる大量の指示 (旧構成では `paths:` なしの rules 約 54KB) がむしろ性能を下げることも理由です。現在の方針は top-level [README.md](../README.md) の Agent Tool Policy を参照します。

旧構成の設計・計画文書 (`docs/improvement-plan/`) は削除済みです。必要なら `git show 8cdd491:docs/improvement-plan/03-roadmap.md` のように、削除直前の commit から読めます。

移行済みの PC:

| PC | 状態 |
|---|---|
| home-9M2KERO | 2026-09-26 移行済み。旧 branch は `archive/profile/ecc-base`, `archive/profile/ecc/full/home-9M2KERO` (local のみ)。 |

## Migration Steps

旧構成 (`profile/ecc/*` の leaf branch、または旧 `main`) を適用している他の PC は、次の順で移行します。`~/dotfiles` で `git reset --hard` と `git clean` は使いません。

1. 現状を確認し、手元の変更を退避します。leaf の `.claude/settings.json` や `.codex/config.toml` に、その PC だけの変更が残っていることがあります。

    ```bash
    cd ~/dotfiles
    git status --short
    git branch --show-current
    git worktree list
    ```

    未 commit の変更は leaf 上で commit し、あとで `main` と比較できるようにします。`main` を checkout している worktree (`~/dotfiles-worktrees/main` など) があれば `git worktree remove` で外します。

2. 旧 link を外します。uninstall は、この checkout を指す symlink だけを削除します。

    ```bash
    bash uninstall.sh --dry-run
    bash uninstall.sh
    ```

3. `main` へ切り替え、leaf を archive 名にします。

    ```bash
    git fetch origin
    git switch main
    git merge --ff-only origin/main
    git branch -m <旧 leaf branch> archive/<旧 leaf branch>
    ```

4. 新構成を適用し、確認します。

    ```bash
    bash install.sh --dry-run
    bash install.sh
    bash status.sh
    ```

    conflict で止まった場合は、書き込み前に停止しています。表示された HOME 側の実ファイルを退避して再実行します。

5. 手順 1 で commit したその PC 固有の設定を `git diff main archive/<旧 leaf branch> -- .claude/settings.json .codex/config.toml` で比較し、必要な差分だけを `main` に取り込みます。Codex の `[projects."<path>"]` の trust 設定は、Codex が link 先の repo 内 `config.toml` へ直接書き込むため、PC ごとに差分として現れます。

6. 残骸を片付けます。
    - 空になった ECC 用 directory を削除します: `find ~/.claude/skills/ecc ~/.claude/rules ~/.claude/.agents ~/.codex/prompts ~/.agents -depth -type d -empty -delete`
    - ECC を plugin として入れていた場合は、`claude plugin list` で確認し、`claude plugin uninstall ecc@ecc` で外します。
    - `git config --show-origin --get core.hooksPath` が ECC の hook directory (`~/dotfiles/.codex/git-hooks` など) を指していれば、表示された設定ファイルから外します。ECC は machine-local な `~/.gitconfig.local` に書き込んでいることがあり、`--global` を付けると include 先が読まれず見落とします。例: `git config --file ~/.gitconfig.local --unset core.hooksPath`
    - checkout 内の ignored な ECC state (`.claude/ecc/`, `.codex/*sync-state.json`, `.codex/git-hooks/` など) は、rollback に使うため残します。rollback が不要になったら削除してかまいません。

7. Claude Code と Codex を再起動し、Claude では `/context` を実行して、常時ロードされる memory が `~/.claude/CLAUDE.md` だけであることを確認します。

## Rollback

旧構成へ戻す場合は、link を外してから archive branch を適用します。archive branch の preflight check が参照する ECC の local state (`.claude/ecc/`, `.codex/dotfiles-profile-ecc-sync-state.json` など、ignored) は checkout 内に残してあります。

```bash
cd ~/dotfiles
bash uninstall.sh
git switch archive/<旧 leaf branch>
bash install.sh
bash status.sh --verbose
```

ECC の git hook も戻す場合は、手順 6 で外した `core.hooksPath` を設定し直します。
