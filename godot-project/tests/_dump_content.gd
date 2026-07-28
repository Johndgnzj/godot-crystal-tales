extends SceneTree
## 內容資料全量 dump（遷移前後對 diff 用）。輸出 JSON 到 user args[0]。
func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var cdb: Node = root.get_node_or_null("/root/ContentDB")
	var g := 0
	while cdb != null and not cdb.is_loaded and g < 240:
		await process_frame
		g += 1
	var db = load("res://resources/content/content_db.tres")
	var out := {}
	for arr_name in ["party", "equipment", "skills", "items", "enemies", "encounters", "shops", "chests"]:
		var rows := []
		for r in db.get(arr_name):
			rows.append(_props(r))
		rows.sort_custom(func(a, b): return JSON.stringify(a) < JSON.stringify(b))
		out[arr_name] = rows
	for single in ["derived", "pacing"]:
		out[single] = _props(db.get(single))
	var path: String = OS.get_cmdline_user_args()[0]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("dumped → ", path, "（", out["equipment"].size(), " equipment / ", out["enemies"].size(), " enemies）")
	quit(0)


func _props(r: Resource) -> Dictionary:
	var d := {}
	if r == null:
		return d
	for p in r.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			d[p["name"]] = r.get(p["name"])
	return d
