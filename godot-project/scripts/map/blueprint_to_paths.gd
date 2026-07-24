extends SceneTree
## blueprint_to_paths.gd — 藍圖 → 可走區（塊 B 前置）。
##
## 讀 assets-source/map/map-def.json 每張圖的 terrain 藍圖（40×40 語意格），把「可走格」寫進場景的
## PathPaint32 層（等同 John 平常在編輯器手刷的可走區）；之後照常跑 invert_paths.gd 反轉成
## CollisionPaint 碰撞。本腳本只寫 PathPaint32、不動任何碰撞層——碰撞仍由 invert_paths 這唯一 builder 產。
##
## 地格語意讀 assets-source/map/terrain_palette.json：walkable=false 的 code（河/牆/山壁）＝擋、不刷；
## 其餘（含未列 code、空白）一律當可走地面 → 刷 PathPaint32。
##
## 執行：Godot --headless -s res://scripts/map/blueprint_to_paths.gd --path <proj> -- [場景名...]
##   不給名＝處理 map-def 內所有「有 terrain 藍圖」的圖。給名（如 nfr_a）＝只做那幾張。
##   跑完接著跑：invert_paths.gd（同樣參數）把 PathPaint 反轉成碰撞。

const N32 := 40
const OUT_DIR := "res://scenes/world/painted/"
const PATH_SRC := 0
const PATH_ATLAS := Vector2i(0, 0)
## palette 讀失敗時的保底擋格集合（須與 terrain_palette.json 的 walkable=false 對齊）。
const FALLBACK_BLOCKED := ["~", "#", "^"]


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
			var scene_name := "%s_%s" % [prefix, k]
			if not only.is_empty() and not only.has(scene_name):
				continue
			if _apply(scene_name, terrain, blocked):
				count += 1
	print("\nblueprint_to_paths 完成：寫入 PathPaint32 的圖 = %d。接著跑 invert_paths.gd 產碰撞。" % count)
	quit(0)


func _apply(scene_name: String, terrain: Array, blocked: Dictionary) -> bool:
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
	var walk := 0
	var block := 0
	for r in mini(terrain.size(), N32):
		var row := str(terrain[r])
		for c in mini(row.length(), N32):
			if blocked.has(row[c]):
				block += 1
				continue
			p32.set_cell(Vector2i(c, r), PATH_SRC, PATH_ATLAS)   # 可走 → 刷 PathPaint32
			walk += 1
	var packed := PackedScene.new()
	if packed.pack(root) == OK:
		ResourceSaver.save(packed, path)
	print("=== %s ===  可走 %d 格 / 擋 %d 格 → 已寫 PathPaint32" % [scene_name, walk, block])
	root.free()
	return true


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
