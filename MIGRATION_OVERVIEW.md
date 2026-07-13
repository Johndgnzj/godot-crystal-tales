# 遷移總覽：可複用 vs 需重寫盤點

- 版本: v1.0
- 對應 GDevelop 原始碼快照: `build_cq2.py`（3487 行）、`game.json`（59469 行）、`CONTENT.json`（561 行），
  2026-07-13 分析
- 狀態: 定案（作為 TASKS/ 拆解的依據，之後 GDevelop 端有大改動要回來更新）

## 關鍵發現

GDevelop 專案的「事件系統」幾乎沒被使用——六個場景（Title/Town/Forest/Forest2/Mine/Cave/Battle）在 game.json
裡各自只有**一個頂層事件，型別是 `JsCode`**。物件層級只有 `Sprite`(271)/`TextObject::Text`(195)/
`TileMap::TileMap`(5)，行為只有 `TopDownMovementBehavior`(5 個實例)。真正的遊戲規則是每場景 ~90KB
（戰鬥場 45KB）手寫 JavaScript，由 `build_cq2.py` 產生後注入 game.json，每幀整段重跑，狀態掛在
`runtimeScene.__v`（世界）/`runtimeScene.__b`（戰鬥）。

**結論**：這不是「資產搬家」等級的遷移，是「把一個手刻小引擎在 Godot 上重新架構」等級的遷移。美術/音效/資料/
文件可高度複用；引擎邏輯與地圖/測試工具鏈需要整套重寫（規則本身可以照搬當規格，程式碼不能機械轉譯）。

## 可高度複用（引擎無關）

| 項目 | 現況 | 複用度 | 對應 CORE/MOD |
|---|---|---|---|
| 美術素材 | 593 張 PNG，~55MB，`assets/` | 100%，直接複製 | MOD-I |
| 音效/音樂 | 10 mp3 + 7 wav | 100% | MOD-I |
| `CONTENT.json` | party/equipment/skills/enemies/encounters/shops/chests/pacing | ~95%，schema 直接沿用 | CORE-2 |
| 設計文件 | DESIGN/ROADMAP/道具裝備一覽/劇情草稿 | 100% | — |
| 授權文件 | CREDITS_素材授權.md | 100%，需持續維護 | MOD-I |
| 美術生成 pipeline（概念） | art_v2/v3/v6/v8/v9/v10/v12/v13/v14（PIL 合成） | ~80%，收尾輸出要換 | MOD-I |
| 存檔資料結構 | `g_party`/`g_flags`/`g_eqInv`/`g_itemInv`/`g_gold`（JSON字串存 localStorage） | ~90%，schema照搬 | CORE-3 |
| 對話/劇情文字內容 | DLG/CUTS（Python dict，嵌在 build_cq2.py） | 文字可用，需抽成獨立資料檔 | MOD-A |

## 需要重寫（遷移主體）

| 項目 | 現況 | 對應 CORE/MOD | 備註 |
|---|---|---|---|
| 對話佇列/matchWhen | WORLD_JS | MOD-A | 規則簡單（always/==/>=），移植成本低 |
| `CFG.pickups` 撿取原語 | WORLD_JS | MOD-B | Area2D + 旗標寫入 |
| TopDownMovementBehavior | GDevelop 內建行為 ×5 | MOD-C | 改 CharacterBody2D |
| 六分頁選單/HUD | WORLD_JS + Design稿 Tweaks JSON | MOD-D | Control 節點重建 |
| ATB 戰鬥系統 | BATTLE_JS（45KB） | MOD-E | 狀態機（run/anim/menu/target…） |
| 衍生屬性/戰鬥公式 | `derive()` 兩份（WORLD/BATTLE 各一，需同步） | MOD-F | 見 `specs/BATTLE_FORMULAS.md`，Godot 端合併成一份，不重蹈重複維護 |
| 遭遇系統（距離累積） | WORLD_JS `st.enc`/`encNext` | MOD-G | |
| 地圖/tilemap 生成 pipeline | `build_cq2.py` 迷宮/佈局演算法 → GDevelop tmj/atlas | MOD-H | 演算法保留，輸出改 Godot TileMapLayer |
| 美術匯入管線 | art_v*.py → GDevelop resources | MOD-I | PIL 合成邏輯保留，收尾改吃 Godot import |
| E2E/驗證工具鏈 | gdevelop-mcp + puppeteer(`cq2_e2e.mjs`) | MOD-J（測試） / CORE-7 | 改用 `godot --headless` + GUT |

## 規模估算（量級，非精確工時）

- 美術/音效/資料/文件（直接複用）：小工
- CONTENT.json parser + 存檔系統（CORE-2/3）：中工，一次到位
- 地圖/tilemap 生成管線改造（MOD-H）：中～大工
- 引擎邏輯重寫（MOD-A~G）：**最大宗，估計佔整體遷移成本 6-7 成**
- 測試/驗證工具鏈重建（CORE-7）：中工，但影響遷移品質風險

## 主要風險

- 行為漂移：邏輯體量大，重寫時最容易在旗標判斷細節/傷害公式邊界情況跟原版不一致 → 靠 `specs/` 逐行對照 +
  既有 E2E 案例回歸驗證。
- Godot TileMap API 版本坑：已在 `CLAUDE.md` 定案用 4.3+，避免 4.0-4.2 的破壞性變動期。
- `wolf` 佔位圖等既有美術債（見 `../gd-crystal-tales/projects/crystal-quest/CREDITS_素材授權.md`）不在遷移
  範疇內，順手處理需另外標記，不要跟遷移任務混在一起。
- 專案目前進度只到第二章（GDevelop 端持續開發中），遷移期間兩邊可能同時演進，`CONTENT.json`/`build_cq2.py`
  規則異動要回頭同步 `specs/`（見 CLAUDE.md 版本規則）。

## 進度追蹤（人工勾選，跟 TASKS/*.md 的狀態欄位保持一致）

- [ ] CORE-1 Godot 專案骨架
- [ ] CORE-2 CONTENT.json → Resource 轉存
- [ ] CORE-3 存檔系統
- [ ] CORE-4 全域狀態 Autoload
- [ ] CORE-5 場景/轉場框架
- [ ] CORE-6 輸入抽象層
- [ ] CORE-7 測試/驗證骨架
- [ ] MOD-A 對話/劇情
- [ ] MOD-B 撿取/觸發
- [ ] MOD-C 移動/碰撞
- [ ] MOD-D 選單/HUD
- [ ] MOD-E 戰鬥 ATB
- [ ] MOD-F 衍生屬性/戰鬥公式
- [ ] MOD-G 遭遇系統
- [ ] MOD-H 地圖生成管線
- [ ] MOD-I 美術匯入管線
- [ ] MOD-J 測試驗證（場景整合）
