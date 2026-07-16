extends MenuPage
## 稱號分頁（3a 版）：頂部佩戴橫幅＋稱號卡片格。
##
## 真實：TitlesData.ALL 名稱/已取得或鎖定/desc/解鎖條件hint；佩戴＝GameState.flags["eqTitle"]（存 String，
## 對照舊 menu_root._tab_titles）。佔位：加成/物攻+2（本作稱號為純裝飾，TitlesData 無 bonus 欄）。
## 單層：↑↓ 選稱號、Enter 佩戴(已取得者)、←→ 切分頁、Esc 關閉。

var _cursor := 0
var _dirty := true
var _content: Control


func page_enter() -> void:
	_cursor = 0
	_dirty = true


func page_input() -> String:
	var n := TitlesData.ALL.size()
	if move_hit("move_up", _cursor > 0):
		_cursor -= 1; _dirty = true
	if move_hit("move_down", _cursor < n - 1):
		_cursor += 1; _dirty = true
	if hit("ui_accept"):
		_equip(_cursor)
	return "↑↓ 選稱號　Enter 佩戴(已取得者)　←→ 切分頁　Esc 關閉"


func _equip(i: int) -> void:
	if i < 0 or i >= TitlesData.ALL.size():
		return
	var t: Dictionary = TitlesData.ALL[i]
	if TitlesData.title_earned(String(t["req"])):
		# eqTitle 存 title id（String），刻意直接寫容器不走 flag_set（那會 int 化）。
		GameState.flags["eqTitle"] = t["id"]
		AudioManager.sfx("select.mp3")   # 對應 build_cq2.py L2295
		_dirty = true
	else:
		AudioManager.sfx("return.mp3")   # 對應 build_cq2.py L2296：未取得


func _on_card(i: int) -> void:
	_cursor = i
	_equip(i)
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

	# 佩戴橫幅
	var banner := PixelUI.panel(PixelUI.PANEL_BG2, 3)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 12)
	banner.add_child(bh)
	bh.add_child(PixelUI.label("目前稱號", 15, PixelUI.SUBTLE, 3))
	var eqname := TitlesData.equipped_name()
	bh.add_child(PixelUI.label(eqname if eqname != "" else "（未佩戴）", 22, PixelUI.SEL if eqname != "" else PixelUI.DIM, 4))
	bh.add_child(PixelUI.label("加成 —", 15, PixelUI.DIM, 3))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bh.add_child(sp)
	bh.add_child(PixelUI.label("點擊/Enter 佩戴已取得的稱號", 13, PixelUI.SUBTLE, 2))
	col.add_child(banner)

	# 卡片格
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	var eq_id := String(GameState.flags.get("eqTitle", ""))
	for i in TitlesData.ALL.size():
		grid.add_child(_card(i, TitlesData.ALL[i], eq_id))
	return col


func _card(i: int, t: Dictionary, eq_id: String) -> Control:
	var earned := TitlesData.title_earned(String(t["req"]))
	var equipped := earned and String(t["id"]) == eq_id
	var focused := i == _cursor
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 78)
	var border := PixelUI.SEL if focused else PixelUI.OUTLINE
	var st := PixelUI.panel_style(Color(0.078, 0.086, 0.149, 0.7), 2, border)
	b.add_theme_stylebox_override("normal", st)
	var hov := PixelUI.panel_style(Color(0.137, 0.149, 0.235, 0.8), 2, PixelUI.SEL)
	b.add_theme_stylebox_override("hover", hov)
	b.pressed.connect(_on_card.bind(i))

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.anchor_right = 1.0
	v.add_theme_constant_override("separation", 3)
	b.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(PixelUI.label(String(t["name"]) if earned else "？？？", 18, PixelUI.GOLD if earned else PixelUI.DIM, 3))
	var status := "【佩戴中】" if equipped else ("可佩戴" if earned else "未取得")
	top.add_child(PixelUI.label(status, 13, PixelUI.SEL if equipped else (PixelUI.GOOD if earned else PixelUI.DIM), 2))
	v.add_child(top)
	v.add_child(PixelUI.label("加成 —", 13, PixelUI.DIM, 2))
	var cond := String(t["desc"]) if earned else ("解鎖：" + String(t["hint"]))
	var cl := PixelUI.label(cond, 13, PixelUI.SUBTLE, 2)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(cl)
	return b
