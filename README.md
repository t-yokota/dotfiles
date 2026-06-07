# dotfiles

個人用 dotfiles です。共通で使う設定は `main` に置き、特定のツール構成や生成物が必要な場合は profile branch で管理します。

このリポジトリは単なる設定ファイルの置き場ではなく、自分の作業環境で様々なポリシーを切り替えながら試すことができる土台になっています。<br>特に AI agent のツールはベストプラクティスが変わり続ける可能性があるため、ベースは薄く保ち、特定ツールとの連携や agent profile 自体は branch と manifest の単位で切りながら扱います。

`.claude/`, `.codex/`, `.agents/` のようなディレクトリは、ディレクトリの root 全体を HOME に symlink しません。credential、cache、session などの runtime state は実 HOME 側に残した上で、再現したい desired state だけを managed surface で管理します。<br>これにより、ベストプラクティスへの追従、複数の policy の切り替え、試行錯誤を git の履歴として扱えるようにします。

## Branch Strategy

`main` は portable な base branch です。共通 dotfiles、共通 installer、共通 ignore rule を置きます。特定環境で生成された tool output や local install state は含めません。<br>profile branch は、top-level dotfile だけでは足りない構成を扱うために使います。profile manifest、branch-specific check、手順書、ツールの desired state などを追加できます。

基本形は次のようにします。

```text
main
profile/<name>-base
profile/<name>/<environment>
```

`*-base` branch は profile の共通構造と手順を置くための branch です。できるだけ portable に保ちます。local path を含む生成物や machine-local な sync marker が必要な場合は、base branch から環境別 branch を切って、その branch で tool installer を実行します。<br>たとえば ECC profile では、`profile/ecc-base` に installer 連携や手順を置き、実際の Claude / Codex 生成物や local sync marker は `profile/ecc/<environment>` 側で管理します。

既存 profile を元に別 profile を作る場合は、`profiles/<name>/` を profile の資産として一式コピーします。`profile.tsv`, `surfaces.tsv`, `skipsets.tsv`, `checks.d/` だけでなく、`bin/` に置いた profile-local な補助 script や smoke test も移植対象です。移植後は `profile.tsv` の branch pattern を新しい profile 名に合わせ、`bash profiles/<name>/bin/test-profile.sh --branch profile/<name>-base` で profile が単独で適用可能か確認します。

## Repository Layout

この repository は、portable な top-level dotfiles、共通 installer、profile branch 固有の manifest / check / 補助 script を分けて管理します。

```text
.
├── install.sh
├── scripts/
│   └── install/
│       ├── lib/
│       │   ├── common.sh
│       │   ├── profile.sh
│       │   └── reconcile.sh
│       ├── test-install.sh
│       └── test-profile.sh
├── profiles/
│   └── <name>/
│       ├── profile.tsv
│       ├── surfaces.tsv
│       ├── skipsets.tsv
│       ├── checks.d/
│       └── bin/
├── docs/
├── .claude/ .codex/ .agents/
└── *.zsh-theme
```

主な役割は次の通りです。

- `install.sh`: 共通 installer の entrypoint です。CLI option、`DOTPATH` / `HOME` の初期化、library 読み込み、install phase の実行順だけを持ちます。
- `scripts/install/lib/common.sh`: 共通 helper です。log 出力、dry-run 判定、branch 取得、path 解決など、profile policy を持たない処理を置きます。
- `scripts/install/lib/profile.sh`: profile manifest loader です。現在の branch に合う profile を選び、`profile.tsv`, `surfaces.tsv`, `skipsets.tsv` を検証して installer state に読み込み、profile 固有 check を実行します。
- `scripts/install/lib/reconcile.sh`: desired state と HOME の actual state を突き合わせる engine です。未管理 path の conflict check、dotfiles 管理 symlink の cleanup、top-level dotfile / managed surface / shell theme の symlink 作成を担当します。
- `scripts/install/test-install.sh`: installer の regression test です。`/tmp` に一時的な dotfiles checkout と HOME を作り、実 HOME を触らずに install / dry-run / conflict / cleanup / manifest validation を確認します。
- `scripts/install/test-profile.sh`: profile smoke test の共通 runner です。指定した `profiles/<name>/` を一時 HOME に適用し、profile manifest と surface の基本動作を確認します。
- `profiles/<name>/`: profile branch 固有の定義です。surface、skipset、branch-specific check、profile 補助 script、profile-local smoke test wrapper をここに置きます。
- `.claude/`, `.codex/`, `.agents/`: profile が HOME に出す tool 用 desired state です。root directory ごと symlink するのではなく、profile manifest の surface 定義に従って扱います。
- `docs/`: profile の背景、手順、外部 tool との対応関係など、README に収めない長めの補足を置きます。

## Install

適用したい branch を checkout した状態で、Bash から installer を実行します。<br>`install.sh` は Bash 前提です。`sh install.sh` では実行せず、誤って Bash 以外から起動された場合は早期に終了します。

```bash
cd ~/dotfiles
bash install.sh
```

実際に symlink を作る前に確認したい場合は、`--dry-run` または短縮形の `-n` を使います。<br>profile manifest、branch-specific check、cleanup 対象、link conflict、作成予定の symlink を確認しますが、共通 installer は directory 作成、symlink 作成、cleanup を書き込みません。

```bash
bash install.sh --dry-run
bash install.sh --help
```

installer の動作確認には、実際の `~/dotfiles` や `$HOME` を変更しない test script を使えます。<br>この script は `/tmp` に一時的な dotfiles checkout と HOME directory を作り、symlink 作成、conflict 検出、stale symlink cleanup、profile check の実行順を検証します。

```bash
bash scripts/install/test-install.sh
```

`test-install.sh` の詳細ログを確認したい場合は、`--verbose` を付けます。内部で実行した `install.sh` の出力も表示されます。

```bash
bash scripts/install/test-install.sh --verbose
```

profile branch 側に `profiles/<name>/bin/test-profile.sh` がある場合は、その profile 自体が一時 HOME に適用できるかを確認できます。たとえば ECC profile では次のように実行します。

```bash
bash profiles/ecc/bin/test-profile.sh
```

## Installer Flow

`install.sh` は `DOTPATH=~/dotfiles` を起点に、現在 checkout されている branch の内容を実 HOME に symlink します。Conflict をチェックして既存の通常ファイルを上書きせず、Cleanup の際にはこの dotfiles checkout が作った symlink だけを対象にします。<br>共通 installer の entrypoint は top-level の `install.sh` に置き、installer の補助実装と regression test は `scripts/install/` にまとめます。一方で、profile branch 固有の surface 定義、check、補助 script は `profiles/<name>/` の下に置き、共通 installer と profile 固有資産を分けます。

処理は大きく以下の 6 段階です。

1. **Preflight**:
   checkout している branch に対応する profile manifest を読み込み、branch 固有の check 処理を行います。
2. **Cleanup**:
   この dotfiles checkout を指している古い symlink だけを削除します。通常ファイルや別の場所を指す symlink は削除しません。
3. **Link Conflict Check**:
   link 先に未管理のファイルや directory がある場合、symlink 作成前に停止します。
4. **Link Top-Level Dotfiles**:
   `.gitconfig`, `.vimrc`, `.zshrc` などの top-level dotfile を symlink します。
5. **Link Managed Dotfile Surfaces**:
   profile branch が managed surface を定義している場合、ツール用 directory を surface ごとの strategy に従って symlink します。
6. **Link Shell Themes**:
   oh-my-zsh の theme directory が存在する場合、repository 直下の `*.zsh-theme` を symlink します。

また、共通 installer は以下の top-level entry を常に symlink 対象から外します。

```text
.git
.gitignore
.gitconfig.local
```

`.gitconfig.local` は環境ごとの machine-local 設定です。tracked な `.gitconfig` から include しますが、`install.sh` では作成も symlink もしません。<br>profile manifest が managed surface として宣言した top-level root、たとえば `.claude`, `.codex`, `.agents` なども、その profile が有効な間は top-level symlink 対象から外します。

## Managed Dotfile Surfaces

managed dotfile surface は、profile branch が tool 用 directory をどの粒度で HOME に出すかを宣言する管理単位です。

主な strategy は次の2つです。

- `entries`: directory 自体は実 HOME に残し、その中の entry を個別に symlink します。利用するツールが directory 内の entry を個別に読む場合、既存の user-local entry と dotfiles 管理 entry を共存させやすくなります。
- `whole`: directory や file を1つの package として symlink します。内部の対応関係を保ったまま出したい generated output に使います。

たとえば profile branch に次の desired state があるとします。

```text
~/dotfiles/.codex/prompts/ecc-plan.md
~/dotfiles/.codex/prompts/ecc-review-pr.md
```

`.codex/prompts` を managed surface として定義すると、installer は `~/.codex` 全体を置き換えず、次のように entry 単位で symlink します。

```text
~/.codex/prompts/ecc-plan.md      -> ~/dotfiles/.codex/prompts/ecc-plan.md
~/.codex/prompts/ecc-review-pr.md -> ~/dotfiles/.codex/prompts/ecc-review-pr.md
```

そのため、同じ `~/.codex/prompts` directory に user-local prompt があっても、同名で衝突しない限り共存できます。

profile branch は、以下の manifest で managed surface を定義します。

```text
profiles/<name>/profile.tsv
profiles/<name>/surfaces.tsv
profiles/<name>/skipsets.tsv
```

共通 installer は現在 checkout されている branch と `profile.tsv` の branch pattern を照合し、有効な profile の surface に基づいて、link 先の conflict check、古い symlink の cleanup、symlink 作成を行います。<br>manifest の kind、必須列、余分な列、surface strategy、skipset 参照は読み込み時に検証します。typo や壊れた行がある場合は、symlink を作る前に file path と line number を出して停止します。

### Profile Manifest Schema

manifest は tab 区切りの TSV です。空行と `#` で始まる行は無視されます。余分な列がある行は invalid として扱います。

`profile.tsv` は、profile が有効になる branch pattern と、関連 manifest の場所を定義します。

```text
branch	<branch-pattern>
surfaces	<profile-relative-path>
skipsets	<profile-relative-path>
checks	<profile-relative-path>
```

- `branch`: 現在の branch に対する glob pattern です。例: `profile/ecc-base`, `profile/ecc/*`
- `surfaces`: surface 定義 file です。省略時は `surfaces.tsv` です。
- `skipsets`: skipset 定義 file です。省略時は `skipsets.tsv` です。
- `checks`: branch-specific check directory です。省略時は `checks.d` です。

`branch` は複数行書けます。`surfaces`, `skipsets`, `checks` は省略可能ですが、それぞれ1回までです。重複して書いた場合は invalid として扱います。

`surfaces.tsv` は、dotfiles 側の desired state を HOME 側にどの粒度で出すかを定義します。

```text
surface	entries|whole	<source>	<dest>	<skipset-name|none>	<label>
```

- `entries`: `<source>` directory の entry を `<dest>` directory 内へ個別に symlink します。
- `whole`: `<source>` の file / directory 自体を `<dest>` へ symlink します。
- `<source>` は dotfiles checkout からの path、`<dest>` は HOME からの path として解決します。どちらも相対 path として書き、絶対 path や `..` を含む path は invalid として扱います。
- `<skipset-name>` は `skipsets.tsv` に定義された名前、または skip しない場合の `none` です。
- `<label>` は install log に出す説明です。space は使えますが、tab は列区切りとして扱います。

`skipsets.tsv` は、`entries` surface で link 対象から外す entry 名 pattern を定義します。

```text
skipset	<name>	<pattern>
```

`<name>` は `surfaces.tsv` から参照する skipset 名です。`<pattern>` は directory 内の entry 名に対する shell glob pattern です。例: `sessions`, `*.log`, `dotfiles-*-sync-state.json`

## Branch-Specific Checks

branch 固有の check 処理は、profile branch を安全に適用できる状態かを確認するための仕組みです。次の形式で実行対象の check script を追加できます。

```text
profiles/<name>/checks.d/*.sh
```

`profile.tsv` で branch pattern に一致した active profile の check だけが、symlink 作成前に実行されます。check は file name の glob 順、つまり通常は辞書順で実行されます。<br>そのため順序を明示したい場合は、`10-local-state.sh`, `20-conflicts.sh` のように番号 prefix を付けます。profile branch に必要な local install state がない場合や、実 HOME 側に危険な競合がある場合は、ここで停止させます。

たとえば Everything Claude Code (https://github.com/affaan-m/ECC) のような外部 tool を profile の元にする場合、その tool が持つ installer や sync step を dotfiles 側で先に実行してから HOME 側に適用することになります。<br>check script によって tool の install 時に生成される install-state や local marker の存在を確認した上で、profile を HOME に適用することが可能です。

check script は選択中の branch の profile を現在の環境に適用する準備が整っているかを判定するためのものなので、check 内容は profile に応じたスクリプトの実装によって定義することができ、上記に限られる必要はありません。

## Safety Rules

- `install.sh` は未管理の通常ファイルを上書きしません。
- cleanup は、この dotfiles checkout を指す symlink だけを削除します。
- `entries` surface の link 先 directory と `whole` surface の親 directory は、通常 directory である必要があります。未管理 symlink 越しには書き込みません。
- credential、cache、backup、machine-local config といった local / runtime state は shared commit に含めません。
