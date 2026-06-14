# Status Classification Reference

- Last reviewed: 2026-06-14

`status.sh` は実 HOME に書き込まず、現在の `DOTPATH` と active profile の desired state を実 HOME の symlink 状態と照合します。この文書は `status.sh` が出す linked / missing / conflicts / stale / orphaned / skipped の分類を、実装に合わせて定義します。

## Scope

`status.sh` が確認する対象は次の通りです。

| Scope | 判定対象 |
|---|---|
| Top-level dotfiles | `DOTPATH` 直下の `.??*` のうち、installer の reserved entry ではないもの |
| Managed surfaces | active profile の `surfaces.tsv` が定義する `entries` / `whole` surface |
| Shell themes | `DOTPATH` 直下の `*.zsh-theme` と `OH_MY_ZSH_THEMES` |
| Unexpected managed links | `HOME` 直下、managed root 配下、active surface の destination、shell theme directory 内の dotfiles-managed symlink |

`status.sh` は branch-specific install checks を実行しません。profile manifest の読み込みと symlink inventory の照合だけを行います。

## Classifications

| Classification | 実装上の条件 | 典型シナリオ | 対処 |
|---|---|---|---|
| `linked` | expected destination が symlink で、target が expected source と完全一致する。 | 既に `bash install.sh` 済みで、HOME が現在の checkout に追従している。 | 対処不要。 |
| `missing` | expected destination が存在しない。 | 新しい desired file を追加したが未 install。別 branch から戻った後に link がまだ再作成されていない。 | `bash install.sh --dry-run` で予定を確認し、問題なければ `bash install.sh` を実行する。 |
| `conflicts` | expected destination が symlink ではない通常 file / directory として存在する、または symlink だが expected source 以外を指す。`entries` surface の destination directory 自体が symlink の場合も conflict。 | HOME 側に同名の手動 file がある。別 checkout への symlink が残っている。managed root directory を丸ごと symlink してしまっている。 | 内容を確認して退避・削除・dotfiles 側へ統合する。解消後に `bash install.sh --dry-run` を再実行する。 |
| `stale` | expected destination ではない dotfiles-managed symlink があり、その target が存在しない。 | branch 切り替えで tracked desired state が消えた。削除済み file への古い symlink が HOME に残っている。 | `bash install.sh --dry-run` で cleanup 予定を確認し、`bash install.sh` で削除する。 |
| `orphaned` | expected destination ではない dotfiles-managed symlink があり、その target は存在するが current desired state には含まれない。 | surface 定義や skipset を変更し、以前は desired だった link が現在は対象外になった。 | まだ使うなら manifest / skipset を見直す。不要なら `bash install.sh --dry-run` で確認し、`bash install.sh` で cleanup する。 |
| `skipped` | `entries` surface で skipset に一致した entry、child surface が管理するため親 surface では defer された entry、または shell theme destination directory が存在しない場合。 | runtime state、credential、cache、child surface の package、oh-my-zsh 未導入環境。 | 通常は対処不要。意図しない skip なら `profiles/<name>/skipsets.tsv` と `surfaces.tsv` を確認する。 |

## Result Semantics

`missing`, `conflicts`, `stale`, `orphaned` の合計が 1 以上の場合、Status Result は `Check:` を表示します。通常表示では件数だけを出し、個別 path は `bash status.sh --verbose` で確認します。

`linked` と `skipped` は reportable issue ではありません。`skipped` は意図的な除外を示しますが、skipset の typo でも増え得るため、manifest 変更時は verbose output と regression test で確認します。
