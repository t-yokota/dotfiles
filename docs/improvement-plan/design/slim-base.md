# Slim Base Design (案D)

- Last reviewed: 2026-09-26
- 前提: [external-tool-layers.md](external-tool-layers.md) (案C)、[03-roadmap.md](../03-roadmap.md)、[profile-manifest.md](../../reference/profile-manifest.md)

この文書は、dotfiles の管理対象を「自分で書いた個人設定」だけに絞り、`main` 一本を実 HOME に適用する構成を定義します。案C (external tool layers) を supersede します。installer、manifest、test、CI の仕組みはそのまま残します。

## 実施記録 (2026-09-26)

| Task | 状態 | 証跡 |
|---|---|---|
| 方針決定 | 完了 | ユーザー合意。ECC は導入しない。 |
| `main` に base profile と個人設定を追加 | 完了 | `bash scripts/install/test-all.sh --branch main` 全 PASS。 |
| 実 HOME の cutover | 未着手 | `uninstall.sh` → `git switch main` → `install.sh` の後、`status.sh` で確認する。 |
| 旧 branch の archive | 未着手 | `archive/profile/ecc-base`, `archive/profile/ecc/full/home-9M2KERO` へ rename する (local のみ)。 |

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
