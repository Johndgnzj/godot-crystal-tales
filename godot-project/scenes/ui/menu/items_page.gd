extends MenuPage
## 道具分頁（3a 版）：一般道具(消耗品+素材) / 任務道具(key)；左清單、右詳情。
##
## 三層 focus：level0 分類選擇(↑↓ 切一般/任務)、level1 清單(↑↓ 選道具、Enter 使用)、level2 選使用對象。
## 使用邏輯＝真實（heal/mp 藥回血/回魔、inv_use，對照舊 menu_root._tab_items who 模式）。捨棄＝佔位停用。

const CATS := ["一般道具", "任務道具"]

var _level := 0
var _cat := 0
var _cursor := 0
var _who := 0
var _dirty := true
var _content: Control


func page_enter() -> void:
	_level = 0
	_cursor = 0
	_dirty = true


func at_top_zone() -> bool:
	return _level == 0


func page_back() -> bool:
	if _level > 0:
		_level -= 1
		_dirty = true
		return true
	return false


func _items_for_cat() -> Array:
	var out: Array = []
	var iv: Dictionary = GameState.inv_all()
	for it in ContentDB.get_all_items():
		var q := int(iv.get(it.id, 0))
		if q <= 0:
			continue
		var is_quest: bool = it.cat == "key"
		if (_cat == 1) == is_quest:
			out.append({"id": it.id, "n": q, "def": it})
	return out


func page_input() -> String:
	var list := _items_for_cat()
	if _level == 0:
		if move_hit("move_up", _cat > 0):
			_cat -= 1; _cursor = 0; _dirty = true
		if move_hit("move_down", _cat < CATS.size() - 1):
			_cat += 1; _cursor = 0; _dirty = true
		if hit("ui_accept") and not list.is_empty():
			_level = 1; _cursor = 0; _dirty = true
			AudioManager.sfx("select.mp3")
		return "↑↓ 切一般/任務　Enter 進入清單　←→ 切分頁　Esc 關閉"

	if _level == 1:
		if move_hit("move_up", _cursor > 0):
			_cursor -= 1; _dirty = true
		if move_hit("move_down", _cursor < list.size() - 1):
			_cursor += 1; _dirty = true
		if hit("ui_accept") and _cursor < list.size():
			_try_use(list[_cursor])
		return "↑↓ 選道具　Enter 使用(可用者)　Esc 返回"

	# level 2：選使用對象
	var ps: Array = GameState.party
	if move_hit("move_up", _who > 0):
		_who -= 1; _dirty = true
	if move_hit("move_down", _who < ps.size() - 1):
		_who += 1; _dirty = true
	if hit("ui_accept") and _cursor < list.size():
		_apply_to(list[_cursor], _who)
	return "↑↓ 選隊員　Enter 使用　Esc 返回"


func _try_use(rec: Dictionary) -> void:
	var it: ItemDef = rec["def"]
	if it.kind == "heal" or it.kind == "mp":
		_level = 2
		_who = 0
		_dirty = true
		AudioManager.sfx("select.mp3")   # 對應 build_cq2.py L2251：可用道具→選對象
	else:
		AudioManager.sfx("return.mp3")   # 對應 build_cq2.py L2252：不可用


func _apply_to(rec: Dictionary, who: int) -> void:
	var ps: Array = GameState.party
	if who >= ps.size():
		return
	var it: ItemDef = rec["def"]
	var tgt: Dictionary = ps[who]
	Derive.derive(tgt)
	var is_mp := it.kind == "mp"
	var full := (float(tgt.get("mp", 0)) >= float(tgt.get("maxmp", 0))) if is_mp else (float(tgt.get("hp", 0)) >= float(tgt.get("maxhp", 0)))
	if full:
		AudioManager.sfx("return.mp3")   # 對應 build_cq2.py L2269：已滿
		return
	var pw := float(it.power)
	if is_mp:
		tgt["mp"] = min(float(tgt.get("maxmp", 0)), float(tgt.get("mp", 0)) + pw)
	else:
		tgt["hp"] = min(float(tgt.get("maxhp", 0)), float(tgt.get("hp", 0)) + pw)
	GameState.inv_use(String(it.id))
	if GameState.inv_get(String(it.id)) <= 0:
		_level = 1
	_dirty = true


# --- 滑鼠 ---
func _on_cat(i: int) -> void:
	_cat = i; _level = 0; _cursor = 0; _dirty = true


func _on_pick(i: int) -> void:
	_level = 1; _cursor = i; _dirty = true


func _on_use() -> void:
	var list := _items_for_cat()
	if _cursor < list.size():
		_try_use(list[_cursor])


func _on_apply(who: int) -> void:
	var list := _items_for_cat()
	if _cursor < list.size():
		_apply_to(list[_cursor], who)


# =========================================================================
func page_refresh() -> void:
	if not _dirty:
		return
	_dirty = false
	if not ContentDB.is_loaded:
		return
	if _content != null:
		_content.queue_free()
	_content = _build()
	add_child(_content)


func _build() -> Control:
	var col := VBoxContainer.new()
	col.anchor_right = 1.0
	col.anchor_bottom = 1.0
	col.add_theme_constant_override("separation", 10)

	# 分類列
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	for i in CATS.size():
		var b := PixelUI.button(CATS[i], PixelUI.GOLD if i == _cat else PixelUI.SUBTLE, 16)
		if i == _cat:
			var sb := PixelUI.selected_style(_level == 0)
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sb)
		b.pressed.connect(_on_cat.bind(i))
		head.add_child(b)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	var list := _items_for_cat()
	head.add_child(PixelUI.label("種類 %d" % list.size(), 15, PixelUI.SUBTLE, 3))
	col.add_child(head)

	var wrap := HBoxContainer.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 14)

	# 左清單
	var left := PixelUI.panel(PixelUI.PANEL_BG, 3)
	left.custom_minimum_size = Vector2(400, 0)
	var lscroll := ScrollContainer.new()
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(lscroll)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 5)
	lscroll.add_child(lv)
	if list.is_empty():
		lv.add_child(PixelUI.label("（沒有%s）" % CATS[_cat], 14, PixelUI.DIM))
	for i in list.size():
		lv.add_child(_item_row(list[i], i, _level >= 1 and i == _cursor))
	wrap.add_child(left)

	# 右詳情
	wrap.add_child(_build_detail(list))
	col.add_child(wrap)
	return col


func _item_row(rec: Dictionary, i: int, focused: bool) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var st := PixelUI.selected_style(true) if focused else PixelUI.panel_style(Color(0.078, 0.086, 0.149, 0.7), 2, PixelUI.OUTLINE)
	b.add_theme_stylebox_override("normal", st)
	var hov := PixelUI.panel_style(Color(0.137, 0.149, 0.235, 0.8), 2, PixelUI.SEL)
	b.add_theme_stylebox_override("hover", hov)
	b.pressed.connect(_on_pick.bind(i))
	b.custom_minimum_size = Vector2(0, 36)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.anchor_right = 1.0
	h.add_theme_constant_override("separation", 8)
	b.add_child(h)
	var it: ItemDef = rec["def"]
	var nm := PixelUI.label(it.display_name, 15, PixelUI.WHITE, 3)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nm)
	h.add_child(PixelUI.label(_kind_label(it), 12, PixelUI.SUBTLE, 2))
	h.add_child(PixelUI.label("×%d" % int(rec["n"]), 14, PixelUI.SEL, 2))
	return b


func _kind_label(it: ItemDef) -> String:
	match it.cat:
		"consumable":
			return "消耗品"
		"material":
			return "素材"
		"key":
			return "任務"
	return ""


func _build_detail(list: Array) -> Control:
	var p := PixelUI.panel(PixelUI.PANEL_BG2, 3)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	if list.is_empty() or _cursor >= list.size():
		v.add_child(PixelUI.label("（沒有可顯示的道具）", 15, PixelUI.DIM))
		return p
	var it: ItemDef = list[_cursor]["def"]
	v.add_child(PixelUI.label(it.display_name, 24, PixelUI.GOLD, 4))
	v.add_child(PixelUI.label(_kind_label(it), 14, PixelUI.SUBTLE, 2))
	if it.effect != "":
		var d := PixelUI.label(it.effect, 15, PixelUI.CYAN, 2)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)

	if _cat == 1:
		# 任務道具
		v.add_child(_kv("取得來源", "—（敬請期待）", PixelUI.DIM))
		v.add_child(PixelUI.label("任務道具僅供查看，無法使用或捨棄。", 14, Color(0.706, 0.604, 0.941), 2))
	else:
		var usable := it.kind == "heal" or it.kind == "mp"
		if _level == 2:
			v.add_child(_build_who(list[_cursor]))
		else:
			var btns := HBoxContainer.new()
			btns.add_theme_constant_override("separation", 10)
			var use := PixelUI.button("使用", PixelUI.GOLD if usable else PixelUI.DIM, 16)
			use.disabled = not usable
			use.pressed.connect(_on_use)
			btns.add_child(use)
			var drop := PixelUI.button("捨棄", PixelUI.DIM, 16)
			drop.disabled = true   # 原版無捨棄機制，保留版面停用
			btns.add_child(drop)
			v.add_child(btns)
			if not usable:
				v.add_child(PixelUI.label("此道具無法在選單中使用。", 13, PixelUI.DIM, 2))
	return p


func _build_who(rec: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(PixelUI.label("對誰使用：", 15, PixelUI.GOLD, 3))
	var ps: Array = GameState.party
	for i in ps.size():
		var m: Dictionary = ps[i]
		Derive.derive(m)
		var b := PixelUI.button("", PixelUI.WHITE, 15)
		b.pressed.connect(_on_apply.bind(i))
		var st := PixelUI.selected_style(true) if i == _who else PixelUI.panel_style(Color(0.078, 0.086, 0.149, 0.7), 2, PixelUI.OUTLINE)
		b.add_theme_stylebox_override("normal", st)
		b.custom_minimum_size = Vector2(0, 34)
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.anchor_right = 1.0
		h.add_theme_constant_override("separation", 10)
		b.add_child(h)
		var nm := PixelUI.label("%s Lv%s" % [m.get("name", ""), m.get("lv", 1)], 15, PixelUI.WHITE, 3)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(PixelUI.label("HP %s/%s" % [MenuLogic.num(m.get("hp", 0)), MenuLogic.num(m.get("maxhp", 0))], 13, PixelUI.HP, 2))
		h.add_child(PixelUI.label("MP %s/%s" % [MenuLogic.num(m.get("mp", 0)), MenuLogic.num(m.get("maxmp", 0))], 13, PixelUI.MP, 2))
		box.add_child(b)
	return box


func _kv(k: String, v: String, vc: Color) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(PixelUI.label(k, 15, PixelUI.SUBTLE, 3))
	h.add_child(PixelUI.label(v, 15, vc, 3))
	return h
