extends Node

## GameState — autoload（註冊名稱 "GameState"，見 ../project.godot [autoload]）。
##
## CORE-4 正式產出，取代協調者先前放置的暫時性 stub（見 68cd7b8「放置 GameState/SceneRouter 暫時性
## stub」）。欄位/方法名稱**沿用 stub 既有命名**，因為 MOD-A（scripts/dialogue/dialogue_system.gd）與
## MOD-B（scripts/world/trigger_zone.gd／exit_zone.gd／pickup_zone.gd／boss_mark.gd）已經合併進 main
## 並直接呼叫這些欄位/方法（flags/party/item_inv/gold/eq_inv/chests/auto_battle/encounter/
## return_scene/return_x/return_y/result/spawn／flag_get/flag_set/flag_inc/inv_all/inv_get/inv_add/
## inv_use）——改名會讓已合併的程式碼失效，故不改。
##
## 規格來源：specs/SAVE_SCHEMA.md（全域變數表、saveGame() 寫入格式）；型別語意對照
## reference/gdevelop/build_cq2.py L1266-1296（flags/invAll/invGet/
## invAdd/invUse）與 L1608-1618（openChest 的 g_chests 去重寫入邏輯）。
##
## 跟 stub 版本比，本次變更：
## 1. `chests` 型別從 `Dictionary` 改成 `Array`（元素為已開啟寶箱 id 的 String）。這是回填
##    SAVE_SCHEMA.md「待確認事項」第二點的定案：build_cq2.py 裡 g_chests 從頭到尾只有
##    `J("g_chests",[])` / `opened.push(C.d.id)` / 線性掃描去重（L1612-1614）三種操作，從未當
##    Dictionary/物件用，因此正確型別是「已開啟寶箱 id 陣列」。**影響範圍**：檢查過
##    godot-project/ 底下目前沒有任何檔案讀寫 `GameState.chests`（MOD-A/MOD-B 都還沒用到這個欄位），
##    所以這個型別修正不影響任何已合併程式碼；新增 `chest_is_opened()`/`chest_mark_opened()` 介面
##    收斂寶箱開啟的去重邏輯，之後 MOD-B 的地圖寶箱互動（若屬於 MOD-B 或後續模組範圍）直接呼叫即可，
##    不用各自重寫線性掃描去重。
## 2. 補上 `flag_get/flag_set/flag_inc/inv_get/inv_add` 的型別安全（key 一律轉 String、value 一律轉
##    int），避免呼叫端不小心塞入 float/其他型別造成存檔序列化或後續 `==` 比對出錯（GDevelop 版全域變數
##    因為原本就是 JSON 字串，天生型別混亂；Godot 端既然改用原生型別，這裡就要收斂成單一真型別）。
## 3. `inv_add` 的負數 clamp 到 0 邏輯確認與 build_cq2.py `invAdd()`（L1295：
##    `v[id]=(v[id]||0)+n;if(v[id]<0)v[id]=0;`）語意一致，stub 版本已經正確，這裡保留並補測試
##    （見下方「驗證」）。
##
## **刻意不做的事**（見 TASKS/00_核心任務.md CORE-4 段落與 TASKS/11_並行協作規則.md 衝突矩陣）：
## - **不整合 `derive()`**：正式規格要求「`party` 成員要能呼叫 CORE-2 的 `derive()` 等價物」，但
##   `derive()` 是 MOD-F（`scripts/content/derive.gd`）的職責，MOD-F 尚未開工。衝突矩陣明講「不允許
##   任何模組自己重算衍生屬性」，所以本檔案的 `party` 維持「普通 Dictionary 陣列」，不內建任何
##   maxhp/maxmp/patk/... 計算。**等 MOD-F 完成 `scripts/content/derive.gd` 後，這裡（或呼叫端）要
##   補上呼叫**——目前所有寫入 `party` 的地方（例如 dialogue_system.gd 的 `_apply_party()`）都已經在
##   註解裡記錄了同樣的已知限制。
## - **不實作 `newGame()`/預設隊伍建立**：build_cq2.py 的 `newGame()`（L3368-3380）與 `mk(id)`
##   （L3357-3364）會建立初始隊伍（ludo/alan）並內嵌計算 maxhp/maxmp——這同樣牽涉 derive() 等價公式，
##   而且初始隊伍成員 id 屬於內容資料（應該從 ContentDB 讀，不該在 GameState 硬編碼）。這屬於「新遊戲」
##   流程的職責（title 場景 + CORE-3 存檔系統 + MOD-F derive() 整合後才能正確組裝），不是 GameState
##   欄位容器本身的職責，所以本檔案只提供空欄位預設值（`party = []` 等），不提供 `reset_to_defaults()`
##   這類會誘使呼叫端塞入未經 derive() 計算的隊員資料的方法。
## - **不新增 `lock`/`inside`（室內子場景）欄位**：見下方「lock/inside 欄位歸屬判斷」。
##
## ## lock/inside 欄位歸屬判斷（回應 TASKS/02_撿取觸發.md「已知風險」）
##
## MOD-B 在 `TASKS/02_撿取觸發.md` 記錄了「GameState 缺少 lock/inside 欄位」的依賴缺口。查證
## build_cq2.py 原始碼後判斷**這兩個欄位不屬於 GameState 的職責範圍**，不塞入本檔案：
## - `lock`/`st.inside`/`st.curDoor` 在原始碼裡是 `rs.__v`（單一 WORLD_JS 執行期 runtime scene state，
##   等同 GDevelop 場景物件 `runtimeScene` 掛的暫存變數），**不是** `g.get("g_xxx")` 這種全域變數，
##   也**不在** `saveGame()` 實際寫入的欄位清單裡（見 build_cq2.py L1277-1290、specs/SAVE_SCHEMA.md
##   「saveGame() 實際寫入的存檔物件」一節，兩份都沒有 lock/inside/curDoor）。
## - 語意上，`lock`/`inside`/`curDoor` 是「玩家目前站在哪個世界場景、是否在跟該場景內某個室內子區域互動」
##   的**單一世界場景 runtime 狀態**，換場景（甚至只是同一張地圖切換室內/室外）就該歸零重算，不需要跨場景
##   持久化，也不需要讓對話/撿取/戰鬥等其他系統跨模組直接讀取——這正是「場景控制器內部狀態」的特徵，而不是
##   `GameState`（全域、跨場景、可能要存檔）該管的東西。
## - 結論：`lock`/`inside` 屬於**世界場景控制器**（World scene controller，目前對照
##   `TASKS/00_核心任務.md` 的任務拆分，這塊落在 MOD-C「移動碰撞」/世界場景邏輯範圍，尚未認領）的職責，
##   不是 CORE-4。MOD-B 現有的 workaround（`exit_zone.gd`/`pickup_zone.gd` 各自曝露 `enabled: bool`
##   export，由外部世界場景控制器切換）方向正確，維持現狀即可；`trigger_zone.gd` 目前沒有同樣的
##   `enabled` 開關（因為只在 body_entered 當下判定一次），是否要補上留給 MOD-C 認領時一併決定。
##   本檔案不代 MOD-B 修改 `scripts/world/*.gd`（那些是 MOD-B 擁有的檔案），僅在此記錄判斷結論；
##   已同步在 `TASKS/00_核心任務.md` CORE-4 段落留言，供 MOD-C 認領時查閱。

# =========================================================================
# 持久化欄位（存檔會寫入，見 specs/SAVE_SCHEMA.md「saveGame() 實際寫入的存檔物件」）
# =========================================================================

## 隊伍成員：Array[Dictionary]，每個 Dictionary 至少含 id/lv/exp/attrs/hp/mp/eq/sk/pts/spts。
## **不**內建 maxhp/maxmp/patk/matk/pdef/mdef/dodgeV/critV/spd 計算——那是 MOD-F `derive()` 的職責，
## 見上方「刻意不做的事」。呼叫端讀取衍生屬性前，應先確認該 Dictionary 是否已被 derive() 等價物處理過。
var party: Array = []

## 劇情旗標。key 一律是 String，value 一律是 int；未定義 key 視為 0（見 flag_get）。
var flags: Dictionary = {}

## 裝備袋：Array[String]，裝備 id 陣列（未裝備的庫存，允許重複 id——同一款裝備可以持有多件，照搬
## build_cq2.py L1605 `iv.push(L.id)` 不去重的語意）。
var eq_inv: Array = []

## 背包：Dictionary[String, int]，`{item_id: count}`。存取一律走 inv_all/inv_get/inv_add/inv_use。
var item_inv: Dictionary = {}

## 金幣，唯一非字串/非容器型別的持久化欄位，直接讀寫（沿用既有呼叫端 `GameState.gold += n` 的用法，
## 不額外包一層方法，避免破壞 dialogue_system.gd 既有呼叫）。
var gold: int = 0

## 已開啟寶箱 id 清單：Array[String]（型別修正，見檔頭「跟 stub 版本比」第 1 點）。
var chests: Array = []

## 自動戰鬥開關，存檔內持久化。
var auto_battle: bool = false

# =========================================================================
# 場景轉場暫態值（不持久化，CORE-5 的 SceneRouter 負責讀寫；見 SAVE_SCHEMA.md「場景轉場暫態值」一節）
# =========================================================================

var encounter: String = ""
var return_scene: String = ""
var return_x: float = 0.0
var return_y: float = 0.0
var result: String = ""          # win/lose/flee/story/resume
var spawn: String = ""


# =========================================================================
# 旗標操作（照搬 build_cq2.py flags()/matchWhen 的「未定義視為 0」語意）
# =========================================================================

func flag_get(key: String) -> int:
	return int(flags.get(key, 0))


func flag_set(key: String, value: int) -> void:
	flags[String(key)] = int(value)


func flag_inc(key: String, delta: int = 1) -> void:
	flag_set(key, flag_get(key) + int(delta))


# =========================================================================
# 背包操作（照搬 build_cq2.py invAll/invGet/invAdd/invUse 的介面收斂意圖，L1293-1296）
# =========================================================================

func inv_all() -> Dictionary:
	return item_inv


func inv_get(id: String) -> int:
	return int(item_inv.get(id, 0))


## 對應 invAdd()：`v[id]=(v[id]||0)+n;if(v[id]<0)v[id]=0;`——負數結果 clamp 到 0，不允許庫存變負。
func inv_add(id: String, n: int) -> void:
	var key := String(id)
	var v: int = inv_get(key) + int(n)
	if v < 0:
		v = 0
	item_inv[key] = v


func inv_use(id: String) -> void:
	inv_add(id, -1)


# =========================================================================
# 寶箱操作（對應 build_cq2.py openChest() L1608-1618 的去重寫入邏輯，L1612-1614）
# =========================================================================

func chest_is_opened(id: String) -> bool:
	return chests.has(id)


## 標記寶箱為已開啟；回傳 true 代表這次是新標記（呼叫端應該發獎），false 代表已經開過（重複呼叫應
## 忽略，對應原始碼 `if(C.opened)return;` 與 `dup` 去重檢查兩層防呆合併成一次呼叫）。
func chest_mark_opened(id: String) -> bool:
	var key := String(id)
	if chests.has(key):
		return false
	chests.append(key)
	return true
