# MOD-E　戰鬥系統（ATB）

- Task 版本: v1.0
- 狀態: 草稿
- 對應 GDevelop 系統: BATTLE_JS 全部（DEV_開發指南.md L56-59）
- 規格來源: `specs/BATTLE_FORMULAS.md` F-3~F-9（本模組是 spec 的主要消費者，需要 MOD-F 的 `derive()` 等價物
  已就緒才能算出角色戰鬥數值）

## 目標

重建 ATB 戰鬥狀態機：指令（攻/技/道/防禦/逃）、陣型（frontRow/backRow）、Boss 血條、自動戰鬥、敵人技能、
勝敗結算與 EXP/掉落。

## 產出

- `godot-project/scenes/battle/battle.tscn` + `godot-project/scripts/battle/battle_state_machine.gd`
  （狀態：`run`/`anim`/`menu`/`target`/`skill`/`item`/`win`/`lose`，對應 GDevelop 版 `b.state`）
- `godot-project/scripts/battle/atb.gd`（F-7 公式，`ATB_K=1.05` 常數集中管理，附註標明來源是 Design
  Tweaks 定案值，不是可隨意調的臨時參數）
- `godot-project/scripts/battle/damage_calc.gd`（F-3~F-6，普攻/技能/道具/敵人技能傷害與治療，全部引用
  `specs/BATTLE_FORMULAS.md` 條目編號作為程式碼註解錨點）
- `godot-project/scripts/battle/auto_battle.gd`（`g_autoBattle` 對應邏輯）
- 勝敗結算：EXP（含 EXPSCALE，見 F-9，直接讀 CORE-2 轉存時算好的值，不在戰鬥程式碼裡重算）、掉落物、
  Boss 專屬「☠ 名稱不露數字」血條顯示規則。

## 前置依賴

CORE-1~CORE-6、MOD-F（衍生屬性公式必須先有等價實作）。**MOD-D 的血條/選單 UI 元件若已就緒可直接複用，
若尚未就緒，本模組先用最簡陋 UI 頂著，之後換裝，不要為了等 MOD-D 卡住整個模組**。

## 驗收標準

- 逐條核對 `specs/BATTLE_FORMULAS.md` F-3~F-9，寫單元測試釘住每條公式的輸出（相同輸入、允許隨機項的
  期望值範圍）。
- 現有已知敵人（含 `bear_dire` 狂暴洞熊、`wolf` 等）的技能/掉落行為與 CONTENT.json 一致。
- 敵人技能 40% 觸發機率、`healer`/`allAttack` 旗標並存邏輯需要在 MOD-E 實作時回 `foeAct` 函式補完精確算式
  （`specs/BATTLE_FORMULAS.md` F-8 目前只有行為輪廓，是本模組的已知待辦，不是可以跳過的細節）。

## 擁有檔案

`godot-project/scenes/battle/**`、`godot-project/scripts/battle/**`。

## 已知風險

- F-8（敵人技能）規格尚未精確化，是本模組工作量裡優先要補齊規格再實作的一項，不要憑感覺猜傷害公式。
- `derive()` 兩份不同步是 GDevelop 端的已知技術債（`specs/BATTLE_FORMULAS.md` F-1），MOD-F 已規劃合併成
  一份，本模組直接呼叫 MOD-F 提供的單一版本即可，不要自己再抄一份。
