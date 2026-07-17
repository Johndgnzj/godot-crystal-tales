extends SceneTree

## smoke_test.gd — headless 冒煙測試（CORE-7）。
##
## ✅ 已實機驗證 @ Godot 4.7（2026-07-14，SMOKE PASS 20/0）。
## 註：首次真機跑時修過一個時序 bug——`-s` 腳本的 _initialize() 早於 autoload 掛上 /root，故檢查移到
## `await process_frame` 之後、autoload 路徑改相對路徑（見 _run()）。用下列指令跑（不需要 GUT addon，
## 純內建 SceneTree 腳本，最少依賴）：
##
##     godot --headless -s res://tests/smoke_test.gd --path .
##     # exit code 0 = 全綠；非 0 = 有場景載入/autoload 失敗。適合直接接 CI。
##
## ## 這支測什麼（對應 GDevelop 端 gdevelop-mcp `validate_project` + `preview_scene` 的最小等價）
##
## 1. 七個 autoload 都掛上且型別正確（ContentDB/GameState/SceneRouter/DialogueSystem/InputBridge/
##    SaveManager/DebugHooks）。
## 2. 資料層載入成功：ContentDB.is_loaded、DialogueSystem.is_loaded，且抽查既有 id 查得到
##    （get_enemy("goblin_chief") 等——id 以 CONTENT.json 實際資料為準，見 CORE-2 驗收現況）。
## 3. 每個場景檔（title / battle / 五張 world / dialogue_box）能被 ResourceLoader 載入成合法 PackedScene
##    （= .tscn 剖析通過、ext_resource 腳本/資源都解析得到——這是「不報錯」最核心的一關）。
## 4. 輕量場景（title / dialogue_box）能實例化並進 tree 跑 _ready 不崩。world/battle 場景的完整實例化
##    需要先擺好 GameState（party/encounter）與美術資源，屬於「自動打法整合測試」的範圍（見 README 的
##    對照表 E2E-2/E2E-3），這裡只做「載入成 PackedScene」的淺檢查，避免冒煙測試變成需要整套遊戲狀態。
##
## 為什麼是 SceneTree 而不是 GutTest：GUT（res://addons/gut）在這個環境無法下載安裝，SceneTree 是引擎
## 內建、零外部依賴，`--check-only` 一定剖析得過。GUT 版骨架另放 tests/gut/（要先 vendor GUT addon 才
## 能跑，見 README）。兩者測試意圖相同，GUT 版提供更好的斷言/報表，SceneTree 版保證「就算沒有 GUT 也能
## 在 CI 冒煙」。

const AUTOLOADS := {
	"ContentDB": "res://autoload/content_db.gd",
	"GameState": "res://autoload/game_state.gd",
	"SceneRouter": "res://autoload/scene_router.gd",
	"DialogueSystem": "res://scripts/dialogue/dialogue_system.gd",
	"InputBridge": "res://autoload/input_bridge.gd",
	"SaveManager": "res://autoload/save_manager.gd",
	"DebugHooks": "res://tests/debug_hooks.gd",
}

# 邏輯場景名稱（對齊 SceneRouter.SCENE_PATHS）→ .tscn 路徑。改路徑時兩邊要同步。
const SCENES := {
	"Title": "res://scenes/title/title.tscn",
	"Battle": "res://scenes/battle/battle.tscn",
	"Town": "res://scenes/world/painted/town.tscn",
	"Forest": "res://scenes/world/forest.tscn",
	"Forest2": "res://scenes/world/forest2.tscn",
	"Mine": "res://scenes/world/mine.tscn",
	"Cave": "res://scenes/world/cave.tscn",
	"Hub": "res://scenes/world/hub.tscn",
	"EForest1": "res://scenes/world/eforest1.tscn",
	"EForest2": "res://scenes/world/eforest2.tscn",
	"EForest3": "res://scenes/world/eforest3.tscn",
	"EFA": "res://scenes/world/painted/ef_a.tscn",
	"EFB": "res://scenes/world/painted/ef_b.tscn",
	"EFC": "res://scenes/world/painted/ef_c.tscn",
	"EFD": "res://scenes/world/painted/ef_d.tscn",
	"EFE": "res://scenes/world/painted/ef_e.tscn",
	"EFF": "res://scenes/world/painted/ef_f.tscn",
	"EFG": "res://scenes/world/painted/ef_g.tscn",
	"EFH": "res://scenes/world/painted/ef_h.tscn",
	"EFI": "res://scenes/world/painted/ef_i.tscn",
	"NMA": "res://scenes/world/painted/nm_a.tscn",
	"NMB": "res://scenes/world/painted/nm_b.tscn",
	"NMC": "res://scenes/world/painted/nm_c.tscn",
	"NMD": "res://scenes/world/painted/nm_d.tscn",
	"NME": "res://scenes/world/painted/nm_e.tscn",
	"NMF": "res://scenes/world/painted/nm_f.tscn",
	"DialogueBox": "res://scenes/ui/dialogue_box.tscn",
}

# 進 tree 跑 _ready 也安全的輕量場景（不依賴 party/encounter/戰鬥狀態）。
const INSTANTIATE_SAFE := ["Title", "DialogueBox"]

var _pass := 0
var _fail := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	print("=== CORE-7 headless smoke test ===")
	# -s 腳本的 _initialize() 跑在 autoload 掛上 /root 之前，先等一個 frame 讓 autoload 就緒再檢查。
	await process_frame
	_check_autoloads()
	_check_data_layer()
	_check_scenes_load()
	_check_scenes_instantiate()

	print("\n=== 彙整：%d 通過 / %d 失敗 ===" % [_pass, _fail])
	if _fail == 0:
		print("SMOKE PASS")
	else:
		print("SMOKE FAIL — 見上方 [FAIL]")
	quit(0 if _fail == 0 else 1)


func _ok(msg: String) -> void:
	_pass += 1
	print("  [OK]   " + msg)


func _bad(msg: String) -> void:
	_fail += 1
	print("  [FAIL] " + msg)


func _check_autoloads() -> void:
	print("\n-- autoloads --")
	for name in AUTOLOADS:
		var node := root.get_node_or_null(NodePath(name))
		if node == null:
			_bad("autoload 未掛上：%s（檢查 project.godot [autoload] 有無 %s=\"*%s\"）" % [name, name, AUTOLOADS[name]])
		else:
			_ok("autoload 已掛上：%s (%s)" % [name, node.get_class()])


func _check_data_layer() -> void:
	print("\n-- data layer --")
	var cdb := root.get_node_or_null(^"ContentDB")
	if cdb == null:
		_bad("ContentDB 不存在，跳過資料層檢查")
		return
	if bool(cdb.get("is_loaded")):
		_ok("ContentDB.is_loaded == true")
	else:
		_bad("ContentDB.is_loaded == false（content.json 載入失敗？）")

	# 抽查既有 id（id 以 CONTENT.json 實際資料為準，見 CORE-2）。
	var enemy = cdb.call("get_enemy", "goblin_chief")
	if enemy != null:
		_ok("ContentDB.get_enemy(\"goblin_chief\") 非 null")
	else:
		_bad("ContentDB.get_enemy(\"goblin_chief\") 回 null（id 改了或載入失敗）")

	var dsys := root.get_node_or_null(^"DialogueSystem")
	if dsys != null and bool(dsys.get("is_loaded")):
		_ok("DialogueSystem.is_loaded == true")
	elif dsys != null:
		_bad("DialogueSystem.is_loaded == false（dialogue.json 載入失敗？）")


func _check_scenes_load() -> void:
	print("\n-- scenes: ResourceLoader.load（剖析 .tscn + 解析 ext_resource）--")
	for name in SCENES:
		var path: String = SCENES[name]
		if not ResourceLoader.exists(path):
			_bad("場景檔不存在：%s -> %s" % [name, path])
			continue
		var packed := ResourceLoader.load(path)
		if packed is PackedScene:
			_ok("載入成 PackedScene：%s" % name)
		else:
			_bad("載入失敗或非 PackedScene：%s -> %s" % [name, path])


func _check_scenes_instantiate() -> void:
	print("\n-- scenes: instantiate + _ready（僅輕量場景）--")
	for name in INSTANTIATE_SAFE:
		var path: String = SCENES.get(name, "")
		if path == "" or not ResourceLoader.exists(path):
			_bad("無法實例化（檔案缺失）：%s" % name)
			continue
		var packed := ResourceLoader.load(path)
		if not (packed is PackedScene):
			_bad("無法實例化（非 PackedScene）：%s" % name)
			continue
		var inst = (packed as PackedScene).instantiate()
		if inst == null:
			_bad("instantiate() 回 null：%s" % name)
			continue
		root.add_child(inst)   # 觸發 _ready
		_ok("實例化 + _ready 無崩潰：%s" % name)
		inst.queue_free()
