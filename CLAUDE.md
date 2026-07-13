# 水晶戰記 Godot 遷移工作區

本目錄是 **GDevelop → Godot 遷移**的準備區，與現有 GDevelop 專案 `../gd-crystal-tales`（內含
`projects/crystal-quest`）平行存在，互不修改對方。遷移完成前，`gd-crystal-tales` 仍是唯一可玩、可發布的版本；
本目錄只做規格、任務拆解與（未來）Godot 專案骨架。

> 這份 CLAUDE.md 是**轉換期規範**：Godot 專案還沒開始寫玩法程式碼前，所有 subagent 協作都要先讀這份文件。
> 待 `godot-project/` 真的長出可玩內容後，這份文件會逐步演化成該專案的正式 CLAUDE.md（不需要重開新檔）。

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
└── godot-project/             # 未來 Godot 專案骨架（先建目錄結構，玩法程式碼待 CORE 任務展開後才寫）
    ├── project.godot
    ├── autoload/               # 全域單例（GameState/SaveManager/ContentDB/AudioBus…）
    ├── scenes/
    │   ├── title/ world/ battle/ ui/
    ├── scripts/                # 非 autoload 的可重用邏輯（純函式/資源類別）
    ├── resources/content/      # CONTENT.json 對應的 Resource 定義與匯入結果
    ├── assets/                 # 從 gd-crystal-tales/projects/crystal-quest/assets 複製＋改 import 設定
    └── tests/                  # GUT 或 headless smoke test
```

## 權威來源與資料流向

- **`../gd-crystal-tales/projects/crystal-quest/CONTENT.json`** 是數值資料的唯一真相來源（party/equipment/
  skills/enemies/encounters/shops/chests/pacing）。Godot 端**不要**手刻重複資料，寫 parser 讀取／轉存成
  Godot Resource（`.tres`）即可。CONTENT.json 有更新時，Godot 端的轉存結果要重新產生，不要手動同步改。
- **`../gd-crystal-tales/projects/crystal-quest/scripts/build_cq2.py`** 是遊戲規則的唯一真相來源（因為
  GDevelop 版的「事件系統」其實只是外殼，真正邏輯全在這支腳本產生的 JsCode 裡）。`specs/` 下的規格文件是從這支
  腳本**凍結抄錄**出來的快照，抄錄時必須附原始行號；之後 build_cq2.py 若改動數值/規則，要回來更新對應 spec 並
  標記版本號遞增（見下方版本規則）。
- **`../gd-crystal-tales/projects/crystal-quest/assets/`** 是美術/音效資產的唯一真相來源，直接複製，不重新繪製
  （除非任務清單明確標記為「順便重繪」）。
- **`../gd-crystal-tales/projects/crystal-quest/DEV_開發指南.md`** 是系統邊界的權威說明（WORLD_JS/BATTLE_JS 的
  各子系統列表），`TASKS/` 底下的模組任務拆分直接對應這份文件的系統清單，不要另外發明系統邊界。

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

- **引擎版本：Godot 4.3（stable）以上**，不用 4.0-4.2（TileMap → TileMapLayer 破壞性 API 變動已在 4.3 定型，
  4.4/4.5 若釋出且無重大 breaking change 可跟進，但同一時間全專案只能有一個目標版本）。
- **語言：GDScript**（不用 C#）——理由：GDevelop 端邏輯本來就是動態語言(JS)風格、資料驅動；GDScript 生態與
  debug 工具鏈更輕量，團隊目前是 John + AI agent 協作，不需要 C# 的型別工程量。
- **渲染：2D，像素風**，比照 GDevelop 設定：`windowWidth=1280 windowHeight=720`，`scaleMode: nearest`
  （對應 Godot 的 `Viewport` texture filter = Nearest；`stretch mode` **CORE-1 決定採用 `viewport`**——
  tile-based 像素風遊戲用 `viewport` 模式整張畫面以固定基準解析度算圖後再整體縮放＋nearest filter，避免
  `canvas_items` 模式下各節點各自縮放造成的 tile 接縫/次像素抖動。**注意**：CORE-1 執行當下環境內沒有可用的
  Godot 執行檔可以實機開專案測試（多方管道嘗試下載皆被網路政策擋下，見 `TASKS/00_核心任務.md` CORE-1 狀態
  說明），這個決定是依 Godot 官方文件＋社群慣例做的書面判斷、**尚未實機驗證**，之後拿到可用的 Godot 編輯器
  時應實際開專案確認縮放/像素對齊行為，如與預期不符再回來調整）。
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
5. 本目錄不影響 `gd-crystal-tales` 的開發與發布；除非任務明確要求，不要修改 `../gd-crystal-tales` 底下的檔案。
