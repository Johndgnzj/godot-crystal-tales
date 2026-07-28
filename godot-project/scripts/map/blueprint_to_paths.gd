extends SceneTree
## blueprint_to_paths.gd — 藍圖 → 可走區（塊 B 前置）。
##
## 讀 assets-source/map/map-def.json 每張圖的 terrain 藍圖（40×40 語意格），把「可走格」寫進場景的
## PathPaint32 層（等同 John 平常在編輯器手刷的可走區）；之後照常跑 invert_paths.gd 反轉成
## CollisionPaint 碰撞。本腳本只寫 PathPaint32、不動任何碰撞層——碰撞仍由 invert_paths 這唯一 builder 產。
##
## 地格語意讀 assets-source/map/terrain_palette.json：walkable=false 的 code（河/牆/山壁/森林/空）＝擋、不刷；
## 其餘 code 當可走地面 → 刷 PathPaint32。**空（.）＝圖外/未畫＝擋**（要可走就得畫地格）。
## **出入口另讀 map 的 entrances 屬性**（獨立於 terrain）：entrances 的 E 格一律當可走開口（刷 PathPaint，覆蓋 terrain 的擋）。
## **高物件另讀 map 的 props 陣列**：每筆 `{cell:[x,y], footprint:[w,h]}` 的 footprint 預設擋，
## 由物件配置與碰撞共用同一份資料；出入口格仍優先可走。
## **例外**：素材 `meta.json` 標 `"walkable": true` 的物件不生碰撞（石階、低矮農作、開著的門）——
## 否則石階會把礦坑唯一通路封死。判定只看這一個旗標，讀不到 meta 時保守當作會擋。
##
## 執行：Godot --headless -s res://scripts/map/blueprint_to_paths.gd --path <proj> -- [場景名...]
##   不給名＝處理 map-def 內所有「有 terrain 藍圖」的圖。給名（如 nfr_a）＝只做那幾張。
##   跑完接著跑：invert_paths.gd（同樣參數）把 PathPaint 反轉成碰撞。

const N32 := 40
const OUT_DIR := "res://scenes/world/painted/"
const PATH_SRC := 0
const PATH_ATLAS := Vector2i(0, 0)
## palette 讀失敗時的保底擋格集合（須與 terrain_palette.json 的 walkable=false 對齊）。
const FALLBACK_BLOCKED := ["~", "#", "^", "f", "."]         # 河/牆/山壁/森林/空(圖外)

var _prop_meta_cache := {}                                  # id → meta.json（同一張圖多實例只讀一次）


func _initialize() -> void:
	_run()


func _run() -> void:
	var blocked := _blocked_codes()
	var regions: Dictionary = _load_json("../assets-source/map/map-def.json").get("regions", {})
	if regions.is_empty():
		push_error("map-def.json 無 regions，或讀取失敗")
		quit(1)
		return
	var only := {}
	for a in OS.get_cmdline_user_args():
		only[str(a)] = true
	var count := 0
	for rc: String in regions:
		var reg: Dictionary = regions[rc]
		var prefix := str(reg.get("file_prefix", ""))
		var maps: Dictionary = reg.get("maps", {})
		for k: String in maps:
			var terrain: Variant = (maps[k] as Dictionary).get("terrain", null)
			if not (terrain is Array) or (terrain as Array).is_empty():
				continue
			var map: Dictionary = maps[k]
			# 場景檔名預設＝<file_prefix>_<key>；手工場景（如芳蕾鎮 town.tscn）用 map 的 scene_file 覆寫。
			var scene_name := str(map.get("scene_file", "%s_%s" % [prefix, k]))
			if not only.is_empty() and not only.has(scene_name):
				continue
			var entrances: Variant = map.get("entrances", null)
			var props: Variant = map.get("props", [])
			if _apply(scene_name, terrain, entrances, props, blocked):
				count += 1
	print("\nblueprint_to_paths 完成：寫入 PathPaint32 的圖 = %d。接著跑 invert_paths.gd 產碰撞。" % count)
	quit(0)


func _apply(scene_name: String, terrain: Array, entrances: Variant, props: Variant, blocked: Dictionary) -> bool:
	var path := OUT_DIR + scene_name + ".tscn"
	if not ResourceLoader.exists(path):
		push_warning("找不到場景（先跑 build_scenes？）：" + path)
		return false
	var root := (load(path) as PackedScene).instantiate()   # 不入樹＝不觸發 _ready
	var p32 := root.get_node_or_null("PathPaint32") as TileMapLayer
	if p32 == null:
		push_error("%s 缺 PathPaint32 層" % path)
		root.free()
		return false
	p32.clear()                                             # 藍圖為可走區的新真相源，重寫整層
	var has_ent: bool = entrances is Array
	var prop_blocks := _prop_blocks(props)
	var walk := 0
	var block := 0
	for r in mini(terrain.size(), N32):
		var row := str(terrain[r])
		var erow := ""
		if has_ent and r < (entrances as Array).size():
			erow = str((entrances as Array)[r])
		for c in mini(row.length(), N32):
			var is_ent: bool = c < erow.length() and erow[c] == "E"   # 出入口格＝一律可走開口（覆蓋 terrain 的擋）
			if not is_ent and (blocked.has(row[c]) or prop_blocks.has(Vector2i(c, r))):
				block += 1
				continue
			p32.set_cell(Vector2i(c, r), PATH_SRC, PATH_ATLAS)   # 可走(或出入口) → 刷 PathPaint32
			walk += 1
	var packed := PackedScene.new()
	if packed.pack(root) == OK:
		ResourceSaver.save(packed, path)
	print("=== %s ===  可走 %d 格 / 擋 %d 格（高物件 %d）→ 已寫 PathPaint32" % [scene_name, walk, block, prop_blocks.size()])
	root.free()
	return true


func _prop_blocks(props: Variant) -> Dictionary:
	var out := {}
	if not (props is Array):
		return out
	for raw: Variant in props:
		if not (raw is Dictionary):
			continue
		var prop: Dictionary = raw
		var cell: Variant = prop.get("cell", [])
		var footprint: Variant = prop.get("footprint", [])
		if not (cell is Array) or not (footprint is Array) or cell.size() < 2 or footprint.size() < 2:
			push_warning("props 格式錯誤，略過：" + str(prop.get("id", "(未命名)")))
			continue
		var x := int(cell[0])
		var y := int(cell[1])
		var w := maxi(1, int(footprint[0]))
		var h := maxi(1, int(footprint[1]))
		if _prop_is_walkable(prop, w, h):                   # 石階／低矮農作／開著的門＝踩得過去，不生碰撞
			continue
		for r in range(y, y + h):
			for c in range(x, x + w):
				if c >= 0 and c < N32 and r >= 0 and r < N32:
					out[Vector2i(c, r)] = true
	return out


## 物件是否可踩過：真相源＝素材的 meta.json `walkable`（見 docs/pipeline/world_object_art/遮擋物件資產架構.md）。
## 讀不到 meta 時保守當作會擋，避免把該擋的地方開成洞。
func _prop_is_walkable(prop: Dictionary, w: int, h: int) -> bool:
	var id := str(prop.get("id", ""))
	if id == "":
		return false
	if not _prop_meta_cache.has(id):
		var rel := "../assets-source/props/world/%s/%dx%d/%s/meta.json" % [
			str(prop.get("type", "structure")), w, h, id]
		_prop_meta_cache[id] = _load_json(rel)
	return bool((_prop_meta_cache[id] as Dictionary).get("walkable", false))


func _blocked_codes() -> Dictionary:
	var out := {}
	for cell in _load_json("../assets-source/map/terrain_palette.json").get("cells", []):
		if cell is Dictionary and not bool((cell as Dictionary).get("walkable", true)):
			out[str((cell as Dictionary).get("code", ""))] = true
	if out.is_empty():
		push_warning("terrain_palette.json 讀取失敗，改用保底擋格集合")
		for ch in FALLBACK_BLOCKED:
			out[ch] = true
	return out


func _load_json(rel_from_res: String) -> Dictionary:
	var abs_path := ProjectSettings.globalize_path("res://").path_join(rel_from_res)
	if not FileAccess.file_exists(abs_path):
		push_error("找不到檔案：" + abs_path)
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(abs_path))
	return data if data is Dictionary else {}
