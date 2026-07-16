extends SceneTree
## 試作建構器：組出「手繪畫面地圖」原型——
##   resources/map/collision_tileset.tres  一格實心碰撞磚（physics layer + 半透明紅，供編輯器筆刷刷牆）
##   scenes/world/painted/ef_a.tscn         背景圖 + CollisionPaint 層(預刷外圍牆) + 玩家 + 左側出口→Town
## 執行：Godot --headless -s res://scripts/map/build_painted_screen.gd --path .
## 用 _initialize()+await：因為要 load player_controller.gd（引用 InputBridge autoload）。

const CELL := 38          # 1254 / 38 = 33 格，整除
const N := 33
const BG := "res://assets/map/east_forest/ef_a.png"
const CELL_TEX := "res://assets/map/_collision_cell.png"
const TILESET_OUT := "res://resources/map/collision_tileset.tres"
const SCENE_OUT := "res://scenes/world/painted/ef_a.tscn"
const PC := "res://scripts/world/player_controller.gd"
const EZ := "res://scripts/world/exit_zone.gd"
const PS := "res://scripts/world/painted_screen.gd"
const PLAYER_TEX := "res://assets/char/aaron_Down_0.png"


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_build_tileset()
	_build_scene()
	quit(0)


func _build_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL, CELL)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = load(CELL_TEX)
	src.texture_region_size = Vector2i(CELL, CELL)
	ts.add_source(src, 0)          # 先掛進 TileSet，tile 才會繼承 physics layer
	src.create_tile(Vector2i(0, 0))
	var td := src.get_tile_data(Vector2i(0, 0), 0)
	td.add_collision_polygon(0)
	var h := CELL / 2.0
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	DirAccess.make_dir_recursive_absolute("res://resources/map/")
	var err := ResourceSaver.save(ts, TILESET_OUT)
	print("build_painted: tileset err=%s" % err)


func _build_scene() -> void:
	var root := Node2D.new()
	root.name = "EFA"
	root.set_script(load(PS))
	root.set("scene_id", "EFA")
	root.set("spawns", {"start": Vector2(627, 900), "fromForest": Vector2(627, 900), "from_Town": Vector2(120, 610)})
	root.set("camera_zoom", 1.0)

	var bg := Sprite2D.new()
	bg.name = "Background"
	bg.centered = false
	bg.position = Vector2.ZERO
	bg.texture = load(BG)
	root.add_child(bg)
	bg.owner = root

	var col := TileMapLayer.new()
	col.name = "CollisionPaint"
	col.tile_set = load(TILESET_OUT)
	root.add_child(col)
	col.owner = root
	# 預刷外圍牆（示範碰撞立即可用）；在三個箭頭處留缺口讓玩家走出去
	for cx in N:
		if cx < 15 or cx > 18:                       # 上方箭頭缺口
			col.set_cell(Vector2i(cx, 0), 0, Vector2i(0, 0))
		col.set_cell(Vector2i(cx, N - 1), 0, Vector2i(0, 0))   # 下方整排
	for cy in N:
		if cy < 14 or cy > 18:                        # 左右箭頭缺口
			col.set_cell(Vector2i(0, cy), 0, Vector2i(0, 0))
			col.set_cell(Vector2i(N - 1, cy), 0, Vector2i(0, 0))

	var zones := Node2D.new()
	zones.name = "Zones"
	root.add_child(zones)
	zones.owner = root
	var exit := Area2D.new()
	exit.name = "ExitLeft"
	exit.set_script(load(EZ))
	exit.position = Vector2(24, 608)
	exit.set("to_scene", "Town")
	exit.set("spawn_id", "fromForest")
	zones.add_child(exit)
	exit.owner = root
	var esh := CollisionShape2D.new()
	esh.name = "Shape"
	var er := RectangleShape2D.new()
	er.size = Vector2(60, 200)
	esh.shape = er
	exit.add_child(esh)
	esh.owner = root

	var ysort := Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	root.add_child(ysort)
	ysort.owner = root
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.set_script(load(PC))
	player.add_to_group("player", true)
	player.position = Vector2(627, 900)
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
	var perr := packed.pack(root)
	if perr == OK:
		perr = ResourceSaver.save(packed, SCENE_OUT)
	print("build_painted: scene err=%s painted_border_cells=%d" % [perr, col.get_used_cells().size()])
	root.free()
