# tests/ — 測試與驗證（CORE-7）

- Task 版本: v1.0
- 對應 GDevelop 系統: gdevelop-mcp（`validate_project`/`preview_scene`）＋ puppeteer E2E（`cq2_e2e.mjs`/
  `cq3_e2e.mjs`）、DEV_開發指南.md L73-79
- 狀態: **Python 聚合全綠（需來源 repo `../gd-crystal-tales` 在場；本機目前未 clone，故 4/5 因找不到來源而 fail）；`smoke_test.gd` 已於 Godot 4.7 實機跑過（SMOKE PASS 20/0）；GUT/debug hook 待 vendor GUT／實機**

本目錄取代 GDevelop 端「開瀏覽器 + puppeteer 按鍵模擬」的驗證管道。**Godot 4.7 已就位**（John 本機
`/Applications/Godot.app/Contents/MacOS/Godot`；PATH 內無 `godot` alias），測試分兩層：

| 層 | 檔案 | 現在可跑？ | 說明 |
|---|---|---|---|
| Python 交叉驗證聚合 | `run_all_tests.py` | ✅ 可跑，全綠 | 掃描並執行各模組既有的 `test_*/validate_*/verify_*.py`，這是目前 CI 唯一能真跑的東西 |
| headless 冒煙測試 | `smoke_test.gd` | ✅ 4.7 實機綠 | 純 SceneTree、零外部依賴；load autoload + 8 個場景確認不報錯 |
| GUT 單元測試 | `gut/test_smoke_gut.gd` + `.gutconfig.json` | ⏸ 骨架 | 需先 vendor GUT addon；斷言/報表更完整 |
| debug hook | `debug_hooks.gd` | ⏸ 骨架 | GDevelop `window.__W/__B/__forceEnc` 的 Godot 等價 autoload |
| UI 截圖工具 | `screenshot.gd` | ✅ 需**非** headless | 開 title／選單分頁／世界場景算圖存 PNG，供改 UI/立繪時目視驗收；用法見檔頭註解 |

---

## 1. 現在就能跑：Python 交叉驗證聚合

```bash
cd godot-project
python3 tests/run_all_tests.py          # 跑全部，印彙整表（exit 0=全綠）
python3 tests/run_all_tests.py -v       # 附每支測試完整輸出
python3 tests/run_all_tests.py --list   # 只列出會跑哪些
python3 tests/run_all_tests.py -k battle # 只跑路徑含 "battle" 的
```

掃描規則：從 `godot-project/` 遞迴收集檔名符合 `test_*.py` / `validate_*.py` / `verify_*.py` 的檔案，
排除 generator（`sync_content.py`/`extract_dialogue.py`，那些有寫檔副作用）與 `tests/` 目錄
本身。每支測試以自己的 exit code 表態，runner 只彙整。

**目前收斂到的 5 支（撰寫時全綠）：**

| 測試 | 任務 | 驗什麼 |
|---|---|---|
| `scripts/content/validate_content.py` | CORE-2 | ContentDB 轉存 vs CONTENT.json 一致性、`.gd` 欄位字面 vs 來源 key |
| `scripts/content/test_derive.py` | MOD-F | `derive.gd`/`exp_need.gd` 對照 build_cq2 實測 fixture（Node.js regen） |
| `scripts/battle/test_battle_formulas.py` | MOD-E | 傷害/ATB/EXP 公式 + Node.js 交叉驗證 + Monte Carlo 統計 |
| `scripts/world/test_encounter_tracker.py` | MOD-G | 遭遇距離累積/grace 邏輯 |
| `scripts/dialogue/verify_dialogue.py` | MOD-A | 對話抽取筆數/action 覆蓋率/matchWhen 分支順序 |

> ⚠️ **全綠 ≠ Godot 能跑起來。** 這層驗證的是「Python 鏡像/資料層跟權威來源（build_cq2.py / CONTENT.json）
> 一致」，**不涵蓋** GDScript 語法能否被 Godot 4.3 剖析、autoload 能否載入、場景能否實例化。那一層待下方
> 骨架在有 Godot 環境時補上。詳見 `VERIFICATION_STATUS.md`。

---

## 2. headless 冒煙測試（Godot 4.7 實跑）

`smoke_test.gd` 是純 `SceneTree` 腳本（零外部依賴），跑完會自己 `quit()`：

```bash
cd godot-project
G=/Applications/Godot.app/Contents/MacOS/Godot   # John 本機路徑；PATH 無 godot alias

# 跑冒煙測試：autoload 掛載 + 8 個場景載入 + 輕量場景實例化
"$G" --headless -s res://tests/smoke_test.gd --path .
# exit 0 = SMOKE PASS；非 0 = 有 autoload/場景失敗
```

> ⚠️ **不要用 `godot --headless --check-only --path .` 做全專案剖析**——`--check-only` 不加 `--script`
> 時會被忽略、直接啟動主場景進主迴圈**卡死不結束**（首次實機踩到的坑）。要逐檔語法檢查用
> `--check-only --script <單檔>`；全專案的實質剖析/載入驗證就靠上面這支冒煙測試（它會連帶剖析
> autoloads ＋ 8 個場景的腳本）。

`smoke_test.gd` 檢查：7 個 autoload 掛載、`ContentDB.is_loaded`、`DialogueSystem.is_loaded`、
`get_enemy("goblin_chief")` 抽查、8 個場景（title/battle/五張 world/dialogue_box）能載入成 `PackedScene`、
輕量場景（title/dialogue_box）實例化 + `_ready` 不崩。

### check-only 範圍注意

`tests/gut/test_smoke_gut.gd` `extends GutTest`，**在 GUT addon 就位前 `--check-only` 會因找不到
`GutTest` 報錯**。啟用 GUT 前，check-only 請排除 `tests/gut/`（例如暫時移出或先裝 GUT）。保證 check-only
一定過的冒煙測試是 `smoke_test.gd`（不碰 GUT）。

---

## 3. 拿到 Godot 後：啟用 GUT（更完整的斷言/報表）

GUT（Godot Unit Test）在本環境無法下載，需手動 vendor：

1. 下載 https://github.com/bitwes/Gut 解壓到 `res://addons/gut/`，Project Settings → Plugins 啟用。
2. CLI 跑：
   ```bash
   godot --headless -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/.gutconfig.json --path .
   ```
   `.gutconfig.json` 已設定蒐集 `res://tests/gut/`、輸出 `gut_results.xml`（JUnit，可接 CI）。

之後 `TASKS/10_測試驗證.md` 列的模組整合測試（對話回歸、戰鬥自動打法、存檔回歸、戰鬥公式回歸）都放
`tests/gut/`，沿用同一套 GUT 慣例擴充。

---

## 4. debug hook（`debug_hooks.gd`，autoload `DebugHooks`）

GDevelop 版 puppeteer 靠瀏覽器全域變數讀狀態、強制遭遇；Godot 沒有瀏覽器全域物件，改用 `DebugHooks`
autoload 當「單一除錯查詢點」。自動化測試拿到 SceneTree 後透過 `/root/DebugHooks` 呼叫：

| GDevelop 瀏覽器掛勾 | Godot `DebugHooks` 等價 | 回傳 |
|---|---|---|
| `window.__W` | `DebugHooks.dump_world()` | Dictionary：scene / player_pos / flags / gold / party 摘要 / 轉場暫態 |
| `window.__B` | `DebugHooks.dump_battle()` | Dictionary：state / sel / heroes / foes 摘要（非戰鬥時 `{in_battle:false}`） |
| `window.__forceEnc="ch1_boss"` | `DebugHooks.force_encounter("ch1_boss")` | 走正規 `SceneRouter.start_battle()` 直接開遭遇戰 |
| （puppeteer 在 evaluate 塞旗標） | `DebugHooks.set_flags({"ch2":1})` / `set_gold(777)` | 把遊戲擺到某劇情節點再驗分支 |

只在 debug build（或環境變數 `CQ_DEBUG_HOOKS=1`）啟用，release 匯出不暴露內部狀態。

---

## 5. GDevelop E2E 案例 → Godot 測試 對照表

確保 `ROADMAP_開發計畫.md` 與 DEV 指南 L73-79 記錄過的既有回歸範圍，遷移後都有對應 Godot 測試涵蓋，
不遺漏。**目前欄位「Godot 測試」多為待建**——CORE-7 提供骨架與 debug hook，實際案例由各 MOD 任務驗收時
逐一補進 `tests/gut/`（`TASKS/10_測試驗證.md` 明訂這是持續性收尾工作）。

| # | GDevelop E2E 案例（來源） | 涵蓋的系統 | Godot 對應測試 | 現況 |
|---|---|---|---|---|
| E2E-1 | 冒煙：preview_scene 開場景零 pageerror（gdevelop-mcp `validate_project`/`preview_scene`） | autoload + 場景載入 | `smoke_test.gd`（8 場景載入 + autoload 掛載） | 骨架已寫，待 Godot 跑 |
| E2E-2 | **Track A 完整委託線**：老葛雷 `ch1==3`→`ch2_take`(ch2=1)→`mine_truth` 過場→**bear_dire 精英戰**勝利→ch2=2＋掉疾風靴→Mine `mine_after`→`ch2_report`(ch2=3)＋150G＋藥水×2（`cq2_e2e.mjs`） | 對話/旗標機/CUTS/場景轉場/戰鬥結算/獎勵 | 待建 `tests/gut/test_track_a_quest.gd`：用 `DebugHooks.set_flags`+`force_encounter`+自動打法逐段驗旗標/獎勵 | 待建（骨架依賴就緒） |
| E2E-3 | **戰鬥自動打法**：等 `__B.state=="menu"`→Enter（攻擊）→`state=="target"`→Enter；技能=Right+Enter；卡 skill/item 態→Escape（DEV 指南 L73-79 step 4） | 戰鬥狀態機/輸入 | 待建 `tests/gut/test_auto_battle.gd`：驅動 `DebugHooks.dump_battle().state` 狀態機 + `InputBridge.simulate_action_press("ui_accept")` | 待建（`dump_battle()` + `InputBridge` 已備） |
| E2E-4 | **支線A 米拉鏡草×3**：`mira_start`(送凝神耳環+mira2=1)→東之森 3 個 Herb pickup→`mira_reward`(藥水×3) | 撿取觸發/背包/對話分支 | 待建 `tests/gut/test_mira_sidequest.gd` | 待建 |
| E2E-5 | **支線B 阿吉頭盔**：礦山 `RelicHelmet` pickup(relic=1+miner_helmet)→老葛雷 `relic_turnin`(+100G) | 撿取觸發/旗標/對話 | 待建 `tests/gut/test_relic_sidequest.gd` | 待建 |
| E2E-6 | **存檔回歸**：存→重載→繼續狀態一致（Mine/gold777/ch2:1）；室內存門口外避免卡牆（ROADMAP Track G） | SaveManager/GameState/場景座標 | 待建 `tests/gut/test_save_load.gd`（對照 `specs/SAVE_SCHEMA.md`） | 待建 |
| E2E-7 | **商店買賣**：買藥水/賣素材/金幣變動（ROADMAP D 驗證） | 商店/背包/gold | 待建 `tests/gut/test_shop.gd` | 待建 |
| E2E-8 | **觸控 E2E**：搖桿右移實測位移、BtnMenu 開關選單、PadR 切分頁（ROADMAP B 驗證） | InputBridge/觸控合成鍵 | 待建 `tests/gut/test_touch_input.gd`（`InputBridge.simulate_action_*`） | 待建 |
| E2E-9 | **出入口碰撞**：碰撞不擋主線動線（ROADMAP C/H 驗證） | 世界場景碰撞/exit_zone | 待建 `tests/gut/test_exits.gd` | 待建 |
| E2E-10 | **戰鬥公式回歸**：F-1~F-9（`specs/BATTLE_FORMULAS.md`） | 傷害/衍生/EXP 公式 | ✅ 已有 Python：`test_battle_formulas.py` + `test_derive.py`；未來搬進 GUT 做 `.gd` 執行期版 | Python 層已綠 |

> 補測試的制度性約束（`TASKS/11_並行協作規則.md`）：每個 MOD 任務驗收時，都要在此表補上對應那一列的
> Godot 測試，避免「先做功能、測試之後補」導致回歸範圍長期缺口。
