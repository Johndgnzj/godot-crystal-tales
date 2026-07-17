extends SceneTree

## build_dialogue_tres.gd — 種子匯入：把 res://resources/content/dialogue.json 轉成原生 .tres。
## 比照 scripts/content/build_tres.gd（CONTENT 版）的做法，對話版獨立一支。
##
## 產出：
##   resources/content/dialogue/npc/<npc_id>.tres    （NpcDialogue，內嵌 DialogueEntry 子資源）
##   resources/content/dialogue/cuts/<cut_id>.tres    （CutsceneEntry，內嵌 CutsceneLine 子資源）
##   resources/content/dialogue/dialogue_db.tres      （DialogueDatabase 聚合，ExtResource 引用上面全部）
##
## 執行（headless，跑一次即可；dialogue.json 有更新時才重跑）：
##   /Applications/Godot.app/Contents/MacOS/Godot --headless -s res://scripts/dialogue/build_dialogue_tres.gd --path .
## 若首次跑報「Could not find type NpcDialogue…」，先跑一次 `--headless --import`（完整跑到 exit 0）
## 讓新 class_name 進 global_script_class_cache.cfg，再重跑本腳本。
##
## 產生後資料真相源＝這些 .tres（設計員在 Inspector 編輯）；DialogueSystem 改讀 dialogue_db.tres。
## dialogue.json 自此降級為「種子」（同 content.json 地位），僅重匯入時用。

const SRC := "res://resources/content/dialogue.json"
const BASE := "res://resources/content/dialogue/"


func _init() -> void:
	var txt := FileAccess.get_file_as_string(SRC)
	if txt == "":
		push_error("build_dialogue_tres: 讀不到 %s" % SRC)
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("build_dialogue_tres: dialogue.json 頂層必須是物件")
		quit(1)
		return
	var d: Dictionary = parsed
	var db := DialogueDatabase.new()
	var npc_count := 0
	var cut_count := 0

	var dlg: Dictionary = d.get("dlg", {})
	for npc_id in dlg.keys():
		var nd := NpcDialogue.new()
		nd.id = npc_id
		var entries: Array[DialogueEntry] = []
		for e in dlg[npc_id]:
			entries.append(DialogueEntry.from_dict(e))
		nd.entries = entries
		_save(nd, "npc", npc_id)
		db.npcs.append(nd)
		npc_count += 1

	var cuts: Dictionary = d.get("cuts", {})
	for cut_id in cuts.keys():
		var ce := CutsceneEntry.from_dict(cut_id, cuts[cut_id])
		_save(ce, "cuts", cut_id)
		db.cutscenes.append(ce)
		cut_count += 1

	var err := ResourceSaver.save(db, BASE + "dialogue_db.tres")
	if err != OK:
		push_error("build_dialogue_tres: 存 dialogue_db.tres 失敗 err=%s" % err)
		quit(1)
		return

	print("build_dialogue_tres: 產生 %d 個 NPC ＋ %d 段過場 .tres ＋ dialogue_db.tres 聚合" % [npc_count, cut_count])
	quit(0)


func _save(res: Resource, subdir: String, id: String) -> void:
	var dir_path := BASE + subdir
	DirAccess.make_dir_recursive_absolute(dir_path)
	var path := dir_path + "/" + id + ".tres"
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("build_dialogue_tres: 存 %s 失敗 err=%s" % [path, err])
		return
	# 讓 res 認得自己的 res:// 路徑：之後 append 進聚合 db，存 dialogue_db.tres 時就會寫成
	# ExtResource 外部引用（而非把整份內容再內嵌一次）。設計員編個別 .tres 即直接生效，個別檔＝真相源。
	res.take_over_path(path)
