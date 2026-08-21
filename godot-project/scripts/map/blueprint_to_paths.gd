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
## **高物件另讀 map 的 props 陣列**：每筆 `{cell:[x,y]}` 的 footprint **由素材庫 meta.json 決定**（素材層級、
## 校正一次所有地圖生效），該範圍預設擋，
## 由物件配置與碰撞共用同一份資料；出入口格仍優先可走。
## **擋人範圍可細到 16px**：素材 `meta.json` 的 `collision_px:[w,h]`（預設＝footprint×32）以 footprint
## 底邊中央為錨點。整格被蓋滿→該格不刷 PathPaint32（全擋）；只蓋到一部分→改刷 PathPaint16 於仍可走的
## 子格（invert_paths 會把未刷的子格做成 16px 牆）。路燈／稻草人這類「只擋腳下半格」就靠這個表達。
##
## **例外**：素材 `meta.json` 標 `"walkable": true` 的物件不生碰撞（石階、低矮農作、開著的門）——
## 否則石階會把礦坑唯一通路封死。判定只看這一個旗標，讀不到 meta 時保守當作會擋。
## **例外二**：prop 帶 `gate` 欄（路障／可開關的柵欄門）也不烘——它的碰撞由 `build_scenes.gd` 生成的
## `GatedBlocker` 節點自己帶著、依旗標開關；烘進 tilemap 就變成拆不掉的永久牆。
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
			# 場景已為每個物件掛 StaticBody2D 者（如芳蕾鎮 town，設計員直接在編輯器搬物件），
			# props 不進 CollisionPaint——否則物件一移動，tilemap 就留下對不上的幽靈牆。
			var props: Variant = [] if bool(map.get("props_collide_in_scene", false)) else map.get("props", [])
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
	var p16 := root.get_node_or_null("PathPaint16") as TileMapLayer
	if p16 == null:
		push_error("%s 缺 PathPaint16 層" % path)
		root.free()
		return false
	var prop_subs := _prop_block_subs(props)
	p32.clear()                                             # 藍圖為可走區的新真相源，重寫整層
	# PathPaint16 **不整層清掉**：那層可能有設計員手刷的細部可走區（Town 就有 22 格）。
	# 只把被高物件蓋住的子格擦掉，其餘保留；部分被擋的格子稍後再補刷。
	for s16: Vector2i in p16.get_used_cells():
		if prop_subs.has(s16):
			p16.erase_cell(s16)
	var has_ent: bool = entrances is Array
	var walk := 0
	var block := 0
	var partial := 0
	for r in mini(terrain.size(), N32):
		var row := str(terrain[r])
		var erow := ""
		if has_ent and r < (entrances as Array).size():
			erow = str((entrances as Array)[r])
		for c in mini(row.length(), N32):
			var is_ent: bool = c < erow.length() and erow[c] == "E"   # 出入口格＝一律可走開口（覆蓋 terrain 的擋）
			if not is_ent and blocked.has(row[c]):
				block += 1
				continue
			var free_subs: Array[Vector2i] = []
			if not is_ent:                                  # 出入口不受高物件影響
				for s16 in _subs(Vector2i(c, r)):
					if not prop_subs.has(s16):
						free_subs.append(s16)
			if is_ent or free_subs.size() == 4:
				p32.set_cell(Vector2i(c, r), PATH_SRC, PATH_ATLAS)   # 整格可走 → PathPaint32
				walk += 1
			elif free_subs.is_empty():
				block += 1                                  # 整格被高物件蓋滿
			else:
				for s16 in free_subs:                       # 部分可走 → 只刷剩下的 16 子格
					p16.set_cell(s16, PATH_SRC, PATH_ATLAS)
				partial += 1
	var packed := PackedScene.new()
	if packed.pack(root) == OK:
		ResourceSaver.save(packed, path)
	print("=== %s ===  整格可走 %d / 部分可走 %d / 擋 %d（高物件佔 %d 個 16 子格）→ 已寫 PathPaint32+16"
		% [scene_name, walk, partial, block, prop_subs.size()])
	root.free()
	return true


## 高物件的擋人範圍，以 **16px 子格** 表示（Vector2i 為 16 單位座標）。
## 錨點＝footprint 底邊中央；範圍＝meta 的 collision_px，預設 footprint×32。
func _prop_block_subs(props: Variant) -> Dictionary:
	var out := {}
	if not (props is Array):
		return out
	for raw: Variant in props:
		if not (raw is Dictionary):
			continue
		var prop: Dictionary = raw
		var cell: Variant = prop.get("cell", [])
		if not (cell is Array) or cell.size() < 2:
			push_warning("props 缺 cell，略過：" + str(prop.get("id", "(未命名)")))
			continue
		if _prop_is_walkable(prop):                         # 石階／低矮農作／開著的門＝踩得過去
			continue
		if prop.get("gate", null) is Dictionary:
			# gated 物件（路障／可開關的柵欄門）的碰撞掛在 GatedBlocker 節點上，依旗標開關。
			# 烘進 CollisionPaint 會變成永久牆，旗標翻轉後也拆不掉——所以這裡一定要跳過。
			continue
		var fp := _prop_footprint(prop)
		var box := _prop_collision_px(prop, fp)
		var cx := (float(cell[0]) + float(fp.x) * 0.5) * 32.0    # footprint 底邊中央（像素）
		var by := (float(cell[1]) + float(fp.y)) * 32.0
		var x0 := int(floor((cx - float(box.x) * 0.5) / 16.0))
		var x1 := int(ceil((cx + float(box.x) * 0.5) / 16.0))
		var y0 := int(floor((by - float(box.y)) / 16.0))
		var y1 := int(ceil(by / 16.0))
		for sy in range(y0, y1):
			for sx in range(x0, x1):
				if sx >= 0 and sx < N32 * 2 and sy >= 0 and sy < N32 * 2:
					out[Vector2i(sx, sy)] = true
	return out


## 一個 32 格的四個 16 子格（座標為 16 單位；與 invert_paths.gd 的 _subs 慣例一致）。
func _subs(c: Vector2i) -> Array[Vector2i]:
	return [Vector2i(c.x * 2, c.y * 2), Vector2i(c.x * 2 + 1, c.y * 2),
		Vector2i(c.x * 2, c.y * 2 + 1), Vector2i(c.x * 2 + 1, c.y * 2 + 1)]


## 擋人範圍（像素）：meta 的 collision_px 優先，否則 footprint×32。
func _prop_collision_px(prop: Dictionary, fp: Vector2i) -> Vector2i:
	var v: Variant = _prop_meta(prop).get("collision_px", null)
	if v is Array and (v as Array).size() >= 2:
		return Vector2i(maxi(16, int(v[0])), maxi(16, int(v[1])))
	return Vector2i(fp.x * 32, fp.y * 32)


## 素材庫 meta.json＝素材層級規格（footprint／walkable／layer）的真相源。
## 用 type＋id **掃描** <footprint> 那層目錄找檔——不能拿 map-def 的 footprint 去拼路徑，
## 否則校正後改了 footprint 就找不到自己的 meta。目錄名只是歸檔，值以 meta.json 為準。
func _prop_meta(prop: Dictionary) -> Dictionary:
	var id := str(prop.get("id", ""))
	if id == "":
		return {}
	if not _prop_meta_cache.has(id):
		var base := ProjectSettings.globalize_path("res://").path_join(
			"../assets-source/props/world/%s" % str(prop.get("type", "structure")))
		var meta := {}
		var da := DirAccess.open(base)
		if da != null:
			for sub in da.get_directories():
				var f := base.path_join("%s/%s/meta.json" % [sub, id])
				if FileAccess.file_exists(f):
					var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
					meta = v if v is Dictionary else {}
					break
		_prop_meta_cache[id] = meta
	return _prop_meta_cache[id]


## footprint＝**素材層級**規格：同一素材擺到哪張圖都同一套碰撞（校正一次全域生效）。
func _prop_footprint(prop: Dictionary) -> Vector2i:
	var fp: Variant = _prop_meta(prop).get("footprint", null)
	if fp is Array and (fp as Array).size() >= 2:
		return Vector2i(maxi(1, int(fp[0])), maxi(1, int(fp[1])))
	var raw: Variant = prop.get("footprint", [])
	if raw is Array and (raw as Array).size() >= 2:
		push_warning("素材庫查無 %s 的 meta.json，改用 map-def 的 footprint" % str(prop.get("id", "")))
		return Vector2i(maxi(1, int(raw[0])), maxi(1, int(raw[1])))
	return Vector2i(1, 1)


## 物件是否可踩過：真相源＝素材的 meta.json `walkable`。讀不到時保守當作會擋。
func _prop_is_walkable(prop: Dictionary) -> bool:
	return bool(_prop_meta(prop).get("walkable", false))


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
