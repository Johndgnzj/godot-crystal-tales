extends SceneTree
func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var cdb: Node = root.get_node_or_null("/root/ContentDB")
	var g := 0
	while cdb != null and not cdb.is_loaded and g < 240:
		await process_frame
		g += 1
	load("res://scripts/game_flow.gd").new_game()
	var gs: Node = root.get_node("/root/GameState")
	# 把三主角都放進隊伍，量各自的攻擊幀縮放
	for id in ["marin", "alan"]:
		var tmpl = cdb.get_party_member(id)
		if tmpl != null:
			var m := {"id": id, "name": tmpl.display_name, "cls": tmpl.char_class, "lv": 1, "exp": 0,
				"attrs": tmpl.base_attrs.duplicate(), "sk": {}, "eq": tmpl.start_eq.duplicate(), "pts": 0, "spts": 0,
				"sprite": id}
			gs.party.append(m)
	gs.encounter = "forest"
	var host: Node = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(host)
	await process_frame
	for n in host._hero_nodes:
		var u: Dictionary = n["unit"]
		var fits: Array = n["atk_fit"]
		var bots: Array = n["atk_bot"]
		var extra := 1.0
		if host.ATTACK_SCALE.has(String(u.get("sprite",""))):
			extra = float(host.ATTACK_SCALE[String(u.get("sprite",""))])
		var line := "%s idle_bot=%.1f 幀數=%d " % [u.get("name"), float(n["idle_bot"]), fits.size()]
		for i in fits.size():
			line += "[%d] fit=%.2f 總倍率=%.2f 腳位移=%.1f  " % [i, float(fits[i]), float(fits[i]) * extra, float(n["idle_bot"]) - float(bots[i]) * float(fits[i]) * extra]
		print(line)
	quit(0)
