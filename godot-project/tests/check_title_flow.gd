extends SceneTree

## headless：標題頁「新遊戲」→ 是否真的切到 Town（完整入口串接）。
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 400 -s res://tests/check_title_flow.gd --path .

var _fail := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	print("=== check_title_flow ===")
	var gs: Node = root.get_node("/root/GameState")
	var title: Node = load("res://scenes/title/title.tscn").instantiate()
	root.add_child(title)
	await process_frame        # title._ready → _render()
	var menu: Label = title.get_node_or_null("Menu")
	_expect(menu != null and menu.text.contains("新遊戲"), "標題選單有渲染（新遊戲）")

	title._confirm()           # _sel=0 → 新遊戲 → GameFlow.new_game() + go_to("Town","home")
	for i in 12:
		await process_frame    # 等 change_scene_to_file 非同步切場景 + Town _ready

	var cur: Node = current_scene
	_expect(cur != null and cur.name == "Town", "已切到 Town（current_scene=%s）" % (cur.name if cur else "<null>"))
	_expect(gs.party.size() == 2, "進城後隊伍就緒")
	if cur != null:
		var player: Node = cur.get_node_or_null("YSort/Player")
		_expect(player != null and player.global_position != Vector2.ZERO,
			"Town 玩家已定位（pos=%s）" % (player.global_position if player else "N/A"))

	print("=== TITLE_FLOW %s ===" % ("OK" if _fail == 0 else "FAIL（%d）" % _fail))
	quit(0 if _fail == 0 else 1)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK]   " + msg)
	else:
		_fail += 1
		print("  [FAIL] " + msg)
