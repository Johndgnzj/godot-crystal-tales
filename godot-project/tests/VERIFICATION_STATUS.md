# VERIFICATION_STATUS — 全專案「未實機驗證」缺口清單（開機驗證清單）

- 產出任務: CORE-7
- 日期: 2026-07-14
- 用途: John 本機（Godot 4.7）「照著跑一遍」的驗收清單；已完成首次真機驗證，其餘逐項待補。

## 一句話總結

**Godot 4.7 已就位，2026-07-14 完成首次真機驗證。** `smoke_test.gd` 在引擎上實跑 **SMOKE PASS（20/0）**：
7 個 autoload 掛載、`ContentDB`/`DialogueSystem` 載入、8 個場景載入成 `PackedScene`、title/dialogue_box
實例化 `_ready` 不崩。首次真機也逼出並修掉 2 個 parse error（`save_manager.gd` 的 `inference_on_variant`、
`battle_state_machine.gd` 的三元式含 Variant 迴圈變數）。**仍未驗證**：全檔剖析（冒煙測試只載 8 場景，
UI 場景 menu/shop/hud 未涵蓋）、實際玩法（存讀檔/戰鬥/移動）、viewport 視覺縮放。下表列出每個任務還差什麼。

## 驗證程度分級

- **L3 Python 交叉驗證**：有一支保留在 repo、`run_all_tests.py` 會跑到的 `test_*/validate_*/verify_*.py`，
  把 `.gd` 邏輯或 build_cq2.py 公式逐行翻成 Python 再比對（或對 CONTENT.json 做資料一致性檢查）。最強的
  「非實機」保證，但仍不證明 GDScript 能被引擎剖析。
- **L2 一次性 Python 驗證**：實作時寫過純 Python 交叉驗證斷言並通過，但腳本**沒有保留在 repo**（一次性
  使用），現在無法重跑，只有任務檔的文字紀錄。
- **L1 語法/人工核對**：只做過括號成對、縮排一致、API 名稱拼寫、`project.godot` 區塊邊界等靜態檢查。
- **L0 未驗證**：草稿/未開工。

**全部任務共同缺口（一律待補）**：冒煙測試未涵蓋的檔案逐一實機載入 ＋ 編輯器內實機執行對應場景/玩法。
（注意：全專案 `--check-only --path` 不加 `--script` 會**卡死**，別用；逐檔用 `--check-only --script <單檔>`，
全專案的實質剖析/載入靠 `smoke_test.gd`。）

## 逐任務清單

| 任務 | 產出（主要 .gd） | 驗證程度 | repo 內可重跑的測試 | 待補（有 Godot 後） |
|---|---|---|---|---|
| CORE-1 骨架 | `project.godot`, `scenes/title/title.tscn` | **實機(4.7)**：專案開得起來、title 載入+實例化 | — | 編輯器開視窗確認 `stretch/mode="viewport"` 縮放/像素對齊（headless 測不到） |
| CORE-2 ContentDB | `autoload/content_db.gd`, `scripts/content/*_def.gd` | **L3＋實機(4.7)**：`is_loaded`＋`get_enemy` 冒煙通過 | `validate_content.py` | 已達驗收標準，可勾「已驗收」 |
| CORE-3 SaveManager | `autoload/save_manager.gd` | L2 | —（41 條斷言未留 repo） | `--check-only`；存→重啟→讀檔一致（含室內存門口外，待 MOD-C/H 場景就緒） |
| CORE-4 GameState | `autoload/game_state.gd` | L2 | —（18 條斷言未留 repo） | `--check-only`；背包加減/旗標/寶箱去重邊界實機測 |
| CORE-5 SceneRouter | `autoload/scene_router.gd` | L2 | —（6 情境 + gdlint 未留 repo） | `--check-only`；World↔Battle 轉場、戰敗回座標（待 MOD-C/H/E 場景） |
| CORE-6 InputBridge | `autoload/input_bridge.gd` | L1 | —（薄轉發，無自訂邏輯） | `--check-only`；鍵盤 + 觸控模擬觸發同一組 action |
| CORE-7 測試骨架 | `tests/run_all_tests.py`, `tests/smoke_test.gd`, `tests/debug_hooks.gd`, `tests/gut/*` | 混合＋**smoke 實機(4.7)綠** | `run_all_tests.py`（聚合 L3，全綠）＋`smoke_test.gd`（實跑綠） | vendor GUT 後跑 `.gutconfig.json`；把 UI 場景加進 smoke 覆蓋 |
| MOD-A 對話劇情 | `scripts/dialogue/dialogue_system.gd` 等 | **L3＋實機(4.7)**：`DialogueSystem.is_loaded` 冒煙通過 | `verify_dialogue.py` | 三位多階段 NPC 對話分支實機抽測 |
| MOD-B 撿取觸發 | `scripts/world/{trigger,exit,pickup}_zone.gd`, `boss_mark.gd`, `flag_matcher.gd` | L2 | —（純邏輯交叉驗證未留 repo） | `--check-only`；Area2D 碰撞觸發 + pickup 存檔 |
| MOD-C 移動碰撞 | `scripts/world/world_scene_state.gd` 等 | L1 | — | `--check-only`；玩家移動/碰撞/室內進出實機 |
| MOD-D 選單 UI | （TASKS/04，本 worktree 草稿；另一 agent 於 mod-d 分支平行進行） | L0 | — | 待該任務完成後補 |
| MOD-E 戰鬥 ATB | `scripts/battle/{battle_state_machine,atb,damage_calc,exp_scale,auto_battle}.gd` | **L3** | `test_battle_formulas.py` | `--check-only`；戰鬥自動打法實機（見 README E2E-3） |
| MOD-F 衍生公式 | `scripts/content/{derive,exp_need}.gd` | **L3** | `test_derive.py` | `--check-only`；`Derive.derive()` 引擎內回傳對齊 fixture |
| MOD-G 遭遇系統 | `scripts/world/encounter_tracker.gd` | **L3** | `test_encounter_tracker.py` | `--check-only`；實機走 ENC 地形觸發間距 |
| MOD-H 地圖管線 | `scripts/world/world_scene.gd`, 五張 `scenes/world/*.tscn`, `scripts/map/gen_maps.py` | L1（+ 生成器逐格比對） | —（`gen_maps.py` 是 generator，不在 test 聚合） | `--check-only`；五張場景實機載入、TileMapLayer/碰撞正確 |
| MOD-I 美術管線 | `assets/**`（612 檔）+ import 設定 | L1（+ 檔案雜湊比對） | — | `--check-only`；編輯器內 Filter 無模糊、bgm loop import |

## 建議的「開機驗證」執行順序

Godot 4.7 已就位。依序做（前一步過才做下一步）：

1. `python3 tests/run_all_tests.py` — 確認 Python 交叉驗證層仍全綠（納入 CI）。
2. `/Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/smoke_test.gd --path .` —
   autoload 掛載 + 8 場景載入 + 輕量場景實例化（**現況：SMOKE PASS 20/0**）。這是全專案的實質剖析/載入門。
   （不要用 `--check-only --path` 全專案掃：不加 `--script` 會卡死；逐檔查用 `--check-only --script <單檔>`。）
3. 逐一實機驗證各任務「待補」欄位（見上表），驗一項、把該任務 `TASKS/*.md` 狀態改「已驗收」、勾
   `MIGRATION_OVERVIEW.md`。
4. 把 UI 場景（menu/shop/hud/menu_panel）加進 `smoke_test.gd` 的場景清單，補上冒煙覆蓋缺口。
5. vendor GUT → 跑 `.gutconfig.json`，開始把 README「E2E 對照表」的待建案例逐一實作進 `tests/gut/`。

## 重要提醒

- **不要因為 `run_all_tests.py` 全綠就把任務標「已驗收」。** L3 只是「Python 鏡像與權威來源一致」，
  不等於引擎能跑。真正的「已驗收」門檻是冒煙測試（或對應場景）實機跑過 + 該任務「驗收標準」的玩法確認
  （見 `CLAUDE.md`「驗證與測試」）。
- **冒煙測試綠 ≠ 全部驗過。** 它只載 8 個場景，未涵蓋 UI 場景與實際玩法（存讀檔/戰鬥/移動/viewport 視覺）。
