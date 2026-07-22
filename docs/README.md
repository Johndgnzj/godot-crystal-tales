# docs — 文件中樞

《水晶傳說》的文件總索引。四分法（2026-07-22 定案）：

- **`design/`** — 定義 xxx **長什麼樣**（武器、道具、角色、敵人、立繪、地圖畫面…）
- **`pipeline/`** — 怎麼**產生**（角色立繪流程、戰鬥立繪產線 battle_art、地圖製作流程、素材 SOP…）
- **`story/`** — 世界觀（敘事聖經）
- 系統規格 **`specs/`** 留在 repo 根目錄（凍結抄錄、被程式註解大量引用，不搬）

> 📌 **文件同步鐵律**：改動遊戲內容（劇情/數值/角色/素材/系統）後，必須回頭同步對應文件、`README.md` 索引（設定集 codex 由 CI 自動發佈到 GitHub Pages）。詳見 `CLAUDE.md` 的「文件同步規則」。文件與實際脫勾，是本專案最該避免的技術債。

---

## 一、story/ — 敘事層（story bible）

| 文件 | 內容 |
|---|---|
| [story/世界觀設定.md](story/世界觀設定.md) | 世界觀權威整理：信仰/地理/勢力/威脅/核心意象。**含「待拍板」清單** |
| [story/故事大綱.md](story/故事大綱.md) | 主軸、章節結構表、flag/step 對照、伏筆與破綻清單 |
| [story/角色設定.md](story/角色設定.md) | 主角/NPC/反派設定（缺點與動機）＋外觀設定（立繪用）|
| [story/第一章劇本草稿.md](story/第一章劇本草稿.md) | 第一章六小節可讀劇本草稿（待審→轉對話 .tres，見 DIALOGUE_SPEC v3.0）|

## 二、design/ — 長什麼樣

| 文件 | 內容 |
|---|---|
| [design/屬性戰鬥設計.md](design/屬性戰鬥設計.md) | 四主屬性(str/agi/int/**luck**)→衍生戰鬥數值→三段式攻擊的設計與係數表（對應 BATTLE_FORMULAS v4.0）|
| [design/道具武器設計.md](design/道具武器設計.md) | 道具與武器的**設計原則**（稀有度/圖示/8 階曲線；equipment_def.gd / validate_content.py 以此為 schema spec）。**數值不在此**——以 `equipment/*.tres`＋codex 設定檢視為準 |
| [design/魔物圖鑑.md](design/魔物圖鑑.md) | 全魔物**總覽**：數值/特性/掉落/出沒地/圖鑑描述＋各地圖遭遇表對照（彙整自 `enemies/*.tres`＋`encounters/*.tres`）|
| [design/角色立繪規格.md](design/角色立繪規格.md) | 對話/介紹用**高品質立繪**長怎樣（a 頭像／b 半身／c 全身＋敵人設定集/懸賞立繪）|
| [design/戰鬥立繪規格.md](design/戰鬥立繪規格.md) | **〔主〕戰鬥素材**長怎樣（角色＋敵人，高品質像素＋二頭身）：動畫集/幀數/排版/風格/逐幀一致性＋敵人專節 |
| [design/世界立繪規格.md](design/世界立繪規格.md) | **地圖移動素材**長怎樣（overworld walk：9 幀×4 向、步態相位）|
| [design/地圖畫面規格.md](design/地圖畫面規格.md) | 手繪**地圖背景畫面**長怎樣（32px 網格/1280²/禁項/遮擋/色彩/城鎮建築）|
| [design/地圖互動物件規格.md](design/地圖互動物件規格.md) | 寶箱、任務拾取物等**引擎另擺的物件**長怎樣（外觀族、狀態、錨點、尺寸與互動資料分離）|

## 三、pipeline/ — 怎麼產生

| 文件 | 內容 |
|---|---|
| [pipeline/設計員指南.md](pipeline/設計員指南.md) | 怎麼在 Godot 編輯器改角色/道具/武器/數值/美術/地圖（不寫程式）|
| [pipeline/角色立繪流程.md](pipeline/角色立繪流程.md) | 角色/敵人立繪：產圖→去背螢光底→切圖→整合＋**prompt 固定開頭模板**＋交付檢查＋帳本（`gen-role-prompt` skill 引用）|
| [pipeline/battle_art/](pipeline/battle_art/workflow.md) | 戰鬥立繪**產線**（唯一入口，`gen-battle-prompt` skill 引用）：workflow 8 步驟（獨立 seed→動作選擇→strip、固定檔名）＋checklist 驗收＋`prompts/`（`actions/` 對話式動作資料集、`sections/` 一檔一規則、`presets/` 凍結正式版、`descriptions/` 各單位最後一版描述（一單位一檔）、組裝規則 `role.md`/`enemy.md`（enemy 含 Gemini 產法＋現況帳本））|
| [pipeline/world_object_art/](pipeline/world_object_art/workflow.md) | 地圖互動物件**產線**：獨立 design anchor→狀態圖→固定命名→整合；首批支援共用寶箱與任務拾取物|
| [pipeline/世界立繪流程.md](pipeline/世界立繪流程.md) | walk 素材：產法/去背/切圖命名/LPC 過渡現況 |
| [pipeline/地圖產圖流程.md](pipeline/地圖產圖流程.md) | 畫一張手繪地圖 png：**prompt 固定開頭模板**＋交付檢查（`gen-map-prompt` skill 引用）|
| [pipeline/地圖製作流程.md](pipeline/地圖製作流程.md) | 地圖從連通到可玩：`map-def.json` schema＋網頁維護工具＋場景生成（塊 A/B/C）|
| [pipeline/素材管理規範.md](pipeline/素材管理規範.md) | 素材放哪、進 Godot 後怎麼處理、授權標註規則、檢查清單 |
| [pipeline/劇本寫作心法.md](pipeline/劇本寫作心法.md) | 劇本寫作教材（訪談整理，構思劇情時的方法論）|
| [pipeline/prompt/](pipeline/prompt/) | 各資源「最後一版」產圖 prompt（role/enemies × portrait/world 四份；戰鬥 prompt 在 `battle_art/prompts/`）|
| [`../CREDITS_素材授權.md`](../CREDITS_素材授權.md) | 授權帳本（每個進遊戲的素材一條）|

## 四、工程 / 規範 / 權威來源 — 在原位

| 文件 | 內容 |
|---|---|
| [`../CLAUDE.md`](../CLAUDE.md) | 規範、目錄結構、Godot 技術選型、協作總則、**文件同步規則** |
| [`../MIGRATION_OVERVIEW.md`](../MIGRATION_OVERVIEW.md) | 可複用 vs 需重寫盤點表 |
| `../specs/` | 從 GDevelop 凍結抄錄的權威規格：SAVE_SCHEMA / BATTLE_FORMULAS / DIALOGUE_SPEC |
| `../TASKS/` | 可執行任務清單（CORE-* / MOD-*）|
| `../reference/gdevelop/` | 原 GDevelop 專案凍結快照（唯讀）|
| `../reference/legacy_art/` | 封存舊美術文件（LPC製作流程；唯讀、AI 不參考）|

---

## 目錄結構

```
docs/
├── README.md            # 本索引
├── story/               # 敘事聖經（世界觀）
│   ├── 世界觀設定.md
│   ├── 故事大綱.md
│   ├── 角色設定.md
│   └── 第一章劇本草稿.md
├── design/              # 長什麼樣
│   ├── 屬性戰鬥設計.md
│   ├── 道具武器設計.md
│   ├── 魔物圖鑑.md
│   ├── 角色立繪規格.md
│   ├── 戰鬥立繪規格.md
│   ├── 世界立繪規格.md
│   ├── 地圖畫面規格.md
│   └── 地圖互動物件規格.md
└── pipeline/            # 怎麼產生
    ├── 設計員指南.md
    ├── 角色立繪流程.md
    ├── 世界立繪流程.md
    ├── 地圖產圖流程.md
    ├── 地圖製作流程.md
    ├── 素材管理規範.md
    ├── 劇本寫作心法.md
    ├── battle_art/      # 戰鬥立繪產線
    │   ├── workflow.md      # 8 步驟產線
    │   ├── checklist.md     # 驗收
    │   └── prompts/
    │       ├── role.md / enemy.md   # 組裝規則（enemy 含 Gemini 產法＋現況帳本）
    │       ├── actions/             # 對話式動作資料集（idle/hurt/cast/death/attack）
    │       ├── sections/        # 一檔一規則（10_風格…80_禁項＋15/65 魔物專用）
    │       ├── presets/         # 凍結正式版（battle_role_hd_pixel、battle_enemy_v1）
    │       └── descriptions/    # 各單位「最後一版」描述，一單位一檔
    ├── world_object_art/ # 地圖互動物件產線
    │   ├── workflow.md / checklist.md
    │   └── prompts/             # preset、類型模板、外觀族描述
    └── prompt/          # 各資源「最後一版」產圖 prompt（portrait/world）
```

**規格與流程的配對**：每種素材一份 `design/*規格.md`（長什麼樣）＋一份 pipeline 產線（怎麼產）——
角色立繪/世界立繪/地圖為 `pipeline/*流程.md`，**戰鬥立繪為 `pipeline/battle_art/`**（actions 動作資料集、sections 一檔一規則、presets 凍結正式版）；**地圖互動物件為 `pipeline/world_object_art/`**（design anchor、狀態模板與固定檔名）。
`gen-role-prompt`／`gen-map-prompt`／`gen-battle-prompt` skill 的規則與模板**只存在對應的 pipeline 文件**（skill 引用文件、不內嵌副本），改規則只改文件即可。
