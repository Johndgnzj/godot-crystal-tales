extends MenuPage
## 地圖分頁（3a 版）：世界→大陸→地區。
##
## 真實：現在位置(scene_id→LOC)、各地區建議等級(ContentDB.get_pacing via MenuLogic.lv_range)。
## 佔位：七大陸階層（僅「艾瑞西亞（當前）」有內容，其餘鎖定「未探索」）、查看地圖 image overlay（敬請期待）。
## 兩層：level0 大陸格(↑↓ 選、Enter 進入)、level1 地區列(↑↓ 瀏覽、Esc 返回)。

# 當前大陸的地區（key 對齊 pacing map key；"" = 無 encounter 的和平區）。
const REGIONS := [
	{"name": "芳蕾鎮", "scene": "Town", "key": ""},
	{"name": "東之森", "scene": "Forest", "key": "forest"},
	{"name": "東之森深處", "scene": "Forest2", "key": "forest2"},
	{"name": "礦山外圍", "scene": "Mine", "key": "mine"},
	{"name": "礦山洞穴", "scene": "Cave", "key": "cave"},
]
const CONTINENTS := 7

var _level := 0
var _cont := 0
var _cursor := 0
var _dirty := true
var _content: Control


func page_enter() -> void:
	_level = 0
	_cursor = 0
	_dirty = true


func at_top_zone() -> bool:
	return _level == 0


func page_back() -> bool:
	if _level == 1:
		_level = 0
		_dirty = true
		return true
	return false


func page_input() -> String:
	if _level == 0:
		if move_hit("move_up", _cursor > 0):
			_cursor -= 1; _dirty = true
		if move_hit("move_down", _cursor < CONTINENTS - 1):
			_cursor += 1; _dirty = true
		if hit("ui_accept") and _cursor == 0:
			_cont = 0; _level = 1; _dirty = true
			AudioManager.sfx("select.mp3")
		return "↑↓ 選大陸　Enter 進入（僅當前大陸）　←→ 切分頁　Esc 關閉"
	return "地區一覽（建議等級為真實資料）　Esc 返回"


func _on_cont(i: int) -> void:
	_cursor = i
	if i == 0:
		_cont = 0; _level = 1
	_dirty = true


func page_refresh() -> void:
	if not _dirty:
		return
	_dirty = false
	if _content != null:
		_content.queue_free()
	_content = _build()
	add_child(_content)


func _build() -> Control:
	var col := VBoxContainer.new()
	col.anchor_right = 1.0
	col.anchor_bottom = 1.0
	col.add_theme_constant_override("separation", 12)

	var here := String(MenuLogic.LOC.get(scene_id, scene_id if scene_id != "" else "—"))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(PixelUI.label("世界地圖", 22, PixelUI.GOLD, 4))
	head.add_child(PixelUI.label("艾瑞西亞 · 七大陸", 15, PixelUI.SUBTLE, 3))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	head.add_child(PixelUI.label("現在位置：%s" % here, 16, PixelUI.SEL, 3))
	col.add_child(head)

	if _level == 0:
		col.add_child(_build_world())
	else:
		col.add_child(_build_continent())
	return col


func _build_world() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for i in CONTINENTS:
		grid.add_child(_cont_card(i))
	return scroll


func _cont_card(i: int) -> Control:
	var known := i == 0
	var focused := i == _cursor
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 96)
	b.disabled = not known
	var border := PixelUI.SEL if focused else PixelUI.OUTLINE
	var st := PixelUI.panel_style(Color(0.078, 0.086, 0.149, 0.7), 2, border)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("disabled", st)
	var hov := PixelUI.panel_style(Color(0.137, 0.149, 0.235, 0.8), 2, PixelUI.SEL)
	b.add_theme_stylebox_override("hover", hov)
	b.pressed.connect(_on_cont.bind(i))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.anchor_right = 1.0
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)
	if known:
		v.add_child(PixelUI.label("艾瑞西亞（當前）", 18, PixelUI.GOLD, 3))
		v.add_child(PixelUI.label("芳蕾鎮周邊 · 東之森 · 礦山", 13, PixelUI.SUBTLE, 2))
		v.add_child(PixelUI.label("Enter 查看地區", 12, PixelUI.CYAN, 2))
	else:
		v.add_child(PixelUI.label("？？？大陸", 18, PixelUI.DIM, 3))
		v.add_child(PixelUI.label("未探索（敬請期待）", 13, PixelUI.DIM, 2))
	return b


func _build_continent() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 7)
	scroll.add_child(v)
	var back := HBoxContainer.new()
	back.add_theme_constant_override("separation", 8)
	back.add_child(PixelUI.label("‹ 艾瑞西亞大陸", 16, PixelUI.GOLD, 3))
	back.add_child(PixelUI.label("（Esc 回世界）", 12, PixelUI.SUBTLE, 2))
	v.add_child(back)
	for r in REGIONS:
		v.add_child(_region_row(r))
	v.add_child(PixelUI.label("查看地區手繪地圖：敬請期待", 13, PixelUI.DIM, 2))
	return scroll


func _region_row(r: Dictionary) -> Control:
	var p := PanelContainer.new()
	var here := String(r["scene"]) == scene_id
	var st := PixelUI.panel_style(Color(0.117, 0.133, 0.211, 0.8) if here else Color(0.078, 0.086, 0.149, 0.7), 2, PixelUI.SEL if here else PixelUI.OUTLINE)
	p.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	h.add_child(PixelUI.label(String(r["name"]), 17, PixelUI.GOLD if here else PixelUI.WHITE, 3))
	if here:
		h.add_child(PixelUI.label("〔現在位置〕", 13, PixelUI.SEL, 2))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
	var key := String(r["key"])
	var lv := "和平地區" if key == "" else ("建議 " + MenuLogic.lv_range(key))
	h.add_child(PixelUI.label(lv, 14, PixelUI.CYAN, 2))
	return p
