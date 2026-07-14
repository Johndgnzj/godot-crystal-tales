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
@export var sfx_name: String = "select.wav"

## 是否啟用，同 exit_zone.gd：`!lock && !st.inside` 閘門交由外部控制器透過這個屬性關閉。
@export var enabled: bool = true

signal picked_up(msg: String, sfx_name: String)

var _collected: bool = false   ## 避免同一幀/同一次重疊被 body_entered 觸發兩次（保險，非原始碼行為）


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_refresh_visibility()


func _process(_delta: float) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	if _collected:
		return
	var shown: bool = is_shown(GameState.flags)
	visible = shown
	monitoring = shown
	monitorable = shown


## 純邏輯判定：showWhen 成立且尚未完成 once。跟 Node 脫鉤方便測試。
func is_shown(flags: Dictionary) -> bool:
	var done: bool = once_flag != "" and int(flags.get(once_flag, 0)) != 0
	return FlagMatcher.matches(flags, show_when) and not done


func _on_body_entered(body: Node) -> void:
	if _collected or not enabled or not body.is_in_group("player"):
		return
	if not is_shown(GameState.flags):
		return
	_collect()


func _collect() -> void:
	_collected = true
	if flag_name != "":
		if op == "inc":
			GameState.flag_inc(flag_name, 1)
		else:
			GameState.flag_set(flag_name, set_value)
	if once_flag != "":
		GameState.flag_set(once_flag, 1)
	if item_id != "":
		GameState.inv_add(item_id, 1)
	visible = false
	monitoring = false
	monitorable = false
	picked_up.emit(msg, sfx_name)
	# CORE-3 完成，SaveManager 已註冊為 autoload：撿取是自動存檔時機之一（見 D-7、
	# specs/SAVE_SCHEMA.md）。零參數呼叫沿用既有存檔的 scene/x/y，只更新旗標/道具欄位。
	SaveManager.save_game()
