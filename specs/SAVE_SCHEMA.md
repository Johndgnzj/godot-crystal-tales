# 規格：存檔／全域狀態 Schema

- Spec 版本: v1.1
- 對應 GDevelop 原始碼快照: `scripts/build_cq2.py` L1275-1296（存檔）、DEV_開發指南.md L65-71（跨場景狀態）
- 狀態: 定案
- 用途: CORE-3（存檔系統）、CORE-4（全域狀態 Autoload）、CORE-5（場景轉場）實作依據
- 版本記錄: v1.1（2026-07-14，CORE-5 認領實作時補齊）在「Godot 端對應設計」補上
  `SceneRouter` 場景轉場暫態值的交握機制（出生點定位規則、`result` 值集合、`lose` 特例），
  原本 v1.0 只寫了「改用 Signal/SceneRouter 參數」一句話，沒有講清楚場景端要怎麼配合讀取，
  本次回讀 `build_cq2.py` L1425-1440/L2812-2821/L3366-3393 補齊，不是破壞性變動（欄位名稱不變）。

## GDevelop 現況

全域狀態存在 GDevelop 的「全域變數」，型別統一是字串，內容是 JSON.stringify 過的物件；`saveGame()`
把這些字串原封不動連同場景/座標寫進 `localStorage["cq_save"]`。

### 全域變數清單（原始碼 `g.get("g_xxx")`）

| 變數 | 型別 | 內容 | 備註 |
|---|---|---|---|
| `g_party` | JSON array | 隊伍成員：`{id, lv, exp, attrs:{str,agi,int}, hp, mp, eq:{slot:eqId}, sk:{skillId:1}, spts, pts, ...}` | `derive()` 會補算 maxhp/maxmp/patk/matk/pdef/mdef/dodgeV/critV/spd |
| `g_flags` | JSON object | 劇情旗標，key 是自由字串（`step`/`reg`/`ch1`/`ch2`/`relic`/`herb`/`mira2`/`gotXxx`/`c_*`…），value 是整數 | 未定義視為 0；`matchWhen` 用 `==`/`>=` 比對 |
| `g_eqInv` | JSON array | 裝備袋，裝備 id 陣列（未裝備的庫存） | |
| `g_itemInv` | JSON object | 背包 `{itemId: count}` | 存取一律走 `invAll/invGet/invAdd/invUse`，Godot 端要保留同樣的介面收斂點 |
| `g_gold` | number | 金幣 | 唯一非字串型別的全域變數 |
| `g_chests` | JSON array/object | 已開啟寶箱清單 | |
| `g_autoBattle` | number(0/1) | 自動戰鬥開關，存檔內持久化 | |
| `g_encounter` | string | 觸發中的遭遇 id | 不持久化（場景切換用） |
| `g_returnScene` / `g_returnX` / `g_returnY` | string/number | 戰鬥結束或讀檔要回到的場景與座標 | 不持久化 |
| `g_result` | string | `win`/`lose`/`flee`/`story`/`resume` | 場景切換用的一次性旗標，不持久化 |
| `g_spawn` | string | 進場出生點 id | 不持久化 |

### `saveGame()` 實際寫入的存檔物件（`localStorage["cq_save"]`）

```jsonc
{
  "v": 1,                 // 存檔格式版本
  "scene": "Town",        // CFG.SCENE，存檔當下所在場景
  "x": 512, "y": 384,      // 玩家座標；室內時存「門口外」座標避免重載卡牆
  "flags": "{...}",        // = g_flags 的 JSON 字串（雙重 stringify，原樣照抄）
  "party": "{...}",
  "eqInv": "{...}",
  "itemInv": "{...}",
  "gold": 350,
  "chests": "{...}",
  "auto": 0
}
```

- 存檔時機（自動存檔，無手動存檔 UI）：場景進場（init 末）／對話帶有存檔動作／pickup／開寶箱／商店買賣完成。
- 室內存檔的特殊規則：若 `rs.__v.inside && rs.__v.curDoor` 為真，存的座標是門口外（`curDoor.tx*TS,
  (curDoor.ty+1)*TS`），不是玩家當下座標，避免重新載入時卡在牆內。
- 讀檔（Title「繼續冒險」）：讀出上述物件 → 還原五個持久化全域變數 → 設 `g_result="resume"` +
  `g_returnX/Y` → `replaceScene(存檔場景)`；場景 init 時的出生點分支要認得 `"resume"` 走 returnX/Y 定位，
  而不是預設出生點。
- 「重新開始」：清 `localStorage["cq_save"]`，其餘全域變數用預設值重建（不持久化，等於全新一局）。
- 進度只有這一個存檔槽（`SAVE_KEY = "cq_save"`），沒有多存檔位。

## Godot 端對應設計（CORE-3/CORE-4 實作用）

- **`GameState`（autoload, `autoload/game_state.gd`）**：持有上表所有欄位的 **原生型別**（不要維持雙重
  JSON 字串包字串的怪癖，那是 GDevelop 全域變數只吃字串的權宜設計）。用 `class_name` Resource 或純
  Dictionary 皆可，但要在本文件補上決定後更新版本號。
- **`SaveManager`（autoload, `autoload/save_manager.gd`）**：
  - `save_game()` 序列化 `GameState` 需要持久化的欄位（=上表「持久化」那幾項，不含
    `g_encounter`/`g_returnScene`/`g_result`/`g_spawn` 這些場景轉場用的暫態值）成 JSON，寫入
    `user://cq_save.json`（Godot 慣例用 `user://`，對應 GDevelop 的 `localStorage`）。
  - 存檔物件的欄位名稱建議與上表一致（`v/scene/x/y/flags/party/eqInv/itemInv/gold/chests/auto`），方便
    未來若要做「讀取 GDevelop 舊存檔」的一次性遷移工具時對照。
  - `v` 欄位保留，Godot 版存檔格式若跟這份 v1 不同，`v` 要遞增並在本文件記錄差異。
  - 室內存檔存門口外座標的規則照搬。
- **場景轉場暫態值**（`g_encounter`/`g_returnScene`/`g_returnX/Y`/`g_result`/`g_spawn`）改用 Godot
  Signal 傳遞或 `SceneRouter` autoload 的參數，**不要**塞進存檔／`GameState` 的持久化欄位裡（對應 CORE-5）。
  `GameState` 仍然提供這五個欄位當作暫態儲存槽（`encounter`/`return_scene`/`return_x`/`return_y`/
  `result`/`spawn`，不持久化，`SaveManager.save_game()` 不寫入這幾個欄位），`SceneRouter` 讀寫它們。

  **`SceneRouter` 交握機制（CORE-5 定案，`godot-project/autoload/scene_router.gd`）**：

  - `go_to(scene_path, spawn_id)`／`start_battle(encounter_id, return_scene, return_x, return_y)`／
    `battle_result(result)` 三個函式簽名維持不變（MOD-A/MOD-B 已在呼叫）。`scene_path`／
    `to_scene`／`return_scene` 三個參數統一吃 GDevelop `CFG.SCENE` 的邏輯場景名稱字串（`"Town"`／
    `"Forest"`／`"Forest2"`／`"Mine"`／`"Cave"`／`"Battle"`／`"Title"`，不是 `res://` 路徑），
    `SceneRouter` 內部有一張 `SCENE_PATHS` 對照表轉成實際場景檔路徑，MOD-H 建立場景檔時只需要
    更新這張表。
  - **出生點定位規則**（照抄 build_cq2.py L1425-1432，取代原本「待補」狀態）：世界場景 `_ready()`
    要呼叫 `SceneRouter.should_use_return_position()`——回傳 `true` 時用
    `GameState.return_x`/`return_y` 定位玩家；回傳 `false` 時改用 `GameState.spawn` 字串查場景
    自己的出生點表。判斷式＝`GameState.result` 屬於 `["win","flee","story","resume"]` **且**
    `GameState.return_x >= 0`（`-1` 是「沒有 return 座標」的哨兵值，對應原始碼 `clrTransient()`）。
  - 場景讀完定位資訊後，**要自行**把 `GameState.spawn = ""` 與 `GameState.result = ""` 清空（對應
    原始碼 L1434/L1440 無條件清空），避免暫態值被下一次進場誤用。`SceneRouter` 本身不清空這兩個
    欄位——切場景是非同步的（`change_scene_to_file()`），沒辦法代為判斷「場景何時讀完」。
  - **`result` 值集合**：`win`/`lose`/`flee`/`story`/`resume`（同上表）。`lose`（隊伍全滅）是特例：
    `battle_result("lose")` 內部會強制把 `GameState.return_scene` 蓋成 `"Town"`、
    `GameState.spawn` 蓋成 `"shrine"`（照抄 build_cq2.py L2814 的寫死規則），所以戰敗一律走
    spawn 分支重生在芳蕾鎮教堂，不會用 return_x/y。這個規則收斂在 `SceneRouter.battle_result()`
    裡，MOD-E（戰鬥結算，尚未開工）呼叫 `battle_result("lose")` 時不用自己重複這段特例判斷。
  - **`resume`（讀檔）流程**：`SaveManager`（CORE-3）設定 `GameState.result = "resume"` 與
    `GameState.return_x`/`return_y` = 存檔座標後，呼叫 `SceneRouter.go_to(存檔場景, "")`——
    `go_to()` 只會覆寫 `GameState.spawn`，不會動 `result`/`return_x`/`return_y`，兩者合成即可
    重現原始碼 `loadSave()`（L3387-3393）的行為，不需要在 `SceneRouter` 上新增第四個公開函式。
  - 已用 Python 邏輯交叉驗證（一般出口、boss 觸發＋勝利/戰敗、CUTS battle/transfer、resume 讀檔
    共 6 個情境）確認跟上述 GDevelop 原始碼行為一致；**沒有可用的 Godot 執行檔可以實機驗證**（同
    CORE-1 已知環境限制）。

## 待確認事項（實作前需與 John 對過，暫列此處避免遺漏）

- 是否要支援多存檔槽（GDevelop 版目前只有一槽）？若不需要，Godot 版維持單槽，不要過度設計。
- `g_chests` 目前型別在原始碼是「陣列/物件」寫法不完全一致，實作 CORE-3 時要回頭讀 build_cq2.py 確認精確
  型別後在本文件補上範例值，目前先標記為存疑。
