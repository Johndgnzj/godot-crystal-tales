# 規格：對話／過場／觸發／撿取資料格式

- Spec 版本: v3.0
- 對應 GDevelop 原始碼快照: `reference/gdevelop/build_cq2.py`（2026-07 快照）L941-1015（DLG）、
  L1016-1036（CUTS）、L1302-1306（matchWhen）、L1564-1566（openOwnerCmd）、L1575-1582（buildIntCmds）、
  L1859-1864（室外 NPC 對話）；其餘段落（劇情佇列/出口/觸發區/pickups）行號仍對應 v1.1 舊快照，待全面校對
- 狀態: 定案
- 用途: MOD-A（對話/劇情）、MOD-B（撿取/觸發）實作依據
- v3.0 變更記錄（2026-07-18，對話資料 .tres 化，John 拍板）：
  1. 對話資料真相源從「run-time parse dialogue.json」改為原生 .tres（比照 content_db.tres 慣例，見
     CLAUDE.md「權威來源與資料流向」）：個別檔 `resources/content/dialogue/npc/<id>.tres`（NpcDialogue，
     內嵌 DialogueEntry）＋ `cuts/<id>.tres`（CutsceneEntry，內嵌 CutsceneLine），由聚合
     `resources/content/dialogue/dialogue_db.tres` 以 ExtResource 引用，DialogueSystem 只 load 聚合檔。
     dialogue.json 降級為「種子」（同 content.json 地位），僅重匯入時用；轉檔腳本
     `scripts/dialogue/build_dialogue_tres.gd`。設計員直接在 Inspector 編個別 .tres 即生效。
  2. **破壞性變更**：CutsceneEntry.lines 從 `Array[Dictionary{speaker,text}]`（v1.1/D-8 原定案）改為
     `Array[CutsceneLine]`（新子資源 class，speaker/text 兩欄），讓過場台詞能在 Inspector 逐句編、與 DLG
     編輯體驗一致。CutsceneEntry 另新增 `id` 欄位（原為 dict 的 key）。不影響存檔 schema（過場內容不進
     save）。詳見 D-8。
- v2.0 變更記錄（2026-07-16，verify_dialogue.py 抽樣失敗調查時發現並修正）：
  1. GDevelop 端 DLG 改版：室內 NPC 條目新增 `cmd`/`label`/`done` 三欄位，條目選擇從單軌扁平掃描變成
     「室外扁平／室內先按 cmd 分組再組內由上而下」雙軌；一次性贈禮（`done`）在互動選單層過濾，不是 when
     條件。D-2 已依新快照改寫，extract_dialogue.py／dialogue.json／dialogue_system.gd／
     verify_dialogue.py 均已同步雙軌語意。
- v1.1 變更記錄（2026-07-13，MOD-A 認領實作時發現並補回）：
  1. D-3 原本只寫了 `once`/`lines` 兩個欄位，實際回讀 `build_cq2.py` L991-1011 與 L1685-1706 收尾邏輯
     後發現 CUTS 條目還有 `battle`/`transfer`/`setstep`/`party` 四個既有欄位（`demon_pre`/`demon_post`/
     `town_start` 三個實例都有用到），本次補齊到 D-3。
  2. D-8「待確認事項」的兩項在本次實作時定案：CUTS `lines` 改用 `Array[Dictionary{speaker,text}]`（不是
     陣列的陣列）；`action` 完整副作用已逐條核對並實作在
     `godot-project/scripts/dialogue/dialogue_system.gd` 的 `_run_action()`，不再只列 id 清單。

## D-1　共用旗標比對器 `matchWhen(f, w)`（L1270-1274）

```
matchWhen(flags, w):
    if w is null/undefined or w === "always": return true
    match w against /^(\w+)(==|>=)(\d+)$/
    if no match: return false
    v = flags[group1] || 0
    n = int(group3)
    return (group2 === "==") ? (v === n) : (v >= n)
```

只支援三種 `when` 語法：`"always"` / `"旗標名==數字"` / `"旗標名>=數字"`。未定義旗標視為 0。**DLG／CUTS 的
`step`／`minStep` 欄位是額外欄位，不是走 `matchWhen`**（見 D-3），實作時不要混為一談。

Godot 端等價：`FlagMatcher.matches(flags: Dictionary, when: String) -> bool`，純函式，放
`scripts/flag_matcher.gd`，MOD-A/MOD-B 共用同一份（對應 GDevelop 版「DLG/trigger/pickup 皆用它」的設計，
不要各自重寫一份判斷邏輯）。

## D-2　NPC 對話表 `DLG`（L941-1015）

```jsonc
DLG = {
  "<npc_id>": [
    {"when": "<matchWhen 語法>", "name": "顯示名稱", "lines": ["台詞1", "台詞2", ...],
     "action": "<可選，對話結束後執行的 side-effect id>",
     "cmd": "<可選，室內互動指令分組：talk/quest/trade/rest/pray/一次性事件 id；無 cmd 視為 talk>",
     "label": "<可選，該指令在室內互動選單顯示的名稱>",
     "done": "<可選，一次性旗標名：事件觸發後由 action 寫 1，選單層過濾不再出現>"},
    ...
  ]
}
```

- **條目選擇分兩軌**（v2.0 快照起）：
  - **室外 NPC**（gray/mira/rossel…，條目無 `cmd`）：貼近對話時扁平掃全表，由上到下第一個 `when` 成立的
    條目勝出（L1859-1864）。
  - **室內主人**（tina/hank/dora/shea/mayor/martha/gid…，條目有 `cmd`）：先由互動選單選指令
    （buildIntCmds L1575-1582——`talk` 永遠有；trade/quest/rest/pray 有條目就出現；其他 cmd 是一次性
    事件，`when` 成立**且 `done` 旗標未設**才出現），再在**同 cmd 組內**由上到下取第一個 `when` 成立的
    條目（openOwnerCmd L1564-1566，`e.cmd||"talk"`）。
- **順序即優先權**（兩軌皆同）：由上到下找第一個 `when` 成立的條目，找到就停止（`for` 迴圈 `return`）。
  撰寫新對話時**越晚觸發的劇情條件要排越前面**（例如 `ch2>=1` 通常要排在 `step>=3` 前面），現有 DLG 表
  全部遵循這個慣例（越後期的旗標排越上面），Godot 端資料若改用陣列結構，順序語意要保留。
- **`done` 不是 when 條件**：贈禮只發一次的機制在選單層（例如漢克贈劍條目是 `when:"ch1>=1",
  done:"gotSword"`，`give_sword` action 觸發後寫 `gotSword=1`，該指令就從選單消失）——DLG 裡**沒有**
  `gotSword==1` 這種 when，驗證/實作時不要發明。
- `action`：對話結束後執行的具名副作用，目前已知值：`register`（登錄冒險者）、`ch1_take`/`ch1_reward`、
  `ch2_take`/`ch2_report`、`heal`（隊伍全恢復）、`give_ring`/`shop_hank_gift`/`shop_gid_gift`（贈送道具/開店）、
  `mira_start`/`mira_reward`、`relic_turnin`、`shop_hank`/`shop_gid`（純開店，無贈禮）。這些 action 各自對應
  一段旗標寫入 + 道具/金幣增減邏輯，**分散寫在對話結束處理的 switch/if 鏈裡**（build_cq2.py 對話結束段落），
  MOD-A 實作時要把每個 action 的完整副作用抄成表格，本文件先只列 action id 清單，完整副作用內容在
  `TASKS/01_對話劇情.md` 的驗收清單裡逐一列出，避免本檔案過長。
- 對話資料目前**寫死在 build_cq2.py 的 Python dict 裡**，不是獨立資料檔。**Godot 遷移時建議把 DLG/CUTS
  抽成獨立的資料檔**（例如 `resources/content/dialogue.json` 或 `.tres`），與 CONTENT.json 同層級管理，
  這是相對於 GDevelop 現況的刻意改善，不是照搬——理由：現況台詞跟地圖生成程式碼混在同一支 3487 行的腳本裡，
  不利於「John 只改劇情」的分工模式。**（v3.0 已落實：真相源為 `resources/content/dialogue/**/*.tres`，
  設計員在 Inspector 編個別 NPC／過場檔，見 D-8 與版本記錄。）**

## D-3　過場資料表 `CUTS`（L991+）

```jsonc
CUTS = {
  "<cut_id>": {
    "once": "<可選，一次性旗標名，播過就不再自動觸發>",
    "lines": [
      ["說話者", "台詞"],       // 說話者為空字串 "" 代表旁白/系統提示（無名字框）
      ...
    ],
    "battle": "<可選，播完立即觸發的 encounter id，見 CONTENT.json encounters>",
    "transfer": ["<目標場景>", "<目標場景的出生點 id>"],  // 可選，播完立即切換場景
    "setstep": <可選，整數，播完寫入 flags.step>,
    "party": ["<member id>", ...]  // 可選，播完套用的隊伍組成（已在隊上的成員保留原資料，新成員用樣板建立）
  }
}
```

- **`battle`/`transfer`/`setstep`/`party` 四個欄位是 v1.0 版本漏記的既有欄位**（2026-07-13 MOD-A 認領
  實作時回讀原始碼發現，見 v1.1 變更記錄），目前只有 3 個 CUTS 實例用到：`demon_pre`（`battle:
  "prologue_demon"`）、`demon_post`（`transfer:["Town","home"], setstep:3`）、`town_start`
  （`party:["ludo","marin"], setstep:4`）。四個欄位彼此不是互斥的（`once`/`setstep`/`party` 可以跟
  `battle`/`transfer` 同時出現），但 `battle` 與 `transfer` 目前資料裡沒有同時出現在同一條目的案例
  （語意上也不合理——不會播完過場同時「開戰」又「切場景」）。
- 播放機制：觸發時 `st.queue.push(cut_id)`，世界場景每幀從 `queue` 頭部取出播放（`st.cut`/`st.cutIdx`
  維護目前播放到第幾句）。播放完畢後（L1685-1706）依序處理：
  1. 若有 `once`：寫 `flags[once]=1`。
  2. 若有 `setstep`：寫 `flags.step = setstep`。
  3. 若有 `party`：依陣列 id 順序重建隊伍——原本在隊上的成員保留其存檔資料（等級/裝備/hp...），新成員
     呼叫 `mkMember(id)`（即 GDevelop 端的樣板建立＋`derive()`）建立。
  4. 若有 `battle`：寫 `g_returnScene/g_returnX/g_returnY`（記錄過場觸發當下的場景與玩家座標，供戰敗/
     逃走返回用，語意同 D-6）→ `replaceScene("Battle")`，**不再處理後續的 `transfer`**（`return`）。
  5. 否則若有 `transfer`：寫 `g_spawn` → `replaceScene(transfer[0])`，**同樣直接 return**。
  6. 都沒有的話（純敘事過場，如 `prologue_town`/`cave_intro`）：留在原場景，佇列繼續處理下一筆
     （若有）。
- 播放完畢的判斷靠 `once` 旗標寫回 `g_flags`，下次不再重複觸發。
- 觸發來源已知兩種：`CFG.triggers` 陣列裡 `t.cut` 有值的項目（見 D-4，最常見）；以及戰鬥結算的特殊分支
  （L1436-1439）——序章魔影戰勝利後（`res==="story"` 且在 Cave 場景）自動 `queue.push("demon_post")`；
  二章洞熊被擊退回到 Mine 場景時（`ch2===2` 且 `!c_mine_after`）`queue.push("mine_after")`；戰敗
  （`res==="lose"`）則是不經 CUTS 表、直接組一句固定旁白 push `"__lose__"`（見下方特例）。**沒有「NPC
  對話觸發過場」這種路徑**——DLG 的 `action` 只會改旗標/道具/金幣，不會 push 過場佇列。
- **`__lose__` 特例**（L1439/L1623）：不是 `CUTS` 表裡的 key，是戰敗時寫死的一句話
  `"你們在芳蕾鎮教堂的祭壇前醒來……蓋婭女神接住了倒下的旅人。（隊伍已完全恢復）"`，沒有 `once`/`battle`/
  `transfer`/`setstep`，播放前 GDevelop 端已經呼叫過 `healAll()`。Godot 端對應
  `DialogueSystem.play_defeat_narration()`。

## D-4　場景觸發區 `CFG.triggers`（L2318-2331）

```jsonc
triggers: [
  {"r": px_rect(...), "when": "<matchWhen 語法，可選>",
   "cut": "<CUTS id，可選>", "step": <整數，可選，額外用 f.step === 此值做閘門>,
   "msg": "<可選，純訊息字串>", "minStep": <整數，可選，f.step >= 此值才顯示 msg>}
]
```

- 判定流程（每幀，玩家不在室內、未被 lock 時）：進入矩形 `r` → `matchWhen(flags, t.when)` 不成立就整條跳過
  → 若有 `t.cut`：`step` 閘門通過（`t.step===undefined || f.step===t.step`，注意是 `===` 不是 `>=`）且
  該過場未播過（`!cc.once || !f[cc.once]`）才 `queue.push` 並 `break`（同一幀只觸發一個 trigger）。
  → 若有 `t.msg`：`minStep` 閘門通過（`f.step >= minStep`，這裡才是 `>=`）才顯示訊息並 `break`。
- **`msg` 型 trigger 顯示後 `break`，可用優先序做互斥訊息**（例如 Cave 場景同一區域依 `ch2` 進度顯示不同
  落石訊息，靠陣列順序 + `when` 互斥達成，不是靠額外的 if/else 巢狀）。
- 這是**跟 `matchWhen` 不同的第二層閘門機制**（`step`/`minStep` 直接比較 `flags.step`，不透過 `matchWhen`
  語法），MOD-B 實作時兩層閘門都要保留，不要合併成一種。

## D-5　場景出口 `CFG.exits`（L2300-2316）

```jsonc
exits: [
  {"r": px_rect(...), "to": "<目標場景名>", "spawn": "<目標場景的出生點 id>",
   "minStep": <整數，可選>, "deny": "<可選，被擋下時的提示文字>",
   "pushX": <可選，被擋下時往回推的位移>, "pushY": <可選>}
]
```

- `armed` 機制：離開矩形後才重新武裝（`st.armed[i]=true`），避免站在出口矩形邊界反覆觸發/一進圖就被推回。
- `minStep` 未通過時：顯示 `deny` 訊息＋把玩家位置往回推 `pushX/pushY`，**不會**呼叫 `replaceScene`。
- 通過時：寫 `g_spawn = spawn` → `replaceScene(to)`。

## D-6　頭目/精英標記（BossMark / BearMark，L2347-2373）

- 不是資料表驅動，是**個別具名物件**（每種 boss 各自一個 sprite 物件 + 一段幾乎重複的碰撞檢查程式碼）。
- 顯示條件：`BossMark` 只在 `ch1===1` 顯示；`BearMark` 只在 `ch2===1` 顯示（每幀檢查一次，不成立就
  `hide(true)`）。
- 觸發條件：玩家與標記中心距離 `< 80px` → 寫 `g_returnScene/g_returnX/g_returnY`（**戰敗/逃走要能重試**，
  所以是記錄「進場前」的座標，不是固定重生點）→ 寫 `g_encounter` id（`"ch1_boss"` / `"ch2_bear"`）→
  `replaceScene("Battle")`。
- Godot 端建議**不要**沿用「每種 boss 各自複製一段檢查程式碼」的寫法，改成資料驅動（`CFG.bossMarks: [{obj,
  showWhen, encounterId, returnOffset}]` 之類），這是相對於現況的刻意改善，MOD-B 實作時一併處理，記得在
  `TASKS/02_撿取觸發.md` 的驗收標準裡列出這條，不要漏掉任一個既有 boss（目前已知：ch1_boss 哥布林頭目、
  ch2_bear 狂暴洞熊）。

## D-7　撿取原語 `CFG.pickups`（L2376-2392）

```jsonc
pickups: [
  {"obj": "<場景物件名>", "showWhen": "<matchWhen 語法>", "once": "<可選，一次性旗標>",
   "flag": "<要寫入的旗標名>", "op": "inc" | "set", "val": <op=set 時的目標值>,
   "item": "<可選，額外加進背包的道具 id>", "msg": "<可選，撿取後的提示訊息>",
   "sfx": "<可選，音效檔名，預設 select.wav>"}
]
```

- 判定流程（每幀，非室內、未 lock 時）：`matchWhen(flags, showWhen) && !已完成(once)` 決定該物件
  顯示/隱藏 → 玩家腳點落在 `pk.r`（撿取矩形）內 → 依 `op` 寫旗標（`inc`＝累加 1，`set`＝寫成 `val`）→
  若有 `once` 一併寫 1 → 若有 `item` 呼叫 `invAdd(item, 1)` → 隱藏該物件 → 顯示 `msg` → 播音效 →
  **立即 `saveGame()`**（撿取是自動存檔時機之一，見 `specs/SAVE_SCHEMA.md`）。
- 目前兩個實例：鏡草 ×3（`op:"inc", flag:"herb"`，`showWhen:"mira2==1"`）、阿吉頭盔
  （`op:"set", flag:"relic", val:1, item:"miner_helmet", showWhen:"ch2>=1"`）。
- **裝飾用 prop 不要誤用 pickup 系統**：純裝飾物件走一般碰撞（`foot` 矩形），不是這裡的 `pickups` 表；
  `foot=(0,0,0,0)` 會被 build 腳本當成整格是牆，這是地圖生成的坑，不是本規格的一部分，記錄在
  `TASKS/08_地圖管線.md` 供 MOD-H 注意。

## D-8　Godot 端資料結構（MOD-A 實作定案，2026-07-13）

- `DialogueEntry`（`class_name`, `extends Resource`，`godot-project/scripts/dialogue/dialogue_entry.gd`）：
  `when: String`, `speaker: String`, `lines: PackedStringArray`, `action: String`（空字串＝無 action），
  以及室內用 `cmd`/`label`/`done: String`（v2.0 起，見 D-2）。
- `CutsceneLine`（`godot-project/scripts/dialogue/cutscene_line.gd`，**v3.0 新增**）：`speaker: String`,
  `text: String`（`@export_multiline`）。過場的一句台詞，speaker 空＝旁白。取代原本的
  `Dictionary{speaker,text}`，讓過場台詞在 Inspector 逐句可編。
- `CutsceneEntry`（`godot-project/scripts/dialogue/cutscene_entry.gd`）：`id: String`（**v3.0 新增**，原為
  cuts dict 的 key）, `once: String`, `lines: Array[CutsceneLine]`（**v3.0 改**，原為 Dictionary 陣列，見
  版本記錄）, `battle: String`, `transfer: PackedStringArray`（`[to_scene, spawn_id]`）, `setstep: int`
  （`-1` 表示未設定，因為 0 是合法的 step 值不能借用當 sentinel）, `party: PackedStringArray`。
- `NpcDialogue`（`godot-project/scripts/dialogue/npc_dialogue.gd`，**v3.0 新增**）：`id: String`,
  `entries: Array[DialogueEntry]`。單一 NPC 的整張對話表，一個 NPC 一個 .tres；entries 陣列順序＝優先權
  （保留 D-2「順序即優先權」語意，勿用檔名/字母序取代）。
- `DialogueDatabase`（`godot-project/scripts/dialogue/dialogue_database.gd`，**v3.0 新增**）：
  `npcs: Array[NpcDialogue]`, `cutscenes: Array[CutsceneEntry]`。聚合入口，存成
  `resources/content/dialogue/dialogue_db.tres`，以 ExtResource 引用個別檔（比照 ContentDatabase）；
  DialogueSystem 只 load 這一個檔（匯出 .pck 安全、型別安全）。
- 資料檔（**v3.0 起**）：真相源＝`resources/content/dialogue/**/*.tres`（設計員在 Inspector 編個別檔），
  由 `dialogue_db.tres` 聚合、DialogueSystem load。`resources/content/dialogue.json`
  （`{dlg: {npc_id: [DialogueEntry...]}, cuts: {cut_id: CutsceneEntry}}`）降級為「種子」：由
  `scripts/dialogue/extract_dialogue.py` 對 `build_cq2.py` 做 AST 解析＋`ast.literal_eval()` 抽取
  （不是手動轉寫），再由 `scripts/dialogue/build_dialogue_tres.gd` 轉成 .tres——兩者僅「重新匯入種子」時才跑。
- `DialogueSystem`（autoload，`godot-project/scripts/dialogue/dialogue_system.gd`）：
  `open_npc_dialogue(npc_id)`／`play_cutscene(cut_id)`／`advance()`／`show_message(speaker, lines)`／
  `play_defeat_narration()`，透過 signal（`dialogue_line_changed`/`cutscene_line_changed`/
  `shop_requested`/`battle_requested`/`scene_transfer_requested`）跟 UI／世界場景／其他 MOD 溝通，見該
  檔案檔頭完整說明。action 副作用完整實作在 `_run_action()`，逐條對照 `build_cq2.py` L1758-1779。
- `TriggerZone` / `ExitZone` / `PickupZone`：對應 D-4/D-5/D-7 三種資料（MOD-B 範圍），建議各自用
  `Area2D` + 自訂 Resource 儲存規則參數，判定邏輯收斂在各自的 MOD-B 腳本裡，不要散落在場景腳本各處
  （對應現況「每幀跑一大段 if」的技術債，Godot 版用 Area2D 的 `body_entered` 訊號取代逐幀矩形比對）。
- `FlagMatcher.matches()` 純函式（見 D-1，MOD-B 建立）供以上三種都呼叫。

## 待確認事項

（v1.0 列出的兩項已在 v1.1／MOD-A 實作時定案，見上方 D-3/D-8 內文與版本記錄，本節暫無新的待確認事項。）
