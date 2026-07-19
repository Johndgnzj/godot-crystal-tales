extends Area2D
class_name TriggerZone

## D-4　場景觸發區（specs/DIALOGUE_SPEC.md D-4，對應 build_cq2.py L2298-2331 `CFG.triggers` 迴圈）。
##
## 取代 GDevelop 版「每幀拿玩家腳點座標跟一串矩形逐一比對」的作法，改用 Area2D 的 body_entered 訊號。
## 玩家節點（或玩家的腳點碰撞體）需要加入 "player" group 才會被偵測到——這是本檔案對外的唯一約定，
## 玩家控制器（MOD-C 範圍）只要把對應節點加進這個 group 即可，不需要跟本檔案有其他耦合。
##
## 判定流程完全比照 D-4：
##   1. `when` 閘門（FlagMatcher，永遠先檢查）不成立 -> 整條略過。
##   2. 若設了 `cut_id`：`step` 精確比對（`===`，不是 `>=`）且該過場未播過（`cut_once_flag` 對應
##      GDevelop `CUTS[cut].once`，因為 CUTS 表由 MOD-A 擁有，這裡改成在場景資料上直接標註對應的
##      once 旗標名稱，避免 trigger_zone 反過來讀 MOD-A 的 CUTS 表造成耦合）才發出 `cutscene_requested`。
##   3. 否則若設了 `msg`：`minStep` 比對（這裡才是 `>=`）成立才發出 `message_requested`。
##   4. 步驟 2、3 都不是 if/else，跟原始碼一樣兩者都可能檢查到（同一個 trigger 理論上可以同時有
##      cut 與 msg，只是目前資料沒有這種案例）。
##
## 「同一幀只觸發一個 trigger」（原始碼 for 迴圈 break 語意）用一個跨所有 TriggerZone 實例共享的
## static 「上次觸發的 physics frame」記錄達成：同一個 physics frame 內第一個成功觸發的 zone 會佔用
## 這一幀，其餘 zone 即使同幀也 body_entered 不會再觸發。

## matchWhen 語法（見 flag_matcher.gd D-1），"" 或 "always" 視為永遠成立。
@export var when: String = "always"

## 過場 id（CUTS 表的 key）。留空代表這是純 msg 型 trigger（不觸發過場）。
@export var cut_id: String = ""

## 對應 CUTS[cut_id].once 的旗標名稱；留空代表該過場沒有 once 限制。
@export var cut_once_flag: String = ""

## t.step 精確比對閘門。has_step=false 對應原始碼 `t.step===undefined`（不設限制，永遠通過）。
@export var has_step: bool = false
@export var step: int = 0

## msg 型 trigger 的訊息文字，留空代表這是純 cut 型 trigger（不顯示訊息）。
@export var msg: String = ""

## msg 的 minStep 閘門（`>=` 比對）。has_min_step=false 對應原始碼 `t.minStep===undefined`。
@export var has_min_step: bool = false
@export var min_step: int = 0

## 是否啟用，跟 exit_zone.gd/pickup_zone.gd 同一套約定（`!lock && !st.inside` 閘門）。由
## world_scene_state.gd 的 register_gated_zone() 自動同步，見 TASKS/03_移動碰撞.md「已知缺口」——
## 這是本檔案原本缺少、MOD-C 完成後回補的欄位，補齊後三個 zone 腳本的閘門行為才一致。
@export var enabled: bool = true

signal cutscene_requested(cut_id: String)
signal message_requested(msg: String)

static var _last_trigger_frame: int = -1


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not enabled or not body.is_in_group("player"):
		return
	var frame: int = Engine.get_physics_frames()
	if TriggerZone._last_trigger_frame == frame:
		return
	var result: Dictionary = evaluate(GameState.flags)
	match result.get("type", "none"):
		"cut":
			TriggerZone._last_trigger_frame = frame
			cutscene_requested.emit(result["cut_id"])
		"msg":
			TriggerZone._last_trigger_frame = frame
			message_requested.emit(result["msg"])
		_:
			pass


## 純邏輯判定，刻意跟 Node/Signal 脫鉤，方便寫單元測試／跨語言（Python）交叉驗證，見
## TASKS/02_撿取觸發.md 驗證章節。
## 回傳 {"type": "cut", "cut_id": String} / {"type": "msg", "msg": String} / {"type": "none"}
func evaluate(flags: Dictionary) -> Dictionary:
	if not FlagMatcher.matches(flags, when):
		return {"type": "none"}
	if cut_id != "":
		var ok_step: bool = (not has_step) or (int(flags.get("ch1_step", 0)) == step)
		var once_done: bool = cut_once_flag != "" and int(flags.get(cut_once_flag, 0)) != 0
		if ok_step and not once_done:
			return {"type": "cut", "cut_id": cut_id}
	if msg != "":
		var ok_min: bool = (not has_min_step) or (int(flags.get("ch1_step", 0)) >= min_step)
		if ok_min:
			return {"type": "msg", "msg": msg}
	return {"type": "none"}
