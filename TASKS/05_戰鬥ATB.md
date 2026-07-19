# MOD-E　戰鬥系統（ATB）

- Task 版本: v1.2
- 狀態: 實作中
- 對應 GDevelop 系統: BATTLE_JS 全部（DEV_開發指南.md L56-59）
- 規格來源: `specs/BATTLE_FORMULAS.md` F-3~F-9、F-11（本模組是 spec 的主要消費者，需要 MOD-F 的 `derive()`
  等價物已就緒才能算出角色戰鬥數值）

## 目標

重建 ATB 戰鬥狀態機：指令（攻/技/道/防禦/逃）、陣型（frontRow/backRow）、Boss 血條、自動戰鬥、敵人技能、
勝敗結算與 EXP/掉落。

## 產出

- `godot-project/scenes/battle/battle.tscn` + `godot-project/scripts/battle/battle_state_machine.gd`
  （狀態：`run`/`anim`/`menu`/`skill`/`item`/`target`/`target_ally`/`win`/`lose`，對應 GDevelop 版
  `b.state`。**`target_ally` 是實作時回原始碼核對後補上的第 9 種狀態**——治療技能/補血道具都需要選我方
  目標（build_cq2.py L2762/L2780），任務檔原本列出的八種狀態清單少列了這個，屬於原始碼既有行為，不是
  自創需求）
- `godot-project/scripts/battle/atb.gd`（F-7 公式，`ATB_K=1.05` 常數集中管理，附註標明來源是 Design
  Tweaks 定案值，不是可隨意調的臨時參數）
- `godot-project/scripts/battle/damage_calc.gd`（F-3~F-6、F-8，普攻/技能/道具/敵人技能傷害與治療，全部
  引用 `specs/BATTLE_FORMULAS.md` 條目編號作為程式碼註解錨點）
- `godot-project/scripts/battle/exp_scale.gd`（F-9 EXPSCALE 現場計算，見下方「與規格書差異」）
- **遭遇抽選（v1.2，2026-07-19，遭遇系統重製）**：`_init_battle()` 改呼叫 `EncounterDef.roll()`（加權抽組
  ＋數量範圍展開＋洗牌＋上限 5＋保底 1 隻，見 F-11）；戰場敵人數上限由 4 提到 5（`FOE_SLOTS` 擴到 5 槽、
  取模改用 `slots.size()`；第 5 槽座標為估值待實機微調）。`exp_scale.gd` 每組平均 EXP 同步改為加權期望（F-9 v3.0 註記）。
- `godot-project/scripts/battle/auto_battle.gd`（`GameState.auto_battle` 對應邏輯）
- 勝敗結算（`battle_state_machine.gd` 的 `_settle_win()`/`_settle_lose()`/`_sync_party_to_game_state()`）：
  EXP（含 EXPSCALE，見 F-9）、升級/技能解鎖、掉落物寫入 `GameState.item_inv`/`gold`、
  Boss 專屬「☠ 名稱不露數字」血條顯示規則、勝負呼叫 `SceneRouter.battle_result()`。
- `godot-project/scripts/battle/test_battle_formulas.py`：F-3~F-9 的 Python 交叉驗證測試（見下方
  「驗證現況」）。

## 前置依賴

CORE-1~CORE-6、MOD-F（衍生屬性公式必須先有等價實作）。**MOD-D 的血條/選單 UI 元件若已就緒可直接複用，
若尚未就緒，本模組先用最簡陋 UI 頂著，之後換裝，不要為了等 MOD-D 卡住整個模組**——本次實作沿用這個
決定，`battle.tscn` 目前是純 Label/ProgressBar，沒有觸控/滑鼠點擊命中判定（`InputBridge` 鍵盤操作已
完整）。

## 驗收標準

- 逐條核對 `specs/BATTLE_FORMULAS.md` F-3~F-9，寫單元測試釘住每條公式的輸出（相同輸入、允許隨機項的
  期望值範圍）。**已完成**：`test_battle_formulas.py` 涵蓋 F-3（phys，含確定性算例＋統計會心率/傷害
  範圍）、F-4（dodge_chance 含上下限 clamp＋統計命中率）、F-5（skPow/skBase/skDef/skill_damage/
  skill_heal，含 str/int 兩種 attr 分支、角色/敵人兩種 skBase 分支）、F-6（item_usable_in_battle）、
  F-8（foe_named_skill_damage 確定性算例、foe_heal_amount 範圍統計、決策樹組合機率統計）、F-9
  （EXPSCALE 五張真實地圖 + 三場特殊戰役 fallback=1.0）。
- 現有已知敵人（含 `bear_dire` 狂暴洞熊、`wolf`、`goblin_chief` 等）的技能/掉落行為與 CONTENT.json
  一致——測試資料直接讀真實 CONTENT.json。
- 敵人技能 40% 觸發機率、`healer`/`allAttack` 旗標並存邏輯已在 MOD-E 實作時回 `foeAct` 函式補完精確
  算式，`specs/BATTLE_FORMULAS.md` F-8 已升版至 v1.1（見該檔案版本紀錄）。

## 與規格書（v1.0）的差異／實作時發現的缺口

1. **F-8 敵人技能規格已補齊並升版至 v1.1**：`healer`（20~30 固定治療、目標取陣列中第一個血量
   <55% 的存活友軍）／具名技能（40%，單體會判 dodge、全體不判）／`allAttack`（40% 沒中才擲的
   30%，不判 dodge、無倍率）／一般攻擊 fallback 四段優先序，精確算式與機率關係（allAttack 實際
   觸發率是 0.6×0.3=18%，不是獨立 30%）都寫進 `specs/BATTLE_FORMULAS.md` F-8。
2. **F-7 原文有一處抄錄錯誤，已修正**：v1.0 寫「敵人初始 ATB `random()*40`、英雄無初值」，實際上
   L2852 的 `random()*40` 是**英雄**的初值，敵人是 L2862 的 `random()*30`——兩者都寫反了。已在
   `specs/BATTLE_FORMULAS.md` v1.1 更正並記錄在版本紀錄。
3. **F-9 EXPSCALE 目前沒有被 CORE-2 轉存進 `content.json`**：規格書 v1.0 原文假設「CORE-2 轉存時
   把 EXPSCALE 算好存進去」，但實際檢查 `sync_content.py`/`content_db.gd`/
   `resources/content/content.json` 後發現這張表從未被轉存過（它在 GDevelop 端只是 build-time
   Python 算出來字串替換進 JS，從未進過 CONTENT.json 本體）。**變通做法**：`exp_scale.gd` 用
   `ContentDB` 現有的唯讀查詢介面（`get_pacing()`/`get_encounter()`/`get_enemy()`）現場算出等價值，
   純函式、不寫回任何狀態，不違反「不允許模組自己重算衍生屬性」的規則（那條規則管的是 `derive()`，
   EXPSCALE 是完全不同的一條公式）。若之後 CORE-2 想把這個表移到轉存階段，介面收斂方式已經記錄在
   `specs/BATTLE_FORMULAS.md` F-9「MOD-E 實作現況」一節，`battle_state_machine.gd` 呼叫端不需要跟著
   改。
4. **狀態機補了 `target_ally`**：見上方「產出」。
5. **`scripted`（序章強制戰 `prologue_demon`）與 boss 專屬結算（`ch1_boss`/`ch2_bear` 的固定裝備/
   旗標獎勵）已一併實作**，雖然任務檔「目標」段落沒有逐字列出，但這些都是 `foeAct()`/`checkEnd()`
   的既有行為，`initB()`/`_check_end()` 沒有實作這兩塊會導致序章戰鬥/兩場劇情 boss 戰結算不正確。

## 驗收現況（2026-07-14 收尾驗證）

- **`test_battle_formulas.py` 全數通過（FAIL: 0）**：確定性算例（F-3/F-4/F-5/F-6/F-8/F-9 逐位元核對）
  ＋ Monte Carlo 統計檢定（N=20000，會心率/閃避率/敵人技能決策樹組合機率）＋ Node.js 交叉驗證
  （8 個案例，「字面抄自 build_cq2.py 的 JS 公式」在固定隨機骰值下與 Python 鏡像逐位元一致）。
  收尾時修正測試腳本兩處問題：(1) `dict(wolf, def=0)` 的 `def` 是 Python 關鍵字造成 SyntaxError
  （dodgeCap 上限測試的假資料建構），改用 dict 展開寫法；(2) F-4 統計檢定原本把攻守方向寫反
  （`dodge_chance(wolf, HERO_A)` 被 clamp 成 0，斷言 0≈0 等於沒測），改成非退化的 6% 方向並加前提
  斷言。**戰鬥公式本身（.gd 與 spec）未因此改動**——兩處都是測試腳本自身的錯，不是公式錯。
- **F-8 規格（v1.1）回 `build_cq2.py foeAct()`（L3019-3068）複核通過**：40% 具名技能機率、
  healer/allAttack/foeSkills 三旗標並存的四段短路優先序（allAttack 實際觸發率 0.6×0.3=18%）、
  傷害算式（`max(1, round(phys().d × mult))`，mult 套在 phys 最終輸出上）、healer 治療量
  `20+round(random()*10)` 與「第一個 <55% 血量友軍」目標規則、單體判 dodge／全體不判——全部與
  原始碼一致。F-7 v1.1 的修正（英雄初值 `random()*40` L2852／敵人 `random()*30` L2862）與 F-9
  的 EXPSCALE 精確算式（L3304-3317、查表 L3092）也一併複核無誤。
- **`battle.tscn` ↔ `battle_state_machine.gd` node path 全面核對通過**：14 個 `@onready` 引用
  （`UI/Banner`/`BossName`/`BossHpBar`/`HeroList`/`FoeList`/`CmdMenu`/`SkillMenu`/`ItemMenu`/
  `TargetHint`/`AutoLabel`/`ResultPanel` 及其 `ResultTitle`/`ResultMsg`/`ContHint` 三個子 Label）
  與場景樹一一對應；`CmdMenu`/`SkillMenu`/`ItemMenu` 各 5 個 Label 子節點符合程式碼的游標範圍。
- **靜態核對**：六個檔案括號/中括號/大括號全數配對、`.gd` 縮排一律 tab 無空格混用；`class_name`
  （Atb/AutoBattle/DamageCalc/ExpScale）與全專案既有 22 個 class_name 無衝突
  （`battle_state_machine.gd` 刻意不宣告 class_name，只掛在場景上）。
- **對外整合點核對**：`GameState.encounter`/`auto_battle`/`gold`/`eq_inv`/`inv_add()`/`inv_use()`/
  `inv_get()`/`flag_set()`、`Derive.derive()`（MOD-F 單一版本）、`ExpNeed.exp_need()`、
  `ContentDB.get_*`（含 `get_all_skills()`/`get_all_items()`）、`InputBridge.is_action_hit()`
  （`battle_auto` action 已在 project.godot [input] 定義）、`SceneRouter.battle_result()`
  （"win"/"lose"/"flee"/"story"，lose→Town/shrine 覆寫由 SceneRouter 內建）——簽名與行為全部核對
  存在且相符。
- **未能實機驗證**：見下方「已知風險」第一條——環境沒有 Godot 執行檔，`.gd` 從未真的執行過，上述皆為
  靜態核對＋公式交叉驗證，不等於執行期驗證。

## 擁有檔案

`godot-project/scenes/battle/**`、`godot-project/scripts/battle/**`。

## 已知風險 / 未決事項

- **未能實機驗證**：這個執行環境沒有 Godot 執行檔（跟其他 CORE/MOD 任務同樣的環境限制），`.gd` 檔案
  從未被真的執行過。驗證方式見 `test_battle_formulas.py` 檔頭說明（Python 鏡像 + Node.js 交叉驗證
  「字面抄自 build_cq2.py 的 JS 公式」+ 統計檢定），是在拿不到 Godot 執行檔的限制下能做到的最接近方案，
  但不等於「跑過 Godot 後驗證通過」。CORE-7/GUT 有真正的 Godot 執行環境時，應該把測試案例搬過去做
  `.gd` 檔案本身的執行期測試。
- **UI 沒有觸控/滑鼠點擊命中判定**：只支援鍵盤（`InputBridge` 的 `ui_*` action），對應 build_cq2.py
  的 `clickOn()` 那一套沒有實作，MOD-D 換裝時需要一併補上。
- **敵人具名技能 target 欄位只處理了 `"all"` 與非 `"all"` 兩種**（原始碼本身就是這樣寫，`target`
  只有 `"one"`/`"all"` 兩種實際資料值，`"one"` 走 else 分支），CONTENT.json 目前所有 `foeSkills`
  的 `target` 值都只有這兩種，若之後新增第三種 target 語意，這裡的 if/else 需要跟著擴充。
- `derive()` 兩份不同步是 GDevelop 端的已知技術債（`specs/BATTLE_FORMULAS.md` F-1），MOD-F 已合併成
  一份，本模組直接呼叫 MOD-F 提供的 `Derive.derive()` 單一版本，沒有自己再抄一份。
- **未做的邊界情況**：`checkEnd()` 的「同時 ha===0 && fa===0」（雙方同時全滅）理論上不可能發生
  （傷害是逐一單位結算，`_check_end()` 在每次演出結束後才呼叫一次），沿用原始碼「先檢查 fa===0
  （優先判定勝利）」的順序，跟原始碼行為一致，未特別測試這個理論邊界。
