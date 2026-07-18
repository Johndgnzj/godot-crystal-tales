extends SceneTree
## 批次建構：M3 東邊森林 9 張手繪畫面場景（ef_a 已存在→只補出口/落點；b–i 全新建）。
## 依 assets-source/map/map-def.xlsx 的空間網格接連通：
##          i
##          h
##  M1 a e b g (M4)
##      f c
##        d(boss)
## 每個連通邊：本圖該邊放「整邊出口帶」Area2D（to=對面、spawn=from_本圖），對面圖建 from_本圖 落點。
## CollisionPaint 只預刷「圖外深灰背景」（/tmp/ef_bg_cells.json，Python 產）；圖內留白由 John 手刷。
## 執行：Godot --headless -s res://scripts/map/build_painted_region.gd --path .

const CELL := 38
const N := 33
const SIZE := 1254.0
const BG_JSON := "/tmp/ef_bg_cells.json"
const TILESET := "res://resources/map/collision_tileset.tres"
const PC := "res://scripts/world/player_controller.gd"
const EZ := "res://scripts/world/exit_zone.gd"
const PSC := "res://scripts/world/painted_screen.gd"
const PLAYER_TEX := "res://assets/char/alan_Down_0.png"

## key: 畫面 id；exits: 邊(W/E/N/S) -> 目標（小寫=本 region 畫面；其他=既有場景名）
const SCREENS := {
	"a": {"W": "Town", "E": "e"},
	"b": {"W": "e", "E": "g", "N": "h", "S": "c"},
	"c": {"N": "b", "S": "d"},
	"d": {"N": "c"},
	"e": {"W": "a", "E": "b", "S": "f"},
	"f": {"N": "e"},
	"g": {"W": "b"},
	"h": {"S": "b", "N": "i"},
	"i": {"S": "h"},
}
const OPP := {"W": "E", "E": "W", "N": "S", "S": "N"}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var txt := FileAccess.get_file_as_string(BG_JSON)
	if txt == "":
		push_error("讀不到 " + BG_JSON + "（先跑 Python 產背景遮罩）")
		quit(1)
		return
	var bg_cells: Dictionary = JSON.parse_string(txt)

	# 收集每張圖需要的落點：來自「鄰居指向我」的邊
	var spawns_of: Dictionary = {}
	for k: String in SCREENS:
		spawns_of[k] = {"start": Vector2(SIZE / 2, SIZE / 2 + 100)}
	for k: String in SCREENS:
		for edge: String in SCREENS[k]:
			var to: String = SCREENS[k][edge]
			if SCREENS.has(to):   # 對面圖建 from_<k> 落點，在其相對邊內側
				spawns_of[to]["from_%s" % k] = _edge_spawn(OPP[edge])
	# a 保留原有慣例落點（從 Town 進來）
	spawns_of["a"]["from_Town"] = _edge_spawn("W")
	spawns_of["a"]["fromForest"] = _edge_spawn("W")

	for k: String in SCREENS:
		_build_screen(k, spawns_of[k], bg_cells.get(k, []))

	print("\n-- 要接的線（SCENE_PATHS / smoke 由本次任務直接套用）--")
	print("Town 若要直接接手繪森林：把某出口 to_scene 設 \"EFA\"、spawn_id \"from_Town\"")
	print("g 東=M4、i 北=M2 未做，未放出口")
	quit(0)


func _edge_spawn(edge: String) -> Vector2:
	match edge:
		"W": return Vector2(100, SIZE / 2)
		"E": return Vector2(SIZE - 100, SIZE / 2)
		"N": return Vector2(SIZE / 2, 100)
		_: return Vector2(SIZE / 2, SIZE - 100)


func _scene_key(id: String) -> String:
	return "EF" + id.to_upper()


func _build_screen(k: String, spawns: Dictionary, bg: Array) -> void:
	var root := Node2D.new()
	root.name = _scene_key(k)
	root.set_script(load(PSC))
	root.set("scene_id", _scene_key(k))
	root.set("spawns", spawns)
	root.set("default_spawn", "start")
	root.set("camera_zoom", 1.0)

	var bgs := Sprite2D.new()
	bgs.name = "Background"
	bgs.centered = false
	bgs.texture = load("res://assets/map/east_forest/ef_%s.png" % k)
	root.add_child(bgs)
	bgs.owner = root

	var col := TileMapLayer.new()
	col.name = "CollisionPaint"
	col.tile_set = load(TILESET)
	root.add_child(col)
	col.owner = root
	if k == "a":
		# a 已由先前試作刷過完整一版：沿用舊場景的刷格
		var old := load("res://scenes/world/painted/ef_a.tscn") as PackedScene
		if old != null:
			var oi := old.instantiate()
			var ocol := oi.get_node_or_null("CollisionPaint") as TileMapLayer
			if ocol != null:
				for c in ocol.get_used_cells():
					col.set_cell(c, 0, Vector2i(0, 0))
			oi.free()
	else:
		for c in bg:   # 只預刷圖外深灰背景
			col.set_cell(Vector2i(int(c[0]), int(c[1])), 0, Vector2i(0, 0))

	var zones := Node2D.new()
	zones.name = "Zones"
	root.add_child(zones)
	zones.owner = root
	for edge: String in SCREENS[k]:
		var to: String = SCREENS[k][edge]
		var area := Area2D.new()
		area.name = "Exit%s" % edge
		area.set_script(load(EZ))
		area.position = _exit_pos(edge)
		if SCREENS.has(to):
			area.set("to_scene", _scene_key(to))
			area.set("spawn_id", "from_%s" % k)
		else:   # 既有場景（Town）
			area.set("to_scene", to)
			area.set("spawn_id", "fromForest")
		zones.add_child(area)
		area.owner = root
		var sh := CollisionShape2D.new()
		sh.name = "Shape"
		var r := RectangleShape2D.new()
		r.size = Vector2(44, 1100) if edge in ["W", "E"] else Vector2(1100, 44)
		sh.shape = r
		area.add_child(sh)
		sh.owner = root

	var ysort := Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	root.add_child(ysort)
	ysort.owner = root
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.set_script(load(PC))
	player.add_to_group("player", true)
	player.position = spawns["start"]
	ysort.add_child(player)
	player.owner = root
	var pspr := Sprite2D.new()
	pspr.name = "Sprite"
	pspr.texture = load(PLAYER_TEX)
	pspr.position = Vector2(0, -22)
	player.add_child(pspr)
	pspr.owner = root
	var pshape := CollisionShape2D.new()
	pshape.name = "Shape"
	pshape.position = Vector2(0, -1)
	var pr := RectangleShape2D.new()
	pr.size = Vector2(22, 14)
	pshape.shape = pr
	player.add_child(pshape)
	pshape.owner = root
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	player.add_child(cam)
	cam.owner = root

	DirAccess.make_dir_recursive_absolute("res://scenes/world/painted/")
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, "res://scenes/world/painted/ef_%s.tscn" % k)
	print("  ef_%s.tscn 出口=%s 預刷=%d err=%s" % [k, SCREENS[k].keys(), col.get_used_cells().size(), err])
	root.free()


func _exit_pos(edge: String) -> Vector2:
	match edge:
		"W": return Vector2(22, SIZE / 2)
		"E": return Vector2(SIZE - 22, SIZE / 2)
		"N": return Vector2(SIZE / 2, 22)
		_: return Vector2(SIZE / 2, SIZE - 22)
