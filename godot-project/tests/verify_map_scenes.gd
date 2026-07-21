extends SceneTree
## 一次性驗證：塊 C 生成的手繪場景骨架＋出入口是否與 map-def.json 一致、連通、無斷點。
## 不 instantiate（用 SceneState 讀），避免觸發 world_scene _ready 依賴 autoload。
## 執行：/Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/verify_map_scenes.gd --path <godot-project>

const OUT_DIR := "res://scenes/world/painted/"

var _regions: Dictionary = {}
var _scenes: Dictionary = {}     # scene_id -> {spawns:{}, exits:[{name,to_scene,spawn_id,enabled}], path}
var _errors: Array = []
var _warns: Array = []
var _ok: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_load_mapdef()
	_load_scenes()
	_check_exits_vs_mapdef()
	_check_spawn_targets()
	_check_bfs()
	_print()
	quit(1 if not _errors.is_empty() else 0)


func _load_mapdef() -> void:
	var p := ProjectSettings.globalize_path("res://").path_join("../assets-source/map/map-def.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(data) == TYPE_DICTIONARY:
		_regions = data.get("regions", {})
	else:
		_errors.append("map-def.json 讀不到/解析失敗")


func _load_scenes() -> void:
	var d := DirAccess.open(OUT_DIR)
	if d == null:
		_errors.append("開不了 " + OUT_DIR)
		return
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir() and fn.ends_with(".tscn"):
			_load_one(OUT_DIR + fn)
		fn = d.get_next()
	d.list_dir_end()


func _load_one(path: String) -> void:
	var ps := ResourceLoader.load(path) as PackedScene
	if ps == null:
		_errors.append("載入失敗（PackedScene null）：" + path)
		return
	var st := ps.get_state()
	if st == null:
		_errors.append("get_state null：" + path)
		return
	var sid := ""
	var spawns := {}
	var exits := []
	var has_player := false
	var has_bg := false
	for i in st.get_node_count():
		var nm := st.get_node_name(i)
		var props := {}
		for j in st.get_node_property_count(i):
			props[st.get_node_property_name(i, j)] = st.get_node_property_value(i, j)
		if i == 0:
			sid = nm
			spawns = props.get("spawns", {})
		elif props.has("to_scene"):
			exits.append({
				"name": nm, "to_scene": str(props.get("to_scene", "")),
				"spawn_id": str(props.get("spawn_id", "")), "enabled": bool(props.get("enabled", true)),
			})
		if nm == "Player":
			has_player = true
		if nm == "Background":
			has_bg = true
	if sid == "":
		_errors.append("讀不到 scene_id（root name）：" + path)
		return
	if not has_player:
		_errors.append("%s 缺 Player 節點" % sid)
	if not has_bg:
		_errors.append("%s 缺 Background 節點" % sid)
	_scenes[sid] = {"spawns": spawns, "exits": exits, "path": path}
	_ok += 1


# ---- 逐一比對每張圖的出入口與 map-def（按「目標集合」比對，name-agnostic：
#      生成場景用 map-def key 當節點名、保留場景用 legacy 名如 ExitN，兩者都適用）----
func _check_exits_vs_mapdef() -> void:
	for rc: String in _regions:
		var reg: Dictionary = _regions[rc]
		for k: String in reg.get("maps", {}):
			var m: Dictionary = reg["maps"][k]
			var sid := _scene_id(rc, k, m)
			if not _scenes.has(sid):
				if _has_image(reg, m, k):
					_errors.append("map-def 有 %s 且有圖，但找不到場景檔" % sid)
				continue
			var have: Dictionary = {}          # 此場景所有 enabled 出口的目標
			for ex in _scenes[sid]["exits"]:
				if ex["enabled"] and ex["to_scene"] != "":
					have[ex["to_scene"]] = true
			var want: Dictionary = {}          # map-def 的可解析目標
			for ek: String in m.get("exits", {}):
				var mex: Dictionary = m["exits"][ek]
				var r := _resolve(rc, str(mex.get("to", "")))
				if r["resolvable"]:
					want[r["tgt"]] = true
				else:
					_warns.append("%s 待接出口 '%s'→%s（disabled/未建，可接受）" % [sid, ek, mex.get("to", "")])
			for w: String in want:
				if not have.has(w):
					_errors.append("%s 缺往 %s 的出口" % [sid, w])
			for h: String in have:
				if not want.has(h):
					_errors.append("%s 多出往 %s 的出口（map-def 無此連通）" % [sid, h])


# ---- 每個 enabled 出口的 to_scene 必存在、且目標有對應 spawn ----
func _check_spawn_targets() -> void:
	for sid: String in _scenes:
		for ex in _scenes[sid]["exits"]:
			if not ex["enabled"] or ex["to_scene"] == "":
				continue
			var tgt: String = ex["to_scene"]
			if not _scenes.has(tgt):
				_errors.append("%s.%s → 場景 %s 不存在" % [sid, ex["name"], tgt])
				continue
			var sp: String = ex["spawn_id"]
			if sp != "" and not (_scenes[tgt]["spawns"] as Dictionary).has(sp):
				_errors.append("%s.%s → %s 缺落點 '%s'（該場景落點：%s）"
					% [sid, ex["name"], tgt, sp, ", ".join((_scenes[tgt]["spawns"] as Dictionary).keys())])


# ---- 從 start（M1 town）BFS，確認可走到所有已生成場景 ----
func _check_bfs() -> void:
	var start := "Town"
	if not _scenes.has(start):
		_errors.append("找不到起點場景 Town")
		return
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for ex in _scenes[cur]["exits"]:
			if not ex["enabled"] or ex["to_scene"] == "":
				continue
			var t: String = ex["to_scene"]
			if _scenes.has(t) and not seen.has(t):
				seen[t] = true
				queue.append(t)
	for sid: String in _scenes:
		if not seen.has(sid):
			_errors.append("BFS：從 Town 走不到 %s（連通斷點）" % sid)


# ---- helpers ----
func _scene_id(rc: String, k: String, m: Dictionary) -> String:
	var sc: String = m.get("scene", "")
	return sc if sc != "" else str(_regions[rc].get("scene_prefix", "")) + k.to_upper()


func _has_image(reg: Dictionary, m: Dictionary, k: String) -> bool:
	var ov: String = m.get("image", "")
	var path := ov if ov != "" else "res://assets/map/%s/%s_%s.png" % [reg.get("dir", ""), reg.get("file_prefix", ""), k]
	return FileAccess.file_exists(ProjectSettings.globalize_path(path))


func _resolve(rc: String, to: String) -> Dictionary:
	if ":" in to:
		var pr := to.split(":")
		return _resolve_map(pr[0], pr[1])
	if _regions.has(to):
		return {"resolvable": false, "tgt": ""}
	return _resolve_map(rc, to)


func _resolve_map(tr: String, tk: String) -> Dictionary:
	if not _regions.has(tr) or not (_regions[tr].get("maps", {}) as Dictionary).has(tk):
		return {"resolvable": false, "tgt": ""}
	var tm: Dictionary = _regions[tr]["maps"][tk]
	var tsid := _scene_id(tr, tk, tm)
	if _has_image(_regions[tr], tm, tk):
		return {"resolvable": true, "tgt": tsid}
	return {"resolvable": false, "tgt": tsid}


func _print() -> void:
	print("\n===== verify_map_scenes 結果 =====")
	print("載入場景 %d：%s" % [_ok, ", ".join(_scenes.keys())])
	print("警告 %d：" % _warns.size())
	for w in _warns:
		print("   ⚠ ", w)
	print("錯誤 %d：" % _errors.size())
	for e in _errors:
		print("   ✗ ", e)
	print("結論：", "全綠 ✅" if _errors.is_empty() else "有錯 ❌")
