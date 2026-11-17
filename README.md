# ClaudeSwitcher

Claude Code を複数アカウントで使い分けるための仕組み一式（macOS 用）。
会話を引き継いだまま（`--resume <セッションID>`）、別アカウントで開き直せる。

## 構成

| パス | 役割 | 導入先 |
|---|---|---|
| `bin/ccx` | アカウント切替ランチャー（本体） | `~/.local/bin/ccx`（シンボリックリンク） |
| `commands/switch.md` | Claude Code 内の `/switch [name]` コマンド | `~/.claude/commands/switch.md`（シンボリックリンク） |
| `Sources/main.swift` ほか | メニューバーアプリ ClaudeSwitcher | `/Applications/ClaudeSwitcher.app` |

## ccx の仕組み

- `main` = `~/.claude`（`CLAUDE_CONFIG_DIR` を設定しない）
- それ以外 = `~/.claude-accounts/<name>` を `CLAUDE_CONFIG_DIR` として使う
- アカウントごとに分かれるのはログイン情報（`.claude.json` とキーチェーン）のみ。
  CLAUDE.md・設定・skills・plugins・commands・会話履歴・memory は `~/.claude` へのシンボリックリンクで共有する。
- 注意: ユーザー MCP 設定（`.claude.json` 側）と claude.ai コネクタはアカウントごとに別になる。

```
ccx                     アカウント選択メニューを表示して起動
ccx <name> [args...]    指定アカウントで claude を起動
ccx <name> -c           直近の会話を指定アカウントで再開
ccx list                アカウントとログイン中のメールを表示
ccx add <name>          アカウントを追加
ccx tab-switch [name]   前面の Terminal タブの claude を切り替える（メニューバーアプリが使用）
```

`/switch` を使うには、claude を ccx 経由で起動する必要がある（`~/.zshrc` に `alias claude="ccx main"`）。

## メニューバーアプリ

- 表示: 前面の Terminal タブのアカウント名（main / WithFox など）
- 操作: クリック →「◯◯ に切り替え」
- 実処理: `~/.local/bin/ccx tab-switch <name>`
- ビルド・導入: `./build.sh install`（/Applications に上書きして起動）

## 導入（新しい Mac）

```sh
ln -s ~/claude-switcher/bin/ccx ~/.local/bin/ccx
mkdir -p ~/.claude/commands && ln -s ~/claude-switcher/commands/switch.md ~/.claude/commands/switch.md
./build.sh install
ccx add <name>   # 追加アカウントごとに実行し、/login する
```
