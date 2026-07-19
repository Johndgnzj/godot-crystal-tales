extends SceneTree
## region_generator.gd — 引擎內地圖生成器（取代 Python region_gen.py）。
##
## 吃一份 RegionDef（.tres 或 .json）→ 產一整個連通地區的 Godot 地圖數據：
##   scenes/world/<id>.tscn                    每張地圖（PackedScene.pack 產出，滿足 world_scene.gd 契約）
##   resources/content/encounters/<id>.tres    自動選怪 encounter 表（ResourceSaver 產出）
##   resources/content/encounters/<id>_boss.tres  若該圖有 boss
##
## 不自動改共享檔（依專案治理）——只「回報」要接的線：SceneRouter.SCENE_PATHS、content_db.tres
## 的 encounters 聚合、pacing.tres。見 TASKS/12_地圖生成器.md。
##
## 執行（headless，全程綁 timeout）：
##   Godot --headless -s res://scripts/map/region_generator.gd --path . -- <region.tres|.json> [--dry-run]
## 給 .json 會順便存一份 RegionDef .tres 到 resources/map/regions/。

const TS := 32
const REGIONS_DIR := "res://resources/map/regions/"
const SCENES_DIR := "res://scenes/world/"
const ENCOUNTERS_DIR := "res://resources/content/encounters/"
const WS := "res://scripts/world/world_scene.gd"
const PC := "res://scripts/world/player_controller.gd"
const EZ := "res://scripts/world/exit_zone.gd"
const BM := "res://scripts/world/boss_mark.gd"
const DLG := "res://scenes/ui/dialogue_box.tscn"
const EDGE_ALIAS := {"east": "E", "west": "W", "north": "N", "south": "S", "up": "N", "down": "S"}

var _rng := RandomNumberGenerator.new()
var _warnings: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame   # 等 autoload（ContentDB）掛好

	var user_args := OS.get_cmdline_user_args()
	var dry := user_args.has("--dry-run")
	var input := ""
	for a in user_args:
		if not a.begins_with("--"):
			input = a
			break
	if input == "":
		push_error("用法：... region_generator.gd --path . -- <region.tres|.json> [--dry-run]")
		quit(1)
		return

	var cdb := root.get_node_or_null("/root/ContentDB")
	if cdb == null or not cdb.is_loaded:
		push_error("region_generator: ContentDB 未就緒（content_db.tres 產了嗎？）")
		quit(1)
		return

	var region := _load_region(input, dry)
	if region == null:
		quit(1)
		return
	_rng.seed = region.seed

	# ---- region-level 連線圖 ----
	var maps: Array = region.maps
	var id_to_scene: Dictionary = {}
	var map_ids: Dictionary = {}
	for m in maps:
		id_to_scene[m.id] = m.scene_name if m.scene_name != "" else m.id
		map_ids[m.id] = true
	var incoming: Dictionary = {}
	for m in maps:
		incoming[m.id] = []
	var externals: Array = []
	for m in maps:
		for e in m.exits:
			if map_ids.has(e.to):
				incoming[e.to].append(m.id)
			else:
				externals.append([m.id, e.to])

	var results: Array = []
	var all_ok := true
	for m in maps:
		var srcs: Array = (incoming[m.id] as Array).duplicate()
		for en in m.entries:
			srcs.append(en)
		var res := _build_map(m, srcs, id_to_scene, map_ids, cdb)
		results.append(res)
		if not res["ok"]:
			all_ok = false

	if not all_ok:
		push_error("region '%s' 有地圖連通性失敗，未寫檔" % region.region_id)
		quit(1)
		return

	print("== gen-region：%s（%d 張地圖）連通性 assert 全過 ==" % [region.region_id, maps.size()])
	if dry:
		print("[--dry-run] 未寫檔。")
	else:
		DirAccess.make_dir_recursive_absolute(SCENES_DIR)
		for r in results:
			var serr := ResourceSaver.save(r["packed"], SCENES_DIR + r["id"] + ".tscn")
			if serr != OK:
				push_error("存 %s.tscn 失敗 err=%s" % [r["id"], serr])
			if not (r["formations"] as Array).is_empty():
				_write_encounter(r["id"], r["formations"])
			if r["boss_enc"] != "":
				_write_encounter(r["boss_enc"], r["boss_formations"])
			print("  寫出 scenes/world/%s.tscn（%s）%s%s" % [r["id"], r["scene_name"],
				"＋encounter" if not (r["formations"] as Array).is_empty() else "（無敵人）",
				"＋boss" if r["boss_enc"] != "" else ""])

	_report(results, maps, id_to_scene, externals)
	quit(0)


func _load_region(input: String, dry: bool) -> RegionDef:
	if input.ends_with(".tres"):
		var r := load(input) as RegionDef
		if r == null:
			push_error("region_generator: %s 不是合法 RegionDef" % input)
		return r
	# .json：用 from_dict 建，順便存一份 .tres recipe
	var txt := FileAccess.get_file_as_string(input)
	if txt == "":
		push_error("region_generator: 讀不到 %s" % input)
		return null
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("region_generator: %s 頂層必須是物件" % input)
		return null
	var region := RegionDef.from_dict(parsed)
	if not dry:
		DirAccess.make_dir_recursive_absolute(REGIONS_DIR)
		var terr := ResourceSaver.save(region, REGIONS_DIR + region.region_id + ".tres")
		if terr == OK:
			print("  （由 json 產出 recipe：resources/map/regions/%s.tres）" % region.region_id)
		else:
			push_error("存 recipe .tres 失敗 err=%s" % terr)
	return region


# ============================ 單張地圖 ============================
func _build_map(m: MapDef, incoming: Array, id_to_scene: Dictionary, map_ids: Dictionary, cdb) -> Dictionary:
	var mb := MapGrid.new(m.w, m.h, MapKit.gid((MapKit.THEME[m.kind] as Dictionary)["base"]))
	var info := MapKit.carve_kind(mb, m, _rng)
	var tileset: String = info["tileset"]
	var atlas: String = info["atlas"]
	var floor_tile: int = info["floor"]
	var used: Dictionary = {}

	# 出口：at 決定邊；記錄每個目標的邊，讓對應 incoming spawn 走同一道門
	var edge_of_target: Dictionary = {}
	var exits: Array = []
	for e in m.exits:
		var edge: String = EDGE_ALIAS.get(e.at, "E")
		edge_of_target[e.to] = edge
		var cell := _place_edge(mb, used, m.id, floor_tile, edge)
		var to_scene: String
		var spawn: String
		if map_ids.has(e.to):
			to_scene = id_to_scene[e.to]
			spawn = "from_%s" % m.id
		else:
			to_scene = e.to
			spawn = e.spawn
		exits.append({"r": _exit_rect(cell.x, cell.y), "to": to_scene, "spawn": spawn})

	# 入口 spawn：同一連線走同一邊；找不到對應 exit（單向）→ 預設西邊
	var spawns: Dictionary = {}
	for src in incoming:
		var edge: String = edge_of_target.get(src, "W")
		var cell := _place_edge(mb, used, m.id, floor_tile, edge)
		spawns["from_%s" % src] = MapKit.spawn_px(cell.x, cell.y)

	# start：內部可走格（不在已用邊格上）
	var interior: Array = []
	for y in range(2, mb.mh - 2):
		for x in range(2, mb.mw - 2):
			var cc := Vector2i(x, y)
			if not mb.blocked[y][x] and not used.has(cc):
				interior.append(cc)
	var start: Vector2i = MapKit.choice(interior, _rng) if not interior.is_empty() else Vector2i(1, 1)
	spawns["start"] = MapKit.spawn_px(start.x, start.y)

	# 選怪 + boss
	var regular_ids := _choose_enemy_ids(m, cdb)
	var boss_node: Dictionary = {}
	var boss_enc := ""
	var boss_formations: Array = []
	if m.boss_enemy != "":
		var edef = cdb.get_enemy(m.boss_enemy)
		if edef == null:
			_warnings.append("map '%s' boss '%s' 不存在，略過 boss" % [m.id, m.boss_enemy])
		else:
			var fc := MapKit.farthest_cell(mb, start)
			used[fc] = true
			boss_node = {
				"show_when": m.boss_show_when, "encounter_id": "%s_boss" % m.id,
				"return_offset": Vector2(0, 90), "x": fc.x * TS, "y": fc.y * TS - 28,
				"w": 64, "h": 80, "tex": "res://assets/battle/foe_%s_0.png" % edef.sprite}
			boss_enc = "%s_boss" % m.id
			var adds: Array = []
			if m.boss_adds:
				for i in regular_ids:
					if i != m.boss_enemy and adds.size() < 2:
						adds.append(i)
			boss_formations = [[m.boss_enemy] + adds]

	# 開放式：鑿林徑串起 start↔各出入口（dirt，不 autotile——atlas_forest 缺 path 變體）
	if m.effective_layout() == "open":
		var key_tiles: Array = []
		for e in exits:
			key_tiles.append(Vector2i(e["r"][0] / TS, e["r"][1] / TS))
		for k in spawns:
			if k != "start":
				var v: Vector2i = spawns[k]
				key_tiles.append(Vector2i((v.x + MapKit.FEET_X) / TS, (v.y + MapKit.FEET_Y) / TS))
		for t in key_tiles:
			MapKit.carve_path(mb, start, t, MapKit.gid("dirt"))
	if m.kind in ["forest", "grassland"]:
		MapKit.place_forest_props(mb, _rng)

	# 連通性：start 到每個 spawn/exit/boss 都必須可達
	var seen := MapKit.reachable(mb, start)
	var fails: Array = []
	for k in spawns:
		var v: Vector2i = spawns[k]
		var cell := Vector2i((v.x + MapKit.FEET_X) / TS, (v.y + MapKit.FEET_Y) / TS)
		if not seen.has(cell):
			fails.append("spawn:%s" % k)
	for e in exits:
		if not seen.has(Vector2i(e["r"][0] / TS, e["r"][1] / TS)):
			fails.append("exit->%s" % e["to"])
	if not boss_node.is_empty():
		if not seen.has(Vector2i(boss_node["x"] / TS, (boss_node["y"] + 28) / TS)):
			fails.append("boss")
	if not fails.is_empty():
		push_error("region map '%s' 連通性失敗：%s" % [m.id, fails])

	var scene_name: String = m.scene_name if m.scene_name != "" else m.id
	var packed := _build_scene(scene_name, mb, spawns, exits, boss_node, tileset, atlas, m)

	return {
		"id": m.id, "scene_name": scene_name, "packed": packed,
		"formations": _make_formations(regular_ids), "boss_enc": boss_enc,
		"boss_formations": boss_formations, "band": m.level_band, "ok": fails.is_empty()}


func _place_edge(mb: MapGrid, used: Dictionary, mid: String, floor_tile: int, edge: String) -> Vector2i:
	var cands: Array = []
	for c in MapKit.inner_edge_cells(mb, edge):
		if not used.has(c):
			cands.append(c)
	if not cands.is_empty():
		var c: Vector2i = MapKit.choice(cands, _rng)
		used[c] = true
		MapKit.carve_opening(mb, edge, c, floor_tile)
		return c
	# 保底：從最近可走格鑿通道到邊
	var walk: Array = []
	for y in range(2, mb.mh - 2):
		for x in range(2, mb.mw - 2):
			var cc := Vector2i(x, y)
			if not mb.blocked[y][x] and not used.has(cc):
				walk.append(cc)
	if walk.is_empty():
		push_error("map '%s' 放不下出入口" % mid)
		return Vector2i(1, 1)
	var anchor: Vector2i = walk[0]
	var bestd := _edge_dist(mb, walk[0], edge)
	for cc in walk:
		var dd := _edge_dist(mb, cc, edge)
		if dd < bestd:
			bestd = dd
			anchor = cc
	var c2 := MapKit.trail_to_edge(mb, edge, anchor, floor_tile)
	used[c2] = true
	return c2


func _edge_dist(mb: MapGrid, c: Vector2i, edge: String) -> int:
	match edge:
		"E": return mb.mw - 1 - c.x
		"W": return c.x
		"N": return c.y
		_: return mb.mh - 1 - c.y


func _exit_rect(tx: int, ty: int) -> Array:
	return [tx * TS, ty * TS, tx * TS + TS, ty * TS + TS]


# ============================ 選怪 / 編成 ============================
func _exp_cap(hi: int) -> int:
	for pair in [[3, 11], [5, 18], [8, 30], [11, 48]]:
		if hi <= pair[0]:
			return pair[1]
	return 1000000000


func _exp_floor(lo: int) -> int:
	if lo >= 8:
		return 12
	return 8 if lo >= 5 else 0


func _choose_enemy_ids(m: MapDef, cdb) -> Array:
	var pool: Array = []
	for e in cdb.get_all_enemies():
		if not e.big and e.exp > 0:
			pool.append(e)
	if not m.enemies.is_empty():
		var valid: Dictionary = {}
		for e in pool:
			valid[e.id] = true
		var ids: Array = []
		var bad: Array = []
		for i in m.enemies:
			if valid.has(i):
				ids.append(i)
			else:
				bad.append(i)
		if not bad.is_empty():
			_warnings.append("map '%s' enemies 指定不存在/boss 敵人：%s（略過）" % [m.id, bad])
		if not ids.is_empty():
			return ids
		_warnings.append("map '%s' enemies 明列全部無效，改用 level_band 自動選" % m.id)
	var lo: int = m.level_band[0]
	var hi: int = m.level_band[1]
	var cap := _exp_cap(hi)
	var floor_exp := _exp_floor(lo)
	var fitting: Array = []
	for e in pool:
		if e.exp >= floor_exp and e.exp <= cap:
			fitting.append(e.id)
	if fitting.is_empty():
		var sorted_pool: Array = pool.duplicate()
		sorted_pool.sort_custom(func(a, b): return absi(a.exp - cap) < absi(b.exp - cap))
		for e in sorted_pool.slice(0, 3):
			fitting.append(e.id)
		_warnings.append("map '%s' level_band %s 無現成合適敵人，暫用最接近的 %s（需補符合難度的新怪）"
			% [m.id, m.level_band, fitting])
	return fitting


func _make_formations(ids: Array) -> Array:
	if ids.is_empty():
		return []
	var sizes := [1, 2, 2, 3]
	var n: int = maxi(3, mini(4, ids.size() + 1))
	var out: Array = []
	for k in sizes.slice(0, n):
		# 先隨機挑 k 隻累計成「同種數量」，再轉成帶範圍的 members（新 EncounterDef 格式，see F-11）
		var counts: Dictionary = {}
		for _j in k:
			var eid: String = MapKit.choice(ids, _rng)
			counts[eid] = int(counts.get(eid, 0)) + 1
		var members: Array = []
		for eid in counts:
			var c: int = counts[eid]
			members.append({"id": eid, "min": maxi(1, c - 1), "max": c + 1})
		out.append({"weight": 1.0, "members": members})
	return out


func _write_encounter(map_id: String, formations: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ENCOUNTERS_DIR)
	var ed := EncounterDef.from_dict(map_id, formations)
	var err := ResourceSaver.save(ed, ENCOUNTERS_DIR + map_id + ".tres")
	if err != OK:
		push_error("存 encounters/%s.tres 失敗 err=%s" % [map_id, err])


# ============================ .tscn 產出（PackedScene.pack）============================
func _rect_shape(cache: Dictionary, w: float, h: float) -> RectangleShape2D:
	var key := Vector2(w, h)
	if not cache.has(key):
		var s := RectangleShape2D.new()
		s.size = key
		cache[key] = s
	return cache[key]


@warning_ignore("integer_division")
func _build_scene(scene_name: String, mb: MapGrid, spawns: Dictionary, exits: Array,
		boss_node: Dictionary, tileset: String, atlas: String, m: MapDef) -> PackedScene:
	var root := Node2D.new()
	root.name = scene_name
	root.set_script(load(WS))
	root.set("scene_id", scene_name)
	root.set("map_w", mb.mw)
	root.set("map_h", mb.mh)
	# 地磚不走 ground_tiles export——直接烘進 Ground TileMapLayer（見下），編輯器可見可用筆刷編。
	root.set("blk_rows", mb.blk_rows())
	root.set("enc_rows", mb.enc_rows())
	var spawns_export: Dictionary = {}
	for k in spawns:
		var v: Vector2i = spawns[k]
		spawns_export[k] = Vector2(v.x + MapKit.FEET_X, v.y + MapKit.FEET_Y)
	root.set("spawns", spawns_export)
	root.set("enc_group", m.id)
	root.set("bgm", "")
	root.set("cut_on_enter", [])
	root.set("npc_list", [])
	root.set("prop_list", [])   # prop 直接烘成 YSort 下的節點（見下），不走 runtime spawn
	root.set("chest_list", [])
	root.set("door_list", [])
	root.set("tileset_path", tileset)
	root.set("atlas_path", atlas)

	var shape_cache: Dictionary = {}

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	root.add_child(ground)
	ground.owner = root
	# 把地磚烘進 TileMapLayer（設好 TileSet + 逐格 set_cell）——編輯器打開即見、可用 TileMap 筆刷編。
	ground.tile_set = load(tileset) as TileSet
	for gy in mb.mh:
		for gx in mb.mw:
			var gt := mb.g[gy * mb.mw + gx]
			if gt <= 0:
				continue
			var gidx := gt - 1
			ground.set_cell(Vector2i(gx, gy), 0, Vector2i(gidx % MapKit.ATLAS_COLS, gidx / MapKit.ATLAS_COLS))

	var collision := StaticBody2D.new()
	collision.name = "Collision"
	root.add_child(collision)
	collision.owner = root
	var idx := 0
	for r in MapKit.merge_block_rects(mb):
		var rw := float((r[2] - r[0] + 1) * TS)
		var rh := float((r[3] - r[1] + 1) * TS)
		var cs := CollisionShape2D.new()
		cs.name = "Col%d" % idx
		cs.position = Vector2(r[0] * TS + rw / 2.0, r[1] * TS + rh / 2.0)
		cs.shape = _rect_shape(shape_cache, rw, rh)
		collision.add_child(cs)
		cs.owner = root
		idx += 1
	var mw_px := mb.mw * TS
	var mh_px := mb.mh * TS
	var borders := [[-TS, -TS, mw_px + TS, 0], [-TS, mh_px, mw_px + TS, mh_px + TS],
		[-TS, 0, 0, mh_px], [mw_px, 0, mw_px + TS, mh_px]]
	for bd in borders:
		var cs := CollisionShape2D.new()
		cs.name = "Col%d" % idx
		cs.position = Vector2((bd[0] + bd[2]) / 2.0, (bd[1] + bd[3]) / 2.0)
		cs.shape = _rect_shape(shape_cache, bd[2] - bd[0], bd[3] - bd[1])
		collision.add_child(cs)
		cs.owner = root
		idx += 1

	var zones := Node2D.new()
	zones.name = "Zones"
	root.add_child(zones)
	zones.owner = root
	var ei := 0
	for e in exits:
		var area := Area2D.new()
		area.name = "Exit%d" % ei
		area.set_script(load(EZ))
		var rr: Array = e["r"]
		area.position = Vector2((rr[0] + rr[2]) / 2.0, (rr[1] + rr[3]) / 2.0)
		area.set("to_scene", e["to"])
		area.set("spawn_id", e["spawn"])
		zones.add_child(area)
		area.owner = root
		var sh := CollisionShape2D.new()
		sh.name = "Shape"
		sh.shape = _rect_shape(shape_cache, rr[2] - rr[0], rr[3] - rr[1])
		area.add_child(sh)
		sh.owner = root
		ei += 1
	if not boss_node.is_empty():
		var area := Area2D.new()
		area.name = "Boss0"
		area.set_script(load(BM))
		area.position = Vector2(boss_node["x"] + boss_node["w"] / 2.0, boss_node["y"] + boss_node["h"] / 2.0)
		area.set("show_when", boss_node["show_when"])
		area.set("encounter_id", boss_node["encounter_id"])
		area.set("return_scene_id", scene_name)
		area.set("return_offset", boss_node["return_offset"])
		area.set_meta("tex", boss_node["tex"])
		area.set_meta("w", float(boss_node["w"]))
		area.set_meta("h", float(boss_node["h"]))
		zones.add_child(area)
		area.owner = root
		var sh := CollisionShape2D.new()
		sh.name = "Shape"
		var circ := CircleShape2D.new()
		circ.radius = 80.0
		sh.shape = circ
		area.add_child(sh)
		sh.owner = root

	var ysort := Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	root.add_child(ysort)
	ysort.owner = root
	# 把 prop 烘成 YSort 下的 Sprite2D 節點（編輯器可見可拖）；定位複製 world_scene._add_base_sprite。
	var pi := 0
	for p in mb.props:
		var ptex: String = p["tex"]
		if not ResourceLoader.exists(ptex):
			continue
		var tex := load(ptex) as Texture2D
		if tex == null:
			continue
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		var pw := float(p.get("w", 0))
		var ph := float(p.get("h", 0))
		var sw := pw if pw > 0.0 else tw
		var sh := ph if ph > 0.0 else th
		var pnode := Node2D.new()
		pnode.name = "Prop%d" % pi
		pnode.position = Vector2(float(p["x"]) + sw / 2.0, float(p["y"]) + sh)
		var pspr := Sprite2D.new()
		pspr.name = "Sprite"
		pspr.texture = tex
		pspr.scale = Vector2(sw / tw, sh / th)
		pspr.position = Vector2(0.0, -sh / 2.0)
		pnode.add_child(pspr)
		ysort.add_child(pnode)
		pnode.owner = root
		pspr.owner = root
		pi += 1
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.set_script(load(PC))
	player.add_to_group("player", true)
	var sp: Vector2i = spawns["start"]
	player.position = Vector2(sp.x + MapKit.FEET_X, sp.y + MapKit.FEET_Y)
	ysort.add_child(player)
	player.owner = root
	var pshape := CollisionShape2D.new()
	pshape.name = "Shape"
	pshape.position = Vector2(0, -1)
	var prect := RectangleShape2D.new()
	prect.size = Vector2(22, 14)
	pshape.shape = prect
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
	prompt.text = ""
	hud.add_child(prompt)
	prompt.owner = root

	var dlg := (load(DLG) as PackedScene).instantiate()
	dlg.name = "DialogueBox"
	root.add_child(dlg)
	dlg.owner = root

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack %s 失敗 err=%s" % [scene_name, err])
	root.free()
	return packed


# ============================ 回報要接的線 ============================
func _report(results: Array, maps: Array, id_to_scene: Dictionary, externals: Array) -> void:
	if not _warnings.is_empty():
		print("\n-- 警告 --")
		for w in _warnings:
			print("  ⚠ " + w)
	print("\n-- 要接的線（請手動套用；共享檔案依治理不自動改）--")
	print("① autoload/scene_router.gd 的 SCENE_PATHS 加入：")
	for r in results:
		print('     "%s": "res://scenes/world/%s.tscn",' % [r["scene_name"], r["id"]])
	print("② content_db.tres 的 encounters 陣列聚合這些檔（否則 ContentDB 讀不到）：")
	for r in results:
		if not (r["formations"] as Array).is_empty():
			print("     resources/content/encounters/%s.tres" % r["id"])
		if r["boss_enc"] != "":
			print("     resources/content/encounters/%s.tres  (boss)" % r["boss_enc"])
	print("③ pacing.tres 建議加入難度條目：")
	for r in results:
		var band: Array = r["band"]
		print('     "%s": {"entryLv": %d, "targetLv": %d}' % [r["id"], band[0], band[1]])
	if not externals.is_empty():
		print("④ 與既有場景（設定外，如 Town）的接口，需你在對方場景接線：")
		for pair in externals:
			print("     %s 有 exit → 既有場景 '%s'：確認 '%s' 有對應 spawn_id" % [pair[0], pair[1], pair[1]])
	print("\n（tests/smoke_test.gd 的 SCENES 若要收錄新圖，一併補上。）")
