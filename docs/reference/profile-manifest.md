# Profile Manifest Reference

- Last reviewed: 2026-09-26

この reference は、common installer が読む `profiles/<name>/` 配下の manifest schema を定義します。manifest はすべて tab 区切りの TSV です。空行と `#` で始まる行は無視され、CRLF 行末は読み込み時に正規化されます。余分な列・未知の kind・壊れた path は symlink 作成前に `file:line` 付き error として停止します。

## Concepts

`.claude/` や `.codex/` には、自分で管理したい設定 (`CLAUDE.md`, `settings.json` など) と、tool 自身が書き込む credential・cache・session が同じ directory に混在します。directory を丸ごと HOME に symlink すると runtime state まで repo に入ってしまうため、installer はこれらを managed root として特別扱いし、「どの entry を HOME に link し、どれを HOME 側に残すか」を宣言した manifest に従って link します。この宣言一式が profile です。

| 用語 | 意味 |
|---|---|
| managed root | `.claude`, `.codex`, `.agents`。top-level dotfile として丸ごと link せず、surface 単位で扱う directory。 |
| profile | `profiles/<name>/` に置く宣言一式。どの branch で有効になり (`profile.tsv`)、何を link し (`surfaces.tsv`)、何を HOME 側に残し (`skipsets.tsv`)、適用前に何を検査するか (`checks.d/`) をまとめたもの。 |
| profile manifest | profile を構成する上記の TSV file 群。 |
| active profile | `profile.tsv` の branch pattern が現在の branch に一致した profile。installer は一致した profile をすべて読み、surface を合算します。一致する profile が無い場合、managed root は HOME に link されません。branch は `git branch --show-current` で判定し、環境変数 `DOTFILES_BRANCH` があればそちらを優先します。branch を判定できない場合 (detached HEAD など) は警告を出し、active profile なしとして続行します。 |
| surface | 「managed root 配下の source を、HOME のどこへ、`entries` (直下の entry ごと) と `whole` (丸ごと) のどちらで link するか」を表す 1 行。 |
| skipset | `entries` surface で link せず HOME 側に残す entry 名 pattern の集まり。`sessions`, `*.log`, `.credentials.json` など。 |
| check | install 前に実行する script。前提が揃っていなければ、HOME に書き込む前に install を止めます。 |

実例として、`profiles/base/` は全 branch で有効 (`branch *`) で、次のように働きます。

```text
surfaces.tsv:  .claude         entries → ~/.claude/CLAUDE.md, ~/.claude/settings.json を個別に link
               .claude/skills  entries → ~/.claude/skills/<name> を skill ごとに link
skipsets.tsv:  claude-root     → projects, sessions, .credentials.json などは link せず HOME 側に残す
```

## Files

```text
profiles/<name>/profile.tsv
profiles/<name>/surfaces.tsv
profiles/<name>/skipsets.tsv
profiles/<name>/checks.d/*.sh
```

active profile の `profile.tsv` だけが必須です。`surfaces.tsv`, `skipsets.tsv`, `checks.d` は `profile.tsv` で別 path を指定できます。`surfaces.tsv` / `skipsets.tsv` が存在しない場合、installer はその file を空として扱います。ただし profile smoke test (`test-profile.sh`) は両 file の存在を要求します。

## profile.tsv

| Kind | Columns | Meaning |
|---|---|---|
| `branch` | `branch	<branch-pattern>` | 現在 branch に対する Bash glob pattern。複数行可。 |
| `surfaces` | `surfaces	<profile-relative-path>` | surface manifest。省略時は `surfaces.tsv`。 |
| `skipsets` | `skipsets	<profile-relative-path>` | skipset manifest。省略時は `skipsets.tsv`。 |
| `checks` | `checks	<profile-relative-path>` | branch-specific check directory。省略時は `checks.d`。 |

`branch` は複数行書けます。`surfaces`, `skipsets`, `checks` はそれぞれ 1 回までです。重複すると invalid です。path は profile directory からの相対 path で、絶対 path や `..` を含む path は invalid です。

## surfaces.tsv

| Kind | Columns |
|---|---|
| `surface` | `surface	entries|whole	<source>	<dest>	<skipset-name|none>	<label>` |

`entries` は `<source>` directory の直下 entry を `<dest>` directory 内へ個別に symlink します。`whole` は `<source>` の file / directory 自体を `<dest>` へ symlink します。

`<source>` は DOTPATH 相対、`<dest>` は HOME 相対です。どちらも明示必須で、`dest=source` の省略記法はありません。列位置の曖昧さを避けるためです。どちらも managed root (`.claude`, `.codex`, `.agents`) 配下である必要があり、絶対 path や `..` を含む path は invalid です。

`<skipset-name>` は `skipsets.tsv` に定義された名前、または skip しない場合の `none` です。`<label>` は log 表示用の説明で、space は使えますが tab は列区切りです。

managed root (`.claude`, `.codex`, `.agents`) は、active profile の有無にかかわらず top-level dotfile link の対象から常に除外されます。managed root を HOME に出す手段は surface だけです。

child surface の source entry は親 `entries` surface では implicit skip されます。たとえば `.codex` と `.codex/items` の両方を surface として定義した場合、`.codex/items` entry は親 `.codex` の個別 symlink 対象から外れ、child surface 側で扱われます。

## skipsets.tsv

| Kind | Columns | Meaning |
|---|---|---|
| `skipset` | `skipset	<name>	<pattern>` | `entries` surface で link 対象から外す entry 名 pattern を追加します。 |
| `skipset-include` | `skipset-include	<name>	<include-name>` | `<name>` に `<include-name>` の patterns を合成します。 |

`<pattern>` は directory 内の entry 名に対する Bash glob pattern です。例: `sessions`, `*.log`, `dotfiles-*-sync-state.json`

`skipset-include` の規則:

- `<include-name>` はその行より前に定義済みである必要があります。前方参照は invalid です。
- `<name>` は未定義でも構いません。include 行で known skipset になります。
- 自己 include、循環 include、同じ `<name>` から同じ `<include-name>` への重複 include は invalid です。
- installer は読み込み時に include を展開し、最終的にはフラットな pattern list として判定します。

## checks.d

`profile.tsv` の branch pattern に一致した active profile の check script だけが、symlink 作成前に実行されます。実行対象は次の filename です。

```text
check-*.sh
[0-9][0-9]-*.sh
```

check は glob 順に実行されます。順序を明示したい場合は `10-local-state.sh`, `20-conflicts.sh` のように番号 prefix を付けます。check は `DOTPATH` と `DOTFILES_BRANCH` を受け取ります。すべての check を実行したあと、1 つでも非 0 exit があれば HOME に書き込む前に install を停止します。

## Error Conditions

すべての manifest validation error は次の形式で stderr に出ます。

```text
Error: invalid installer manifest: <file>:<line>: <message>
```

主な error 条件:

| File | Condition |
|---|---|
| `profile.tsv` | unknown kind。 |
| `profile.tsv` | value が空。 |
| `profile.tsv` | 余分な列がある。 |
| `profile.tsv` | `surfaces` / `skipsets` / `checks` path が絶対 path または `..` を含む。 |
| `profile.tsv` | `surfaces` / `skipsets` / `checks` が重複している。 |
| `surfaces.tsv` | kind が `surface` 以外。 |
| `surfaces.tsv` | strategy が空、または `entries` / `whole` 以外。 |
| `surfaces.tsv` | source / dest / skipset / label が空。 |
| `surfaces.tsv` | source / dest が絶対 path または `..` を含む。 |
| `surfaces.tsv` | source / dest root が managed root (`.claude`, `.codex`, `.agents`) ではない。 |
| `surfaces.tsv` | skipset が `none` ではなく、`skipsets.tsv` に定義されていない。 |
| `surfaces.tsv` | 余分な列がある。 |
| `skipsets.tsv` | kind が `skipset` / `skipset-include` 以外。 |
| `skipsets.tsv` | name が空。 |
| `skipsets.tsv` | `skipset` の pattern が空。 |
| `skipsets.tsv` | `skipset-include` の include name が空。 |
| `skipsets.tsv` | 余分な列がある。 |
| `skipsets.tsv` | `skipset-include` が未知の skipset を参照している。 |
| `skipsets.tsv` | 自己 include、循環 include、重複 include。 |

## Regression Coverage

manifest validation は `bash scripts/install/test-installer.sh --case '60-*'` で重点実行できます。主な対応 case は `invalid manifest fails`, `duplicate profile manifest kind fails`, `invalid surface path fails`, `surface outside managed root fails`, `skipset include composes patterns`, `unknown skipset include fails`, `cyclic skipset include fails`, `self skipset include fails`, `duplicate skipset include fails`, `detached HEAD warns no profile` です。
