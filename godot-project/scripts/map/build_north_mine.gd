extends SceneTree
## 建構 M2 北方礦山 a～f 手繪畫面地圖：背景、32px 碰撞格、出生點與場景出口。
## 執行：Godot --headless -s res://scripts/map/build_north_mine.gd --path .

const CELL := 32
const N := 40
const SIZE := 1280.0
const TILESET := "res://resources/map/collision_tileset_32.tres"
const PC := "res://scripts/world/player_controller.gd"
const EZ := "res://scripts/world/exit_zone.gd"
const WORLD_SCENE := "res://scripts/world/world_scene.gd"

const SCREENS := {
	"a": {"E": "b", "S": "Town"},
	"b": {"W": "a", "E": "c", "N": "d"},
	"c": {"W": "b", "N": "e"},
	"d": {"S": "b", "E": "e"},
	"e": {"W": "d", "E": "f", "S": "c"},
	"f": {"W": "e"},
}
const OPP := {"W": "E", "E": "W", "N": "S", "S": "N"}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var spawns_of: Dictionary = {}
	for key: String in SCREENS:
		spawns_of[key] = {"start": Vector2(SIZE / 2.0, SIZE / 2.0)}
	for key: String in SCREENS:
		for edge: String in SCREENS[key]:
			var target: String = SCREENS[key][edge]
			if SCREENS.has(target):
				spawns_of[target]["from_%s" % key] = _edge_spawn(OPP[edge])
	# a↔b 的東側接口是嵌在岩壁的向上洞口，不在畫布右邊界。
	spawns_of["a"]["from_b"] = Vector2(1080, 720)
	# b 的西向連線在美術上改為左下方「由下往上」的入口。
	spawns_of["b"]["from_a"] = Vector2(150, 1120)
	spawns_of["a"]["from_Town"] = _edge_spawn("S")

	for key: String in SCREENS:
		_build_screen(key, spawns_of[key])
	quit(0)


func _build_screen(key: String, spawns: Dictionary) -> void:
	var root := Node2D.new()
	root.name = _scene_key(key)
	root.set_script(load(WORLD_SCENE))
	root.set("scene_id", _scene_key(key))
	root.set("map_w", N)
	root.set("map_h", N)
	root.set("spawns", spawns)
	root.set("camera_zoom", 1.0)

	var bg := Sprite2D.new()
	bg.name = "Background"
	bg.centered = false
	bg.texture = load("res://assets/map/north_mine/nm_%s.png" % key)
	root.add_child(bg)
	bg.owner = root

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	root.add_child(ground)
	ground.owner = root

	var collision := TileMapLayer.new()
	collision.name = "CollisionPaint"
	collision.tile_set = load(TILESET)
	_paint_collision(collision, key)
	root.add_child(collision)
	collision.owner = root

	var zones := Node2D.new()
	zones.name = "Zones"
	root.add_child(zones)
	zones.owner = root
	for edge: String in SCREENS[key]:
		var target: String = SCREENS[key][edge]
		var area := Area2D.new()
		area.name = "Exit%s" % edge
		area.set_script(load(EZ))
		if key == "a" and edge == "E":
			area.position = Vector2(1080, 625)
		elif key == "b" and edge == "W":
			area.position = Vector2(150, SIZE - 22)
		else:
			area.position = _exit_pos(edge)
		if SCREENS.has(target):
			area.set("to_scene", _scene_key(target))
			area.set("spawn_id", "from_%s" % key)
		else:
			area.set("to_scene", target)
			area.set("spawn_id", "fromMine")
		zones.add_child(area)
		area.owner = root
		var shape := CollisionShape2D.new()
		shape.name = "Shape"
		var rect := RectangleShape2D.new()
		if (key == "a" and edge == "E") or (key == "b" and edge == "W"):
			rect.size = Vector2(128, 44)
		else:
			rect.size = Vector2(44, 160) if edge in ["W", "E"] else Vector2(160, 44)
		shape.shape = rect
		area.add_child(shape)
		shape.owner = root

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
	var player_shape := CollisionShape2D.new()
	player_shape.name = "Shape"
	player_shape.position = Vector2(0, -1)
	var player_rect := RectangleShape2D.new()
	player_rect.size = Vector2(22, 14)
	player_shape.shape = player_rect
	player.add_child(player_shape)
	player_shape.owner = root
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	player.add_child(camera)
	camera.owner = root

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, "res://scenes/world/painted/nm_%s.tscn" % key)
	print("nm_%s: exits=%s collision=%d err=%s" % [
		key, SCREENS[key].keys(), collision.get_used_cells().size(), err])
	root.free()


func _paint_collision(layer: TileMapLayer, key: String) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(
		"res://assets/map/north_mine/nm_%s.png" % key))
	for y in N:
		for x in N:
			if not _is_walkable(image, x, y):
				layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	# 深色隧道口、木框與陰影容易被自動判定成牆；已設定的出口固定清出 4 格寬走廊。
	for edge: String in SCREENS[key]:
		if key == "a" and edge == "E":
			_carve_a_east_tunnel(layer)
		elif key == "b" and edge == "W":
			_carve_b_lower_left_entrance(layer)
		else:
			_carve_exit(layer, edge)
	# a 的北側通往 M6，該地區尚未實作；先封住畫面邊界避免玩家離開地圖。
	if key == "a":
		for x in range(15, 25):
			layer.set_cell(Vector2i(x, 0), 0, Vector2i(0, 0))


func _carve_exit(layer: TileMapLayer, edge: String) -> void:
	match edge:
		"W":
			for y in range(18, 22):
				for x in range(0, 12):
					layer.erase_cell(Vector2i(x, y))
		"E":
			for y in range(18, 22):
				for x in range(N - 12, N):
					layer.erase_cell(Vector2i(x, y))
		"N":
			for y in range(0, 12):
				for x in range(18, 22):
					layer.erase_cell(Vector2i(x, y))
		"S":
			for y in range(N - 12, N):
				for x in range(18, 22):
					layer.erase_cell(Vector2i(x, y))


func _carve_a_east_tunnel(layer: TileMapLayer) -> void:
	# 洞口朝上：只清掉洞口與下方接近路徑，保留右側畫布邊界岩壁。
	for y in range(18, 24):
		for x in range(32, 36):
			layer.erase_cell(Vector2i(x, y))


func _carve_b_lower_left_entrance(layer: TileMapLayer) -> void:
	for y in range(28, N):
		for x in range(3, 7):
			layer.erase_cell(Vector2i(x, y))


func _is_walkable(image: Image, cx: int, cy: int) -> bool:
	var sum := Vector3.ZERO
	var samples := 0
	for py in range(cy * CELL + 7, cy * CELL + 25, 3):
		for px in range(cx * CELL + 7, cx * CELL + 25, 3):
			var color := image.get_pixel(px, py)
			sum += Vector3(color.r8, color.g8, color.b8)
			samples += 1
	var avg := sum / float(samples)
	var value: float = maxf(avg.x, maxf(avg.y, avg.z))
	return value >= 72.0 and avg.x - avg.z >= 12.0 and avg.y >= avg.z + 4.0


func _scene_key(key: String) -> String:
	return "NM" + key.to_upper()


func _edge_spawn(edge: String) -> Vector2:
	match edge:
		"W": return Vector2(104, SIZE / 2.0)
		"E": return Vector2(SIZE - 104, SIZE / 2.0)
		"N": return Vector2(SIZE / 2.0, 104)
		_: return Vector2(SIZE / 2.0, SIZE - 104)


func _exit_pos(edge: String) -> Vector2:
	match edge:
		"W": return Vector2(22, SIZE / 2.0)
		"E": return Vector2(SIZE - 22, SIZE / 2.0)
		"N": return Vector2(SIZE / 2.0, 22)
		_: return Vector2(SIZE / 2.0, SIZE - 22)
