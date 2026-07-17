extends SceneTree

## UI/美術截圖工具 —— 把指定畫面算圖後存成 PNG，供改完 UI 或立繪時一鍵目視驗收。
## （headless 用 dummy renderer 會截出空白，所以本工具**不能加 --headless**。）
##
## 用法：
##   /Applications/Godot.app/Contents/MacOS/Godot --path . -s res://tests/screenshot.gd -- <輸出目錄> [目標...]
##
## 目標（可帶多個、空白分隔；預設 "title menu:char"）：
##   title              標題頁（scenes/title/title.tscn）
##   menu[:頁]          new_game 後開遊戲選單；頁 = char/items/map/titles/system（預設 char）
##   world:<場景ID>     new_game 後載入世界場景（Town/Mine/EFA…，見 SceneRouter.SCENE_PATHS）
##                      ※ 進場可能自動播開場過場（對話框會入鏡），屬正常
##
## 例：
##   ... -- /tmp/shots title menu:char menu:items menu:map world:Town
## 輸出檔名＝目標名把 :/ 換成 _ 再加 .png（例 menu:char → menu_char.png）。

const PAGES := {"char": 0, "items": 1, "map": 2, "titles": 3, "system": 4}

var _out := "user://"
var _targets: Array = []
var _game_started := false


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	_targets = a.slice(1) if a.size() > 1 else ["title", "menu:char"]
	_run()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_warning("screenshot.gd 在 headless 下執行——截圖會是空白，請拿掉 --headless")
	await process_frame
	await process_frame
	var cdb: Node = root.get_node_or_null("/root/ContentDB")
	var guard := 0
	while cdb != null and not cdb.is_loaded and guard < 240:
		await process_frame
		guard += 1
	for t in _targets:
		await _shoot(String(t))
	quit(0)


func _shoot(target: String) -> void:
	var kind := target
	var arg := ""
	var ci := target.find(":")
	if ci >= 0:
		kind = target.substr(0, ci)
		arg = target.substr(ci + 1)

	var host: Node = null
	match kind:
		"title":
			host = _instance("res://scenes/title/title.tscn")
		"menu":
			_ensure_new_game()
			host = _instance("res://scenes/ui/menu_root.tscn")
			if host != null:
				await process_frame
				host.set_scene_id("Town")
				host._open_menu()
				var page: int = int(PAGES.get(arg, 0))
				if page != 0:
					host._set_tab(page)
		"world":
			_ensure_new_game()
			var gs: Node = root.get_node_or_null("/root/GameState")
			if gs != null:
				gs.spawn = "home"
			var path := _world_path(arg)
			if path == "" or not ResourceLoader.exists(path):
				print("[SHOT] 略過 world:%s（SceneRouter 無此場景ID或檔案不存在）" % arg)
				return
			host = _instance(path)
		_:
			print("[SHOT] 未知目標：%s（支援 title / menu[:頁] / world:<ID>）" % target)
			return

	if host == null:
		print("[SHOT] 目標 %s 場景載入失敗" % target)
		return
	for _i in 24:               # 等貼圖載入＋版面 settle
		await process_frame
	await _capture(_safe_name(target) + ".png")
	host.queue_free()
	await process_frame


func _instance(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var n: Node = load(path).instantiate()
	root.add_child(n)
	return n


func _ensure_new_game() -> void:
	if _game_started:
		return
	load("res://scripts/game_flow.gd").new_game()
	_game_started = true


func _world_path(scene_id: String) -> String:
	var sr: Node = root.get_node_or_null("/root/SceneRouter")
	if sr == null:
		return ""
	return String(sr.SCENE_PATHS.get(scene_id, ""))


func _capture(fname: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var path := _out.path_join(fname)
	print("[SHOT] %s err=%d size=%s" % [path, img.save_png(path), str(img.get_size())])


func _safe_name(s: String) -> String:
	return s.replace(":", "_").replace("/", "_")
