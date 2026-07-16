extends CanvasLayer
## menu_root.tscn 的控制腳本 —— 選單「框架＋分頁路由」（角色選單重設 3a 版）。
##
## 取代舊版的「6 分頁文字列渲染器」：頂部 5 分頁列（角色/道具/地圖/稱號/系統）＋金幣，切換顯示對應
## MenuPage；裝備併入角色子頁。各頁版面改由 Control 節點樹表達（見 scenes/ui/menu/*.gd、pixel_ui.gd），
## 本檔只負責「開關狀態機＋分頁路由＋輸入分派」，不再組 rows/bars。
##
## ## 維持不變的對外契約（世界場景/商店依賴）
## - 根路徑 res://scenes/ui/menu_root.tscn（CanvasLayer, layer 10），由 world_scene.gd _setup_ui() 掛載。
## - is_open()：world_scene.gd 每幀 poll 來鎖世界移動。
## - group "cq_menu" ＋ force_close()：shop.gd 靠 group 找選單並強制關閉（選單/商店互斥）。
## - set_scene_id(id)：地圖頁需要目前世界場景 id。
## - 訊號 menu_opened/menu_closed：文件化契約（目前無外部訂閱者），開/關時 emit。
##
## ## 輸入（沿用 CORE-6 InputBridge，edge-triggered）
## - menu_toggle(M) 開；開啟中 menu_toggle/ui_cancel 先問 active page 是否消費（page_back），否則關。
## - ←→ 切頂部分頁（僅當 active page.at_top_zone()）；↑↓/Enter/1・2・3 交給 page（focus-zone 模型）。
##
## 開選單前確認商店未開（_shop_open）；世界移動鎖由整合端（world_scene）查 is_open() 處理，本檔不改世界場景。

signal menu_opened
signal menu_closed

const TABS := ["角色", "道具", "地圖", "稱號", "系統"]
const _PAGE_SCRIPTS := [
	preload("res://scenes/ui/menu/char_page.gd"),
	preload("res://scenes/ui/menu/items_page.gd"),
	preload("res://scenes/ui/menu/map_page.gd"),
	preload("res://scenes/ui/menu/titles_page.gd"),
	preload("res://scenes/ui/menu/system_page.gd"),
]

const TOPBAR_H := 58.0
const CONTENT_TOP := 66.0
const MARGIN := 20.0

@onready var _root: Control = $Root

var _open := false
var scene_id: String = ""
var tab := 0

var _pages: Array[MenuPage] = []
var _tab_buttons: Array[Button] = []
var _gold_label: Label
var _hint_label: Label
var _page_host: Control


func _ready() -> void:
	add_to_group("cq_menu")
	_build_ui()
	_root.visible = false


func _build_ui() -> void:
	# --- 頂部列 ---
	var topbar := PanelContainer.new()
	topbar.name = "TopBar"
	topbar.anchor_left = 0.0
	topbar.anchor_right = 1.0
	topbar.offset_top = 0.0
	topbar.offset_bottom = TOPBAR_H
	var tb_style := PixelUI.panel_style(PixelUI.TOPBAR_BG, 0)
	tb_style.border_width_bottom = 3
	tb_style.border_color = PixelUI.OUTLINE
	tb_style.content_margin_left = 22
	tb_style.content_margin_right = 22
	tb_style.content_margin_top = 6
	tb_style.content_margin_bottom = 6
	topbar.add_theme_stylebox_override("panel", tb_style)
	_root.add_child(topbar)

	var tb_row := HBoxContainer.new()
	tb_row.add_theme_constant_override("separation", 18)
	topbar.add_child(tb_row)

	var menu_lbl := PixelUI.label("MENU", 15, PixelUI.GOLD, 3)
	menu_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tb_row.add_child(menu_lbl)

	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_constant_override("outline_size", 4)
		b.add_theme_color_override("font_outline_color", PixelUI.OUTLINE)
		b.pressed.connect(_set_tab.bind(i))
		tb_row.add_child(b)
		_tab_buttons.append(b)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_row.add_child(spacer)

	_gold_label = PixelUI.label("金幣 0", 20, PixelUI.GOLD, 4)
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tb_row.add_child(_gold_label)

	# 關閉鈕（滑鼠/觸控關選單；鍵盤仍可 Esc/M）。
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.custom_minimum_size = Vector2(42, 40)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", PixelUI.BAD)
	close_btn.add_theme_color_override("font_hover_color", PixelUI.WHITE)
	close_btn.add_theme_color_override("font_pressed_color", PixelUI.WHITE)
	close_btn.add_theme_constant_override("outline_size", 4)
	close_btn.add_theme_color_override("font_outline_color", PixelUI.OUTLINE)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.039, 0.039, 0.078, 0.45)
	cs.set_border_width_all(2)
	cs.border_color = PixelUI.OUTLINE
	var ch := cs.duplicate() as StyleBoxFlat
	ch.bg_color = Color(0.5, 0.24, 0.24, 0.75)
	ch.border_color = PixelUI.BAD
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.add_theme_stylebox_override("hover", ch)
	close_btn.add_theme_stylebox_override("pressed", ch)
	close_btn.pressed.connect(_close_menu)
	tb_row.add_child(close_btn)

	# --- 內容區（各 page 填滿）---
	_page_host = Control.new()
	_page_host.name = "PageHost"
	_page_host.anchor_left = 0.0
	_page_host.anchor_right = 1.0
	_page_host.anchor_bottom = 1.0
	_page_host.offset_top = CONTENT_TOP
	_page_host.offset_left = MARGIN
	_page_host.offset_right = -MARGIN
	_page_host.offset_bottom = -MARGIN - 30.0   # 留底部提示列空間
	_root.add_child(_page_host)

	for ps in _PAGE_SCRIPTS:
		var p: MenuPage = ps.new()
		p.anchor_right = 1.0
		p.anchor_bottom = 1.0
		p.scene_id = scene_id
		p.visible = false
		_page_host.add_child(p)
		_pages.append(p)

	# --- 底部提示列 ---
	_hint_label = PixelUI.label("", 16, Color(0.667, 0.706, 0.863), 3)
	_hint_label.anchor_left = 0.0
	_hint_label.anchor_right = 1.0
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_left = MARGIN + 4
	_hint_label.offset_right = -MARGIN
	_hint_label.offset_top = -28.0
	_hint_label.offset_bottom = -4.0
	_root.add_child(_hint_label)


func set_scene_id(id: String) -> void:
	scene_id = id
	for p in _pages:
		p.scene_id = id


func is_open() -> bool:
	return _open


func _hit(action: String) -> bool:
	return InputBridge.is_action_hit(action)


func _active_page() -> MenuPage:
	return _pages[tab]


func _process(_delta: float) -> void:
	if not _open:
		if not DialogueSystem.is_busy() and not _shop_open():
			if _hit("menu_toggle"):
				_open_menu()
		return

	if _hit("menu_toggle") or _hit("ui_cancel"):
		AudioManager.sfx("return.mp3")   # 對應 build_cq2.py L2000-2005：返回/關選單
		if _active_page().page_back():
			_active_page().page_refresh()
			_refresh_frame(_last_hint)
			return
		_close_menu()
		return

	if not ContentDB.is_loaded:
		return
	_tick_open()


var _last_hint := ""


func _tick_open() -> void:
	var page := _active_page()
	# 頂部分頁切換：僅當 active page 焦點在 top zone 時吃 ←→（否則交給 page 自用）。
	if page.at_top_zone():
		if _hit("move_left"):
			AudioManager.sfx("cursor.mp3")
			_set_tab((tab + TABS.size() - 1) % TABS.size())
			return
		if _hit("move_right"):
			AudioManager.sfx("cursor.mp3")
			_set_tab((tab + 1) % TABS.size())
			return
	_last_hint = page.page_input()
	page.page_refresh()
	_refresh_frame(_last_hint)


func _set_tab(i: int) -> void:
	if not _open:
		return
	tab = i
	for p in _pages:
		p.visible = false
	var page := _pages[tab]
	page.visible = true
	page.page_enter()
	page.page_refresh()
	_last_hint = ""
	_refresh_frame("")


func _refresh_frame(hint: String) -> void:
	_gold_label.text = "金幣 %d" % GameState.gold
	_hint_label.text = hint
	for i in _tab_buttons.size():
		_style_tab_button(_tab_buttons[i], i == tab)


func _style_tab_button(b: Button, active: bool) -> void:
	b.add_theme_color_override("font_color", PixelUI.GOLD if active else PixelUI.SUBTLE)
	b.add_theme_color_override("font_hover_color", PixelUI.SEL)
	b.add_theme_color_override("font_pressed_color", PixelUI.SEL)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.235, 0.251, 0.353, 0.5) if active else Color(0, 0, 0, 0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	if active:
		sb.border_width_bottom = 3
		sb.border_color = PixelUI.SEL
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", sb)


func _open_menu() -> void:
	_open = true
	tab = 0
	_root.visible = true
	AudioManager.sfx("menu.mp3")   # 對應 build_cq2.py L1332：開選單
	_set_tab(0)
	menu_opened.emit()


func _close_menu() -> void:
	_open = false
	_root.visible = false
	menu_closed.emit()


## 供商店開啟時強制關閉選單（對應 build_cq2 openShop() 的 st.menu=false，L1298）。
func force_close() -> void:
	if _open:
		_close_menu()


## 供 HUD 右上角選單圖示點擊開啟（與 M 鍵同一條開啟路徑、同樣的防護：對話/商店進行中不開）。
func request_open() -> void:
	if _open:
		return
	if DialogueSystem.is_busy() or _shop_open():
		return
	_open_menu()


func _shop_open() -> bool:
	var s := get_tree().get_first_node_in_group("cq_shop")
	return s != null and s.has_method("is_open") and s.is_open()


## 回標題（對應 build_cq2 replaceScene("Title")）。system_page 的「離開遊戲」呼叫。
func quit_to_title() -> void:
	_close_menu()
	get_tree().change_scene_to_file("res://scenes/title/title.tscn")
