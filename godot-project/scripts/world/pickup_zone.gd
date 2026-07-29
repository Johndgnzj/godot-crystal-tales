extends Area2D
class_name PickupZone

## D-7　撿取原語（specs/DIALOGUE_SPEC.md D-7，對應 build_cq2.py L2376-2392 `CFG.pickups` 迴圈）。
##
## 取代 GDevelop 版逐幀矩形比對；顯示/隱藏仍然每幀重算（跟原始碼 `po.hide(!pshown)` 一樣，因為目前
## GameState 沒有旗標變更通知機制可訂閱，這裡用輕量 `_process` 每幀重算取代——資料量小，可接受）；
## 實際撿取判定改用 Area2D body_entered 訊號取代逐幀矩形比對。玩家節點需加入 "player" group。
##
## 現有兩個實例（見 TASKS/02_撿取觸發.md 驗收標準）：
##   鏡草 ×3：op="inc", flag_name="herb", once_flag="herb_p<i>", show_when="mira2==1"
##   阿吉頭盔：op="set", flag_name="relic", set_value=1, once_flag="relic_p", show_when="ch2>=1",
##             item_id="miner_helmet"

@export var show_when: String = "always"
@export var once_flag: String = ""      ## 留空代表沒有 once 限制。
@export var flag_name: String = ""      ## 撿取時要寫入的旗標名稱。
@export var op: String = "inc"          ## "inc"（累加 1）| "set"（寫成 set_value）
@export var set_value: int = 0
@export var item_id: String = ""        ## 留空代表不額外加道具。
@export var msg: String = ""
@export var sfx_name: String = "select.mp3"

## 是否啟用，同 exit_zone.gd：`!lock && !st.inside` 閘門交由外部控制器透過這個屬性關閉。
@export var enabled: bool = true

## 撿取物的「發光呼吸」。手繪地圖上一張 32px 的小圖會被草叢花叢吃掉（2026-07-29 John 實測在東之森
## 找不到鏡草），用亮度＋微幅縮放的循環讓它自己跳出來，順帶對上「發光的鏡草」這個設定。
## 只動名為 `Sprite` 的子節點（沒有就靜默略過，例如舊 mine.tscn 的無圖撿取點），不動碰撞形狀。
@export var glow: bool = true

## 顯示倍率（不影響碰撞範圍）：32px 的鏡草先放大到 48px 才看得見，2026-07-30 John 回饋太大再縮 30%。
@export var display_scale: float = 1.05

## true＝**走過去不會自動撿**，要靠玩家在旁邊按互動鍵「調查」（world_scene 的 _update_interactions 負責
## 顯示提示與呼叫 investigate()）。2026-07-30 John 指定：採集要有動作，不是路過就入手。
@export var require_interact: bool = true

## true＝在原地生一個 StaticBody2D 擋路，讓玩家會「撞到」這株草而不是走進去（撿到後自動移除）。
@export var blocks: bool = true

## 撿取後要播的過場 id 前綴：實際播 `<cut_prefix>_<flag_name 撿完後的值>`（例：herb_get_1／_2／_3）。
## 留空＝不播過場，沿用 msg 提示列。查不到該 id 時自動退回 msg，不擋流程。
@export var cut_prefix: String = ""

const GLOW_PERIOD := 0.7                       ## 呼吸半週期（秒）
const GLOW_BRIGHT := Color(1.45, 1.45, 1.3)    ## 呼吸最亮時的 modulate（>1＝提亮，微偏暖白）
const GLOW_SCALE := 1.12                       ## 呼吸最大時的額外縮放

signal picked_up(msg: String, sfx_name: String)

var _collected: bool = false   ## 避免同一幀/同一次重疊被 body_entered 觸發兩次（保險，非原始碼行為）


var _blocker: StaticBody2D = null   ## blocks=true 時的擋路體（撿到後移除）
var _blocker_shape: CollisionShape2D = null   ## 隨顯示狀態開關——隱藏中的撿取物不該擋路


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_sprite()
	_setup_blocker()
	_refresh_visibility()


## 擋路體：複製 zone 自己的 CollisionShape2D，掛一個 StaticBody2D 在同一個位置。
## 撿走之後 _collect() 會把它刪掉，不留看不見的牆。
func _setup_blocker() -> void:
	if not blocks:
		return
	var shape := get_node_or_null("Shape") as CollisionShape2D
	if shape == null or shape.shape == null:
		return
	_blocker = StaticBody2D.new()
	_blocker_shape = CollisionShape2D.new()
	_blocker_shape.shape = shape.shape
	_blocker_shape.position = shape.position
	_blocker.add_child(_blocker_shape)
	add_child(_blocker)


## 放大顯示＋起一條無限循環的呼吸 tween（節點隱藏時 tween 照跑，重新顯示時不必重啟）。
func _setup_sprite() -> void:
	var spr := get_node_or_null("Sprite") as Node2D
	if spr == null:
		return
	spr.scale = Vector2.ONE * display_scale
	if not glow:
		return
	var base: Vector2 = spr.scale
	var tw := create_tween().set_loops()
	tw.tween_property(spr, "scale", base * GLOW_SCALE, GLOW_PERIOD).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(spr, "modulate", GLOW_BRIGHT, GLOW_PERIOD).set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "scale", base, GLOW_PERIOD).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(spr, "modulate", Color.WHITE, GLOW_PERIOD).set_trans(Tween.TRANS_SINE)


func _process(_delta: float) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	if _collected:
		return
	var shown: bool = is_shown(GameState.flags)
	visible = shown
	monitoring = shown
	monitorable = shown
	if _blocker_shape != null:
		_blocker_shape.disabled = not shown   # 還沒接委託＝草還沒出現，不能擋路


## 純邏輯判定：showWhen 成立且尚未完成 once。跟 Node 脫鉤方便測試。
func is_shown(flags: Dictionary) -> bool:
	var done: bool = once_flag != "" and int(flags.get(once_flag, 0)) != 0
	return FlagMatcher.matches(flags, show_when) and not done


func _on_body_entered(body: Node) -> void:
	if require_interact or _collected or not enabled or not body.is_in_group("player"):
		return
	if not is_shown(GameState.flags):
		return
	_collect()


## 可否被「調查」：require_interact 的撿取點由 world_scene 在玩家靠近時呼叫。
func can_investigate() -> bool:
	return require_interact and not _collected and enabled and is_shown(GameState.flags)


func investigate() -> bool:
	if not can_investigate():
		return false
	_collect()
	return true


func _collect() -> void:
	_collected = true
	var count := 0
	if flag_name != "":
		if op == "inc":
			GameState.flag_inc(flag_name, 1)
		else:
			GameState.flag_set(flag_name, set_value)
		count = GameState.flag_get(flag_name)
	if once_flag != "":
		GameState.flag_set(once_flag, 1)
	if item_id != "":
		GameState.inv_add(item_id, 1)
	visible = false
	monitoring = false
	monitorable = false
	if _blocker != null:
		_blocker.queue_free()
		_blocker = null
	# 有對應過場就播過場（撿第 N 株各有台詞），沒有才退回提示列訊息。
	var played := false
	if cut_prefix != "":
		played = DialogueSystem.play_cutscene("%s_%d" % [cut_prefix, count])
	if not played:
		picked_up.emit(msg, sfx_name)
	# CORE-3 完成，SaveManager 已註冊為 autoload：撿取是自動存檔時機之一（見 D-7、
	# specs/SAVE_SCHEMA.md）。零參數呼叫沿用既有存檔的 scene/x/y，只更新旗標/道具欄位。
	SaveManager.save_game()
