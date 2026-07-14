extends GutTest

## test_smoke_gut.gd — GUT（Godot Unit Test）版冒煙測試骨架（CORE-7）。
##
## ⚠️ 骨架，需要先 vendor GUT addon，且尚未實機驗證 ⚠️
##
## 這個檔案 `extends GutTest`，需要 GUT addon 存在於 `res://addons/gut/`。本環境無法下載 GUT
## （網路政策擋下，同 Godot 執行檔），所以：
##   - 這支檔案在 GUT addon 就位前，`godot --headless --check-only` 會因為找不到 GutTest 而報錯，
##     因此 **check-only 時要先排除 tests/gut/**（見 tests/README.md 的「check-only 範圍」）。
##   - 保證 check-only 一定過的冒煙測試是 tests/smoke_test.gd（純 SceneTree、零外部依賴），GUT 版是
##     「有 GUT 後更好用」的加值，不是唯一路徑。
##
## ## 拿到 Godot + GUT 後怎麼啟用
##   1. 下載 GUT（https://github.com/bitwes/Gut）解壓到 res://addons/gut/，編輯器 Project Settings →
##      Plugins 啟用。
##   2. CLI 跑：
##        godot --headless -s res://addons/gut/gut_cmdln.gd -gconfig=res://tests/.gutconfig.json
##      或用 .gutconfig.json 裡設定的 dirs 自動蒐集。
##
## GUT 版比 SceneTree 版多的價值：每個 assert 獨立記錄、失敗不中斷後續、有結構化 JUnit 報表可接 CI。
## 測試意圖與 tests/smoke_test.gd 相同（autoload 掛載 / 資料層載入 / 場景可載入），這裡示範 GUT 斷言寫法，
## 之後的模組整合測試（對話回歸、戰鬥自動打法、存檔回歸——見 TASKS/10_測試驗證.md）都放這個目錄，用同一套
## GUT 慣例擴充。

const SCENES := {
	"Title": "res://scenes/title/title.tscn",
	"Battle": "res://scenes/battle/battle.tscn",
	"Town": "res://scenes/world/town.tscn",
	"Forest": "res://scenes/world/forest.tscn",
	"Forest2": "res://scenes/world/forest2.tscn",
	"Mine": "res://scenes/world/mine.tscn",
	"Cave": "res://scenes/world/cave.tscn",
	"DialogueBox": "res://scenes/ui/dialogue_box.tscn",
}

const AUTOLOAD_NAMES := [
	"ContentDB", "GameState", "SceneRouter", "DialogueSystem",
	"InputBridge", "SaveManager", "DebugHooks",
]


func test_autoloads_present() -> void:
	for name in AUTOLOAD_NAMES:
		var node := get_tree().root.get_node_or_null(NodePath("/root/" + name))
		assert_not_null(node, "autoload 應已掛上：%s" % name)


func test_content_db_loaded() -> void:
	var cdb := get_tree().root.get_node_or_null(^"/root/ContentDB")
	assert_not_null(cdb, "ContentDB autoload 應存在")
	if cdb == null:
		return
	assert_true(bool(cdb.get("is_loaded")), "ContentDB.is_loaded 應為 true")
	# id 以 CONTENT.json 實際資料為準（CORE-2 驗收現況：boss id 是 goblin_chief，不是 goblin_boss）。
	assert_not_null(cdb.call("get_enemy", "goblin_chief"), "get_enemy(goblin_chief) 應非 null")


func test_dialogue_system_loaded() -> void:
	var dsys := get_tree().root.get_node_or_null(^"/root/DialogueSystem")
	assert_not_null(dsys, "DialogueSystem autoload 應存在")
	if dsys != null:
		assert_true(bool(dsys.get("is_loaded")), "DialogueSystem.is_loaded 應為 true")


func test_all_scenes_load_as_packed_scene() -> void:
	for name in SCENES:
		var path: String = SCENES[name]
		assert_true(ResourceLoader.exists(path), "場景檔應存在：%s (%s)" % [name, path])
		if not ResourceLoader.exists(path):
			continue
		var packed := ResourceLoader.load(path)
		assert_true(packed is PackedScene, "應載入成 PackedScene：%s" % name)


func test_title_instantiates() -> void:
	var packed := ResourceLoader.load(SCENES["Title"])
	assert_true(packed is PackedScene, "Title 應為 PackedScene")
	if packed is PackedScene:
		var inst = (packed as PackedScene).instantiate()
		assert_not_null(inst, "Title.instantiate() 應非 null")
		if inst != null:
			add_child_autofree(inst)   # GUT 會在測試後自動 free
