---
name: gen-battle-prompt
description: 組出「戰鬥立繪」的產圖 prompt（純文字，直接貼到 John 的產圖工具）。當 John 說「產戰鬥立繪」「幫某角色/敵人出戰鬥圖 prompt」「戰鬥 sprite／二頭身戰鬥圖 prompt」「重出某單位的戰鬥圖」等需求時使用。規則與模板不內嵌在本 skill——權威來源是 docs/pipeline/battle_art/（workflow.md 產線入口、prompts/role.md 組裝規則、prompts/presets/ 凍結正式版），開工先讀。
---

# gen-battle-prompt：組出戰鬥立繪產圖 prompt（純文字）

目的：John 要產某單位（角色／敵人）的戰鬥立繪時，組出**一段可直接複製貼上的純文字 prompt**。
本 skill 只負責問答與組裝，**規則一律以 `docs/pipeline/battle_art/` 為準**。

## 開工必讀

1. `docs/pipeline/battle_art/workflow.md` —— 產線 8 步驟（本 skill 對應 Step 3）
2. `docs/pipeline/battle_art/prompts/role.md`（角色）／`prompts/enemy.md`（敵人）—— 組裝規則＋**目前正式版 preset 的指向**
3. `docs/design/戰鬥立繪規格.md` —— 素材長什麼樣（有疑義時對照）

## 流程

1. **確認單位與動作**：查 `prompts/descriptions/<id>.md`（一單位一檔）有沒有該單位的「最後一版」描述；
   動作需求（戰鬥預備／seed／idle／attack…）John 沒講就問。
2. **取 preset**：角色以 `prompts/role.md`、敵人以 `prompts/enemy.md`「正式版本」節指向的 preset 為準
   （不要自己挑舊版），整段沿用、不改內文。
3. **帶入單位描述**：把 preset 結尾的描述插槽換成該單位的一段（外觀＋服裝配色＋武器＋姿勢與面向，
   我方面向左、敵方面向右）。descriptions 沒有的單位→用問答補齊（角色外觀先引 `docs/story/角色設定.md`、
   敵人照 `portrait_<id>` 特徵，缺再問），去背底色依 `prompts/sections/50_去背螢光底.md` 的挑色規則。
4. **輸出**：一個 code block、純 prompt 文字、繁體中文、整段同一語言；不含 markdown 標記以外的說明文字。
5. **輸出後提醒（一行）**：產完照 `battle_art/checklist.md` 驗收（先預覽給 John 驗收、過了才整合——
   CLAUDE.md 產圖驗收流程）；驗收通過把這次的描述回寫 `prompts/descriptions/<id>.md`（沒有就新增一檔）。

## 邊界

- 對話／介紹用立繪 → `gen-role-prompt`；地圖 walk 素材 → 見 `docs/pipeline/世界立繪流程.md`。
- 要**實驗改規則**（風格／去背／動畫限制…）→ 改 `prompts/sections/` 對應檔組實驗版，不動 preset；
  成功後另存新 preset 並更新 `role.md` 與 `workflow.md` 的指向。
