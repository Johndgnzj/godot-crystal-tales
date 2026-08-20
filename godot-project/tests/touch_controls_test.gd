extends SceneTree
## TASKS/21 階段 1 的觸控控制器（autoload/touch_controls.gd）回歸測試。跑法：
##   /Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/touch_controls_test.gd --path <godot-project>
## exit code 0 = 全綠。
##
## 事件用 `tc._input(e)` 直接注入而非 `root.push_input()`：`-s` 腳本沒有 current_scene，viewport 不會
## 把事件派發到 autoload 的 _input（實機有場景時才會），那樣測到的是引擎派發而不是本控制器的邏輯。

var fails := 0
var tc: Node = null

func _ck(label: String, cond: bool) -> void:
	print(("  [OK]   " if cond else "  [FAIL] ") + label)
	if not cond:
		fails += 1

func _touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	e.index = index
	tc._input(e)

func _drag(pos: Vector2, index: int = 0) -> void:
	var e := InputEventScreenDrag.new()
	e.position = pos
	e.index = index
	tc._input(e)

func _initialize() -> void:
	_run()


func _run() -> void:
	print("=== TASKS/21 觸控控制器測試 ===")
	await process_frame
	create_timer(20.0).timeout.connect(func(): print("TIMEOUT GUARD"); quit(2))
	tc = root.get_node("/root/TouchControls")
	tc.set_enabled(true)
	await process_frame
	# 安全區：桌機／headless 沒有瀏海資訊 → 應退回整個可見矩形，佈局與先前一致（不能因為加了安全區
	# 處理就把桌機的搖桿往內縮）。
	var full := root.get_visible_rect()
	var safe: Rect2 = tc._safe_rect()
	_ck("無安全區資訊時退回整個可見矩形", safe == full)

	var stick: Vector2 = tc._stick_center
	print("搖桿中心 %s / viewport %s" % [stick, root.get_visible_rect().size])

	# 搖桿往右推 → move_right 持續按住、ui_right 該幀 just_pressed
	_touch(stick + Vector2(70, 0), true)
	_ck("推右：move_right held", Input.is_action_pressed("move_right"))
	_ck("推右：ui_right just_pressed（選單導航）", Input.is_action_just_pressed("ui_right"))
	_ck("推右：move_left 沒被按", not Input.is_action_pressed("move_left"))

	# 斜推右下 → 八方向：兩軸同時
	_drag(stick + Vector2(60, 60))
	_ck("斜推右下：move_right + move_down 同時 held",
		Input.is_action_pressed("move_right") and Input.is_action_pressed("move_down"))

	# 地圖情境（headless 無 current_scene，等同「不是游標式 UI」）：右下不該有按鈕，只有搖桿
	_ck("地圖情境：右下不顯示按鈕", not tc._buttons[0]["visible"])

	# 第二指按「取消」鈕（多指：搖桿仍握著）。headless 沒有戰鬥/選單場景可進，直接把按鈕點亮再測命中；
	# 顯示條件本身由上一項與 _sync_context() 負責。
	tc._buttons[0]["visible"] = true
	var cancel_btn: Vector2 = tc._buttons[0]["center"]
	_touch(cancel_btn, true, 1)
	_ck("多指：ui_cancel pressed", Input.is_action_pressed("ui_cancel"))
	_ck("多指：搖桿仍 held", Input.is_action_pressed("move_right"))
	_touch(cancel_btn, false, 1)
	_ck("放開取消鈕：ui_cancel released", not Input.is_action_pressed("ui_cancel"))

	# 手指離開 → 全部方向放開，且 ui_* 脈衝不再重複（headless 單幀 delta 很大，長按重複會立刻觸發，
	# 所以「脈衝只維持一幀」要在放開搖桿之後驗）
	_touch(stick + Vector2(60, 60), false)
	_ck("放開搖桿：move_* 全放開",
		not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_down"))
	await process_frame
	_ck("放開搖桿一幀後：ui_* 全放開",
		not Input.is_action_pressed("ui_right") and not Input.is_action_pressed("ui_down"))

	# 沒命中控制器的觸控不該被吃掉（畫面中央點擊仍要能推進對話）
	_touch(Vector2(640, 200), true)
	_ck("畫面中央觸控：不觸發任何 action",
		not Input.is_action_pressed("ui_cancel") and not Input.is_action_pressed("move_right"))
	_touch(Vector2(640, 200), false)

	# 關閉（PC 無觸控螢幕的預設狀態）→ 觸控事件無效
	tc.set_enabled(false)
	_touch(stick + Vector2(70, 0), true)
	_ck("關閉後：搖桿無反應", not Input.is_action_pressed("move_right"))
	_touch(stick + Vector2(70, 0), false)

	await _check_world_prompt()
	await _check_battle_clicks()
	await _check_shop_clicks()

	print("=== 觸控測試：%d 失敗 ===" % fails)
	quit(1 if fails > 0 else 0)


## 階段 2：世界互動提示（$HUD/Prompt 文字列 vs $HUD/PromptBtn 可點按鈕）依模式切換。
## 用真的 painted 場景實例化（同 world_harness_test 的做法），驗 production code path。
func _check_world_prompt() -> void:
	var gs: Node = root.get_node("/root/GameState")
	gs.set("party", [{"id": "ludo", "sprite": "ludo", "hp": 100, "maxhp": 100, "mp": 10, "maxmp": 10}])
	gs.set("flags", {})
	gs.set("spawn", "start")
	gs.set("result", "")
	gs.set("return_x", -1.0)
	gs.set("return_y", -1.0)

	var packed := ResourceLoader.load("res://scenes/world/painted/ef_a.tscn")
	if not (packed is PackedScene):
		_ck("世界場景 ef_a 載入", false)
		return
	var world: Node = (packed as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var label: Label = world.get_node("HUD/Prompt")
	var btn: Button = world.get_node("HUD/PromptBtn")

	tc.set_enabled(true)
	world._set_prompt_hint("調查")
	_ck("觸控：提示變成可點按鈕「調查」", btn.visible and btn.text == "調查")
	_ck("觸控：文字列讓位給按鈕", label.text == "")
	_ck("觸控：按鈕水平置中", absf(btn.position.x + btn.size.x * 0.5 - 640.0) < 2.0)
	_ck("觸控：按鈕高度達觸控目標尺寸", btn.size.y >= 44.0)
	world._set_prompt_hint("")
	_ck("離開互動範圍：按鈕收掉", not btn.visible)

	tc.set_enabled(false)
	world._set_prompt_hint("交談")
	_ck("鍵盤：顯示「空白鍵：交談」且無按鈕",
		label.text == "空白鍵：交談" and not btn.visible)

	root.remove_child(world)
	world.queue_free()


func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


## 階段 2：戰鬥的指令／技能／道具／目標都能直接點（鍵盤游標流程並存）。
func _check_battle_clicks() -> void:
	var gs: Node = root.get_node("/root/GameState")
	gs.set("party", [load("res://scripts/game_flow.gd").make_member("ludo")])
	gs.set("encounter", "forest")
	var packed := ResourceLoader.load("res://scenes/battle/battle.tscn")
	if not (packed is PackedScene):
		_ck("戰鬥場景載入", false)
		return
	var b: Node = (packed as PackedScene).instantiate()
	root.add_child(b)
	await process_frame

	_ck("戰鬥：指令格可點", b._cmd_labels[0].mouse_filter == Control.MOUSE_FILTER_STOP)
	_ck("戰鬥：技能列可點", b._skill_labels[0].mouse_filter == Control.MOUSE_FILTER_STOP)
	_ck("戰鬥：道具列可點", b._item_labels[0].mouse_filter == Control.MOUSE_FILTER_STOP)
	_ck("戰鬥：敵人立繪可點",
		(b._foe_nodes[0]["sprite"] as Control).mouse_filter == Control.MOUSE_FILTER_STOP)

	# 非指令階段誤觸不該有反應（Label 常駐畫面）
	b.state = "run"
	b._on_cmd_gui_input(_click(), 1)
	_ck("戰鬥：非指令階段點指令無效", b.state == "run")

	# 指令階段點「攻擊」→ 進選目標
	b.state = "menu"
	b.actor = b.heroes[0]
	b._on_cmd_gui_input(_click(), 0)
	_ck("戰鬥：點「攻擊」→ 選目標", b.state == "target")

	# 選目標階段點敵人立繪 → 直接出手（離開 target）
	var foe: Dictionary = b._foe_nodes[0]["unit"]
	b._on_unit_gui_input(_click(), foe)
	_ck("戰鬥：點敵人立繪即出手", b.state != "target")

	root.remove_child(b)
	b.queue_free()


## 階段 2：商店（CqMenuPanel 的文字列表）也能直接點——列可點、頁籤可點。
func _check_shop_clicks() -> void:
	var gs: Node = root.get_node("/root/GameState")
	gs.set("gold", 9999)
	var packed := ResourceLoader.load("res://scenes/ui/shop.tscn")
	if not (packed is PackedScene):
		_ck("商店場景載入", false)
		return
	var shop: Node = (packed as PackedScene).instantiate()
	root.add_child(shop)
	await process_frame
	shop.open_shop("gid")
	await process_frame   # _process 跑一輪 → _render → panel.render 掛上 click

	var panel: Node = shop.get_node("Panel")
	var row0: Label = panel._row_nodes[0]
	_ck("商店：商品列可點", row0.mouse_filter == Control.MOUSE_FILTER_STOP)
	_ck("商店：商品列命中框有寬高", row0.size.x > 100.0 and row0.size.y >= 26.0)

	shop._on_tab_clicked()
	_ck("商店：點頁籤切到販售", shop._tab == 1)
	shop._on_tab_clicked()

	var gold_before: int = gs.get("gold")
	panel._on_row_gui_input(_click(), 0)
	_ck("商店：點商品列即成交（金幣變動）", int(gs.get("gold")) != gold_before)

	root.remove_child(shop)
	shop.queue_free()
