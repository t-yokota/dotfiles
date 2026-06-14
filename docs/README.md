# Documentation Index

- Last reviewed: 2026-06-14

この directory は、dotfiles repository の手書きドキュメントを置く場所です。`.claude/`, `.codex/`, `.agents/` 配下の README や notes 類は ECC upstream / installer / sync 由来の生成物として扱い、dotfiles 側では直接編集しません。

## Documents

| Document | Description | Main reader | Origin |
|---|---|---|---|
| [development.md](development.md) | common installer の architecture、bash 規約、test 追加手順。 | installer を変更する人 / agent | 手書き |
| [worktree-workflow.md](worktree-workflow.md) | `~/dotfiles` 本体を適用 branch に常駐させ、他 branch 作業を worktree で行う運用。 | 共通資産を編集する人 / agent | 手書き |
| [reference/profile-manifest.md](reference/profile-manifest.md) | `profile.tsv`, `surfaces.tsv`, `skipsets.tsv`, `checks.d` の schema reference。 | profile を設計・変更する人 | 手書き |
| [improvement-plan/README.md](improvement-plan/README.md) | 改善計画全体の前提、実行規則、進め方。 | 改善作業を引き継ぐ agent / 人 | 計画文書 |
| [improvement-plan/01-documentation.md](improvement-plan/01-documentation.md) | ドキュメント品質向上 task 群。 | docs を整備する agent / 人 | 計画文書 |
| [improvement-plan/02-refactoring.md](improvement-plan/02-refactoring.md) | installer 一式のリファクタリング task 群。 | installer を変更する agent / 人 | 計画文書 |
| [improvement-plan/03-roadmap.md](improvement-plan/03-roadmap.md) | D / R / F task を依存関係順に統合した roadmap。 | 改善作業の進行管理者 | 計画文書 |

## Freshness Rule

すべての docs 配下の Markdown は、冒頭 3 行以内に `Last reviewed: YYYY-MM-DD` を持ちます。内容に影響する変更を入れた commit では、その文書の `Last reviewed` を更新します。

## Origin Rule

dotfiles 側で手書き管理する文書は、この `docs/` directory と top-level [README.md](../README.md) です。`.claude/`, `.codex/`, `.agents/` 配下の README・notes・schema notes は ECC 生成物または外部 tool の同期結果であり、再生成で上書きされ得るため直接編集しません。

## Related Reference

`archive/` は過去の dotfile 参照用で、installer の適用対象ではありません。top-level の `.??*` glob が対象なので、`archive/.bashrc` や `archive/.inputrc` は HOME に symlink されません。
