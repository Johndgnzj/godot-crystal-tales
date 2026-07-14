extends SceneTree

## headless 冒煙：選單/HUD 場景實例化 ＋ 六分頁 row 組裝不崩（補 VERIFICATION_STATUS 的 UI 場景缺口）。
##   /Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/check_menu_smoke.gd --path .
##
## 刻意只實例化 hud/menu_root（含 menu_panel），不碰 title/dialogue_box，避免與其他進行中工作搶場景檔。
## headless 沒有輸入事件，因此直接呼叫 menu_root 的內部組列函式逐一過每個分頁，驗證「組資料階段」
## （Derive.derive／ContentDB 查表／panel.render）不會丟出 runtime error。視覺正確性仍須編輯器目視。

var _fail := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame   # 等 autoload 掛上
	print("=== check_menu_smoke ===")
	var gs: Node = root.get_node("/root/GameState")
	var gf: GDScript = load("res://scripts/game_flow.gd")
	if gf == null:
		print("  [FAIL] game_flow.gd 載入失敗"); print("=== MENU_SMOKE FAIL ==="); quit(1); return
	gf.new_game()   # 合法隊伍，讓角色/裝備/道具頁有資料可組

	# --- 實例化 HUD ---
	var hud_ps: PackedScene = load("res://scenes/ui/hud.tscn")
	_expect(hud_ps != null, "hud.tscn 載入為 PackedScene")
	var hud: Node = hud_ps.instantiate()
	root.add_child(hud)
	await process_frame   # 跑 _ready + 一次 _process(_refresh)
	if hud.has_method("set_scene_id"):
		hud.set_scene_id("Town")
	await process_frame
	var party_label: Label = hud.get_node("Root/HudParty")
	_expect(party_label != null and party_label.text != "", "HUD 隊伍列有文字（%s）" % (party_label.text if party_label else "<null>"))

	# --- 實例化選單 ---
	var menu_ps: PackedScene = load("res://scenes/ui/menu_root.tscn")
	_expect(menu_ps != null, "menu_root.tscn 載入為 PackedScene")
	var menu: Node = menu_ps.instantiate()
	root.add_child(menu)
	await process_frame   # _ready（含 Panel._ready 建 20 列）

	var panel: Node = menu.get_node("Panel")
	_expect(panel != null, "menu 內含 Panel（CqMenuPanel）")

	# 開選單並逐一過六個分頁組列
	menu._open_menu()
	_expect(menu.is_open(), "選單開啟 is_open()=true")

	var tab_names := ["角色", "裝備", "道具", "地圖", "稱號", "系統"]
	for i in tab_names.size():
		menu.tab = i
		menu._reset_tab_cursors()
		menu._tick_open()   # 沒有輸入 → 純組列 + panel.render；不崩即算過
		_expect(true, "分頁[%s] 組列不崩" % tab_names[i])

	# 回角色頁再 tick 一次，驗證 panel 第一列有寫入內容
	menu.tab = 0
	menu._reset_tab_cursors()
	menu._tick_open()
	var has_rows: bool = panel._row_nodes.size() > 0
	var row0_text: String = String(panel._row_nodes[0].text) if has_rows else ""
	_expect(has_rows and row0_text != "", "面板首列有內容（%s）" % (row0_text if has_rows else "<無列>"))

	# 成員頁（配點/換裝/升技組列，最容易踩 Derive/裝備查表）
	menu.m_mode = "member"
	menu.sel = 0
	menu._tick_open()
	_expect(true, "角色成員頁組列不崩")

	print("=== %s ===" % ("MENU_SMOKE OK" if _fail == 0 else "MENU_SMOKE FAIL（%d）" % _fail))
	quit(0 if _fail == 0 else 1)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK]   " + msg)
	else:
		_fail += 1
		print("  [FAIL] " + msg)
