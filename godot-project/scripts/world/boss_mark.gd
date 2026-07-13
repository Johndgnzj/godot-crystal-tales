extends Area2D
class_name BossMark

## D-6　頭目/精英標記，資料驅動版本（specs/DIALOGUE_SPEC.md D-6，對應 build_cq2.py L2347-2373）。
##
## GDevelop 版是「每種 boss 各自一個具名 sprite 物件 + 幾乎重複的碰撞檢查程式碼」（BossMark/BearMark
## 各自一段）。這裡改成單一腳本＋資料參數化，新增第三章 boss 只需要在場景裡放一個 BossMark 節點並
## 設好 export 參數，不用再加程式碼。
##
## 現有兩個實例：
##   ch1_boss 哥布林頭目：show_when="ch1==1", encounter_id="ch1_boss", return_offset=(-90, 0)
##   ch2_bear 狂暴洞熊  ：show_when="ch2==1", encounter_id="ch2_bear", return_offset=(0, 90)
## （`ch1`/`ch2` 由戰鬥結算流程負責在勝利時寫成 2 使其自動隱藏，見 build_cq2.py L3124/L3127；
## 那段屬於戰鬥結算範圍，不是本檔案職責，只需要 show_when 每幀重算即可自然反映最新旗標值。）
##
## 觸發距離：原始碼用「兩物件中心點歐幾里得距離 < 80px」逐幀檢查；這裡改成 Area2D + 圓形
## CollisionShape2D（半徑 = trigger_radius，預設 80）搭配 body_entered 訊號，近似同樣的判定範圍
## （場景檔由 MOD-H／地圖任務建立時，記得幫 BossMark 節點掛一個半徑等於 trigger_radius 的
## CircleShape2D，本檔案只提供腳本邏輯，不建立 .tscn）。玩家節點需加入 "player" group。

@export var show_when: String = "always"
@export var encounter_id: String = ""
@export var return_scene_id: String = ""
@export var return_offset: Vector2 = Vector2.ZERO
@export var trigger_radius: float = 80.0
@export var sfx_name: String = "hurt.wav"

signal boss_triggered(encounter_id: String)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_refresh_visibility()


func _process(_delta: float) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	var shown: bool = FlagMatcher.matches(GameState.flags, show_when)
	visible = shown
	monitoring = shown
	monitorable = shown


func _on_body_entered(body: Node) -> void:
	if not visible or not body.is_in_group("player"):
		return
	if not (body is Node2D):
		return
	_trigger(body as Node2D)


func _trigger(player: Node2D) -> void:
	var return_pos: Vector2 = compute_return_position(player.global_position)
	boss_triggered.emit(encounter_id)
	SceneRouter.start_battle(encounter_id, return_scene_id, return_pos.x, return_pos.y)
	# TODO: sfx_name（預設 "hurt.wav"）目前沒有 AudioBus/音效 autoload 可呼叫（尚無對應 CORE 任務
	# 產出）。播音效邏輯留給監聽 boss_triggered 訊號的世界場景控制器處理，或等音效系統就位後這裡直接呼叫。


## 純邏輯計算，跟 Node/Signal 脫鉤方便測試：戰敗/逃走重試用的「回到觸發前座標」= 觸發當下玩家座標
## + return_offset（照抄原始碼 BossMark 用 `p.getX()-90`／BearMark 用 `p.getY()+90` 的偏移語意）。
func compute_return_position(player_pos: Vector2) -> Vector2:
	return player_pos + return_offset
