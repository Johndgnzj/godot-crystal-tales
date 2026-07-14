extends SceneTree

## build_tres.gd — 一次性匯入：把 res://resources/content/content.json 轉成原生 .tres。
##
## 產出：
##   resources/content/{party,equipment,skills,items,enemies,encounters,shops,chests}/<id>.tres
##   resources/content/derived.tres、pacing.tres
##   resources/content/content_db.tres（ContentDatabase 聚合，引用上面全部）
##
## 執行（headless，跑一次即可；content.json 有更新時才重跑）：
##   /Applications/Godot.app/Contents/MacOS/Godot --headless -s res://scripts/content/build_tres.gd --path .
##
## 產生後，資料真相源就是這些 .tres（設計員在 Inspector 編輯）；ContentDB 改讀 content_db.tres。

const SRC := "res://resources/content/content.json"
const BASE := "res://resources/content/"


func _init() -> void:
	var txt := FileAccess.get_file_as_string(SRC)
	if txt == "":
		push_error("build_tres: 讀不到 %s" % SRC)
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("build_tres: content.json 頂層必須是物件")
		quit(1)
		return
	var d: Dictionary = parsed
	var db := ContentDatabase.new()
	var total := 0

	for e in d.get("party", []):
		var r := PartyMemberDef.from_dict(e)
		_save(r, "party", r.id); db.party.append(r); total += 1
	for e in d.get("equipment", []):
		var r := EquipmentDef.from_dict(e)
		_save(r, "equipment", r.id); db.equipment.append(r); total += 1
	for e in d.get("skills", []):
		var r := SkillDef.from_dict(e)
		_save(r, "skills", r.id); db.skills.append(r); total += 1
	for e in d.get("items", []):
		var r := ItemDef.from_dict(e)
		_save(r, "items", r.id); db.items.append(r); total += 1
	for e in d.get("enemies", []):
		var r := EnemyDef.from_dict(e)
		_save(r, "enemies", r.id); db.enemies.append(r); total += 1
	for e in d.get("chests", []):
		var r := ChestDef.from_dict(e)
		_save(r, "chests", r.id); db.chests.append(r); total += 1

	var enc: Dictionary = d.get("encounters", {})
	for map_id in enc.keys():
		var r := EncounterDef.from_dict(map_id, enc[map_id])
		_save(r, "encounters", map_id); db.encounters.append(r); total += 1

	var shops: Dictionary = d.get("shops", {})
	for sid in shops.keys():
		var r := ShopDef.from_dict(sid, shops[sid])
		_save(r, "shops", sid); db.shops.append(r); total += 1

	db.derived = DerivedParams.from_dict(d.get("derived", {}))
	_save(db.derived, "", "derived"); total += 1
	db.pacing = PacingParams.from_dict(d.get("pacing", {}))
	_save(db.pacing, "", "pacing"); total += 1

	var err := ResourceSaver.save(db, BASE + "content_db.tres")
	if err != OK:
		push_error("build_tres: 存 content_db.tres 失敗 err=%s" % err)
		quit(1)
		return

	print("build_tres: 產生 %d 個實體 .tres ＋ content_db.tres 聚合" % total)
	quit(0)


func _save(res: Resource, subdir: String, id: String) -> void:
	var dir_path := BASE + subdir
	if subdir != "":
		DirAccess.make_dir_recursive_absolute(dir_path)
	var path := (dir_path + "/" if subdir != "" else BASE) + id + ".tres"
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("build_tres: 存 %s 失敗 err=%s" % [path, err])
