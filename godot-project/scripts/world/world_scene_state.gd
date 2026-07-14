extends RefCounted
class_name WorldSceneState

## MOD-C 產出：世界場景層級的執行期狀態容器（`lock`/`inside`/`cur_door`）。
##
## ## 為什麼不是 autoload，而是 per-scene 物件
##
## `autoload/game_state.gd`（CORE-4）檔頭「lock/inside 欄位歸屬判斷」一節已經查證 build_cq2.py 原始碼
## 並下結論：`lock`/`st.inside`/`st.curDoor` 是 `rs.__v`（單一 WORLD_JS runtime scene state，等同
## GDevelop 場景物件掛的暫存變數），**不是** `g.get("g_xxx")` 全域變數，也不在 `saveGame()` 實際寫入
## 的欄位清單裡（見 specs/SAVE_SCHEMA.md）。語意上是「玩家目前站在哪個世界場景、是否在跟該場景內某個
## 室內子區域互動」的單一場景 runtime 狀態，換場景（甚至只是同一張地圖切換室內/室外）就該歸零重算，
## 不需要跨場景持久化，也不需要讓對話/撿取/戰鬥等其他系統跨模組直接讀取——這是「場景控制器內部狀態」
## 的特徵，不是「全域、跨場景、可能要存檔」的 GameState 該管的東西。
##
## 本檔案採用 CORE-4 建議的做法：**per-scene 物件，不是 autoload**。理由：
## 1. 貼近 GDevelop `rs.__v` 本來就是 per-scene（`if(!rs.__v){rs.__v={...}}`，見 build_cq2.py:1389）
##    的語意——每個世界場景各自的 runtime scene 都有自己的一份，不會互相污染。如果做成 autoload
##    單例，換場景時必須記得手動重置每個欄位，任何一個世界場景忘記重置就會把上一個場景的
##    lock/inside/cur_door 狀態帶進新場景，這正是 GDevelop 版靠「每個 RuntimeScene 各自的
##    `rs.__v`」天生避免掉的一類 bug，做成 autoload 反而要重新引入這個風險。
## 2. 沒有任何其他模組需要「跨場景」讀取這三個欄位（衝突矩陣裡也沒有其他 MOD 任務依賴它），符合
##    CORE-4 檔頭「不需要讓對話/撿取/戰鬥等其他系統跨模組直接讀取」的判斷——不需要 autoload 的
##    「全域可見」特性。
## 3. 用法：世界場景根節點腳本（MOD-H 之後建立）在 `_ready()` 呼叫
##    `var state := WorldSceneState.new()`，把它指派給 `player_controller.world_state`，並用
##    `register_gated_zone()`/`register_gated_zones()` 把場景內的 `ExitZone`/`PickupZone` 節點註冊
##    進來（見下方）。用 `RefCounted`（不是 `Node`）是因為它不需要進場景樹、不需要 `_process`，純粹是
##    一份跟著世界場景根節點生命週期走的資料容器 + 少量邏輯，比另外掛一個 Node 子節點更輕量。
##
## ## 跟 MOD-B 三個 zone 腳本的整合
##
## `exit_zone.gd`/`pickup_zone.gd`（MOD-B 擁有，唯讀參考）各自曝露 `@export var enabled: bool = true`，
## 檔頭註解明講「由外部（世界場景控制器/玩家控制器）透過這個屬性關閉，對應原始碼 `!lock && !st.inside`
## 閘門」（見 build_cq2.py:2305 `if(!lock&&!st.inside){...exits.../triggers...}`）。本檔案的
## `register_gated_zone()`/`_refresh_gates()` 就是那個「外部世界場景控制器」：每次 `lock`/`inside`
## 透過 `set_lock()`/`enter_building()`/`exit_building()` 改變時，重新計算 `is_gate_open()`
## （`not lock and not inside`）並寫回每個已註冊 zone 的 `enabled` 屬性。
##
## **`trigger_zone.gd` 缺口（已補齊，2026-07-14）**：MOD-C 完成當下 `trigger_zone.gd` 還沒有
## `enabled` export，`register_gated_zone()` 對它不會生效。協調者合併時補上了同款 `@export var
## enabled: bool = true` + `_on_body_entered()` 開頭的 `if not enabled: return`（跟 exit_zone.gd/
## pickup_zone.gd 同一套寫法），現在三個 zone 腳本的閘門行為一致，`_apply_gate()` 的 `"enabled" in
## zone` 動態檢查對三者都會生效，不需要呼叫端額外處理。

signal lock_changed(locked: bool)
signal inside_changed(is_inside: bool)

## 是否鎖定移動（例如對話進行中），對應 GDevelop `lock`（build_cq2.py 多處 `lock=true`，例如選單/
## 商店/對話開啟時）。`player_controller.gd` 每個 physics frame 讀這個欄位決定要不要吃輸入。
var lock: bool = false

## 是否在室內子區域，對應 GDevelop `st.inside`（值是門所屬物件名稱字串或 null；這裡簡化成 bool，
## 因為目前沒有任何模組需要知道「是哪個門」，只需要知道「在不在室內」——真正的門資訊在 `cur_door`）。
var inside: bool = false

## 室內時記錄門口位置，對應 GDevelop `st.curDoor`（`door` 物件含 `tx`/`ty`/`key`/`obj`/`owners`，
## 見 build_cq2.py:1517-1522 `enterBuilding()`）。供 `get_save_position()` 查詢——CORE-3
## SaveManager 存檔時，室內要存「門口外座標」而不是玩家實際站位（對應 build_cq2.py:1281
## `if(sv.inside&&sv.curDoor){sx=sv.curDoor.tx*TS;sy=(sv.curDoor.ty+1)*TS;}`），呼叫端（世界場景
## 根節點）在呼叫 `SaveManager.save_game()` 前應該先呼叫 `get_save_position()` 做這個校正
## （SaveManager 本身刻意不做這個判斷，見 autoload/save_manager.gd 檔頭「介面設計」一節）。
## 最少需要 `tx`/`ty` 兩個 int 欄位；其餘欄位（`key`/`obj`/`owners`）由呼叫端自行需要時填入，本檔案
## 不強制格式。
var cur_door: Dictionary = {}

## 已註冊、需要跟著 `lock`/`inside` 一起開關 `enabled` 的 zone 節點（`ExitZone`/`PickupZone`，
## 也可以是任何未來有 `enabled: bool` 屬性的節點）。
var _gated_zones: Array = []


## 註冊一個 zone 節點，之後 `lock`/`inside` 變動時會自動同步它的 `enabled` 屬性。註冊當下立刻套用
## 一次目前的閘門狀態（不用等下一次 `set_lock()`/`enter_building()` 才生效）。
func register_gated_zone(zone: Node) -> void:
	if zone in _gated_zones:
		return
	_gated_zones.append(zone)
	_apply_gate(zone)


## 批次註冊，方便世界場景根節點一次把 `get_tree().get_nodes_in_group("exit_zone")` 之類的查詢結果
## 全部丟進來（分組慣例待 MOD-H 場景檔定案，本檔案不強制）。
func register_gated_zones(zones: Array) -> void:
	for z in zones:
		register_gated_zone(z)


## 設定 lock 狀態（例如對話開啟時 `set_lock(true)`，對話結束時 `set_lock(false)`）。
func set_lock(locked: bool) -> void:
	if lock == locked:
		return
	lock = locked
	_refresh_gates()
	lock_changed.emit(lock)


## 進入室內子區域，對應 `enterBuilding(door)`（build_cq2.py:1517-1518：`st.inside=door.obj;
## st.curDoor=door;`）。`door` 至少要有 `tx`/`ty`（見 `cur_door` 欄位註解）。
func enter_building(door: Dictionary) -> void:
	inside = true
	cur_door = door.duplicate(true)
	_refresh_gates()
	inside_changed.emit(true)


## 離開室內子區域，對應 `exitBuilding()`（build_cq2.py:1560-1561：`st.inside=null;st.curDoor=null;`）。
## 回傳離開前的 `cur_door`，方便呼叫端（世界場景根節點）沿用門的座標把玩家放到門口外
## （原始碼 `exitBuilding()` 接著用 `door.tx`/`door.ty` 算玩家重新出現的位置，見 build_cq2.py:1573-1574）。
func exit_building() -> Dictionary:
	var door: Dictionary = cur_door
	inside = false
	cur_door = {}
	_refresh_gates()
	inside_changed.emit(false)
	return door


## 對應 GDevelop `!lock && !st.inside` 閘門（build_cq2.py:2305），出口/撿取/觸發區是否應該生效。
func is_gate_open() -> bool:
	return not lock and not inside


## 存檔座標校正：室內時回傳門口外座標，否則回傳原樣（`fallback` 通常是玩家目前 `global_position`）。
## 對應 build_cq2.py:1281（見 `cur_door` 欄位註解）。`tile_size` 預設 32，對應 build_cq2.py `TS=32`。
func get_save_position(fallback: Vector2, tile_size: int = 32) -> Vector2:
	if inside and cur_door.has("tx") and cur_door.has("ty"):
		return Vector2(float(cur_door["tx"]) * tile_size, float(int(cur_door["ty"]) + 1) * tile_size)
	return fallback


func _apply_gate(zone: Node) -> void:
	if zone == null:
		return
	if "enabled" in zone:
		zone.enabled = is_gate_open()


func _refresh_gates() -> void:
	for z in _gated_zones:
		_apply_gate(z)
