extends CanvasLayer
## touch_controls.gd — autoload（註冊名稱 "TouchControls"，見 ../project.godot [autoload]）。
##
## TASKS/21 階段 1：螢幕虛擬控制器（左下搖桿＋右下按鈕），讓同一份專案在手機／平板上可玩，而**遊戲
## 邏輯零改動**——沿用 CORE-6 `autoload/input_bridge.gd` 已定好的設計：觸控 UI 呼叫
## `simulate_action_press()`/`simulate_action_release()` 把輸入灌回同一組 InputMap action，因此
## `InputBridge.is_action_held()`（世界移動）與 `is_action_hit()`（選單／戰鬥游標）對觸控自然生效。
##
## ## 設計決定
## - **自繪不用美術素材**：`_draw` 畫圓＋文字，避免為觸控 UI 另跑一輪產圖驗收流程（見 CLAUDE.md）。
## - **直接處理 `InputEventScreenTouch`/`ScreenDrag` 並追蹤 `event.index`**，不靠 Godot 的
##   `emulate_mouse_from_touch`（那只轉第一根手指），否則「按著搖桿走路的同時按決定」會失效。
## - **autoload 而非各場景掛載**：autoload 節點排在場景樹最前面，`_process` 早於場景節點執行，
##   下面 `ui_*` 脈衝的 press／release 才能保證落在場景讀取 `is_action_just_pressed()` 之前
##   （`just_pressed` 只在按下的那一幀為真，時序反了就會漏輸入）。同時一處掛載即覆蓋
##   世界／戰鬥／選單／標題所有場景。
## - **搖桿同時灌 `move_*` 與 `ui_*`**：世界移動要「持續按住」（`move_*` 維持 pressed，方向變才切換），
##   游標式選單要「邊緣觸發」（`ui_*` 按一幀就放，長按後以固定間隔重複），兩者是不同 action 故不衝突。
## - **選單開關不另設按鈕**：HUD 右上角 `MenuBtn`（hud.tscn TextureButton）與選單內 `✕` 觸控本來就能點。

const STICK_R := 92.0          # 基座半徑（1280×720 base 座標，canvas_items 會等比縮放到實際視窗）
const KNOB_R := 40.0
const STICK_GRAB := 1.6        # 命中判定放寬倍率（手指不用精準壓在基座上）
const DEAD := 0.32             # 死區（相對半徑）
const AXIS := 0.38             # 分量門檻 → 該方向的 move_* 視為按下（八方向由兩軸組合而成）
const UI_REPEAT_DELAY := 0.40  # 長按後開始重複的等待
const UI_REPEAT_RATE := 0.16

const MOVE_ACTIONS := {"up": "move_up", "down": "move_down", "left": "move_left", "right": "move_right"}
const UI_ACTIONS := {"up": "ui_up", "down": "ui_down", "left": "ui_left", "right": "ui_right"}

var _ui: Control
var _font: Font
var _buttons: Array[Dictionary] = []
var _stick_center := Vector2.ZERO

var _touches := {}             # touch index -> "stick" 或 action 名稱（支援多指）
var _stick_vec := Vector2.ZERO # 相對基座的正規化位移（長度 0~1）
var _held := {}                # move_* action -> 目前是否已 press（只在變化時呼叫 InputBridge）
var _ui_dir := ""              # 搖桿目前的主方向（"" = 回中）
var _ui_timer := 0.0
var _ui_pulse := ""            # 上一幀 press 的 ui_* action，本幀開頭要放開
var _stick_visible := true


func _ready() -> void:
	layer = 20  # 高於既有最高的 dialogue_box（layer 12）
	_ui = Control.new()
	_ui.name = "Overlay"
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = load("res://resources/ui_theme.tres")  # 取 CJK 字型，按鈕文字才不會是豆腐
	_ui.draw.connect(_on_draw)
	_ui.resized.connect(_layout)
	add_child(_ui)
	_font = _ui.get_theme_default_font()
	_layout()
	set_enabled(DisplayServer.is_touchscreen_available() or _forced_by_cmdline())


## PC 上用 `godot --path godot-project -- --touch`（或 `--touch` 直接接在後面）強制顯示，方便不拿手機也能除錯。
func _forced_by_cmdline() -> bool:
	return "--touch" in OS.get_cmdline_user_args() or "--touch" in OS.get_cmdline_args()


## 對外開關（之後系統設定頁若要讓玩家手動開關觸控介面，呼叫這個）。
func set_enabled(on: bool) -> void:
	visible = on
	set_process(on)
	if not on:
		_release_all()


## 其他 UI 問「現在是不是觸控模式」（例：世界提示要寫「空白鍵：調查」還是顯示可點的「調查」按鈕）。
func is_active() -> bool:
	return visible


## 佈局基準是**安全區**（見 `_safe_rect()`）而不是整個畫面：手機的瀏海／圓角／小白條會切掉邊緣，
## 搖桿與取消鈕又剛好貼在左右下角。也不用 `_ui.size`——`_ready()` 當幀 Control 的 size 還可能是 0，
## 會把控制器排到畫面外。
func _layout() -> void:
	var r := _safe_rect()
	var s := r.end   # 安全區右下角（base 座標）
	_stick_center = Vector2(r.position.x + 180.0, s.y - 150.0)
	# 階段 2 完成後只剩一顆：標題／世界提示／戰鬥／選單／商店／室內的選項全部可點，`決定` 不再需要；
	# 但「返回上一層」（戰鬥的技能→指令、選單的深層 focus、離開商店）沒有畫面內的對應物，故留 `取消`。
	_buttons = [
		{"action": "ui_cancel", "label": "取消", "center": Vector2(s.x - 132.0, s.y - 150.0), "r": 54.0, "visible": false},
	]
	_ui.queue_redraw()


## 安全區（`1280×720` base 座標）。`DisplayServer.get_display_safe_area()` 回的是**實際視窗像素**，
## 這裡用 window 的 final transform 反轉回 base 座標——canvas_items stretch＋`aspect=keep` 會縮放並
## 置中（20:9 手機左右留黑邊），直接把像素值當 UI 座標會錯位。桌機／平台沒回報安全區時退回整個可見矩形。
func _safe_rect() -> Rect2:
	var full := get_viewport().get_visible_rect()
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return full
	if safe.position == Vector2i.ZERO and safe.size == win:
		return full
	var inv := get_window().get_final_transform().affine_inverse()
	var a: Vector2 = inv * Vector2(safe.position)
	var b: Vector2 = inv * Vector2(safe.position + safe.size)
	var rect := Rect2(a, b - a).intersection(full)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return full
	return rect


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var target := _hit(event.position)
			if target == "":
				return
			_touches[event.index] = target
			if target == "stick":
				_update_stick(event.position)
			else:
				InputBridge.simulate_action_press(target)
			_consume()
		elif _touches.has(event.index):
			var target: String = _touches[event.index]
			_touches.erase(event.index)
			if target == "stick":
				_update_stick(_stick_center)  # 回中：放開所有方向
			else:
				InputBridge.simulate_action_release(target)
			_consume()
	elif event is InputEventScreenDrag and _touches.get(event.index, "") == "stick":
		_update_stick(event.position)
		_consume()


## 吃掉這次觸控，否則同一下點擊會再被 dialogue_box.gd 的 _unhandled_input 當成「點畫面推進對話」。
func _consume() -> void:
	_ui.queue_redraw()
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _hit(pos: Vector2) -> String:
	for b in _buttons:
		if b["visible"] and pos.distance_to(b["center"]) <= b["r"] * 1.15:
			return b["action"]
	if _stick_visible and pos.distance_to(_stick_center) <= STICK_R * STICK_GRAB:
		return "stick"
	return ""


func _update_stick(pos: Vector2) -> void:
	_stick_vec = ((pos - _stick_center) / STICK_R).limit_length(1.0)
	var v := _stick_vec
	var dead := v.length() < DEAD
	_set_held(MOVE_ACTIONS["left"], not dead and v.x < -AXIS)
	_set_held(MOVE_ACTIONS["right"], not dead and v.x > AXIS)
	_set_held(MOVE_ACTIONS["up"], not dead and v.y < -AXIS)
	_set_held(MOVE_ACTIONS["down"], not dead and v.y > AXIS)
	var dir := ""
	if not dead:
		if absf(v.x) > absf(v.y):
			dir = "right" if v.x > 0.0 else "left"
		else:
			dir = "down" if v.y > 0.0 else "up"
	if dir != _ui_dir:
		_ui_dir = dir
		_ui_timer = UI_REPEAT_DELAY
		if dir == "":
			_flush_pulse()   # 手指回中：立刻放開，不留殘留的 ui_* pressed
		else:
			_pulse_ui(dir)   # 推進新方向 → 選單游標立刻移一格


func _set_held(action: String, on: bool) -> void:
	if _held.get(action, false) == on:
		return
	_held[action] = on
	if on:
		InputBridge.simulate_action_press(action)
	else:
		InputBridge.simulate_action_release(action)


## ui_* 是邊緣觸發（選單/戰鬥用 is_action_just_pressed 讀），只能按一幀就放；autoload 的 _process
## 早於場景節點，故「本幀開頭放開上一幀的脈衝」不會讓場景漏讀。
## **先 `_flush_pulse()` 再按新方向**：否則切換方向時 `_ui_pulse` 被覆寫，舊方向的 action 永遠沒放開，
## 會卡在 pressed（該方向之後再也觸發不了 just_pressed）。
func _pulse_ui(dir: String) -> void:
	_flush_pulse()
	_ui_pulse = UI_ACTIONS[dir]
	InputBridge.simulate_action_press(_ui_pulse)


func _flush_pulse() -> void:
	if _ui_pulse != "":
		InputBridge.simulate_action_release(_ui_pulse)
		_ui_pulse = ""


func _process(delta: float) -> void:
	_flush_pulse()
	if _ui_dir != "":
		_ui_timer -= delta
		if _ui_timer <= 0.0:
			_ui_timer = UI_REPEAT_RATE
			_pulse_ui(_ui_dir)
	_sync_context()


## 依「現在在玩什麼」決定要顯示什麼（John 2026-08-19 定案：**地圖移動只要搖桿**，其餘互動走
## 「畫面上的東西直接點」）：
## - 搖桿：只在「能走路」時出現——世界地圖且沒有對話／過場、沒開選單商店室內、不在標題或戰鬥。
##   對話中特別重要：搖桿會吃掉左下角的觸控，留著就點不動那一塊來推進對話。
## - `取消`：疊層 UI（選單／商店／室內）與戰鬥要（返回上一層／離開）。
func _sync_context() -> void:
	var cs := get_tree().current_scene
	var path := "" if cs == null else cs.scene_file_path
	var in_battle := path.contains("/scenes/battle/")
	var in_title := path.contains("/scenes/title/")
	var overlay := _overlay_ui_open()
	var changed := false
	var want_stick := not in_title and not in_battle and not overlay and not DialogueSystem.is_busy()
	if _stick_visible != want_stick:
		_stick_visible = want_stick
		if not want_stick:
			_release_stick_state()
		changed = true
	var want_btn := overlay or in_battle
	for b in _buttons:
		if b["visible"] != want_btn:
			b["visible"] = want_btn
			changed = true
	if changed:
		_ui.queue_redraw()


## 搖桿被藏起來時把方向 action 歸零，免得「藏起來還一直往右走」。
func _release_stick_state() -> void:
	for index in _touches.keys():
		if _touches[index] == "stick":
			_touches.erase(index)
	_update_stick(_stick_center)


## 選單／商店／室內立繪是疊在世界場景上的 CanvasLayer（current_scene 仍是世界），只能問它們自己。
func _overlay_ui_open() -> bool:
	for g in ["cq_menu", "cq_shop", "cq_interior"]:
		var n := get_tree().get_first_node_in_group(g)
		if n != null and n.has_method("is_open") and n.is_open():
			return true
	return false


func _release_all() -> void:
	for action in _held.keys():
		if _held[action]:
			InputBridge.simulate_action_release(action)
	_held.clear()
	for target in _touches.values():
		if target != "stick":
			InputBridge.simulate_action_release(target)
	_touches.clear()
	_flush_pulse()
	_stick_vec = Vector2.ZERO
	_ui_dir = ""


func _on_draw() -> void:
	var base := Color(1, 1, 1, 0.10)
	var line := Color(1, 1, 1, 0.28)
	if _stick_visible:
		_ui.draw_circle(_stick_center, STICK_R, base)
		_ui.draw_arc(_stick_center, STICK_R, 0.0, TAU, 48, line, 3.0, true)
		var knob := _stick_center + _stick_vec * (STICK_R - KNOB_R)
		_ui.draw_circle(knob, KNOB_R, Color(1, 1, 1, 0.22))
		_ui.draw_arc(knob, KNOB_R, 0.0, TAU, 32, line, 2.0, true)
	var pressed := _touches.values()
	for b in _buttons:
		if not b["visible"]:
			continue
		var on: bool = b["action"] in pressed
		var center: Vector2 = b["center"]
		var radius: float = b["r"]
		_ui.draw_circle(center, radius, Color(1, 1, 1, 0.22) if on else base)
		_ui.draw_arc(center, radius, 0.0, TAU, 40, line, 3.0, true)
		if _font != null:
			var text: String = b["label"]
			var size := 20
			var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
			var at := center + Vector2(-w * 0.5, size * 0.36)
			_ui.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(1, 1, 1, 0.75))
