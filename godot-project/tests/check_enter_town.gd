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
	var flow: GDScript = load("res://scripts/game_flow.gd")   # runtime load：autoload 註冊後才編譯
	flow.new_game()
	# 2026-08-19：第一章重構後開場只有路德（亞倫小節3 guest 入隊、瑪琳小節4 入隊，見 TASKS/13 附錄A）；
	# 對 flow.START_PARTY.size() 斷言，之後起始隊伍再改也不用回頭修這裡。
	_expect(gs.party.size() == flow.START_PARTY.size(),
		"新遊戲隊伍就緒（%d 人，期望 %d）" % [gs.party.size(), flow.START_PARTY.size()])

	# 2026-08-19：改讀 SceneRouter 對照表的 Town（＝手繪版 painted/town.tscn）。
	# 先前寫死 res://scenes/world/town.tscn＝已封存的舊 tile 版，等於一直在測不是遊戲在跑的那張。
	var town_path: String = SceneRouter.SCENE_PATHS.get("Town", "")
	var packed: PackedScene = load(town_path) if town_path != "" else null
	if packed == null:
		print("  [FAIL] Town 場景載入失敗（path=%s）" % town_path); _finish(); return
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
	# 手繪地圖沒有圖磚（Ground 是空層、畫面來自 Background 貼圖），改驗這兩樣：
	var bg := town.get_node_or_null("Background") as Sprite2D
	_expect(bg != null and bg.texture != null, "Background 有手繪底圖")
	var col := town.get_node_or_null("CollisionPaint") as TileMapLayer
	var walls: int = col.get_used_cells().size() if col != null else -1
	_expect(walls > 0, "碰撞層已導出（CollisionPaint=%d 格）" % walls)

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
