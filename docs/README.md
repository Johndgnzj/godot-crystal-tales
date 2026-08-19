# docs — 文件中樞

《水晶傳說》的文件總索引。另設 `todo/` 收納尚未排入實作的優化議題：

- **`design/`** — 定義 xxx **長什麼樣**（武器、道具、角色、敵人、立繪、地圖畫面…）
- **`pipeline/`** — 怎麼**產生**（角色立繪流程、戰鬥立繪產線 battle_art、地圖製作流程、素材 SOP…）
- **`story/`** — 世界觀（敘事聖經）
- **`todo/`** — 後續優化議題與驗收方向
- 系統規格 **`specs/`** 留在 repo 根目錄（凍結抄錄、被程式註解大量引用，不搬）

> 📌 **文件同步鐵律**：改動遊戲內容（劇情/數值/角色/素材/系統）後，必須回頭同步對應文件、`README.md` 索引（設定集 codex 由 CI 自動發佈到 GitHub Pages）。詳見 `CLAUDE.md` 的「文件同步規則」。文件與實際脫勾，是本專案最該避免的技術債。

---

## 一、story/ — 敘事層（story bible）

| 文件 | 內容 |
|---|---|
| [story/世界觀設定.md](story/世界觀設定.md) | 世界觀權威整理：信仰/地理/勢力/威脅/核心意象。**含「待拍板」清單** |
| [story/故事大綱.md](story/故事大綱.md) | 主軸、章節結構表、flag/step 對照、伏筆與破綻清單 |
| [story/路德篇章節骨架.md](story/路德篇章節骨架.md) | **已核可方向**：七章路德篇、王都嫁禍線、炎龍終戰、角色弧線與伏筆邊界；各章細節尚在設計 |
| [story/角色設定.md](story/角色設定.md) | 主角/NPC/反派設定（缺點與動機）＋外觀設定（立繪用）|
| [story/第一章劇本草稿.md](story/第一章劇本草稿.md) | **v3.0 對話優化定稿（2026-08-15，已同步 runtime `.tres` 逐字一致）**：六小節可讀劇本＝遊戲台詞對照版；優化紀錄見 `TASKS/18` |
| [story/第一章小說式母稿.md](story/第一章小說式母稿.md) | 第一章小說式敘事母稿：場景氣氛、人物動作、情緒轉折與完整因果；不直接等同 runtime 台詞 |
| [story/第一章任務攻略.md](story/第一章任務攻略.md) | 攻略式任務流程：`ch1_step` 0→13 逐節（觸發/地點/道具/NPC/旗標）＋支線＋驗收缺口，順劇情驗收用 |
| [story/第二章任務攻略.md](story/第二章任務攻略.md) | **v1.1 定案（2026-08-12）·第二章施工藍圖**：《無名的旅伴》六小節展開成 `ch2_step` 0→12 任務流程＋大道路網＋灰木危機事件＋休斯城多種族 NPC＋新內容清單；開發待辦見 `TASKS/16_第二章施工.md` |
| [story/第二章劇本草稿.md](story/第二章劇本草稿.md) | **草稿 v1.0（待審）**：第二章六小節可讀劇本（全過場 `t1_*`~`t6_*` 台詞＋NPC 對話＋支線③；含轉 `.tres` 備忘），審過→轉對話 .tres |

## 二、design/ — 長什麼樣

| 文件 | 內容 |
|---|---|
| [design/屬性戰鬥設計.md](design/屬性戰鬥設計.md) | 四主屬性(str/agi/int/**luck**)→衍生戰鬥數值→三段式攻擊的設計與係數表（對應 BATTLE_FORMULAS v4.0）|
| [design/武器/](design/武器/杖/description.md) | **各武器類型的部件說明與立繪比例**，一類一目錄（`刀`／`劍`／`錘`／`杖`），每個目錄 `description.md`＋參考圖。部件名稱一律用實物術語；含「角色立繪可完整呈現／戰鬥立繪只強調哪幾項」與長度佔身高比例；`杖`另含莉莉角色＋武器介紹圖 |
| [design/道具武器設計.md](design/道具武器設計.md) | 道具與武器的**設計原則**（稀有度/8 階曲線；equipment_def.gd / validate_content.py 以此為 schema spec）＋**§三＝道具/裝備圖示規格單一來源**（手繪水彩 64px、路徑、構圖、不可畫進圖裡的東西）。**數值不在此**——以 `equipment/*.tres`＋codex 設定檢視為準 |
| [design/魔物圖鑑.md](design/魔物圖鑑.md) | 全魔物**總覽**：數值/特性/掉落/出沒地/圖鑑描述＋各地圖遭遇表對照（彙整自 `enemies/*.tres`＋`encounters/*.tres`）|
| [design/角色立繪規格.md](design/角色立繪規格.md) | 對話/介紹用**高品質立繪**長怎樣（a 頭像／b 半身／c 全身＋敵人設定集/懸賞立繪）|
| [design/戰鬥立繪規格.md](design/戰鬥立繪規格.md) | **〔主〕戰鬥素材**長怎樣：我方高品質 Pixel Art 約 3.5 頭身、角色身高換算、動畫集／幀數／排版／逐幀一致性＋敵人專節＋受擊特效 fx_* 素材規格 |
| [design/戰鬥背景規格.md](design/戰鬥背景規格.md) | **戰鬥背景**長怎樣：16:9、下方至少 2/3 連續可站立地面、腳底承托與站位禁項 |
| [design/世界立繪規格.md](design/世界立繪規格.md) | **地圖 Sprite 唯一規格源**：D1 高解析非 Pixel Art → D2 grid-authored 中等細節 Pixel Art → D3 原生 Native Seed、outline、視覺尺寸級別、strip／runtime／影子與驗收 |
| [design/地圖畫面規格.md](design/地圖畫面規格.md) | 手繪**地圖背景畫面**長怎樣（32px 網格/1280²/禁項/遮擋/色彩/城鎮建築/地格藍圖）|
| [design/地圖互動物件規格.md](design/地圖互動物件規格.md) | 寶箱、任務拾取物等**引擎另擺的物件**長怎樣（外觀族、狀態、錨點、尺寸與互動資料分離）；同時是背包道具者另有 64×64 圖示交付 |
| [design/事件演出規格.md](design/事件演出規格.md) | **草稿（待討論）**：過場演出三層手段——轉場 fade/時間字卡/**事件 CG**（16:9 精美插圖、構圖三原則）＋第一章 CG 清單與轉場稽核表；任務＝`TASKS/19` |

## 三、pipeline/ — 怎麼產生

| 文件 | 內容 |
|---|---|
| [pipeline/設計員指南.md](pipeline/設計員指南.md) | 怎麼在 Godot 編輯器改角色/道具/武器/數值/美術/地圖（不寫程式）|
| [pipeline/角色立繪流程.md](pipeline/角色立繪流程.md) | 角色/敵人立繪：產圖→去背螢光底→切圖→整合＋**prompt 固定開頭模板**＋交付檢查＋帳本（`gen-role-prompt` skill 引用）|
| [pipeline/battle_art/](pipeline/battle_art/workflow.md) | 戰鬥立繪**產線**（唯一入口，`gen-battle-prompt` skill 引用）：G0～G7 分階段 Gate（Seed 鍵色靜態→Seed Alpha→動作首幀→Strip 鍵色靜態→Alpha 靜態→GIF→整合）＋checklist 驗收＋`prompts/`（我方正式 `battle_role_hd_pixel_v5`、actions／sections／presets／descriptions）；待辦總表見 [`TASKS/17_戰鬥角色美術統一.md`](../TASKS/17_戰鬥角色美術統一.md) |
| [pipeline/戰鬥背景流程.md](pipeline/戰鬥背景流程.md) | 戰鬥背景的產圖→預覽驗收→整合流程，含固定 prompt 核心與地面／腳點檢查清單 |
| [pipeline/world_object_art/](pipeline/world_object_art/workflow.md) | 地圖互動物件**與道具/裝備圖示產線**：獨立 design anchor→狀態圖→固定命名→整合；類型 `chest`／`quest_item`／`icon`（圖示規格見 design/道具武器設計.md §三）|
| [pipeline/world_object_art/遮擋物件資產架構.md](pipeline/world_object_art/遮擋物件資產架構.md) | 城鎮／野外高物件：滿版 Ground、透明遮擋物件、`YSort`／`GroundProps` 分層與類型→footprint 素材歸檔；`walkable`／`layer` 旗標語意 |
| [pipeline/世界立繪流程.md](pipeline/世界立繪流程.md) | 世界 Sprite **W0～W7 產線**：需求→D1→D2→D3→完整 strip→Alpha→實景 runtime QA→整合 |
| [pipeline/地圖產圖流程.md](pipeline/地圖產圖流程.md) | 畫一張手繪地圖 png：**prompt 固定開頭模板**＋交付檢查（`gen-map-prompt` skill 引用）|
| [pipeline/地圖製作流程.md](pipeline/地圖製作流程.md) | 地圖從連通到可玩：`map-def.json` schema＋網頁維護工具＋**40×40 地格藍圖（§2.5）**＋場景生成（塊 A/B/C）；**既有地圖的重製待辦＝[`TASKS/22_地圖高物件重製.md`](../TASKS/22_地圖高物件重製.md)**（僅芳蕾鎮已對齊新機制）|
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
| [`../TASK/v2/00_世界美術終版.md`](../TASK/v2/00_世界美術終版.md) | v2 世界美術終版執行追蹤：芳蕾鎮垂直切片、角色／NPC、32 張場景、28 個物件與 QA |
| `../reference/gdevelop/` | 原 GDevelop 專案凍結快照（唯讀）|
| `../reference/legacy_art/` | 封存舊美術文件（LPC製作流程；唯讀、AI 不參考）|

## 五、todo/ — 後續優化

| 文件 | 內容 |
|---|---|
| [todo/地圖視覺平滑與特色物件.md](todo/地圖視覺平滑與特色物件.md) | terrain 藍圖不變下的道路視覺平滑、阻擋區特色物件與 `decor anchors` 後續評估 |

---

## 目錄結構

```
docs/
├── README.md            # 本索引
├── todo/                # 尚未排入實作的優化議題
│   └── 地圖視覺平滑與特色物件.md
├── story/               # 敘事聖經（世界觀）
│   ├── 世界觀設定.md
│   ├── 故事大綱.md
│   ├── 路德篇章節骨架.md
│   ├── 角色設定.md
│   ├── 第一章劇本草稿.md
│   ├── 第一章小說式母稿.md
│   ├── 第一章任務攻略.md
│   ├── 第二章任務攻略.md   # v1.1 定案·第二章施工藍圖
│   └── 第二章劇本草稿.md   # 草稿 v1.1（待審）
├── design/              # 長什麼樣
│   ├── 屬性戰鬥設計.md
│   ├── 道具武器設計.md
│   ├── 武器/            # 一類一目錄：刀／劍／錘／杖，各 description.md＋參考圖
│   ├── 魔物圖鑑.md
│   ├── 角色立繪規格.md
│   ├── 戰鬥立繪規格.md
│   ├── 戰鬥背景規格.md
│   ├── 世界立繪規格.md
│   ├── 地圖畫面規格.md
│   └── 地圖互動物件規格.md
└── pipeline/            # 怎麼產生
    ├── 設計員指南.md
    ├── 角色立繪流程.md
    ├── 世界立繪流程.md
    ├── 戰鬥背景流程.md
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
    ├── world_object_art/ # 地圖互動物件＋道具圖示產線
    │   ├── workflow.md / checklist.md
    │   └── prompts/             # preset、類型模板、外觀族描述
    └── prompt/          # 各資源「最後一版」產圖 prompt（portrait/world）
```

**規格與流程的配對**：每種素材一份 `design/*規格.md`（長什麼樣）＋一份 pipeline 產線（怎麼產）——
角色立繪/世界立繪/地圖為 `pipeline/*流程.md`，**戰鬥立繪為 `pipeline/battle_art/`**（actions 動作資料集、sections 一檔一規則、presets 凍結正式版）；**地圖互動物件與道具/裝備圖示為 `pipeline/world_object_art/`**（design anchor、狀態模板與固定檔名；圖示走 `types/icon.md`，規格在 `design/道具武器設計.md` §三，刻意不另開產線目錄以免同一 art id 出現兩份描述檔）。
`gen-role-prompt`／`gen-map-prompt`／`gen-battle-prompt`／`gen-world-prompt` skill 的規則與模板**只存在對應的 design／pipeline 文件**（skill 只負責觸發、讀取與執行 Gate，不內嵌副本），改規則只改權威文件即可。
