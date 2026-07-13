# 規格：對話／過場／觸發／撿取資料格式

- Spec 版本: v1.0
- 對應 GDevelop 原始碼快照: `scripts/build_cq2.py` L930-990（DLG/CUTS 定義）、L1270-1274（matchWhen）、
  L1516（openOwnerDlg）、L2298-2392（出口/觸發區/BossMark/pickups）
- 狀態: 定案
- 用途: MOD-A（對話/劇情）、MOD-B（撿取/觸發）實作依據

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

## D-2　NPC 對話表 `DLG`（L931-990）

```jsonc
DLG = {
  "<npc_id>": [
    {"when": "<matchWhen 語法>", "name": "顯示名稱", "lines": ["台詞1", "台詞2", ...], "action": "<可選，對話結束後執行的 side-effect id>"},
    ...  // 由上到下第一個 matchWhen 為真的條目勝出（見 openOwnerDlg，L1516）
  ]
}
```

- **順序即優先權**：陣列由上到下找第一個 `when` 成立的條目，找到就停止（`for` 迴圈 `return`）。撰寫新對話時
  **越晚觸發的劇情條件要排越前面**（例如 `ch2>=1` 通常要排在 `step>=3` 前面），現有 DLG 表全部遵循這個慣例
  （越後期的旗標排越上面），Godot 端資料若改用陣列結構，順序語意要保留。
- `action`：對話結束後執行的具名副作用，目前已知值：`register`（登錄冒險者）、`ch1_take`/`ch1_reward`、
  `ch2_take`/`ch2_report`、`heal`（隊伍全恢復）、`give_ring`/`shop_hank_gift`/`shop_gid_gift`（贈送道具/開店）、
  `mira_start`/`mira_reward`、`relic_turnin`、`shop_hank`/`shop_gid`（純開店，無贈禮）。這些 action 各自對應
  一段旗標寫入 + 道具/金幣增減邏輯，**分散寫在對話結束處理的 switch/if 鏈裡**（build_cq2.py 對話結束段落），
  MOD-A 實作時要把每個 action 的完整副作用抄成表格，本文件先只列 action id 清單，完整副作用內容在
  `TASKS/01_對話劇情.md` 的驗收清單裡逐一列出，避免本檔案過長。
- 對話資料目前**寫死在 build_cq2.py 的 Python dict 裡**，不是獨立資料檔。**Godot 遷移時建議把 DLG/CUTS
  抽成獨立的資料檔**（例如 `resources/content/dialogue.json` 或 `.tres`），與 CONTENT.json 同層級管理，
  這是相對於 GDevelop 現況的刻意改善，不是照搬——理由：現況台詞跟地圖生成程式碼混在同一支 3487 行的腳本裡，
  不利於「John 只改劇情」的分工模式。

## D-3　過場資料表 `CUTS`（L991+）

```jsonc
CUTS = {
  "<cut_id>": {
    "once": "<可選，一次性旗標名，播過就不再自動觸發>",
    "lines": [
      ["說話者", "台詞"],       // 說話者為空字串 "" 代表旁白/系統提示（無名字框）
      ...
    ]
  }
}
```

- 播放機制：觸發時 `st.queue.push(cut_id)`，世界場景每幀從 `queue` 頭部取出播放（`st.cut`/`st.cutIdx`
  維護目前播放到第幾句）。播放完畢的判斷靠 `once` 旗標寫回 `g_flags`，下次不再重複觸發。
- 觸發來源只有一種：`CFG.triggers` 陣列裡 `t.cut` 有值的項目（見 D-4），沒有「NPC 對話觸發過場」這種路徑。

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

## D-8　Godot 端資料結構建議（MOD-A/MOD-B 實作起點）

- `DialogueEntry`（`class_name`, `extends Resource`）：`when: String`, `speaker: String`,
  `lines: PackedStringArray`, `action: String`。
- `CutsceneEntry`：`once: String`, `lines: Array[Array]`（或 `Array[Dictionary{speaker,text}]`，實作時
  二選一定案並回填本文件）。
- `TriggerZone` / `ExitZone` / `PickupZone`：對應 D-4/D-5/D-7 三種資料，建議各自用 `Area2D` +
  自訂 Resource 儲存規則參數，判定邏輯收斂在各自的 MOD-B 腳本裡，不要散落在場景腳本各處（對應現況「每幀跑一大段
  if」的技術債，Godot 版用 Area2D 的 `body_entered` 訊號取代逐幀矩形比對）。
- `FlagMatcher.matches()` 純函式（見 D-1）供以上三種都呼叫。

## 待確認事項

- CUTS 的 `lines` 結構（陣列的陣列 `[speaker, text]`）在 Godot 端要不要改成 `Dictionary` 陣列，MOD-A 實作
  時定案並回填本節版本。
- 各 `action` id 的完整副作用（金幣/道具/旗標異動明細）尚未逐條抄錄進本文件，避免與 `TASKS/01_對話劇情.md`
  重複維護；MOD-A 認領時要回 build_cq2.py 原始碼逐一核對，不要憑對話文字內容猜測。
