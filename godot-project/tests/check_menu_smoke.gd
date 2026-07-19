extends SceneTree

## headless 冒煙：選單/HUD 場景實例化 ＋ 五分頁（含角色 4 子頁）結構化建節點不崩。
##   /Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/check_menu_smoke.gd --path .
##
## 角色選單重設後，選單改為「框架＋分頁路由」的 Control 節點樹（非舊的文字列渲染器），故本測試改驗新架構：
## new_game() → 開選單 → is_open() → 逐一切 5 分頁確認有建出內容節點 → 切角色 4 子頁確認組建不崩。
## headless 沒有輸入事件，直接呼叫 menu_root._set_tab / page._on_subtab_pressed + page_refresh 驗「組建階段」
## （Derive.derive／ContentDB 查表／PixelUI 建節點）不丟 runtime error。視覺正確性仍須編輯器目視。

var _fail := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame   # 等 autoload 掛上
	print("=== check_menu_smoke ===")
	var gf: GDScript = load("res://scripts/game_flow.gd")
	if gf == null:
		print("  [FAIL] game_flow.gd 載入失敗"); print("=== MENU_SMOKE FAIL ==="); quit(1); return
	gf.new_game()   # 合法隊伍，讓各分頁有資料可組

	# --- HUD（未改動，維持覆蓋）---
	var hud_ps: PackedScene = load("res://scenes/ui/hud.tscn")
	_expect(hud_ps != null, "hud.tscn 載入為 PackedScene")
	var hud: Node = hud_ps.instantiate()
	root.add_child(hud)
	await process_frame
	if hud.has_method("set_scene_id"):
		hud.set_scene_id("Town")
	await process_frame
	var menu_btn: Node = hud.get_node_or_null("Root/MenuBtn")
	_expect(menu_btn != null, "HUD 右上角選單圖示鈕存在")

	# --- 實例化選單（新框架）---
	var menu_ps: PackedScene = load("res://scenes/ui/menu_root.tscn")
	_expect(menu_ps != null, "menu_root.tscn 載入為 PackedScene")
	var menu: Node = menu_ps.instantiate()
	root.add_child(menu)
	await process_frame   # _ready 建框架＋5 個 page

	menu.set_scene_id("Town")
	menu._open_menu()
	_expect(menu.is_open(), "選單開啟 is_open()=true")
	await process_frame

	# 逐一過 5 分頁：切換後應顯示且有建出內容節點
	var tab_names := ["角色", "道具", "地圖", "稱號", "系統"]
	for i in tab_names.size():
		menu._set_tab(i)
		await process_frame
		var page: Node = menu._pages[i]
		_expect(page.visible, "分頁[%s] 顯示" % tab_names[i])
		_expect(page.get_child_count() > 0, "分頁[%s] 有建出內容節點" % tab_names[i])

	# 角色頁 4 子頁（屬性/裝備/技能/故事）逐一組建
	menu._set_tab(0)
	var cp: Node = menu._pages[0]
	var sub_names := ["屬性", "裝備", "技能", "故事"]
	for st in sub_names.size():
		cp._on_subtab_pressed(st)
		cp.page_refresh()
		await process_frame
		_expect(cp.get_child_count() > 0, "角色子頁[%s] 組建不崩" % sub_names[st])

	# --- 行為：驗新 view 確實接上邏輯的狀態變更（headless 無輸入，直接呼叫頁面動作方法）---
	# 注意：-s 主腳本編譯早於 autoload 掛上；不可在此引用會鏈到 autoload 的 class_name（如 MenuLogic/Derive），
	# 否則整條依賴鏈於啟動時提早編譯、ContentDB 尚未註冊會失敗。故一律走「runtime 已載好」的頁面方法。
	var gs: Node = root.get_node("/root/GameState")
	var ps: Array = gs.party
	if not ps.is_empty():
		var m: Dictionary = ps[0]
		m["pts"] = 2
		var str0: int = int(m["attrs"]["str"])
		cp._member = 0; cp._level = 1; cp._subtab = 0
		cp._alloc("str")
		_expect(int(m["attrs"]["str"]) == str0 + 1 and int(m["pts"]) == 1, "配點 +力量 生效（pts 遞減）")
		m["spts"] = 1
		var sk_ids: Array = m.get("sk", {}).keys()
		if not sk_ids.is_empty():
			var sid: String = String(sk_ids[0])
			var lv0: int = int(m["sk"][sid])
			cp._on_upgrade_pressed(sid)
			_expect(int(m["sk"][sid]) == lv0 + 1, "技能升級生效（%s）" % sid)

	# 稱號佩戴：使 t_rookie（req step>=3）為已取得後佩戴，驗寫入 eqTitle。
	gs.flag_set("ch1_step", 3)
	var tp: Node = menu._pages[3]
	tp._equip(0)
	_expect(String(gs.flags.get("eqTitle", "")) == "t_rookie", "稱號佩戴寫入 eqTitle")

	print("=== %s ===" % ("MENU_SMOKE OK" if _fail == 0 else "MENU_SMOKE FAIL（%d）" % _fail))
	quit(0 if _fail == 0 else 1)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK]   " + msg)
	else:
		_fail += 1
		print("  [FAIL] " + msg)
