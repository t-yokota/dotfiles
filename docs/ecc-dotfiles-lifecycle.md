# ECC Dotfiles Lifecycle Procedure

- Last reviewed: 2026-06-14
- ECC version: 2.0.0-rc.1

この文書は、ECC profile を導入した後の uninstall / regenerate / update / cleanup 手順をまとめます。新しい環境で最初に ECC output を作る手順は [ecc-dotfiles-manual-install.md](ecc-dotfiles-manual-install.md) を参照します。

この文書のコマンド例だけを参照する場合は、先に次の変数を定義します。`ECC_REPO` は自分の環境の clone 先に置き換えます。

```bash
export DOTPATH="$HOME/dotfiles"
export ECC_REPO="/path/to/everything-claude-code"
```

## Layer Model

この dotfiles では、uninstall / cleanup の対象を layer ごとに分けます。

| Layer | 対象 | 主な操作 |
|---|---|---|
| 実 HOME symlink layer | `~/.claude`, `~/.codex`, `~/.agents`, top-level dotfiles 内の dotfiles-managed symlink | `bash install.sh`, `bash uninstall.sh`, `bash status.sh` |
| dotfiles desired state | `profile/ecc/*` branch に commit した tracked asset | git で追加・削除・差分確認 |
| ECC generated output | `HOME=$DOTPATH` / `CODEX_HOME=$DOTPATH/.codex` で作った Claude / Codex output | ECC repo 側の installer / sync / uninstall |
| machine-local state | install-state, sync marker, `.gitconfig.local`, Codex auth/session/logs, hooks body | commit しない。必要時に再生成・削除 |

## 実 HOME の symlink を update / cleanup する

`profile/ecc/*` に commit した ECC asset は、dotfiles branch の checkout に合わせて切り替わります。branch を切り替えた後は dotfiles の `install.sh` を実行し、実 HOME 側の symlink を新しい branch の desired state に合わせます。

```bash
cd "$DOTPATH"
git switch <target-branch>
bash install.sh
```

`install.sh` は、target がなくなった dotfiles 管理 symlink を stale symlink として削除します。これは `~/.claude`, `~/.codex`, `~/.agents` の中身にも適用されます。entry 単位 surface では各 entry の symlink が削除され、whole directory surface では `.claude/hooks`, `.claude/scripts`, `.claude/mcp-configs` などの directory symlink 自体が削除対象になります。一方で、実 HOME にある non-managed file / directory や runtime state は削除しません。

`profile/ecc-base` に戻す場合も同じです。base branch には ECC install output がないため、branch checkout によって tracked output が作業ツリーから消え、`bash install.sh` が実 HOME 側の dotfiles 管理 symlink を cleanup します。ignored な local marker や install-state は branch checkout では消えないため、環境を初期化したい場合だけ各 layer の cleanup 手順で削除します。

## Claude installer output を uninstall / regenerate する

Claude manual installer で `~/dotfiles/.claude` に入れた generated asset を uninstall する場合は、ECC repo 側の uninstall を `HOME=$DOTPATH` 付きで実行します。実 HOME の `~/.claude` に対して ECC uninstall を実行する手順ではありません。

```bash
cd "$ECC_REPO"

HOME="$DOTPATH" node scripts/uninstall.js --target claude --dry-run
HOME="$DOTPATH" node scripts/uninstall.js --target claude
```

uninstall は `.claude/ecc/install-state.json` を基準に削除対象を判断します。この install-state は `.gitignore` 対象であり、`profile/ecc/*` の desired state として commit しません。clean clone や `git clean -X` 後は tracked asset は残っていても lifecycle state がないため、ECC の uninstall / doctor / repair / list は no-op になり得ます。その場合は、必要に応じて `HOME=$DOTPATH` で install を再実行し、state を再生成してから lifecycle command を使います。

同じ `profile/ecc/*` branch 内で ECC installer profile を作り直す場合は、uninstall 後に目的の profile で再 install します。この手順では `full` を標準にします。

```bash
HOME="$DOTPATH" bash ./install.sh --target claude --profile full
```

Claude installer output を uninstall / regenerate した後、実 HOME へ反映するには dotfiles 側で `bash install.sh` を実行します。

## Codex sync output を cleanup / regenerate する

Codex sync には Claude installer の `uninstall.js` に相当する専用 unsync script はありません。`scripts/sync-ecc-to-codex.sh` は backup / marker / manifest を持ちますが、基本は add-only merge と生成物配置です。

cleanup の考え方は次です。

- `.codex/AGENTS.md` は `<!-- BEGIN ECC -->` / `<!-- END ECC -->` の marker block を削除するか、Git の履歴から戻す。
- `.codex/config.toml` は add-only merge なので、自動逆変換せず、ECC baseline / MCP sections を手動で削るか、Git の履歴から戻す。
- `.codex/agents/*.toml` と `.codex/prompts/ecc-*` は generated output として cleanup / regenerate する。
- `.codex/backups/` は local backup であり、uninstall contract ではない。
- `.codex/dotfiles-profile-ecc-sync-state.json` は local marker なので、Codex sync output を cleanup / regenerate する場合は先に削除する。sync output と skills bundle を再生成したあと、`profiles/ecc/bin/write-codex-sync-state.sh` で作り直す。

Codex sync は existing agent role file を上書きせず、古い `ecc-*.md` prompt を自動削除しません。upstream 更新を取り直す場合は、manifest と prefix を基準に古い生成物を削除してから再 sync します。

```bash
cd "$DOTPATH"

if [ -f .codex/prompts/ecc-prompts-manifest.txt ]; then
  while IFS= read -r file; do
    [ -n "$file" ] && rm -f ".codex/prompts/$file"
  done < .codex/prompts/ecc-prompts-manifest.txt
fi

if [ -f .codex/prompts/ecc-extension-prompts-manifest.txt ]; then
  while IFS= read -r file; do
    [ -n "$file" ] && rm -f ".codex/prompts/$file"
  done < .codex/prompts/ecc-extension-prompts-manifest.txt
fi

rm -f .codex/prompts/ecc-*.md
rm -f .codex/prompts/ecc-prompts-manifest.txt .codex/prompts/ecc-extension-prompts-manifest.txt
rm -f .codex/agents/explorer.toml .codex/agents/docs-researcher.toml .codex/agents/reviewer.toml
rm -f .codex/dotfiles-profile-ecc-sync-state.json
```

その後、必要なら Codex sync apply を再実行します。

```bash
cd "$ECC_REPO"

HOME="$DOTPATH" \
CODEX_HOME="$DOTPATH/.codex" \
AGENTS_HOME="$DOTPATH/.agents" \
ECC_GLOBAL_HOOKS_DIR="$DOTPATH/.codex/git-hooks" \
GIT_CONFIG_GLOBAL="$DOTPATH/.gitconfig.local" \
bash scripts/sync-ecc-to-codex.sh
```

sync output と skills bundle を確認したら、local marker を作り直します。

```bash
cd "$DOTPATH"

DOTPATH="$DOTPATH" ECC_REPO="$ECC_REPO" \
bash profiles/ecc/bin/write-codex-sync-state.sh
```

## Codex skills bundle を update / regenerate する

Codex skills は sync script の output ではなく、ECC repo の `.agents/skills/` bundle を dotfiles に手動コピーしたものです。更新時もまずは既存内容を残したまま ECC bundle をコピーし、差分を確認します。

```bash
cd "$DOTPATH"
mkdir -p .agents/skills
cp -R "$ECC_REPO/.agents/skills/." .agents/skills/
git diff -- .agents/skills
```

ECC 側で削除された skill まで dotfiles 側に反映したい場合は、`git diff -- .agents/skills` と ECC repo の状態を確認したうえで、不要になった ECC 由来 skill を個別に削除します。個人 skill を `~/dotfiles/.agents/skills/` に統合している場合は、directory 全体を削除しません。

`profile/ecc/*` から Codex skills を外す場合は、`.agents/skills` の tracked desired state を削除して commit し、その後 `bash install.sh` を実行します。実 HOME 側では `~/.agents/skills/<skill>` の dotfiles 管理 symlink が stale symlink として削除されます。`~/.agents/skills` directory 自体と、そこにある non-managed skill は削除されません。

## Update from upstream ECC

ECC upstream を取り直す場合は、各 layer を混ぜずに更新します。

1. `ECC_REPO` 側で upstream 更新を取り込み、`npm install` を通常 HOME で実行する。
2. Claude output を更新する場合は、`HOME="$DOTPATH" bash ./install.sh --target claude --profile full --dry-run` で差分を確認してから apply する。
3. Codex output を更新する場合は、古い prompt / role / local marker を cleanup し、`CODEX_HOME="$DOTPATH/.codex"` などの環境変数を指定して sync apply を実行する。
4. Codex skills bundle を更新する場合は、ECC repo の `.agents/skills/` を dotfiles 側へコピーし、`git diff -- .agents/skills` を確認する。
5. `profiles/ecc/bin/write-codex-sync-state.sh` で local marker を再作成する。
6. `bash scripts/install/test-all.sh`, `bash install.sh --dry-run`, `bash status.sh` を確認してから commit する。

## ECC global git hooks を disable / cleanup する

Codex sync apply で生成した `$DOTPATH/.codex/git-hooks/` と `$DOTPATH/.gitconfig.local` は machine-local state です。dotfiles 側の観察用 hooksPath を消す場合は、`GIT_CONFIG_GLOBAL` を `$DOTPATH/.gitconfig.local` に向けて unset します。

```bash
GIT_CONFIG_GLOBAL="$DOTPATH/.gitconfig.local" \
git config --global --unset core.hooksPath
```

実 HOME で global hooks を有効化していた場合は、実 HOME 側の machine-local config からも unset します。

```bash
GIT_CONFIG_GLOBAL="$HOME/.gitconfig.local" \
git config --global --unset core.hooksPath
```

hook body 自体は ignored output なので、不要になったら `$DOTPATH/.codex/git-hooks/` を削除します。再度使う場合は `scripts/codex/install-global-git-hooks.sh` または Codex sync apply で再生成します。

## Operational Notes

### Codex sync の入力 config を用意する

`scripts/sync-ecc-to-codex.sh` は `$CODEX_HOME/config.toml` を要求します。まっさらな `.codex` では、先に空ファイルを作ります。

```bash
cd "$DOTPATH"
mkdir -p .codex
touch .codex/config.toml
```

### ECC repo の Node dependencies を入れる

ECC repo root で `npm install` を実行します。

```bash
cd "$ECC_REPO"
npm install
```

### Plugin route と manual route を混ぜない

Claude plugin route を使う場合、ECC README では `--profile full` の manual installer を重ねない方針が示されています。この手順では plugin ではなく manual installer を使うため、Claude の `/plugin install ecc@ecc` は使いません。

### Codex prompts / agents の配置を確認する

ECC の Codex sync は `~/.codex/prompts/ecc-*` と `~/.codex/agents/*.toml` に配置します。`~/.codex/prompts/ecc/` や `~/.codex/agents/ecc/` にはなりません。cleanup は file name / manifest file を基準に行います。
