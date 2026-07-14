# VERIFICATION_STATUS — 全專案「未實機驗證」缺口清單（開機驗證清單）

- 產出任務: CORE-7
- 日期: 2026-07-14
- 用途: 交給 John／未來任何**有 Godot 4.3+ 執行檔**的環境，作為「拿到引擎後照著跑一遍」的驗收清單。

## 一句話總結

**整個 Godot 專案目前 0 個任務做過真正的實機驗證。** 六種下載管道全被網路政策擋下（見
`../TASKS/00_核心任務.md` CORE-1「驗收現況」），這個沙盒環境從頭到尾沒有 Godot 執行檔，所有 `.gd` 檔案
**從未被引擎剖析或執行過**。各任務用「純 Python 交叉驗證」或「人工語法核對」逼近正確性，但**沒有任何一項
跑過 `godot --headless --check-only`**。這份清單列出每個任務的驗證程度，讓有引擎的人知道該補跑什麼。

## 驗證程度分級

- **L3 Python 交叉驗證**：有一支保留在 repo、`run_all_tests.py` 會跑到的 `test_*/validate_*/verify_*.py`，
  把 `.gd` 邏輯或 build_cq2.py 公式逐行翻成 Python 再比對（或對 CONTENT.json 做資料一致性檢查）。最強的
  「非實機」保證，但仍不證明 GDScript 能被引擎剖析。
- **L2 一次性 Python 驗證**：實作時寫過純 Python 交叉驗證斷言並通過，但腳本**沒有保留在 repo**（一次性
  使用），現在無法重跑，只有任務檔的文字紀錄。
- **L1 語法/人工核對**：只做過括號成對、縮排一致、API 名稱拼寫、`project.godot` 區塊邊界等靜態檢查。
- **L0 未驗證**：草稿/未開工。

**全部任務共同缺口（一律待補）**：`godot --headless --check-only --path godot-project`（語法/場景剖析）＋
編輯器內實機執行。

## 逐任務清單

| 任務 | 產出（主要 .gd） | 驗證程度 | repo 內可重跑的測試 | 待補（有 Godot 後） |
|---|---|---|---|---|
| CORE-1 骨架 | `project.godot`, `scenes/title/title.tscn` | L1 | — | `--check-only`；實機確認 `stretch/mode="viewport"` 縮放/像素對齊 |
| CORE-2 ContentDB | `autoload/content_db.gd`, `scripts/content/*_def.gd` | **L3** | `validate_content.py` | `--check-only`；編輯器內 `ContentDB.get_enemy("goblin_chief").hp` 回傳正確 |
| CORE-3 SaveManager | `autoload/save_manager.gd` | L2 | —（41 條斷言未留 repo） | `--check-only`；存→重啟→讀檔一致（含室內存門口外，待 MOD-C/H 場景就緒） |
| CORE-4 GameState | `autoload/game_state.gd` | L2 | —（18 條斷言未留 repo） | `--check-only`；背包加減/旗標/寶箱去重邊界實機測 |
| CORE-5 SceneRouter | `autoload/scene_router.gd` | L2 | —（6 情境 + gdlint 未留 repo） | `--check-only`；World↔Battle 轉場、戰敗回座標（待 MOD-C/H/E 場景） |
| CORE-6 InputBridge | `autoload/input_bridge.gd` | L1 | —（薄轉發，無自訂邏輯） | `--check-only`；鍵盤 + 觸控模擬觸發同一組 action |
| CORE-7 測試骨架 | `tests/run_all_tests.py`, `tests/smoke_test.gd`, `tests/debug_hooks.gd`, `tests/gut/*` | 混合 | **`run_all_tests.py` 本身可跑（聚合下方 L3 測試，全綠）** | `--check-only`；`smoke_test.gd` 實跑；vendor GUT 後跑 `.gutconfig.json` |
| MOD-A 對話劇情 | `scripts/dialogue/dialogue_system.gd` 等 | **L3** | `verify_dialogue.py` | `--check-only`；三位多階段 NPC 對話分支實機抽測 |
| MOD-B 撿取觸發 | `scripts/world/{trigger,exit,pickup}_zone.gd`, `boss_mark.gd`, `flag_matcher.gd` | L2 | —（純邏輯交叉驗證未留 repo） | `--check-only`；Area2D 碰撞觸發 + pickup 存檔 |
| MOD-C 移動碰撞 | `scripts/world/world_scene_state.gd` 等 | L1 | — | `--check-only`；玩家移動/碰撞/室內進出實機 |
| MOD-D 選單 UI | （TASKS/04，本 worktree 草稿；另一 agent 於 mod-d 分支平行進行） | L0 | — | 待該任務完成後補 |
| MOD-E 戰鬥 ATB | `scripts/battle/{battle_state_machine,atb,damage_calc,exp_scale,auto_battle}.gd` | **L3** | `test_battle_formulas.py` | `--check-only`；戰鬥自動打法實機（見 README E2E-3） |
| MOD-F 衍生公式 | `scripts/content/{derive,exp_need}.gd` | **L3** | `test_derive.py` | `--check-only`；`Derive.derive()` 引擎內回傳對齊 fixture |
| MOD-G 遭遇系統 | `scripts/world/encounter_tracker.gd` | **L3** | `test_encounter_tracker.py` | `--check-only`；實機走 ENC 地形觸發間距 |
| MOD-H 地圖管線 | `scripts/world/world_scene.gd`, 五張 `scenes/world/*.tscn`, `scripts/map/gen_maps.py` | L1（+ 生成器逐格比對） | —（`gen_maps.py` 是 generator，不在 test 聚合） | `--check-only`；五張場景實機載入、TileMapLayer/碰撞正確 |
| MOD-I 美術管線 | `assets/**`（612 檔）+ import 設定 | L1（+ 檔案雜湊比對） | — | `--check-only`；編輯器內 Filter 無模糊、bgm loop import |

## 建議的「開機驗證」執行順序

拿到 Godot 4.3+ 執行檔後，依序做（前一步過才做下一步）：

1. `python3 tests/run_all_tests.py` — 確認 Python 交叉驗證層仍全綠（此步現在就能做，且應納入 CI）。
2. **暫時移出 `tests/gut/`**（或先 vendor GUT addon），然後
   `godot --headless --check-only --path godot-project` — 全專案語法/場景剖析。這是解鎖所有任務「已驗收」
   的第一道門；過了之後可把 CORE-1~6 及各 L2/L1 任務逐一升級狀態。
3. `godot --headless -s res://tests/smoke_test.gd --path .` — autoload 掛載 + 8 場景載入 + 輕量場景實例化。
4. 逐一實機驗證各任務的「下一步」欄位（見上表），驗一項、把該任務 `TASKS/*.md` 狀態改「已驗收」、勾
   `MIGRATION_OVERVIEW.md`。
5. vendor GUT → 跑 `.gutconfig.json`，開始把 README「E2E 對照表」的待建案例逐一實作進 `tests/gut/`。

## 重要提醒

- **不要因為 `run_all_tests.py` 全綠就把任務標「已驗收」。** L3 也只是「Python 鏡像與權威來源一致」，
  不等於引擎能跑。真正的「已驗收」門檻是 `--check-only` 過 + 實機執行對應場景（見 `CLAUDE.md`
  「驗證與測試」與各任務「驗收標準」）。
- **不要重試下載 Godot。** 六種管道確認被網路政策擋下，重試是浪費時間（`../TASKS/00_核心任務.md`
  CORE-1）。這份清單的存在就是為了把驗證工作明確移交給有引擎的環境。
