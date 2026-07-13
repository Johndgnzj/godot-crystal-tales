extends Area2D
class_name ExitZone

## D-5　場景出口（specs/DIALOGUE_SPEC.md D-5，對應 build_cq2.py L2298-2316 `CFG.exits` 迴圈）。
##
## 取代 GDevelop 版逐幀矩形比對＋`st.armed[]` 陣列，改用 Area2D body_entered/body_exited 訊號。
## 玩家節點需加入 "player" group（跟 trigger_zone.gd 同一個約定）。
##
## `armed` 語意（照抄原始碼行為，不是隨意簡化）：玩家「重生點剛好疊在出口矩形上」時，不能一進場景
## 就被立刻推出去；必須先觀察到玩家離開過矩形一次，才「武裝」這個出口，之後才會在再次進入時判定。
## 原始碼是「只要這一幀腳點不在矩形內就設 armed=true」，所以絕大多數出口（玩家重生點本來就不在
## 出口矩形上）第一幀就會武裝；只有重生點與出口矩形重疊的少數案例才需要玩家先走出去一次。
## Area2D 版本用 `_init_armed_state()`（延後一幀檢查 `get_overlapping_bodies()`）+ `body_exited`
## 訊號重現同樣的行為。

@export var to_scene: String = ""    ## 目標場景識別碼／路徑，格式跟 SceneRouter.go_to() 的
                                      ## scene_path 參數一致（實際格式待 CORE-5/MOD-H 場景檔定案）。
@export var spawn_id: String = ""    ## 目標場景的出生點 id。

@export var has_min_step: bool = false
@export var min_step: int = 0
@export var deny_msg: String = "現在還不能離開"

## 被擋下時往回推的位移。原始碼是加在「上一次有效座標」（`st.last`，由玩家移動碰撞解算持有，不是
## 本檔案的職責）上，這裡直接加在玩家目前的 global_position 上做近似，兩者在絕大多數情況下等價
## （玩家在被擋下的當幀通常還沒有明顯偏移），若跟玩家控制器（MOD-C）整合後發現行為不符，由 MOD-C
## 決定要不要改成呼叫方自行處理位移。
@export var push_offset: Vector2 = Vector2.ZERO

## 是否啟用。GameState（CORE-4 stub）目前沒有 `lock`／`inside`（室內子場景）欄位，原始碼的
## `!lock && !st.inside` 閘門先交由外部（世界場景控制器 / 玩家控制器）透過這個 exported 屬性關閉，
## 不強行擴充 GameState stub 的結構——見 TASKS/02_撿取觸發.md 的「已知風險」與任務報告「未決事項」。
@export var enabled: bool = true

signal exit_denied(msg: String)
signal exit_taken(to_scene: String, spawn_id: String)

var _armed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	call_deferred("_init_armed_state")


func _init_armed_state() -> void:
	var player_inside: bool = false
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			player_inside = true
			break
	_armed = not player_inside


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_armed = true


func _on_body_entered(body: Node) -> void:
	if not enabled or not body.is_in_group("player"):
		return
	if not _armed:
		return
	var decision: Dictionary = evaluate(GameState.flags)
	if decision.get("allowed", false):
		exit_taken.emit(to_scene, spawn_id)
		SceneRouter.go_to(to_scene, spawn_id)
	else:
		exit_denied.emit(decision.get("msg", deny_msg))
		if body is Node2D:
			(body as Node2D).global_position += push_offset


## 純邏輯判定，跟 trigger_zone.gd 同樣的設計理由：脫鉤 Node/Signal 方便測試。
## 回傳 {"allowed": true} 或 {"allowed": false, "msg": String}
func evaluate(flags: Dictionary) -> Dictionary:
	if has_min_step and int(flags.get("step", 0)) < min_step:
		return {"allowed": false, "msg": deny_msg}
	return {"allowed": true}
