# 水晶戰記 Godot 遷移工作區

本目錄是《水晶戰記》**Godot 版主專案**（自 GDevelop 遷移而來，POC 已可玩）。原 GDevelop 專案已凍結，
所有仍被引用的檔案（`build_cq2.py`／`CONTENT.json`／`DEV_開發指南.md`）已收進本 repo 的
**`reference/gdevelop/`** 唯讀快照（2026-07-16），**開發不再依賴 `../GDevelop` 目錄**，該目錄可整個封存。

> 所有 subagent 協作開工前都要先讀這份文件。舊文件（TASKS/、specs/、程式註解）中的
> `../GDevelop/projects/crystal-quest/...` 或 `../gd-crystal-tales/...` 路徑，一律對應
> `reference/gdevelop/` 的同名檔案。

## 目錄地圖

```
godot-crystal-tales/
├── CLAUDE.md                  # 本文件：規範、目錄結構、協作規則
├── README.md                  # 給人看的專案簡介／現況
├── MIGRATION_OVERVIEW.md      # 複用/重寫盤點總表（承接前次評估報告）
├── TASKS/                     # ★ 可執行任務清單，核心(CORE-*)＋模組(MOD-*)
│   ├── 00_核心任務.md
│   ├── 01_對話劇情.md ... 09_美術管線.md, 10_測試驗證.md
│   └── 11_並行協作規則.md      # 多 subagent 同時開工的檔案owner/衝突規則
├── specs/                     # 從 GDevelop 現況「抄錄」出的權威規格（凍結版，供 Godot 端對照實作）
│   ├── SAVE_SCHEMA.md         # 存檔/全域狀態 JSON schema
│   ├── BATTLE_FORMULAS.md     # 戰鬥/衍生屬性公式（逐行對照 build_cq2.py 原始碼行號）
│   └── DIALOGUE_SPEC.md       # matchWhen/DLG/CUTS/pickups 資料格式與語意
├── reference/gdevelop/        # 原 GDevelop 專案凍結快照：build_cq2.py / CONTENT.json / DEV_開發指南.md（唯讀）
└── godot-project/             # Godot 專案本體
    ├── project.godot
    ├── autoload/               # 全域單例（GameState/SaveManager/ContentDB/AudioBus…）
    ├── scenes/
    │   ├── title/ world/ battle/ ui/
    ├── scripts/                # 非 autoload 的可重用邏輯（純函式/資源類別）
    ├── resources/content/      # CONTENT.json 對應的 Resource 定義與匯入結果
    ├── assets/                 # 從 GDevelop/projects/crystal-quest/assets 複製＋改 import 設定
    └── tests/                  # GUT 或 headless smoke test
```

## 權威來源與資料流向

- **數值資料真相源＝Godot 端 `resources/content/**/*.tres`**（2026-07-14 切斷 GDevelop 臍帶後定案，取代原本
  「以 GDevelop CONTENT.json 為源、run-time parse JSON」的做法）：party/equipment/skills/items/enemies/
  encounters/shops/chests/derived/pacing 各自一個 `.tres`，由聚合資源 `content_db.tres` 引用、`ContentDB`
  autoload 載入。**設計員直接在 Godot 編輯器 Inspector 編輯 .tres**，不再手刻或改 JSON。
  `reference/gdevelop/CONTENT.json`（凍結快照）只是最初的資料種子——僅在「要重新匯入種子資料」時，
  才跑 `sync_content.py` → `build_tres.gd`（見 `autoload/content_db.gd` 檔頭）。
- **`reference/gdevelop/build_cq2.py`**（凍結快照）是遊戲規則的唯一真相來源（因為
  GDevelop 版的「事件系統」其實只是外殼，真正邏輯全在這支腳本產生的 JsCode 裡）。`specs/` 下的規格文件是從這支
  腳本**凍結抄錄**出來的快照，抄錄時必須附原始行號；spec 引用的行號皆對照此檔。
- **美術/音效資產**已全數複製進 `godot-project/assets/`，以 repo 內為準，不重新繪製
  （除非任務清單明確標記為「順便重繪」）。原始出處為 GDevelop 版 assets，出處紀錄見 `CREDITS_素材授權.md`。
- **`reference/gdevelop/DEV_開發指南.md`**（凍結快照）是系統邊界的權威說明（WORLD_JS/BATTLE_JS 的
  各子系統列表），`TASKS/` 底下的模組任務拆分直接對應這份文件的系統清單，不要另外發明系統邊界。

## 產圖驗收流程（必須分階段）

任何 AI 產圖或圖片編輯任務，必須依下列兩階段執行：

1. **預覽驗收階段**：只產生候選圖並顯示給 John 驗收。此階段不得覆蓋或複製到
   `godot-project/assets/`，不得更新 `CREDITS_素材授權.md`，不得重建場景／碰撞，不得執行 import、build 或測試。
2. **正式整合階段**：只有當 John 明確回覆「可以了」、「這張可以」或其他等價的驗收通過語句後，
   才可將圖片放入專案，同步授權與相關文件，重建場景／碰撞，並執行必要的 import、build 與測試。

驗收前若 John 要求修改，必須繼續留在預覽驗收階段，不可提前做任何專案整合工作。

## 文件同步規則（重要，避免文件與實際脫勾）

**調整遊戲內容後，必須同步更新對應文件——這是硬性規則，不是可選項。** 文件與實際脫勾是本專案最該避免的技術債。

改動 → 要一起更新的文件對照：

| 你改了什麼 | 必須同步更新 |
|---|---|
| 劇情 / 對話 / 過場（`resources/content/dialogue/**/*.tres`；種子 `dialogue.json`）| `docs/story/故事大綱.md`、`docs/story/世界觀設定.md`、`docs/story/角色設定.md`（受影響者）|
| 數值 / 角色 / 裝備（`resources/content/*.tres`）| 對應 `docs/` 敘事或設計文件、**設定集 Artifact**（見下）|
| 素材（`godot-project/assets/`）| `CREDITS_素材授權.md`（授權帳本）、必要時 `docs/素材管理規範.md`|
| 新增/移除/搬動任何文件 | `README.md` 索引、`docs/README.md` 索引 |
| 系統/規格（`specs/*`）| 版本區塊遞增（見下）、引用該 spec 的 `TASKS/` 與程式註解 |

- **設定集 Artifact（game-codex）**：內容（角色/數值/劇情全文）改動後不會自動更新——需重跑 `build_codex.py` → 用 Artifact 工具帶 `url` 參數重發佈同一網址（網址與機制見 memory `game-codex-artifact`）。
- **一句話**：改內容 → 更新 `docs/` 對應文件 → 更新 `README` 索引 → 更新設定集 Artifact →（動素材再加 `CREDITS`）。

## 版本規則

每個 `specs/*.md` 與 `TASKS/*.md` 檔案開頭要有版本區塊：

```
- Spec/Task 版本: vX.Y
- 對應 GDevelop 原始碼快照: build_cq2.py @ <git commit / 日期>
- 狀態: 草稿 / 定案 / 實作中 / 已驗收
```

- **X（大版）**：規則/資料結構有破壞性變動時才加（例如戰鬥傷害公式改變、存檔 schema 改欄位）。
- **Y（小版）**：補充說明、修字、補邊界案例。
- `specs/` 內容一旦被某個 CORE/MOD 任務引用實作，改動前要先跟該任務負責者對過，避免實作到一半規格底下被抽換。

## Godot 版本與技術選型（先定案，避免各 subagent各自選版本）

- **引擎版本：Godot 4.7（stable，2026-06-18 釋出）**，不用 4.0-4.2（TileMap → TileMapLayer 破壞性 API 變動已在
  4.3 定型）。本專案原訂 4.3，2026-07-14 趁遷移早期、程式碼尚少時把目標版本上修到 4.7，換取 4.4~4.7 累積的
  bug fix／QoL；Godot 4.x feature release 保持向下相容，2D／TileMapLayer 這條線到 4.7 已很成熟。**同一時間全專案
  只能有一個目標版本**：日後只跟 4.7 的點版（4.7.x），要跨大版升級須另開任務評估 breaking change 後再全專案切換。
- **語言：GDScript**（不用 C#）——理由：GDevelop 端邏輯本來就是動態語言(JS)風格、資料驅動；GDScript 生態與
  debug 工具鏈更輕量，團隊目前是 John + AI agent 協作，不需要 C# 的型別工程量。
- **渲染：2D 手繪風（2026-07-18 定案，取代原「像素風」方向）**：`stretch mode = canvas_items`＋全域
  `texture filter = Linear`（`project.godot` 的 `default_texture_filter=1`），讓手繪地圖與水彩立繪以**視窗原生
  解析度**算圖、平滑取樣。base 視窗 `1280×720` 保留為設計/座標參考，實際視窗 `1920×1080`。
  - **沿革**：CORE-1 原採 `viewport`＋Nearest（像素風的**書面判斷、未實機驗證**），理由是 tile 像素風要避免
    接縫/次像素抖動。2026-07-18 John 實機發現手繪素材偏糊，且**美術方向已轉手繪**（地圖改成整張手繪畫面圖、
    非 tilemap，接縫理由消失；角色改水彩立繪），故正式改 `canvas_items`＋Linear。縮放/清晰度以 John 實機觀感為準。
  - **例外**：若仍保留**真正的像素小圖**（LPC 行走圖／戰鬥圖／tile atlas／虛擬搖桿等），那幾張要在各自的
    `.import` 個別設 `Nearest` 覆蓋全域 Linear，避免被糊化（待製作，逐一挑出）。
- **狀態管理：Autoload 單例**取代 GDevelop 的全域變數（`g_party`/`g_flags`/…），詳見 `specs/SAVE_SCHEMA.md`。
- **場景切換**：用 `get_tree().change_scene_to_file()` 或自訂 `SceneRouter` autoload，取代 GDevelop 的
  `replaceScene` + `g_result`/`g_returnScene` 機制（規格照搬，實作方式改用 Godot Signal）。

## 程式碼規範

- 檔案/節點命名：`snake_case.gd`、場景檔 `snake_case.tscn`、Node 名稱 `PascalCase`（跟 Godot 官方風格一致）。
- Autoload 單例用 `PascalCase` 類別、`snake_case` 檔名，例如 `autoload/game_state.gd` → 註冊為 `GameState`。
- 資料類別一律用 `class_name` + `extends Resource`，對應 CONTENT.json 的每個陣列元素（`PartyMember`、
  `Equipment`、`Skill`、`Enemy`、`Encounter`…）。
- **不要**把玩法邏輯寫成「每幀整段重跑」的巨大函式（那是 GDevelop JsCode 的權宜作法，不是 Godot 該有的寫法）。
  改用 Godot 的訊號/狀態機/`_process`分工，模組邊界對齊 `TASKS/` 的 MOD-* 拆分。
- 每個 MOD 任務的程式碼盡量收斂在自己的 `scenes/<area>/` 或 `scripts/<module>/` 目錄下，減少跨任務檔案衝突（見
  `TASKS/11_並行協作規則.md`）。
- 不寫不必要的註解；只在公式/魔術數字旁標明對應的 `specs/BATTLE_FORMULAS.md` 條目編號（例如
  `# see specs/BATTLE_FORMULAS.md F-3`），方便回溯權威來源。

## 驗證與測試（取代 gdevelop-mcp + puppeteer）

GDevelop 端用 `gdevelop-mcp` 的 `validate_project`/`preview_scene`，加上 puppeteer E2E（`cq2_e2e.mjs` 等）。
Godot 端沒有對應工具，遷移期間統一用：

```bash
# 語法/場景完整性檢查（不開視窗）
godot --headless --check-only --path godot-project

# 之後 CORE-7 會補上 GUT（Godot Unit Test）單元測試與 headless smoke test，指令待補
```

在 `TASKS/10_測試驗證.md` 定案前，**任何 MOD 任務完成的定義都必須包含**：`godot --headless --check-only`
過＋手動在編輯器內跑一次該場景無 error/warning。

## 多 Subagent 協作總則

1. 開工前一定先讀 `TASKS/11_並行協作規則.md`，確認自己要動的檔案沒有跟其他進行中任務重疊。
2. **核心任務（CORE-*）必須先完成、且互相有序**（CORE-1 → CORE-2 → CORE-3/4 → CORE-5/6 → CORE-7），因為所有
   模組任務都依賴 CORE 提供的資料層/存檔/狀態管理基礎；模組任務之間（MOD-A ~ MOD-K）**可平行**，但共享檔案
   （例如 `autoload/game_state.gd`）只能由當時任務清單標記的「擁有者」修改，其他任務如需擴充要用該檔案已提供
   的介面，不直接改內容。
3. 每個任務完成時，在對應 `TASKS/*.md` 裡把狀態改成「已驗收」，並在 `MIGRATION_OVERVIEW.md` 的進度表打勾。
4. 遇到規格與現有 `specs/` 衝突（例如發現 GDevelop 原始碼與 DEV_開發指南.md 描述不一致），以**原始碼
  （build_cq2.py 實際邏輯）為準**，回頭更新 spec 並註記版本遞增，不要自行改規則。
5. `reference/gdevelop/` 是唯讀凍結快照，**不要修改**；原 `../GDevelop` 目錄已無開發依賴，不要再引用或修改它。
