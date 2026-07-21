extends SceneTree
## ⚠️ 已被 scripts/map/build_scenes.gd 取代（讀 map-def.json 的通用版，一次處理全 region）；保留供歷史參考，勿再執行。
##（註：Town 含 NPC/門/劇情/實例，build_scenes.gd 將其列為「受保護、不重生」，仍由本檔的產出為準。）
## 建構 M1 芳蕾鎮手繪版場景（取代 tile 版 Town）：world_scene.gd 完整契約（NPC/門/劇情資料驅動）
## ＋ 手繪背景圖 ＋ CollisionPaint（32px；圖外背景與建築體已預刷，地形細節由 John 手刷）。
## 座標依 assets/map/floret/floret_town.png（1280×1280，40×40 格 @32px）視覺定位。
## 執行：Godot --headless -s res://scripts/map/build_floret_town.gd --path .

const OUT := "res://scenes/world/painted/town.tscn"
const BLOCKED_JSON := "/tmp/floret_town_blocked.json"
const TS := 32

## 門：手繪圖以 entry_pos / outside_pos 精確對準門洞；tx/ty 保留給舊存檔相容。
const DOORS := [
	{"tx": 13, "ty": 16, "key": "guild", "label": "公會", "owners": ["tina"], "entry_pos": Vector2(416, 512), "outside_pos": Vector2(416, 560)},
	{"tx": 25, "ty": 18, "key": "inn", "label": "旅店", "owners": ["dora"], "entry_pos": Vector2(804, 560), "outside_pos": Vector2(804, 608)},
	{"tx": 12, "ty": 27, "key": "shrine", "label": "教會", "owners": ["shea"], "entry_pos": Vector2(394, 832), "outside_pos": Vector2(394, 882)},
	{"tx": 18, "ty": 31, "key": "mayor", "label": "鎮長宅", "owners": ["barton"], "entry_pos": Vector2(580, 982), "outside_pos": Vector2(580, 1032)},
	{"tx": 25, "ty": 27, "key": "shop", "label": "道具店", "owners": ["gid"], "entry_pos": Vector2(808, 820), "outside_pos": Vector2(808, 870)},
	{"tx": 32, "ty": 28, "key": "smithy", "label": "鐵匠鋪", "owners": ["don"], "entry_pos": Vector2(1054, 846), "outside_pos": Vector2(1054, 896)},
]
const NPCS := [
	{"id": "gray", "sprite": "gray", "x": 17, "y": 18, "pos": Vector2(576, 640), "face": "Right"},
	{"id": "mira", "sprite": "villager", "x": 7, "y": 16, "pos": Vector2(250, 576), "face": "Down"},
	{"id": "rossel", "sprite": "rossel", "x": 19, "y": 11, "pos": Vector2(640, 400), "face": "Down"},
]
const SPAWNS := {
	"home": Vector2(628, 720),        # 廣場（水井南側）
	"fromMine": Vector2(628, 200),    # 北：礦山口樓梯下
	"fromForest": Vector2(1180, 650), # 東：森林口內側
	"shrine": Vector2(400, 900),      # 教會前（戰敗重生點）
}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var txt := FileAccess.get_file_as_string(BLOCKED_JSON)
	if txt == "":
		push_error("讀不到 " + BLOCKED_JSON)
		quit(1)
		return
	var blocked: Array = JSON.parse_string(txt)

	var root := Node2D.new()
	root.name = "Town"
	root.set_script(load("res://scripts/world/world_scene.gd"))
	root.set("scene_id", "Town")
	root.set("map_w", 40)
	root.set("map_h", 40)
	root.set("spawns", SPAWNS)
	root.set("enc_group", "")
	root.set("bgm", "bgm_town.mp3")
	root.set("cut_on_enter", [{"cut": "prologue_town", "step": 0}, {"cut": "town_start", "step": 3}])
	root.set("npc_list", NPCS)
	root.set("door_list", DOORS)
	root.set("tileset_path", "")   # 地形是手繪背景圖，無 tile 地面

	var bg := Sprite2D.new()
	bg.name = "Background"
	bg.centered = false
	bg.texture = load("res://assets/map/floret/floret_town.png")
	root.add_child(bg)
	bg.owner = root

	var ground := TileMapLayer.new()   # world_scene 契約需要 $Ground（空，_fill_ground 會跳過）
	ground.name = "Ground"
	root.add_child(ground)
	ground.owner = root

	var col := TileMapLayer.new()
	col.name = "CollisionPaint"
	col.tile_set = load("res://resources/map/collision_tileset_32.tres")
	for c in blocked:
		col.set_cell(Vector2i(int(c[0]), int(c[1])), 0, Vector2i(0, 0))
	root.add_child(col)
	col.owner = root

	var zones := Node2D.new()
	zones.name = "Zones"
	root.add_child(zones)
	zones.owner = root
	var shape_cache: Dictionary = {}
	# 北：礦山（沿用原故事動線，無閘）
	_exit(root, zones, shape_cache, "ExitN", Vector2(628, 120), Vector2(96, 64),
		{"to_scene": "NMA", "spawn_id": "from_Town"})
	# 東：東之森林 EFA（恢復原第一章劇情閘：step<3 擋）
	_exit(root, zones, shape_cache, "ExitE", Vector2(1258, 650), Vector2(44, 128),
		{"to_scene": "EFA", "spawn_id": "from_Town", "has_min_step": true, "min_step": 3,
		 "deny_msg": "瑪琳：先跟亞倫先生去礦山吧！（往北）", "push_offset": Vector2(-24, 0)})
	# 南／西：未來地區（M5 大都市之路／M4 之外），先用劇情封鎖訊息
	_trigger(root, zones, shape_cache, "TriggerS", Vector2(643, 1245), Vector2(128, 44),
		"南方大道封鎖中（找羅素隊長打聽）")
	_trigger(root, zones, shape_cache, "TriggerW", Vector2(20, 650), Vector2(44, 128),
		"西邊瀰漫著不自然的濃霧……現在進不去")

	var ysort := Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	root.add_child(ysort)
	ysort.owner = root
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.set_script(load("res://scripts/world/player_controller.gd"))
	player.add_to_group("player", true)
	player.position = SPAWNS["home"]
	ysort.add_child(player)
	player.owner = root
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

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 5
	root.add_child(hud)
	hud.owner = root
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.offset_left = 240.0
	prompt.offset_top = 500.0
	prompt.offset_right = 1040.0
	prompt.offset_bottom = 532.0
	prompt.set("theme_override_font_sizes/font_size", 22)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(prompt)
	prompt.owner = root

	var dlg := (load("res://scenes/ui/dialogue_box.tscn") as PackedScene).instantiate()
	dlg.name = "DialogueBox"
	root.add_child(dlg)
	dlg.owner = root

	DirAccess.make_dir_recursive_absolute("res://scenes/world/painted/")
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("FLORET_TOWN cells=%d doors=%d npcs=%d err=%s" % [col.get_used_cells().size(), DOORS.size(), NPCS.size(), err])
	root.free()
	quit(0 if err == OK else 1)


func _exit(root: Node, zones: Node, cache: Dictionary, name: String, pos: Vector2, size: Vector2, props: Dictionary) -> void:
	var area := Area2D.new()
	area.name = name
	area.set_script(load("res://scripts/world/exit_zone.gd"))
	area.position = pos
	for k in props:
		area.set(k, props[k])
	zones.add_child(area)
	area.owner = root
	_shape(root, area, cache, size)


func _trigger(root: Node, zones: Node, cache: Dictionary, name: String, pos: Vector2, size: Vector2, msg: String) -> void:
	var area := Area2D.new()
	area.name = name
	area.set_script(load("res://scripts/world/trigger_zone.gd"))
	area.position = pos
	area.set("msg", msg)
	zones.add_child(area)
	area.owner = root
	_shape(root, area, cache, size)


func _shape(root: Node, area: Node, cache: Dictionary, size: Vector2) -> void:
	var sh := CollisionShape2D.new()
	sh.name = "Shape"
	if not cache.has(size):
		var r := RectangleShape2D.new()
		r.size = size
		cache[size] = r
	sh.shape = cache[size]
	area.add_child(sh)
	sh.owner = root
