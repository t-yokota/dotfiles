# Slim Base Design (案D)

- Last reviewed: 2026-09-26
- 前提: [external-tool-layers.md](external-tool-layers.md) (案C)、[03-roadmap.md](../03-roadmap.md)、[profile-manifest.md](../../reference/profile-manifest.md)

この文書は、dotfiles の管理対象を「自分で書いた個人設定」だけに絞り、`main` 一本を実 HOME に適用する構成を定義します。案C (external tool layers) を supersede します。installer、manifest、test、CI の仕組みはそのまま残します。

## 実施記録 (2026-09-26)

| Task | 状態 | 証跡 |
|---|---|---|
| 方針決定 | 完了 | ユーザー合意。ECC は導入しない。 |
| `main` に base profile と個人設定を追加 | 完了 | `bash scripts/install/test-all.sh --branch main` 全 PASS。 |
| 実 HOME の cutover | 完了 | `uninstall.sh` (旧 link 510 本を削除) → `git switch main` → `install.sh` (13 本を link)。`status.sh` は linked 13 / missing・conflicts・stale・orphaned 0。空になった ECC 用 directory (`~/.claude/rules`, `~/.claude/skills/ecc`, `~/.claude/.agents`, `~/.codex/prompts`, `~/.agents`) を削除。 |
| 旧 branch の archive | 完了 | `archive/profile/ecc-base`, `archive/profile/ecc/full/home-9M2KERO` へ rename (local のみ、未 push)。旧 worktree 2 つを削除。 |

## Background

案C は、ECC の生成物 (約 800 files / 15 万行) を git 外の staging root に置き、registry と lock で複数 source root を reconcile する設計でした。その後、次の 2 点で前提が変わりました。

1. ECC を含む外部 tool は、Claude Code / Codex のネイティブ plugin として配布されるようになった。配置・更新・version pin・有効化は tool 側の plugin 機構が担う (`enabledPlugins`, marketplace の `#ref`, `installed_plugins.json` の `gitCommitSha`)。
2. モデルが賢くなり、常時ロードされる大量の指示はむしろ性能を下げる。公式ガイドは CLAUDE.md を 200 行未満に保ち、推測できることは書かないよう求めている。旧構成では `paths:` を持たない rules 約 54KB (同内容の中国語訳を含む) と skill / agent / command の説明約 56KB が毎ターン読み込まれていた。

外部 tool の desired state を dotfiles が抱える理由がなくなったため、staging root、registry、lock、regenerate wrapper、multi-root reconcile は実装しません。

## Policy

- dotfiles が管理するのは、自分で書いた設定だけです。外部 tool が生成・配布するものは commit しません。
- 外部 tool を使うときは、その tool の plugin 機構で入れます。常時有効にせず、必要な project の local scope で有効にすることを優先します。
- 指示ファイルは短く保ちます。追加するのは「2 回間違えたこと」だけで、必ず守らせたいものは hook にします。rules は置かず、必要になったら `paths:` 付きで追加します。

## Layout

| Path | 内容 |
|---|---|
| `.claude/CLAUDE.md` | 個人の好み (emoji 禁止、commit 形式、secret の扱い、Bash の書き方)。 |
| `.claude/settings.json` | model、permission、plugin 有効化などの個人設定。 |
| `.claude/skills/orchestrator-playbook/` | 自作 skill。役割ごとのモデル割り当て表もここに統合。 |
| `.codex/config.toml`, `.codex/AGENTS.md`, `.codex/agents/*.toml` | Codex の個人設定と subagent 定義。 |
| `profiles/base/` | すべての branch で有効な profile (`branch *`)。surface は `.claude`, `.claude/skills`, `.codex`, `.codex/agents`。 |

`.claude/skills` と `.codex/agents` は child `entries` surface にしています。HOME 側の directory を実体のまま保つためで、`claude plugin init` などが `~/.claude/skills/` に作るものが repo に入り込みません。

`.agents/` は管理対象から外しました。

## Installer Changes

installer 本体の変更はありません。profile は既存どおり `profiles/*/profile.tsv` の branch glob で有効になります。

`scripts/install/test-profile.sh` の smoke test は、`profile/<name>-base` と `profile/<name>/*` の branch pattern を必須にしていました。これは branch 積層の命名規約であり、`main` で有効な base profile とは合わないため、「branch pattern が 1 つ以上あり、検査対象の branch で有効になること」だけを確認するように緩めました。

## Roadmap Impact

| Item | 処遇 |
|---|---|
| 案C (external tool layers) | 本設計で supersede。Stage 1 以降は実施しない。文書は履歴として残す。 |
| F1 (Claude / Codex 選択適用) | 不要。plugin の有効化 / 無効化で代替。 |
| F2 (main ↔ profile 同期補助) | 中止。同期する branch がない。 |
| F4 (ECC upstream 更新チェック) | 中止。ECC を導入しない。 |
| F6 (worktree 運用) | 任意に降格。`main` を直接編集してよい。 |
| F3 (profile scaffolding) | 保留。profile を増やす必要が出た時点で再検討。 |

## Migrating Other Machines

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
    - `git config --global --get core.hooksPath` が ECC の hook directory を指していれば、`git config --global --unset core.hooksPath` で外します。
    - checkout 内の ignored な ECC state (`.claude/ecc/`, `.codex/*sync-state.json`, `.codex/git-hooks/` など) は、rollback に使うため残します。

7. Claude Code と Codex を再起動し、Claude では `/context` を実行して、常時ロードされる memory が `~/.claude/CLAUDE.md` だけであることを確認します。

## Rollback

旧構成へ戻す場合は、tool link を外してから archive branch を適用します。archive branch の preflight check が参照する ECC の local state (`.claude/ecc/`, `.codex/dotfiles-profile-ecc-sync-state.json` など、ignored) は checkout 内に残してあります。

```bash
cd ~/dotfiles
bash uninstall.sh
git switch archive/profile/ecc/full/home-9M2KERO
bash install.sh
bash status.sh --verbose
```

## Verification

- `bash scripts/install/test-all.sh --branch main` が全 PASS すること。
- cutover 後、`bash status.sh` の missing / conflicts / stale / orphaned が 0 であること。
- 新しいセッションで `/context` を実行し、常時ロードされる memory files が `~/.claude/CLAUDE.md` だけであること。
