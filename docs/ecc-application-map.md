# ECC Application Map for Claude Code and Codex

Last reviewed: 2026-05-30

このメモは、Everything Claude Code (ECC) を Claude Code と Codex に適用するときに、何がどこへ配置され、各エージェントがどこから読むのかを整理するためのものです。

ここでは次の2つを分けて扱います。

- **公式の読み込み仕様**: Claude Code / Codex がランタイムで読む場所
- **ECCの配置方法**: ECC の plugin / installer / sync script がファイルを置く場所

## 全体像

```mermaid
flowchart LR
  ECC["ECC repository"]

  ECC --> CPlugin["Claude plugin install"]
  ECC --> CManual["Claude manual installer"]
  ECC --> CodexSync["Codex sync script"]
  ECC --> SkillsInstall["Codex skills install / .agents"]
  ECC --> CodexPlugin["Codex plugin install"]

  CPlugin --> CPluginRoot["Claude plugin storage"]
  CManual --> ClaudeHome["~/.claude/"]

  CodexSync --> CodexHome["~/.codex/"]
  CodexPlugin --> CodexPluginRoot["Codex plugin storage"]

  CPluginRoot --> ClaudeRuntime["Claude Code runtime"]
  ClaudeHome --> ClaudeRuntime

  CodexHome --> CodexRuntime["Codex runtime"]
  SkillsInstall --> AgentsHome["~/.agents/skills/"]
  AgentsHome --> CodexRuntime
  CodexPluginRoot --> CodexRuntime
```

重要なのは、plugin install と manual installer は同じ種類の資産を別経路でランタイムへ渡すことがある点です。ECC README でも、Claude plugin を使う場合は `--profile full` の manual installer を重ねない方針が示されています。

## Claude Code

### 公式の読み込み場所

| 種類 | Claude Code が読む場所 | 読み込み・優先順位の要点 | 公式ドキュメント |
|---|---|---|---|
| Memory / instruction | `~/.claude/CLAUDE.md`, `./CLAUDE.md` | 起動時に読み込まれる。プロジェクトでは current working directory から親方向の `CLAUDE.md` が対象になり、`@path` import も使える。 | [Memory](https://docs.anthropic.com/en/docs/claude-code/memory) |
| Settings | `~/.claude/settings.json`, `.claude/settings.json`, `.claude/settings.local.json`, managed policy | 権限、環境変数、model、hooks、plugin 有効化などを設定する。local project settings は個人用。 | [Settings](https://docs.anthropic.com/en/docs/claude-code/settings) |
| Subagents | `~/.claude/agents/`, `.claude/agents/` | Markdown + YAML frontmatter。project subagent が user subagent より優先される。 | [Sub agents](https://docs.anthropic.com/en/docs/claude-code/sub-agents) |
| Hooks | settings files 内 | `PreToolUse`, `PostToolUse`, `Notification`, `UserPromptSubmit`, `Stop`, `SubagentStop`, `PreCompact`, `SessionStart`, `SessionEnd` などのイベントで shell command を実行する。 | [Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) |
| Plugins | `/plugin` で追加した marketplace / plugin | plugin manifest が commands, agents, hooks, MCP servers, skills などの同梱コンポーネントを指す。`settings.json` の `enabledPlugins` にも関係する。 | [Plugins](https://docs.anthropic.com/en/docs/claude-code/plugins) |

### Claude plugin route

```mermaid
flowchart TD
  ECC["ECC repository"]
  Marketplace["/plugin marketplace add ..."]
  Install["/plugin install ecc@ecc"]
  PluginManifest[".claude-plugin/plugin.json"]
  PluginAssets["commands/ skills/ hooks/ agents/ mcpServers"]
  Claude["Claude Code runtime"]

  ECC --> Marketplace --> Install --> PluginManifest
  PluginManifest --> PluginAssets --> Claude

  ECCRules["ECC rules/"]
  ManualRules["manual copy to ~/.claude/rules/ecc/"]
  ECCRules -. "Claude pluginでは rules は自動配布されない" .-> ManualRules
  ManualRules -. "必要に応じて参照" .-> Claude
```

ECC の Claude plugin は、Claude Code の plugin 機構に乗せて commands / skills / hooks / agents / MCP server などを配布する経路です。

ECC README では、plugin install の場合は plugin が ECC の skills / commands / hooks を読み込むため、`--profile full` の manual installer は重ねない方針が説明されています。一方で、Claude plugin は rules を自動配布できないため、必要な rule pack は `~/.claude/rules/ecc/` へ手動コピーする運用が示されています。

### Claude manual installer route

```mermaid
flowchart TD
  ECC["ECC repository"]
  Installer["./install.sh or scripts/install.js"]
  ClaudeHome["~/.claude/"]
  State["~/.claude/ecc/install-state.json"]
  Runtime["Claude Code runtime"]

  ECC --> Installer
  Installer --> ClaudeHome
  Installer --> State
  ClaudeHome --> Runtime
```

ECC の installer target for Claude home は、ECC 資産を `~/.claude/` 配下へ配置します。`hooks-runtime` を含める場合、ECC hooks は `~/.claude/settings.json` ではなく `~/.claude/hooks/hooks.json` に resolved hook graph として配置されます。ECC の install state は `~/.claude/ecc/install-state.json` に記録され、uninstall 時はこの記録を基準に削除対象を判断します。

この経路は Claude Code 公式の通常読み込み場所にファイルを置く方式です。plugin route と重ねると、同種の skills / commands / hooks が重複する可能性があります。

## Codex

### 公式の読み込み場所

| 種類 | Codex が読む場所 | 読み込み・優先順位の要点 | 公式ドキュメント |
|---|---|---|---|
| Instructions | `~/.codex/AGENTS.override.md` または `~/.codex/AGENTS.md`, project root から cwd までの `AGENTS.override.md` / `AGENTS.md` | 起動時に instruction chain を構築する。global では override があればそれを読み、project では root から cwd へ順に重ねる。近い階層の指示が後に来る。 | [AGENTS.md](https://developers.openai.com/codex/guides/agents-md#how-codex-discovers-guidance) |
| Config | `~/.codex/config.toml`, trusted project の `.codex/config.toml` | user config が基本。trusted project では project config も読む。ただし provider / auth / telemetry など machine-local な設定は project config からは上書きできない。 | [Config reference](https://developers.openai.com/codex/config-reference#configtoml) |
| Skills | `$CWD/.agents/skills`, 親方向の `.agents/skills`, `$REPO_ROOT/.agents/skills`, `$HOME/.agents/skills`, `/etc/codex/skills`, system bundled skills | repo, user, admin, system の各場所から読む。symlink された skill directory もサポートされる。同名 skill は merge されない。 | [Skills](https://developers.openai.com/codex/skills#where-to-save-skills) |
| Custom agents | `~/.codex/agents/*.toml`, `.codex/agents/*.toml` | personal agent と project-scoped agent を TOML で定義する。spawn された subagent session の config layer として使われる。 | [Subagents](https://developers.openai.com/codex/subagents#custom-agents) |
| Hooks | `~/.codex/hooks.json`, `~/.codex/config.toml`, trusted project の `.codex/hooks.json`, `.codex/config.toml`, plugin bundled hooks | active config layers の横にある hooks を読む。複数 source の hooks は置換ではなく追加で読み込まれる。project local hooks は project が trusted の場合のみ。 | [Hooks](https://developers.openai.com/codex/hooks#where-codex-looks-for-hooks) |
| Plugins | plugin manifest が指す bundled components | Codex plugin manifest は skills, MCP servers, apps, hooks などを plugin root からの相対パスで指せる。marketplace は CLI から追加できる。 | [Plugin manifest](https://developers.openai.com/codex/plugins/build#manifest-fields), [Marketplace](https://developers.openai.com/codex/plugins/build#add-a-marketplace-from-the-cli) |

### Codex sync script route

```mermaid
flowchart TD
  ECC["ECC repository"]
  Sync["scripts/sync-ecc-to-codex.sh"]
  Backup["~/.codex/backups/ecc-<timestamp>/"]
  AgentsMd["~/.codex/AGENTS.md"]
  Config["~/.codex/config.toml"]
  Agents["~/.codex/agents/*.toml"]
  Prompts["~/.codex/prompts/"]
  GitHooks["~/.codex/git-hooks/"]
  GlobalGit["git config --global core.hooksPath"]
  Runtime["Codex runtime"]

  ECC --> Sync
  Sync --> Backup
  Sync --> AgentsMd
  Sync --> Config
  Sync --> Agents
  Sync --> Prompts
  Sync --> GitHooks --> GlobalGit

  AgentsMd --> Runtime
  Config --> Runtime
  Agents --> Runtime

  Skills["ECC skills"]
  UserSkills["~/.agents/skills/"]
  Skills -. "sync script itself does not copy skills" .-> UserSkills
  UserSkills --> Runtime
```

ECC の `scripts/sync-ecc-to-codex.sh` は、Codex を使う前提で `~/.codex/` に ECC の instruction / config / agents / prompts / MCP 設定などを同期する補助スクリプトです。

このスクリプトは既存の `~/.codex/config.toml` と `AGENTS.md` をバックアップします。`config.toml` には ECC baseline / MCP settings を add-only で追記し、`AGENTS.md` には marker 付き ECC block を追加・更新します。skills についてはスクリプト内で直接コピーせず、Codex 公式の読み込み場所である `~/.agents/skills/` などから読む前提になっています。

注意点として、この route は Claude manual installer のような install state ベースの uninstall とは性質が違います。バックアップや marker はありますが、dotfiles で管理している `~/.codex/config.toml` や `AGENTS.md` が symlink の場合、sync script はリンク先の dotfiles 側を書き換えます。

### Codex plugin route

```mermaid
flowchart TD
  ECC["ECC repository"]
  Marketplace["codex plugin marketplace add ..."]
  Install["codex plugin install ..."]
  Manifest[".codex-plugin/plugin.json"]
  Skills["skills/"]
  Mcp[".mcp.json"]
  Runtime["Codex runtime"]

  ECC --> Marketplace --> Install --> Manifest
  Manifest --> Skills --> Runtime
  Manifest --> Mcp --> Runtime
```

ECC には Codex plugin manifest もあります。Codex plugin route では、plugin manifest が `skills/` や `.mcp.json` などの bundled components を指し、Codex が plugin として読み込みます。

Codex 公式ドキュメントでは、plugins は skills / MCP servers / apps / hooks などを manifest から配布できる仕組みとして説明されています。plugin route を使う場合、同じ資産を `~/.codex/` や `~/.agents/skills/` に手動展開するかどうかは、重複を避ける観点で分けて考える必要があります。

## dotfiles で管理するときの構成

dotfiles で管理する場合は、ECC の出力をいったん `~/dotfiles` 配下に受け、その内容を `install.sh` で実 HOME の読み込み場所へ symlink します。Claude Code や Codex が読むのは実 HOME 側ですが、差分確認や再生成の基準は dotfiles 側に置きます。

この節では、ECC の出力先と runtime の読み込み場所の対応だけを示します。導入手順、branch の作り方、commit / ignore、preflight、uninstall / regenerate は [ecc-dotfiles-manual-install.md](ecc-dotfiles-manual-install.md) を参照します。

```mermaid
flowchart TD
  ECC["ECC repository"]
  ClaudeInstall["Claude manual installer<br/>HOME=$DOTPATH"]
  CodexSync["Codex sync script<br/>CODEX_HOME=$DOTPATH/.codex"]
  CodexSkills["ECC .agents/skills bundle"]
  Install["install.sh"]
  HomeClaude["~/.claude/"]
  HomeCodex["~/.codex/"]
  HomeAgents["~/.agents/skills/"]
  ClaudeRuntime["Claude Code runtime"]
  CodexRuntime["Codex runtime"]

  subgraph Dotfiles["~/dotfiles"]
    DotClaude["~/dotfiles/.claude/"]
    DotCodex["~/dotfiles/.codex/"]
    DotAgents["~/dotfiles/.agents/skills/"]
  end

  ECC --> ClaudeInstall --> DotClaude
  ECC --> CodexSync --> DotCodex
  ECC --> CodexSkills --> DotAgents
  DotClaude --> Install --> HomeClaude --> ClaudeRuntime
  DotCodex --> Install --> HomeCodex --> CodexRuntime
  DotAgents --> Install --> HomeAgents --> CodexRuntime
```

Claude 側は、ECC manual installer を `HOME=$DOTPATH` で実行し、`~/dotfiles/.claude/` に受けます。主な出力は次の通りです。

```text
~/dotfiles/.claude/rules/ecc/
~/dotfiles/.claude/skills/ecc/
~/dotfiles/.claude/commands/
~/dotfiles/.claude/agents/
~/dotfiles/.claude/hooks/
~/dotfiles/.claude/scripts/
~/dotfiles/.claude/mcp-configs/
~/dotfiles/.claude/the-security-guide.md
~/dotfiles/.claude/ecc/install-state.json
```

Codex 側は、ECC sync script の `CODEX_HOME` を `~/dotfiles/.codex` に向けます。主な出力は次の通りです。

```text
~/dotfiles/.codex/AGENTS.md
~/dotfiles/.codex/config.toml
~/dotfiles/.codex/agents/
~/dotfiles/.codex/prompts/
```

Codex sync script は `$DOTPATH/.codex/git-hooks/` も生成できますが、これは Git global hooks 用の script body で、Codex runtime が読む `~/.codex/` の instruction / config / prompt surface とは別に扱います。

Codex sync script は skills をコピーしないため、Codex skills は ECC repo の `.agents/skills/` bundle を `~/dotfiles/.agents/skills/` に用意します。`install.sh` 実行後、Codex は実 HOME 側の `~/.agents/skills/` からそれらを読みます。

## ECC local references

The examples in this document use `ECC_REPO=/path/to/everything-claude-code`.

- ECC README: `$ECC_REPO/README.md`
- Claude installer target: `$ECC_REPO/scripts/lib/install-targets/claude-home.js`
- Codex installer target: `$ECC_REPO/scripts/lib/install-targets/codex-home.js`
- Codex sync script: `$ECC_REPO/scripts/sync-ecc-to-codex.sh`
- dotfiles install surface definition: `profiles/ecc/surfaces.tsv`, `profiles/ecc/skipsets.tsv`
- dotfiles install preflight: `profiles/ecc/checks.d/10-local-state.sh`
- dotfiles Codex sync marker writer: `profiles/ecc/bin/write-codex-sync-state.sh`
- Claude plugin manifest: `$ECC_REPO/.claude-plugin/plugin.json`
- Codex plugin manifest: `$ECC_REPO/.codex-plugin/plugin.json`

## Official references

- Anthropic Claude Code settings: <https://docs.anthropic.com/en/docs/claude-code/settings>
- Anthropic Claude Code memory: <https://docs.anthropic.com/en/docs/claude-code/memory>
- Anthropic Claude Code subagents: <https://docs.anthropic.com/en/docs/claude-code/sub-agents>
- Anthropic Claude Code hooks: <https://docs.anthropic.com/en/docs/claude-code/hooks>
- Anthropic Claude Code plugins: <https://docs.anthropic.com/en/docs/claude-code/plugins>
- OpenAI Codex AGENTS.md: <https://developers.openai.com/codex/guides/agents-md#how-codex-discovers-guidance>
- OpenAI Codex config: <https://developers.openai.com/codex/config-reference#configtoml>
- OpenAI Codex skills: <https://developers.openai.com/codex/skills#where-to-save-skills>
- OpenAI Codex hooks: <https://developers.openai.com/codex/hooks#where-codex-looks-for-hooks>
- OpenAI Codex subagents: <https://developers.openai.com/codex/subagents#custom-agents>
- OpenAI Codex plugin manifest: <https://developers.openai.com/codex/plugins/build#manifest-fields>
- OpenAI Codex plugin marketplace: <https://developers.openai.com/codex/plugins/build#add-a-marketplace-from-the-cli>
