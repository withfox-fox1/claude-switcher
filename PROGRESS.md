# PROGRESS

最終更新: 2026-11-17

## 完了
- ccx 本体（main / withfox の 2 アカウント構成、設定・会話履歴・memory は共有）
- withfox ログイン済み（キーチェーン項目 `Claude Code-credentials-16317cc0`、main とは別）
  - 再ログイン手順: `BROWSER=<Chrome の WithFox プロファイルで開くスクリプト> ccx withfox auth login --email <メール>`
- `/switch [name]`: 本物の claude で main → withfox の切替を確認済み（同一セッションが再開し、`claude auth status` が withfox を示した）
- メニューバーアプリ ClaudeSwitcher を /Applications に導入
- ccx・switch.md を本リポジトリへ移し、元の場所はシンボリックリンク化

## 次の作業
- メニューバーアプリからの切替（withfox → main）を実機で確認する

## 判明した注意点
- claude.ai コネクタはアカウントごとに別。withfox では Gmail・Drive・Sheets が使え、main で使えていた Meetings・Claude Data は使えない。
- 切替時は実行中の処理が中断される。再開直後の 1 回目はキャッシュが効かず、会話全体を読み直す分の使用量がかかる。
- セッション中に許可した権限はリセットされる（settings に保存した許可は維持）。
- `/exit` 後に `claude` で起動し直すと main に戻る（`claude` = `ccx main`）。
