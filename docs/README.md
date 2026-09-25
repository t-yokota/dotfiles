# Documentation Index

- Last reviewed: 2026-09-26

この directory は、dotfiles repository の手書きドキュメントを置く場所です。

## Documents

| Document | Description | Main reader | Origin |
|---|---|---|---|
| [development.md](development.md) | common installer の architecture、bash 規約、test 追加手順。 | installer を変更する人 / agent | 手書き |
| [worktree-workflow.md](worktree-workflow.md) | `~/dotfiles` 本体を `main` に常駐させ、実験用 branch を worktree で扱う運用。 | 共通資産を編集する人 / agent | 手書き |
| [reference/profile-manifest.md](reference/profile-manifest.md) | `profile.tsv`, `surfaces.tsv`, `skipsets.tsv`, `checks.d` の schema reference。 | profile を設計・変更する人 | 手書き |
| [reference/status-classification.md](reference/status-classification.md) | `status.sh` の linked / missing / conflicts / stale / orphaned / skipped 分類。 | install 状態を診断する人 / agent | 手書き |
| [improvement-plan/README.md](improvement-plan/README.md) | 改善計画全体の前提、実行規則、進め方。 | 改善作業を引き継ぐ agent / 人 | 計画文書 |
| [improvement-plan/01-documentation.md](improvement-plan/01-documentation.md) | ドキュメント品質向上 task 群。 | docs を整備する agent / 人 | 計画文書 |
| [improvement-plan/02-refactoring.md](improvement-plan/02-refactoring.md) | installer 一式のリファクタリング task 群。 | installer を変更する agent / 人 | 計画文書 |
| [improvement-plan/03-roadmap.md](improvement-plan/03-roadmap.md) | D / R / F task を依存関係順に統合した roadmap。 | 改善作業の進行管理者 | 計画文書 |
| [improvement-plan/design/slim-base.md](improvement-plan/design/slim-base.md) | 管理対象を個人設定だけに絞り、`main` 一本を適用する構成 (案D)。案C の後継。 | installer / profile 構成を変更する人 / agent | 計画文書 |
| [improvement-plan/design/external-tool-layers.md](improvement-plan/design/external-tool-layers.md) | main 一本 + 外部 tool layer への転換設計 (案C)。案D により superseded。 | installer / profile 構成を変更する人 / agent | 計画文書 |

## Freshness Rule

すべての docs 配下の Markdown は、冒頭 3 行以内に `Last reviewed: YYYY-MM-DD` を持ちます。内容に影響する変更を入れた commit では、その文書の `Last reviewed` を更新します。

## Origin Rule

dotfiles 側で手書き管理する文書は、この `docs/` directory と top-level [README.md](../README.md) です。`.claude/` と `.codex/` 配下の `CLAUDE.md`, `AGENTS.md`, skill は agent tool 向けの個人設定であり、この docs の対象外です。

## Related Reference

`archive/` は過去の dotfile 参照用で、installer の適用対象ではありません。top-level の `.??*` glob が対象なので、`archive/.bashrc` や `archive/.inputrc` は HOME に symlink されません。
