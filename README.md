# 水晶戰記 — Godot 版

《水晶戰記 Crystal Tale》從 GDevelop 遷移到 **Godot 4.7** 的專案。原 GDevelop 版（規則/資料的原始出處）
已凍結；仍被引用的檔案（`build_cq2.py`、`CONTENT.json`、`DEV_開發指南.md`）已收進本 repo 的
`reference/gdevelop/`，**開發不再依賴 `../GDevelop` 目錄**。

## 現況（2026-07-14）
- **可在 Godot 4.7 開啟並通過 headless 冒煙測試**（7 個 autoload 掛載＋11 個場景載入，SMOKE PASS）。
- 資料層已切成 Godot **原生 `.tres`**（不再依賴 GDevelop 的 CONTENT.json；見下）。
- 尚未完成：實際玩法端到端驗證（移動/戰鬥/存讀檔）、viewport 視覺確認、部分模組收尾。詳見
  `godot-project/tests/VERIFICATION_STATUS.md`。

## 這裡有什麼

| 目錄/檔案 | 內容 |
|---|---|
| `CLAUDE.md` | 給開發者/AI agent：目錄結構、Godot 技術選型、程式碼規範、協作總則、權威來源、**文件同步規則** |
| `docs/` | **文件中樞**：敘事聖經（世界觀/大綱/角色）、劇本寫作心法、素材管理規範、設計層文件（`docs/design/`）。總索引見 `docs/README.md` |
| `docs/design/設計員指南.md` | **給遊戲設計員（不需寫程式）**：怎麼加/改角色·道具·武器數值、美術、地圖 |
| `TASKS/` | 可執行任務清單，核心 CORE-* ＋ 模組 MOD-* |
| `specs/` | 從 GDevelop `build_cq2.py` 凍結抄錄的權威規格：存檔 schema、戰鬥公式、對話格式 |
| `reference/gdevelop/` | 原 GDevelop 專案的凍結快照（`build_cq2.py`、`CONTENT.json`、`DEV_開發指南.md`），唯讀 |
| `MIGRATION_OVERVIEW.md` | 可複用 vs 需重寫的盤點總表 |
| `godot-project/` | Godot 專案本體（`autoload/` 全域單例、`scenes/` 場景、`scripts/` 模組、`resources/content/` 資料 .tres、`assets/` 美術、`tests/` 測試）|
| `tools/` | 開發輔助工具（非遊戲程式）。`role_slicer/`：上傳一張全身圖 → 去螢光底＋框頭像(a)/半身(b) → 匯出 `face_/portrait_/menuart_` 到 `assets-source/role/<id>/` 暫存。啟動 `python3 tools/role_slicer/serve.py` |

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

**設計員（做角色/數值/美術/地圖）**：直接讀 **`docs/design/設計員指南.md`**，不用碰程式碼。

**構思劇情/世界觀**：讀 **`docs/`**（`docs/README.md` 是總索引）——世界觀設定、故事大綱、角色設定、劇本寫作心法都在裡面。

**找/處理素材**：讀 **`docs/素材管理規範.md`**——素材放哪、進 Godot 後怎麼處理、授權怎麼記。

> ⚠️ **改任何內容後，記得同步文件**（對應 docs、本 README 索引、設定集 Artifact）。規則見 `CLAUDE.md` 的「文件同步規則」。

## 權威來源
- 數值資料：**Godot 端 `godot-project/resources/content/**/*.tres`**（唯一真相源，設計員在編輯器 Inspector 編輯）。
- 遊戲規則/公式：`reference/gdevelop/build_cq2.py`（凍結快照；規格已抄錄進 `specs/`）。
- 美術/音效：已全數複製進 `godot-project/assets/`（原始出處為 GDevelop 版 assets，該目錄已無開發依賴）。
- 舊文件（TASKS/、specs/、程式註解）中的 `../GDevelop/...` 或 `../gd-crystal-tales/...` 路徑，一律對應 `reference/gdevelop/` 的同名檔案。
