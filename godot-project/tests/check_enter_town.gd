extends SceneTree

## headless：新遊戲 → 進 Town，把世界場景 _ready/_physics_process 的 runtime bug 逼出來。
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --quit-after 300 -s res://tests/check_enter_town.gd --path .

var _fail := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	print("=== check_enter_town ===")
	var gs: Node = root.get_node("/root/GameState")
	load("res://scripts/game_flow.gd").new_game()
	_expect(gs.party.size() == 2, "新遊戲隊伍就緒")

	var packed: PackedScene = load("res://scenes/world/town.tscn")
	if packed == null:
		print("  [FAIL] town.tscn 載入失敗"); _finish(); return
	var town: Node = packed.instantiate()
	if town == null:
		print("  [FAIL] town 實例化回 null"); _finish(); return
	root.add_child(town)          # 觸發 world_scene._ready()
	for i in 8:
		await process_frame       # 跑幾幀讓 _ready + _physics_process 執行

	var player: Node = town.get_node_or_null("YSort/Player")
	_expect(player != null, "玩家節點 YSort/Player 存在")
	if player != null:
		var pos: Vector2 = player.global_position
		_expect(pos != Vector2.ZERO, "玩家有被定位到出生點（pos=%s）" % pos)
	var tml := town.get_node_or_null("Ground")
	if tml == null:
		# TileMapLayer 名稱可能不同，找第一個 TileMapLayer
		for c in town.get_children():
			if c is TileMapLayer:
				tml = c; break
	if tml != null and tml is TileMapLayer:
		var cells: int = (tml as TileMapLayer).get_used_cells().size()
		_expect(cells > 0, "地圖有圖磚（used_cells=%d）" % cells)
	else:
		print("  [??]   找不到 TileMapLayer（名稱非 Ground？）")

	town.queue_free()
	_finish()


func _finish() -> void:
	print("=== ENTER_TOWN %s ===" % ("OK" if _fail == 0 else "FAIL（%d）" % _fail))
	quit(0 if _fail == 0 else 1)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK]   " + msg)
	else:
		_fail += 1
		print("  [FAIL] " + msg)
