extends SceneTree
## build_scenes.gd — 通用手繪地圖場景生成器（塊 C：出入口＋場景骨架）。
##
## 讀 assets-source/map/map-def.json（真相源），一次生成／更新 scenes/world/painted/ 下
## 所有「有專案圖、非受保護」的 region×map 場景骨架與出入口 Area2D。
## 取代舊 per-地區腳本 build_painted_region / build_floret_town / build_north_mine
## （那些讀退休的 map-def.xlsx、把連通硬編碼在腳本裡、且用 1254/38 座標）。
##
## 設計依 docs/pipeline/地圖製作流程.md：
##   §1 真相分離——語意（通到哪／落點）在 map-def.json；幾何（碰撞／出入口位置）在場景，用「出口 id」綁定。
##   §5 工作流——本腳本只負責「建／同步骨架、擺出入口、填 to_scene/spawn_id」；碰撞留空是塊 B 的事、美術不動。
##
## 規則：
##   - 場景 id ＝ map 的 "scene" 覆寫，否則 region.scene_prefix ＋ KEY(大寫)。Background＝dir/file_prefix/key 推導的 1280 圖。
##   - 出口節點名＝map-def 的 exit key；side 決定出口帶位置；spawn_id＝同區 from_<來源key>／跨區沿用既有或 from_<來源場景id>。
##   - 落點：對每張圖，蒐集所有「指向我」的出口，在其相對邊建 from_<來源> 落點；既有手調座標優先保留。
##   - 待接整區（裸 Mx）或目標圖未就緒 → 該出口建成 disabled placeholder（enabled=false、無 to_scene）。
##   - 受保護場景（Town：含 NPC／門／過場／實例、且已符合 map-def）與既有含實例/Trigger/NPC/門的場景 → 完全不動。
##   - **手工節點不會被清掉**（2026-08-19）：重生成時，舊場景中不屬於生成器骨架的節點（設計員在編輯器
##     手加的裝飾樹、Props 群組等）會原樣搬進新場景的同一個父節點下；名稱與生成節點衝突時以生成的為準
##     並在報告列出。之前這些節點會在重生成時整批消失（nfr_a 的 7 棵樹踩過）。
##   - map 的 props 陣列可建立透明高物件：位置與 footprint 由同一筆資料定義；碰撞由 blueprint_to_paths.gd 消費。
##     prop 節點會帶 `prop_id`／`prop_type`／`prop_fp` metadata，供 `tools/scene_props_sync.py` 反向同步
##     （在編輯器手調位置 → 寫回 map-def，之後重生成就重現，不必每張重調）。
##     素材庫 meta.json 標 `layer:"ground"` 者（平貼地面的農作列等）掛進 `GroundProps`＝不參與 YSort、
##     不會依 y 遮住玩家；其餘（缺欄＝`"object"`）掛進 `YSort` 與玩家一起排序。旗標讀法比照
##     blueprint_to_paths.gd 的 walkable：直接讀素材庫 meta.json，不經 map-def（改素材不必回編輯器存檔）。
##   - 既有場景的 enc_group／cut_on_enter／落點座標／跨區落點名 → 用 SceneState 讀出保留（不硬編碼、不脫勾）。
##
## 執行：/Applications/Godot.app/Contents/MacOS/Godot --headless -s res://scripts/map/build_scenes.gd --path <godot-project>

const SIZE := 1280.0
const GRID := 40                        # map_w/h＝1280/32
const HALF := 640.0
const OUT_DIR := "res://scenes/world/painted/"
const TILESET := "res://resources/map/collision_tileset_32.tres"   # 塊 B 主格 32；本腳本只掛空層
const DETAIL_TILESET := "res://resources/map/collision_tileset_16.tres"
const PATH_TILESET := "res://resources/map/path_tileset_32.tres"
const PATH_DETAIL_TILESET := "res://resources/map/path_tileset_16.tres"
const WS := "res://scripts/world/world_scene.gd"
const EZ := "res://scripts/world/exit_zone.gd"
const PC := "res://scripts/world/player_controller.gd"
## 受保護：手工內容無法由 map-def 重現、且連通已符合 map-def，完全不重生。
const PROTECTED := ["Town"]

# 生成器自己會建的節點；不在這份名單裡的，一律視為設計員手加、重生成時要搬過去。
const GEN_ROOT_CHILDREN := ["Background", "Ground", "GroundProps", "CollisionPaint", "CollisionDetail",
	"PathPaint32", "PathPaint16", "Zones", "YSort"]
const GEN_SUB_CHILDREN := {"YSort": ["Player"], "GroundProps": [], "Zones": []}   # Zones 子節點＝map-def 出口，逐張比對
const GEN_PROP_PREFIX := "Prop_"                                                  # map-def props 生成的節點

const OPP := {
	"west": "east", "east": "west", "north": "south", "south": "north",
	"up": "down", "down": "up", "interior": "interior",
}
const EDGE_SIDES := ["west", "east", "north", "south"]

var _regions: Dictionary = {}
var _existing: Dictionary = {}          # scene_id -> {scene_id, fields, exits[], spawns, protected}
var _all_maps: Array = []               # 每個 region×map 一筆 entry（見 _index_maps）
var _generated_set: Dictionary = {}     # 已（重）生成的 scene_id
var _only_scene_id := ""                # 可選：只生成一張，避免新素材同步時碰到其他地圖
var _report := {
	"generated": [], "preserved": [], "pending": [], "placeholders": [], "empty_regions": [], "props": [],
	"resync": [], "cleared": [], "blueprint": [], "carried": [],
}


func _initialize() -> void:
	_run()


func _run() -> void:
	var mapdef := _load_mapdef()
	if mapdef.is_empty():
		quit(1)
		return
	_regions = mapdef.get("regions", {})
	_parse_only_scene()
	_index_maps()
	if _all_maps.is_empty():
		push_error("map-def.json 沒有任何 map")
		quit(1)
		return
	_read_existing_scenes()
	_resolve_all_exits()
	_generate()
	_collect_placeholders()
	_print_report()
	quit(0)


## 可用 `-- M5:a` 只同步單一 map；未指定時維持全量行為。
func _parse_only_scene() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	var parts := str(args[0]).split(":", false)
	if parts.size() != 2:
		push_error("單圖參數格式應為 Region:map，例如 M5:a")
		return
	var region_id := parts[0]
	var map_key := parts[1]
	if not _regions.has(region_id) or not (_regions[region_id].get("maps", {}) as Dictionary).has(map_key):
		push_error("map-def.json 找不到指定地圖：%s" % args[0])
		return
	_only_scene_id = _scene_id(region_id, map_key, _regions[region_id]["maps"][map_key])
	print("單圖同步：", _only_scene_id)


# ---------------------------------------------------------------------------
# 讀取
# ---------------------------------------------------------------------------

func _load_mapdef() -> Dictionary:
	var abs_path := ProjectSettings.globalize_path("res://").path_join("../assets-source/map/map-def.json")
	if not FileAccess.file_exists(abs_path):
		push_error("找不到 map-def.json：" + abs_path)
		return {}
	var txt := FileAccess.get_file_as_string(abs_path)
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("map-def.json 解析失敗")
		return {}
	print("讀 map-def.json：", abs_path)
	return data


func _index_maps() -> void:
	for rc: String in _regions:
		var reg: Dictionary = _regions[rc]
		var maps: Dictionary = reg.get("maps", {})
		if maps.is_empty():
			_report["empty_regions"].append("%s %s" % [rc, reg.get("name", "")])
			continue
		for k: String in maps:
			var m: Dictionary = maps[k]
			var sid := _scene_id(rc, k, m)
			var img := _image_path(reg, m, k)
			_all_maps.append({
				"r": rc, "k": k, "scene_id": sid, "map": m,
				"image": img, "has_image": _res_exists(img), "resolved": [],
			})


func _read_existing_scenes() -> void:
	var d := DirAccess.open(OUT_DIR)
	if d == null:
		return
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.ends_with(".tscn"):
			var info := _read_scene_state(OUT_DIR + fn)
			if info.get("scene_id", "") != "":
				_existing[info["scene_id"]] = info
		fn = d.get_next()
	d.list_dir_end()


## 用 SceneState 讀既有 .tscn 的「已存值」——不 instantiate（不觸發 _ready），安全。
func _read_scene_state(path: String) -> Dictionary:
	var ps := ResourceLoader.load(path) as PackedScene
	if ps == null:
		return {}
	var st := ps.get_state()
	var info := {"scene_id": "", "fields": {}, "exits": [], "spawns": {}, "protected": false, "col_tileset": "", "has_collision": false}
	for i in st.get_node_count():
		var nm := st.get_node_name(i)
		if st.get_node_instance(i) != null:
			info["protected"] = true          # 內含實例子場景（如 Town 的 DialogueBox）
		if nm.begins_with("Trigger"):
			info["protected"] = true
		var props := {}
		for j in st.get_node_property_count(i):
			props[st.get_node_property_name(i, j)] = st.get_node_property_value(i, j)
		if nm == "CollisionPaint":
			var tsv: Variant = props.get("tile_set", null)
			if tsv is TileSet and (tsv as TileSet).resource_path != "":
				info["col_tileset"] = (tsv as TileSet).resource_path
			var tmd: Variant = props.get("tile_map_data", null)
			if tmd is PackedByteArray and (tmd as PackedByteArray).size() > 0:
				info["has_collision"] = true
		if i == 0:
			info["scene_id"] = nm
			info["fields"] = props
			info["spawns"] = props.get("spawns", {})
			for lst in ["npc_list", "door_list"]:
				var v: Variant = props.get(lst, [])
				if v is Array and not (v as Array).is_empty():
					info["protected"] = true
		elif props.has("to_scene"):
			info["exits"].append({
				"name": nm, "to_scene": props.get("to_scene", ""), "spawn_id": props.get("spawn_id", ""),
			})
	return info


# ---------------------------------------------------------------------------
# 推導與解析
# ---------------------------------------------------------------------------

func _scene_id(rc: String, k: String, m: Dictionary) -> String:
	var sc: String = m.get("scene", "")
	if sc != "":
		return sc
	return str(_regions[rc].get("scene_prefix", "")) + k.to_upper()


func _image_path(reg: Dictionary, m: Dictionary, k: String) -> String:
	var ov: String = m.get("image", "")
	if ov != "":
		return ov
	return "res://assets/map/%s/%s_%s.png" % [reg.get("dir", ""), reg.get("file_prefix", ""), k]


func _res_exists(res_path: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(res_path))


func _resolve_all_exits() -> void:
	for e in _all_maps:
		var exits: Dictionary = (e["map"] as Dictionary).get("exits", {})
		var openings := _blueprint_openings(e["map"])          # side -> {lo,hi}（藍圖 E 格開口，可能為空）
		var side_count := {}                                   # 每 side 幾個出口：>1 則開口無法唯一對應
		for ek: String in exits:
			var sd := str((exits[ek] as Dictionary).get("side", ""))
			side_count[sd] = int(side_count.get(sd, 0)) + 1
		var resolved := []
		for ek: String in exits:
			var ex: Dictionary = exits[ek]
			var side := str(ex.get("side", ""))
			var to := str(ex.get("to", ""))
			var r := _resolve_target(e["r"], to)
			var spawn_id := ""
			if r["resolvable"]:
				spawn_id = _spawn_id_for(e, r)
			var opening: Variant = null
			if openings.has(side):
				if int(side_count.get(side, 0)) == 1:
					opening = openings[side]
					_report["blueprint"].append("%s.%s 用藍圖開口 %s[%d..%d]" %
						[e["scene_id"], ek, side, opening["lo"], opening["hi"]])
				else:
					_report["blueprint"].append("%s.%s side=%s 有多個出口共用、藍圖開口無法唯一對應 → 回退整邊" %
						[e["scene_id"], ek, side])
			resolved.append({
				"name": ek, "side": side,
				"to_scene": (r["tgt_scene_id"] if r["resolvable"] else ""),
				"spawn_id": spawn_id,
				"enabled": r["resolvable"],
				"resolvable": r["resolvable"],
				"tgt_desc": to, "reason": r.get("reason", ""),
				"opening": opening,
			})
		e["resolved"] = resolved


## 回傳 {resolvable, tgt_scene_id, tgt_r, tgt_k, reason}
func _resolve_target(rc: String, to: String) -> Dictionary:
	if ":" in to:
		var parts := to.split(":")
		return _resolve_map(parts[0], parts[1], "跨區")
	if _regions.has(to):
		return {"resolvable": false, "tgt_scene_id": "", "tgt_r": to, "reason": "待接整區 " + to}
	return _resolve_map(rc, to, "同區")


func _resolve_map(tr: String, tk: String, kind: String) -> Dictionary:
	if not _regions.has(tr) or not (_regions[tr].get("maps", {}) as Dictionary).has(tk):
		return {"resolvable": false, "tgt_scene_id": "", "reason": "%s目標 %s:%s 不存在" % [kind, tr, tk]}
	var tm: Dictionary = _regions[tr]["maps"][tk]
	var tsid := _scene_id(tr, tk, tm)
	var timg := _image_path(_regions[tr], tm, tk)
	if _res_exists(timg) or PROTECTED.has(tsid):
		return {"resolvable": true, "tgt_scene_id": tsid, "tgt_r": tr, "tgt_k": tk}
	return {"resolvable": false, "tgt_scene_id": tsid, "tgt_r": tr, "tgt_k": tk, "reason": "%s目標圖未就緒" % kind}


func _spawn_id_for(e: Dictionary, r: Dictionary) -> String:
	if r["tgt_r"] == e["r"]:
		return "from_" + e["k"]                       # 同區：from_<來源 map key>
	# 跨區：優先沿用既有場景該出口的落點名（保留 fromForest／fromMine 等 legacy 命名，不打斷既有導航）
	var src_id: String = e["scene_id"]
	if _existing.has(src_id):
		for ex in _existing[src_id]["exits"]:
			if ex["to_scene"] == r["tgt_scene_id"] and ex["spawn_id"] != "":
				return ex["spawn_id"]
	return "from_" + src_id                            # 跨區新連結：from_<來源場景 id>


## 某場景所需的全部落點：start ＋ 每個「指向我」的可用出口在「來源出口 side 的相對邊」的落點。
## 一律用計算座標，不沿用既有座標——因為重生場景（ef/efd）的連通方向可能已被 map-def 改版，
## 舊座標會落錯邊；真正需要手調座標的場景（Town/nm）都走「保留不重生」不會進到這裡。
func _spawns_for(scene_id: String) -> Dictionary:
	var sp := {"start": Vector2(HALF, HALF + 100.0)}
	for e in _all_maps:
		for rex in e["resolved"]:
			if rex["resolvable"] and rex["to_scene"] == scene_id:
				sp[rex["spawn_id"]] = _edge_spawn(OPP.get(rex["side"], ""))
	return sp


func _edge_spawn(side: String) -> Vector2:
	match side:
		"west": return Vector2(120.0, HALF)
		"east": return Vector2(SIZE - 120.0, HALF)
		"north": return Vector2(HALF, 120.0)
		"south": return Vector2(HALF, SIZE - 120.0)
		_: return Vector2(HALF, HALF + 100.0)         # up/down/interior：無邊，落中央（現況 M2–M4 未用）


## 讀 map 的 entrances 屬性（出入口專用層，獨立於 terrain）的 E 格，依「最近邊」分組，回傳 {side: {lo,hi}}。
## west/east 的 lo,hi 是 row 範圍；north/south 是 col 範圍。無 entrances 或無 E 格＝回空字典。
func _blueprint_openings(m: Dictionary) -> Dictionary:
	var ent: Variant = m.get("entrances", null)
	if not (ent is Array) or (ent as Array).is_empty():
		return {}
	var by_side := {}
	var rows: Array = ent
	for r in mini(rows.size(), GRID):
		var row := str(rows[r])
		for c in mini(row.length(), GRID):
			if row[c] != "E":
				continue
			var dw := c
			var de := GRID - 1 - c
			var dn := r
			var ds := GRID - 1 - r
			var nearest := mini(mini(dw, de), mini(dn, ds))
			var side := ""
			var idx := 0
			if nearest == dw:
				side = "west"
				idx = r
			elif nearest == de:
				side = "east"
				idx = r
			elif nearest == dn:
				side = "north"
				idx = c
			else:
				side = "south"
				idx = c
			if not by_side.has(side):
				by_side[side] = []
			(by_side[side] as Array).append(idx)
	var out := {}
	for sd: String in by_side:
		var arr: Array = by_side[sd]
		arr.sort()
		out[sd] = {"lo": int(arr[0]), "hi": int(arr[arr.size() - 1])}
	return out


func _exit_pos(side: String, opening: Variant = null) -> Vector2:
	var mid := HALF
	if opening != null:
		mid = (float(opening["lo"]) + float(opening["hi"]) + 1.0) * 0.5 * 32.0   # 開口中心（像素）
	match side:
		"west": return Vector2(22.0, mid)
		"east": return Vector2(SIZE - 22.0, mid)
		"north": return Vector2(mid, 22.0)
		"south": return Vector2(mid, SIZE - 22.0)
		_: return Vector2(HALF, HALF)


func _exit_size(side: String, opening: Variant = null) -> Vector2:
	var span := 1120.0
	if opening != null:
		span = (float(opening["hi"]) - float(opening["lo"]) + 1.0) * 32.0 + 32.0   # 開口寬＋各邊 16px 緩衝
	if side in ["west", "east"]:
		return Vector2(44.0, span)
	if side in ["north", "south"]:
		return Vector2(span, 44.0)
	return Vector2(200.0, 200.0)


# ---------------------------------------------------------------------------
# 生成
# ---------------------------------------------------------------------------

func _generate() -> void:
	for e in _all_maps:
		var sid: String = e["scene_id"]
		if _only_scene_id != "" and sid != _only_scene_id:
			continue
		if not e["has_image"]:
			_report["pending"].append("%s:%s (%s) 無專案圖 %s" % [e["r"], e["k"], sid, e["image"]])
			continue
		var reason := _preserve_reason(sid)
		if reason != "":
			_report["preserved"].append("%s（%s）" % [sid, reason])
			_check_preserved_sync(e)
			continue
		_build_scene(e)


## 回傳非空字串＝該場景要保留不動的原因；空＝可（重）生成。
func _preserve_reason(sid: String) -> String:
	if PROTECTED.has(sid):
		return "受保護清單"
	var info: Dictionary = _existing.get(sid, {})
	if info.get("protected", false):
		return "含實例/NPC/門/Trigger 手工內容"
	# 已有真實 32px 碰撞資料＝塊 B 已完成，重生會清掉；只有掛 tileset 但空層者不算。
	if info.get("has_collision", false) and str(info.get("col_tileset", "")).ends_with("collision_tileset_32.tres"):
		return "已含 32px 塊 B 碰撞，清除會毀工"
	return ""


## 保留的場景若連通與 map-def 不符，出警告（本輪不自動改，交由人工/後續同步）。
func _check_preserved_sync(e: Dictionary) -> void:
	var sid: String = e["scene_id"]
	var want := {}
	for rex in e["resolved"]:
		if rex["resolvable"]:
			want[rex["to_scene"]] = true
	var have := {}
	for ex in _existing.get(sid, {}).get("exits", []):
		if str(ex["to_scene"]) != "":
			have[ex["to_scene"]] = true
	for w in want:
		if not have.has(w):
			_report["resync"].append("%s 缺出口→%s（保留未動，需人工同步）" % [sid, w])
	for h in have:
		if not want.has(h):
			_report["resync"].append("%s 多出口→%s（map-def 已無此連通）" % [sid, h])


## 從舊場景撈出「不屬於生成器骨架」的節點（設計員手加的裝飾／群組），供重生成後原樣搬回。
## 回傳 {父節點路徑: [Node,…]}，路徑 ""＝根；找不到舊場景或載入失敗回空（不阻擋生成）。
func _collect_handmade(path: String) -> Dictionary:
	var out := {}
	if not _res_exists(path):
		return out
	var ps := ResourceLoader.load(path) as PackedScene
	if ps == null:
		return out
	var old_root := ps.instantiate()          # 不掛進 SceneTree，_ready 不會跑
	if old_root == null:
		return out
	for child in old_root.get_children():
		if not GEN_ROOT_CHILDREN.has(child.name):
			out.get_or_add("", []).append(child)
			continue
		if not GEN_SUB_CHILDREN.has(child.name):
			continue
		var known: Array = GEN_SUB_CHILDREN[child.name]
		for sub in child.get_children():
			if known.has(String(sub.name)) or String(sub.name).begins_with(GEN_PROP_PREFIX):
				continue
			if child.name == "Zones" and sub.get("to_scene") != null:
				continue                      # 出口由 map-def 重建，不搬
			out.get_or_add(String(child.name), []).append(sub)
	if out.is_empty():
		old_root.free()
	else:
		out["__root__"] = old_root            # 呼叫端搬完才 free（節點還掛在它底下）
	return out


## 把 _collect_handmade 撈到的節點複製進新場景的同一個父節點；名稱撞到生成節點就跳過並記錄。
func _restore_handmade(root: Node, carry: Dictionary, sid: String) -> void:
	for parent_path in carry:
		if parent_path == "__root__":
			continue
		var parent: Node = root if parent_path == "" else root.get_node_or_null(NodePath(parent_path))
		if parent == null:
			_report["carried"].append("%s：找不到父節點 %s，未搬 %d 個手工節點" % [
				sid, parent_path, (carry[parent_path] as Array).size()])
			continue
		for node: Node in carry[parent_path]:
			if parent.get_node_or_null(NodePath(String(node.name))) != null:
				_report["carried"].append("%s：%s/%s 與生成節點同名，保留生成的" % [sid, parent_path, node.name])
				continue
			var dup := node.duplicate()
			parent.add_child(dup)
			dup.owner = root
			for d in dup.find_children("*", "", true, false):
				d.owner = root
			_report["carried"].append("%s：搬回 %s/%s" % [sid, parent_path, node.name])
	var old_root: Variant = carry.get("__root__")
	if old_root is Node:
		(old_root as Node).free()


func _build_scene(e: Dictionary) -> void:
	var sid: String = e["scene_id"]
	var f: Dictionary = _existing.get(sid, {}).get("fields", {})
	var spawns := _spawns_for(sid)
	if _existing.get(sid, {}).get("has_collision", false):
		var old_col: String = _existing[sid].get("col_tileset", "")
		_report["cleared"].append("%s（原 %s，塊 B 於 1280 重刷）" % [sid, old_col.get_file()])

	var carry := _collect_handmade(OUT_DIR + _file_name(e))   # 舊場景的手工節點，pack 前搬回

	var root := Node2D.new()
	root.name = sid
	root.set_script(load(WS))
	root.set("scene_id", sid)
	root.set("map_w", GRID)
	root.set("map_h", GRID)
	root.set("enc_group", f.get("enc_group", ""))
	root.set("camera_zoom", f.get("camera_zoom", 1.8))
	root.set("bgm", f.get("bgm", ""))
	if f.has("cut_on_enter"):
		root.set("cut_on_enter", f["cut_on_enter"])
	if f.has("enc_rows"):
		root.set("enc_rows", f["enc_rows"])
	if f.has("blk_rows"):
		root.set("blk_rows", f["blk_rows"])
	root.set("spawns", spawns)

	var bg := Sprite2D.new()
	bg.name = "Background"
	bg.centered = false
	var tex := load(e["image"]) as Texture2D
	if tex != null:
		bg.texture = tex
	else:
		push_warning("圖載入失敗（未 import？）：" + e["image"])
	_add(root, bg, root)

	var ground := TileMapLayer.new()          # 手繪背景不用 atlas，空層即可（對齊 ef_a 範本）
	ground.name = "Ground"
	_add(root, ground, root)

	var col := TileMapLayer.new()             # 塊 B 專用，一律留空
	col.name = "CollisionPaint"
	var ts := load(TILESET) as TileSet
	if ts != null:
		col.tile_set = ts
	col.visible = false
	_add(root, col, root)
	var detail := TileMapLayer.new()
	detail.name = "CollisionDetail"
	var detail_ts := load(DETAIL_TILESET) as TileSet
	if detail_ts != null:
		detail.tile_set = detail_ts
	detail.visible = false
	_add(root, detail, root)

	# 設計員刷可走區的暫存層；invert_paths.gd 讀取後反轉為上述兩個碰撞層。
	var path32 := TileMapLayer.new()
	path32.name = "PathPaint32"
	var path32_ts := load(PATH_TILESET) as TileSet
	if path32_ts != null:
		path32.tile_set = path32_ts
	_add(root, path32, root)
	var path16 := TileMapLayer.new()
	path16.name = "PathPaint16"
	var path16_ts := load(PATH_DETAIL_TILESET) as TileSet
	if path16_ts != null:
		path16.tile_set = path16_ts
	_add(root, path16, root)

	var zones := Node2D.new()
	zones.name = "Zones"
	_add(root, zones, root)
	for rex in e["resolved"]:
		_add_exit(root, zones, rex)

	var ground_props := Node2D.new()          # layer:"ground" 的 prop：疊在背景上、不進 YSort（不會遮玩家）
	ground_props.name = "GroundProps"
	_add(root, ground_props, root)

	var ysort := Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	_add(root, ysort, root)
	_add_world_props(root, ysort, ground_props, e["map"].get("props", []))

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.set_script(load(PC))
	player.add_to_group("player", true)
	player.position = spawns["start"]
	_add(root, player, ysort)
	var pshape := CollisionShape2D.new()
	pshape.name = "Shape"
	pshape.position = Vector2(0.0, -1.0)
	var prect := RectangleShape2D.new()
	prect.size = Vector2(22.0, 14.0)
	pshape.shape = prect
	_add(root, pshape, player)
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	_add(root, cam, player)

	_restore_handmade(root, carry, sid)

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_DIR + _file_name(e))
	if err == OK:
		_report["generated"].append(sid)
		_generated_set[sid] = true
	else:
		push_error("儲存失敗 %s err=%s" % [sid, err])
	root.free()


func _add_world_props(root: Node, ysort: Node, ground_props: Node, raw_props: Variant) -> void:
	if not (raw_props is Array):
		return
	for i in (raw_props as Array).size():
		var raw: Variant = raw_props[i]
		if not (raw is Dictionary):
			push_warning("props[%d] 不是物件，略過" % i)
			continue
		var prop: Dictionary = raw
		var cell: Variant = prop.get("cell", [])
		if not (cell is Array) or cell.size() < 2:
			push_warning("props[%d] 缺 cell，略過" % i)
			continue
		var fp := _prop_footprint(prop)              # 素材庫決定，不看 map-def
		var w := fp.x
		var h := fp.y
		var asset_path := _prop_asset_path(prop, w, h)
		var tex := load(asset_path) as Texture2D
		if tex == null:
			_report["props"].append("略過 %s（尚無素材 %s）" % [prop.get("id", "(未命名)"), asset_path])
			continue
		var is_ground: bool = _prop_layer(prop) == "ground"
		var holder := Node2D.new()
		holder.name = "Prop_%s_%d" % [_node_safe_name(str(prop.get("id", "world"))), i]
		# 身分標記：供 tools/scene_props_sync.py 把編輯器手調的位置寫回 map-def（節點名會被 _node_safe_name
		# 洗掉數字等字元，認不回素材，故另存 meta）。
		holder.set_meta("prop_id", str(prop.get("id", "")))
		holder.set_meta("prop_type", str(prop.get("type", "structure")))
		holder.set_meta("prop_fp", Vector2i(w, h))
		var asset_override := str(prop.get("asset", ""))
		if asset_override != "":
			holder.set_meta("prop_asset", asset_override)
		holder.position = Vector2((float(cell[0]) + float(w) * 0.5) * 32.0, (float(cell[1]) + float(h)) * 32.0)
		_add(root, holder, ground_props if is_ground else ysort)
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = tex
		sprite.position = Vector2(0.0, -float(tex.get_height()) * 0.5)
		_add(root, sprite, holder)
		var tag := "　地面層" if is_ground else ""
		_report["props"].append("%s @ [%d,%d] %dx%d%s" % [prop.get("id", "(未命名)"), int(cell[0]), int(cell[1]), w, h, tag])


var _prop_meta_cache := {}                # id → {"meta": Dictionary, "dir": String}


## 素材庫 meta.json＝素材層級規格（footprint／walkable／layer）的真相源。
## 用 type＋id **掃描** <footprint> 那層目錄找檔——不能反過來拿 map-def 的 footprint 去拼路徑，
## 否則校正後改了 footprint 就再也找不到自己的 meta。目錄名只是歸檔，值以 meta.json 為準。
func _prop_meta(prop: Dictionary) -> Dictionary:
	var id := str(prop.get("id", ""))
	if id == "":
		return {}
	if not _prop_meta_cache.has(id):
		var base := ProjectSettings.globalize_path("res://").path_join(
			"../assets-source/props/world/%s" % str(prop.get("type", "structure")))
		var found := {"meta": {}, "dir": ""}
		var da := DirAccess.open(base)
		if da != null:
			for sub in da.get_directories():
				var f := base.path_join("%s/%s/meta.json" % [sub, id])
				if FileAccess.file_exists(f):
					var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
					found = {"meta": (v if v is Dictionary else {}), "dir": sub}
					break
		_prop_meta_cache[id] = found
	return _prop_meta_cache[id]["meta"]


## footprint＝**素材層級**規格：同一素材擺到哪張圖都是同一套碰撞（校正一次全域生效）。
## map-def 不再逐筆存；只有素材庫查不到時才退回用 map-def 那份。
func _prop_footprint(prop: Dictionary) -> Vector2i:
	var fp: Variant = _prop_meta(prop).get("footprint", null)
	if fp is Array and (fp as Array).size() >= 2:
		return Vector2i(maxi(1, int(fp[0])), maxi(1, int(fp[1])))
	var raw: Variant = prop.get("footprint", [])
	if raw is Array and (raw as Array).size() >= 2:
		push_warning("素材庫查無 %s 的 meta.json，改用 map-def 的 footprint" % str(prop.get("id", "")))
		return Vector2i(maxi(1, int(raw[0])), maxi(1, int(raw[1])))
	push_warning("無法決定 %s 的 footprint，當 1x1" % str(prop.get("id", "")))
	return Vector2i(1, 1)


## 素材的擺放層：`"ground"`＝平貼地面、掛 GroundProps 不進 YSort；缺欄＝`"object"`（一般高物件）。
func _prop_layer(prop: Dictionary) -> String:
	var override := str(prop.get("layer", ""))
	if override != "":
		return override
	return str(_prop_meta(prop).get("layer", "object"))


func _prop_asset_path(prop: Dictionary, w: int, h: int) -> String:
	var override := str(prop.get("asset", ""))
	if override != "":
		return override if override.begins_with("res://") else "res://assets/props/world/" + override
	var id := str(prop.get("id", ""))
	_prop_meta(prop)                                 # 確保快取有值（順便拿到實際歸檔目錄）
	var dir := str(_prop_meta_cache.get(id, {}).get("dir", ""))
	if dir == "":
		dir = "%dx%d" % [w, h]                       # 素材庫查不到就照 footprint 推（舊行為）
	return "res://assets/props/world/%s/%s/%s.png" % [str(prop.get("type", "structure")), dir, id]


func _node_safe_name(value: String) -> String:
	var out := ""
	for ch in value:
		out += ch if ch.is_valid_identifier() else "_"
	return out if out != "" else "world"


## 全域蒐集待接/跨區未就緒出口（含保留場景未建的），供人工追蹤。
func _collect_placeholders() -> void:
	for e in _all_maps:
		if not e["has_image"]:
			continue                      # 缺圖場景本身未建，已列在 pending
		var sid: String = e["scene_id"]
		var built: bool = _generated_set.has(sid)
		for rex in e["resolved"]:
			if rex["resolvable"]:
				continue
			var note := "已建 disabled placeholder" if built else "保留場景，未建節點"
			_report["placeholders"].append("%s.%s → %s（%s，%s）" % [sid, rex["name"], rex["tgt_desc"], rex["reason"], note])


func _add_exit(root: Node, zones: Node, rex: Dictionary) -> void:
	var opening: Variant = rex.get("opening", null)          # 藍圖開口（無藍圖＝null＝維持整邊粗長條）
	var area := Area2D.new()
	area.name = rex["name"]
	area.set_script(load(EZ))
	area.position = _exit_pos(rex["side"], opening)
	area.set("to_scene", rex["to_scene"])
	area.set("spawn_id", rex["spawn_id"])
	area.set("enabled", rex["enabled"])
	_add(root, area, zones)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = _exit_size(rex["side"], opening)
	shape.shape = rect
	_add(root, shape, area)


func _add(root: Node, node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = root


func _file_name(e: Dictionary) -> String:
	return "%s_%s.tscn" % [_regions[e["r"]].get("file_prefix", ""), e["k"]]


# ---------------------------------------------------------------------------
# 報告
# ---------------------------------------------------------------------------

func _print_report() -> void:
	print("\n===== build_scenes 報告 =====")
	print("生成／更新 %d：%s" % [_report["generated"].size(), ", ".join(_report["generated"])])
	print("保留不動 %d：%s" % [_report["preserved"].size(), ", ".join(_report["preserved"])])
	print("碰撞層重置（舊料清除）%d：" % _report["cleared"].size())
	for c in _report["cleared"]:
		print("   ", c)
	print("保留場景連通不符警告 %d：" % _report["resync"].size())
	for r in _report["resync"]:
		print("   ", r)
	print("待接 placeholder %d：" % _report["placeholders"].size())
	for p in _report["placeholders"]:
		print("   ", p)
	print("缺圖略過 %d：" % _report["pending"].size())
	for p in _report["pending"]:
		print("   ", p)
	print("空地區 %d：%s" % [_report["empty_regions"].size(), ", ".join(_report["empty_regions"])])
	print("藍圖出入口 %d：" % _report["blueprint"].size())
	for b in _report["blueprint"]:
		print("   ", b)
	print("手工節點搬移 %d：" % _report["carried"].size())
	for c in _report["carried"]:
		print("   ", c)
	print("世界物件 %d：" % _report["props"].size())
	for p in _report["props"]:
		print("   ", p)
	print("SCENE_PATHS 需登錄（新場景）：")
	for e in _all_maps:
		if _report["generated"].has(e["scene_id"]) and not _existing.has(e["scene_id"]):
			print("   \"%s\": \"%s%s\"," % [e["scene_id"], OUT_DIR, _file_name(e)])
