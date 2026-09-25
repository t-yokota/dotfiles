# Documentation Index

- Last reviewed: 2026-09-26

この directory は、dotfiles repository の手書きドキュメントを置く場所です。

## Documents

| Document | Description | Main reader |
|---|---|---|
| [development.md](development.md) | common installer の architecture、bash 規約、test 追加手順。 | installer を変更する人 / agent |
| [worktree-workflow.md](worktree-workflow.md) | `~/dotfiles` 本体を `main` に常駐させ、実験用 branch を worktree で扱う運用。 | branch を切って試す人 / agent |
| [reference/profile-manifest.md](reference/profile-manifest.md) | `profile.tsv`, `surfaces.tsv`, `skipsets.tsv`, `checks.d` の schema reference。 | profile を設計・変更する人 |
| [reference/status-classification.md](reference/status-classification.md) | `status.sh` の linked / missing / conflicts / stale / orphaned / skipped 分類。 | install 状態を診断する人 / agent |
| [migration-from-ecc.md](migration-from-ecc.md) | 旧 ECC profile 構成を適用している PC の移行手順と rollback。全 PC の移行後に削除する。 | 他の PC を移行する人 / agent |

## Freshness Rule

すべての docs 配下の Markdown は、冒頭 3 行以内に `Last reviewed: YYYY-MM-DD` を持ちます。内容に影響する変更を入れた commit では、その文書の `Last reviewed` を更新します。

## Origin Rule

dotfiles 側で手書き管理する文書は、この `docs/` directory と top-level [README.md](../README.md) です。`.claude/` と `.codex/` 配下の `CLAUDE.md`, `AGENTS.md`, skill は agent tool 向けの個人設定であり、この docs の対象外です。

過去の計画文書 (`docs/improvement-plan/`) は削除済みです。`git show 8cdd491:docs/improvement-plan/<file>` で削除直前の版を読めます。

## Related Reference

`archive/` は過去の dotfile 参照用で、installer の適用対象ではありません。top-level の `.??*` glob が対象なので、`archive/.bashrc` や `archive/.inputrc` は HOME に symlink されません。
