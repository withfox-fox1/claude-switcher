---
description: Claude のアカウントを切り替えて、この会話を続きから再開する（例: /switch, /switch withfox）
argument-hint: "[アカウント名（省略時は次のアカウント）]"
allowed-tools: Bash(ccx switch:*)
disable-model-invocation: true
---

!`ccx switch $ARGUMENTS 2>&1`

上の結果を1行で伝えてください。
