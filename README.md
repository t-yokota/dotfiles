# dotfiles

個人用 dotfiles です。共通で使う設定は `main` に置き、特定のツール構成や生成物が必要な場合は profile branch で管理します。

## インストール

適用したい branch を checkout した状態で、Bash から installer を実行します。

```bash
cd ~/dotfiles
bash install.sh
```

`install.sh` は Bash 前提です。`sh install.sh` では実行せず、誤って Bash 以外から起動された場合は早期に終了します。

## `install.sh` の仕組み

`install.sh` は `DOTPATH=~/dotfiles` を起点に、現在 checkout されている branch の内容を実 HOME に symlink します。Conflict をチェックして既存の通常ファイルを上書きせず、Cleanup の際にはこの dotfiles checkout が作った symlink だけを対象にします。

処理は大きく以下の 5 段階です。

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

また、共通 installer は以下の top-level entry を常に symlink 対象から外します。

```text
.git
.gitignore
.gitconfig.local
```

`.gitconfig.local` は環境ごとの machine-local 設定です。tracked な `.gitconfig` から include しますが、`install.sh` では作成も symlink もしません。profile manifest が managed surface として宣言した top-level root、たとえば `.claude`, `.codex`, `.agents` なども、その profile が有効な間は top-level symlink 対象から外します。

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

共通 installer は現在 checkout されている branch と `profile.tsv` の branch pattern を照合し、有効な profile の surface に基づいて、link 先の conflict check、古い symlink の cleanup、symlink 作成を行います。

## Branch-Specific Checks

branch 固有の check は、profile branch を安全に適用できる状態かを確認するための仕組みです。次の形式でファイルを追加できます。

```text
scripts/install/preflight.d/*/check-*.sh
```

これらの check は symlink 作成前に実行されます。profile branch に必要な local install state がない場合や、実 HOME 側に危険な競合がある場合は、ここで停止させます。

たとえば ECC のように外部 installer や sync step を先に実行してから HOME側に適用する profile では、その install-state や local marker の存在をここで確認します。check script は、現在の環境でこの branch を適用する準備が整っているかを判定するためのもので、確認内容は profile に応じて決定できます。

## Branch 戦略

`main` は portable な base branch です。共通 dotfiles、共通 installer、共通 ignore rule を置きます。特定環境で生成された tool output や local install state は含めません。

profile branch は、top-level dotfile だけでは足りない構成を扱うために使います。profile manifest、branch-specific check、手順書、ツールの desired state などを追加できます。

基本形は次のようにします。

```text
main
profile/<name>-base
profile/<name>/<environment>
```

`*-base` branch は profile の共通構造と手順を置くための branch です。できるだけ portable に保ちます。local path を含む生成物や machine-local な sync marker が必要な場合は、base branch から環境別 branch を切って、その branch で tool installer を実行します。

たとえば ECC profile では、`profile/ecc-base` に installer 連携や手順を置き、実際の Claude / Codex 生成物や local sync marker は `profile/ecc/<environment>` 側で管理します。

## 安全ルール

- `install.sh` は未管理の通常ファイルを上書きしません。
- cleanup は、この dotfiles checkout を指す symlink だけを削除します。
- `entries` surface の link 先 directory と `whole` surface の親 directory は、通常 directory である必要があります。未管理 symlink 越しには書き込みません。
- runtime state、credential、cache、backup、machine-local config は shared commit に含めません。
