# 水晶傳說 — Godot 版

《水晶傳說：路德篇 Tale of Crystal: The Legend of Ludo》的 **Godot 4.7** 專案。遊戲規則來源 `build_cq2.py`、資料種子 `CONTENT.json`、系統邊界說明 `DEV_開發指南.md` 收在本 repo 的 `reference/gdevelop/` 唯讀快照，供開發對照。

## 現況（2026-07-14）
- **可在 Godot 4.7 開啟並通過 headless 冒煙測試**（7 個 autoload 掛載＋11 個場景載入，SMOKE PASS）。
- 資料層為 Godot **原生 `.tres`**（真相源；`CONTENT.json` 僅為最初的資料種子，見下）。
- 尚未完成：實際玩法端到端驗證（移動/戰鬥/存讀檔）、viewport 視覺確認、部分模組收尾。詳見
  `godot-project/tests/VERIFICATION_STATUS.md`。

## 這裡有什麼

| 目錄/檔案 | 內容 |
|---|---|
| `CLAUDE.md` | 給開發者/AI agent：目錄結構、Godot 技術選型、程式碼規範、協作總則、權威來源、**文件同步規則** |
| `docs/` | **文件中樞**：`design/` 長什麼樣、`pipeline/` 怎麼產生、`story/` 世界觀（敘事聖經）、`todo/` 後續優化議題。總索引見 `docs/README.md` |
| `docs/pipeline/設計員指南.md` | **給遊戲設計員（不需寫程式）**：怎麼加/改角色·道具·武器數值、美術、地圖 |
| `docs/design/戰鬥背景規格.md` ／ `docs/pipeline/戰鬥背景流程.md` | 戰鬥背景的構圖規格與產圖流程；含下方 2/3 可站立地面、腳底承托與驗收清單 |
| `docs/pipeline/world_object_art/遮擋物件資產架構.md` | 滿版地圖的透明高物件資產架構：`YSort` 遮擋、類型→footprint 歸檔、terrain 單一碰撞真相 |
| `TASKS/` | 可執行任務清單，核心 CORE-* ＋ 模組 MOD-* |
| `TASKS/17_戰鬥角色美術統一.md` | 我方戰鬥角色 3.5 頭身統一：路德／瑪琳全套重製、莉莉／潔絲補齊、實際身高正規化與全隊驗收 |
| `TASKS/20_敵人戰鬥圖重製.md` | 敵人戰鬥圖 HD 重製：依放大倍率×曝光度排 P1~P3 優先序，逐隻走 battle_art 產線對齊 necro 品質基準 |
| `TASKS/21_觸控支援.md` | 手機／平板觸控支援：階段 1 左下虛擬搖桿、階段 2 選項直接可點（標題／世界調查／戰鬥／商店／室內）皆已完成；階段 3 行動裝置適配出包待辦 |
| `TASKS/22_地圖高物件重製.md` | 既有地圖對齊芳蕾鎮的高物件／碰撞新機制：各區盤點（M2/M3 手刷碰撞、M4 全空、M5 藍圖齊但缺 props）＋動工前要先解的生成器保護規則 |
| `TASK/v2/` | v2 後續製作追蹤；目前入口為世界美術終版與芳蕾鎮垂直切片 |
| `specs/` | 從 `build_cq2.py` 凍結抄錄的權威規格：存檔 schema、戰鬥公式、對話格式 |
| `reference/gdevelop/` | 原 GDevelop 專案的凍結快照（`build_cq2.py`、`CONTENT.json`、`DEV_開發指南.md`），唯讀 |
| `MIGRATION_OVERVIEW.md` | 可複用 vs 需重寫的盤點總表 |
| `godot-project/` | Godot 專案本體（`autoload/` 全域單例、`scenes/` 場景、`scripts/` 模組、`resources/content/` 資料 .tres、`resources/shaders/` 畫面效果 shader、`assets/` 美術、`tests/` 測試）|
| `tools/` | 開發輔助工具（非遊戲程式）。`map_editor/`：地圖連通維護＋**40×40 地格藍圖** paint 工具（真相＝`assets-source/map/map-def.json`；詞彙＝`terrain_palette.json`），啟動 `python3 tools/map_editor/serve.py`；`scene_props_sync.py`：把 Godot 編輯器手調過的高物件位置反向寫回 `map-def.json`（`python3 tools/scene_props_sync.py <場景名>` 先預覽、加 `--write` 寫回）；`blueprint_from_image.py`：從已定稿的手繪成圖**逆推** 40×40 藍圖（藍圖機制之前產的圖用），`--full-bleed` 另做滿版化、`--write` 才寫回 map-def；`role_slicer/`：上傳一張全身圖 → 去螢光底＋框頭像(a)/半身(b) → 匯出 `face_/portrait_/menuart_` 到 `assets-source/role/<id>/` 暫存，啟動 `python3 tools/role_slicer/serve.py` |

## 怎麼開始

**開發者/AI**：讀 `CLAUDE.md` → `MIGRATION_OVERVIEW.md` → 認領任務前讀 `TASKS/11_並行協作規則.md` → 依
`TASKS/00_核心任務.md` 順序。改任何 `.gd` 後跑冒煙測試：
```bash
cd godot-project
/Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/smoke_test.gd --path .
```
改 painted 世界場景（`scenes/world/painted/**`）或 `scripts/world/world_scene.gd` 後，另跑世界場景 harness
（實際實例化每張主線場景、驗遭遇系統接線；`-- <SCENE_ID>` 可只驗指定張）：
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/world_harness_test.gd --path .
```

**設計員（做角色/數值/美術/地圖）**：直接讀 **`docs/pipeline/設計員指南.md`**，不用碰程式碼。

**構思劇情/世界觀**：讀 **`docs/story/`**（`docs/README.md` 是總索引）——世界觀設定、故事大綱、角色設定；已核可的七章路德篇走向見 `docs/story/路德篇章節骨架.md`，小說式正文從 `docs/story/第一章小說式母稿.md` 開始；寫作方法論在 `docs/pipeline/劇本寫作心法.md`。

**找/處理素材**：讀 **`docs/pipeline/素材管理規範.md`**——素材放哪、進 Godot 後怎麼處理、授權怎麼記；武器部件與立繪比例見 **`docs/design/武器/`**（刀／劍／錘／杖）。

> ⚠️ **改任何內容後，記得同步文件**（對應 docs、本 README 索引；設定集 codex 由 CI 自動發佈到 GitHub Pages）。規則見 `CLAUDE.md` 的「文件同步規則」。

## 權威來源
- 數值資料：**Godot 端 `godot-project/resources/content/**/*.tres`**（唯一真相源，設計員在編輯器 Inspector 編輯）。
- 遊戲規則/公式：`reference/gdevelop/build_cq2.py`（凍結快照；規格已抄錄進 `specs/`）。
- 美術/音效：已全數複製進 `godot-project/assets/`（素材出處與授權見 `CREDITS_素材授權.md`）。
- 舊文件（TASKS/、specs/、程式註解）中的 `../GDevelop/...` 或 `../gd-crystal-tales/...` 路徑，一律對應 `reference/gdevelop/` 的同名檔案。
