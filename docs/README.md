# docs — 文件中樞

《水晶傳說》的文件總索引。**敘事層**與**素材治理**文件放在本目錄；**工程/規範/設計**文件因被程式或 skill 引用，留在原位，這裡一併索引。

> 📌 **文件同步鐵律**：改動遊戲內容（劇情/數值/角色/素材/系統）後，必須回頭同步對應文件、`README.md` 索引（設定集 codex 由 CI 自動發佈到 GitHub Pages）。詳見 `CLAUDE.md` 的「文件同步規則」。文件與實際脫勾，是本專案最該避免的技術債。

---

## 一、敘事層（story bible）— 本目錄

| 文件 | 內容 |
|---|---|
| [story/世界觀設定.md](story/世界觀設定.md) | 世界觀權威整理：信仰/地理/勢力/威脅/核心意象。**含「待拍板」清單** |
| [story/故事大綱.md](story/故事大綱.md) | 主軸、章節結構表、flag/step 對照、伏筆與破綻清單 |
| [story/角色設定.md](story/角色設定.md) | 主角/NPC/反派設定（缺點與動機）＋外觀設定（立繪用）|
| [story/第一章劇本草稿.md](story/第一章劇本草稿.md) | 第一章六小節可讀劇本草稿（待審→轉對話 .tres，見 DIALOGUE_SPEC v3.0）|
| [劇本寫作心法.md](劇本寫作心法.md) | 劇本寫作教材（訪談整理，構思時的方法論）|

## 二、素材治理 — 本目錄

| 文件 | 內容 |
|---|---|
| [素材管理規範.md](素材管理規範.md) | 素材放哪、進 Godot 後怎麼處理、授權標註規則、檢查清單 |
| [`../CREDITS_素材授權.md`](../CREDITS_素材授權.md) | 授權帳本（每個進遊戲的素材一條）|

## 三、設計層（給不寫程式的設計員）— `docs/design/`

| 文件 | 內容 |
|---|---|
| [design/設計員指南.md](design/設計員指南.md) | 怎麼在 Godot 編輯器改角色/道具/武器/數值/美術/地圖 |
| [design/地圖區域設計.md](design/地圖區域設計.md) | 手繪地圖區域的連通/樓層/出入口設計＋`map-def.json` schema＋網頁維護工具（塊 A/B/C 流程）|
| [design/道具武器設計.md](design/道具武器設計.md) | 道具與武器的**設計原則**（稀有度/圖示/8 階曲線；equipment_def.gd / validate_content.py 以此為 schema spec）。**數值不在此**——以 `equipment/*.tres`＋codex 設定檢視為準（v2.2 去重）|
| [design/屬性戰鬥設計.md](design/屬性戰鬥設計.md) | 四主屬性(str/agi/int/**luck**)→衍生戰鬥數值→三段式攻擊的設計與係數表（對應 BATTLE_FORMULAS v4.0）|
| [design/魔物立繪素材設計.md](design/魔物立繪素材設計.md) | 戰鬥魔物立繪的來源位置、朝向、兩幀呼吸動畫與驗收規格 |
| [design/魔物圖鑑.md](design/魔物圖鑑.md) | 全魔物**總覽**：數值/特性/掉落/出沒地/圖鑑描述＋各地圖遭遇表對照（彙整自 `enemies/*.tres`＋`encounters/*.tres`；機制見 BATTLE_FORMULAS F-11）|
| [design/美術規格/地圖產圖規格.md](design/美術規格/地圖產圖規格.md) | 手繪畫面地圖產圖規格（`gen-map-prompt` skill 的權威來源）|
| [design/美術規格/角色立繪產圖規格.md](design/美術規格/角色立繪產圖規格.md) | 角色立繪產圖規格：a 戰鬥頭像／b 對話半身／c 全身＋去背螢光底規則（`gen-role-prompt` skill 的權威來源）|
| [design/美術規格/角色Sprite規格.md](design/美術規格/角色Sprite規格.md) | 角色 sprite（走路/戰鬥）「遊戲可直接用」規格：動畫集/排版/尺寸/一致性/交付；產出者無關（LPC 或 AI 的驗收門檻）|
| [design/美術規格/LPC製作流程.md](design/美術規格/LPC製作流程.md) | LPC 角色走路圖／戰鬥圖製作流程（可復用四步：配方→匯出→接線驗證→更新文件；ludo 範本）|
| [design/prompt/roles.md](design/prompt/roles.md) | 角色立繪 prompt 集（全 15 位的全身 c prompt，`gen-role-prompt` 產；路德＝風格基準）|
| [design/prompt/emenies.md](design/prompt/emenies.md) | 魔物設定集立繪／公會懸賞黑墨圖的可重出 prompt 集；以角色立繪風格為共同基線 |

## 四、工程 / 規範 / 權威來源 — 在原位

| 文件 | 內容 |
|---|---|
| [`../CLAUDE.md`](../CLAUDE.md) | 規範、目錄結構、Godot 技術選型、協作總則、**文件同步規則** |
| [`../MIGRATION_OVERVIEW.md`](../MIGRATION_OVERVIEW.md) | 可複用 vs 需重寫盤點表 |
| `../specs/` | 從 GDevelop 凍結抄錄的權威規格：SAVE_SCHEMA / BATTLE_FORMULAS / DIALOGUE_SPEC |
| `../TASKS/` | 可執行任務清單（CORE-* / MOD-*）|
| `../reference/gdevelop/` | 原 GDevelop 專案凍結快照（唯讀）|

---

## 目錄結構

```
docs/
├── README.md            # 本索引
├── story/               # 敘事聖經
│   ├── 世界觀設定.md
│   ├── 故事大綱.md
│   └── 角色設定.md
├── design/              # 設計層（給不寫程式的設計員）
│   ├── 設計員指南.md
│   ├── 地圖區域設計.md
│   ├── 道具武器設計.md
│   ├── 屬性戰鬥設計.md
│   ├── 美術規格/          # 產圖／sprite 規格（gen-* skill 權威來源）
│   │   ├── 地圖產圖規格.md
│   │   ├── 角色立繪產圖規格.md
│   │   ├── 角色Sprite規格.md
│   │   └── LPC製作流程.md
│   └── prompt/           # 依規格產出的 prompt 集
├── 劇本寫作心法.md        # 寫作教材
└── 素材管理規範.md        # 素材治理 SOP
```
