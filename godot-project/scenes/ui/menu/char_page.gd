extends MenuPage
## 角色分頁（3a 版核心）：左立繪＋隊員切換，右子頁 屬性/裝備/技能/故事。
##
## 兩層 focus 模型（沿用舊選單 list→detail 的 Esc 分層，讓 ←→ 仍能跨頂部分頁）：
##   level 0（瀏覽）：↑↓ 換隊員、Enter 進入細節、←→ 由 menu_root 切頂部分頁（at_top_zone()==true）。
##   level 1（細節）：←→ 切子頁、↑↓ 移 body 游標、Enter 動作、1/2/3 配點、Esc 回 level 0。
## 滑鼠可直接點子頁/隊員箭頭/裝備候選/升級/＋，繞過 level（設狀態＋標記重建）。
##
## 效能：body 只在狀態變動時重建（_dirty），不每幀重建——否則按鈕每幀被 free 會吃不到滑鼠點擊。
## 邏輯一律走 MenuLogic（換裝環/差異/技能/衍生），view 走 PixelUI。無資料處佔位「—」。

const ST_ATTR := 0
const ST_EQUIP := 1
const ST_SKILL := 2
const ST_STORY := 3
const SUBTABS := ["屬性", "裝備", "技能", "故事"]

var _level := 0
var _member := 0
var _subtab := 0
var _cursor := 0
var _dirty := true

var _content: Control          # 每次重建的內容根（HBox）
var _subtab_btns: Array[Button] = []


func _get_party() -> Array:
	return GameState.party


func page_enter() -> void:
	_level = 0
	_cursor = 0
	_dirty = true
	if _member >= _get_party().size():
		_member = 0


func at_top_zone() -> bool:
	return _level == 0


func page_back() -> bool:
	if _level == 1:
		_level = 0
		_cursor = 0
		_dirty = true
		return true
	return false


func page_input() -> String:
	var ps := _get_party()
	if ps.is_empty():
		return "（隊伍是空的）"
	_member = clampi(_member, 0, ps.size() - 1)

	if _level == 0:
		if move_hit("move_up", _member > 0):
			_member -= 1; _dirty = true
		if move_hit("move_down", _member < ps.size() - 1):
			_member += 1; _dirty = true
		if hit("ui_accept"):
			_level = 1; _cursor = 0; _dirty = true
			AudioManager.sfx("select.mp3")
		return "↑↓ 換隊員　Enter 檢視/操作　←→ 切分頁　Esc 關閉"

	# level 1
	if move_hit("move_left"):
		_subtab = (_subtab + SUBTABS.size() - 1) % SUBTABS.size(); _cursor = 0; _dirty = true
	if move_hit("move_right"):
		_subtab = (_subtab + 1) % SUBTABS.size(); _cursor = 0; _dirty = true

	var m: Dictionary = ps[_member]
	if ContentDB.is_loaded:
		Derive.derive(m)
	match _subtab:
		ST_ATTR:
			return _input_attr(m)
		ST_EQUIP:
			return _input_equip(m)
		ST_SKILL:
			return _input_skill(m)
		_:
			return "←→ 切子頁　Esc 返回"


func _input_attr(m: Dictionary) -> String:
	var n := MenuLogic.PRIMARY.size()
	if move_hit("move_up", _cursor > 0):
		_cursor -= 1; _dirty = true
	if move_hit("move_down", _cursor < n - 1):
		_cursor += 1; _dirty = true
	# 配點：1/2/3 直接對 力/敏/智；Enter/→ 對游標所在屬性。
	if hit("stat_str"):
		_alloc("str")
	if hit("stat_agi"):
		_alloc("agi")
	if hit("stat_int"):
		_alloc("int")
	if hit("ui_accept"):
		_alloc(String(MenuLogic.PRIMARY[_cursor][0]))
	return "↑↓ 選屬性　1/2/3 或 Enter 配點　←→ 切子頁　Esc 返回"


func _input_equip(m: Dictionary) -> String:
	var n := MenuLogic.SLOTS.size()
	if move_hit("move_up", _cursor > 0):
		_cursor -= 1; _dirty = true
	if move_hit("move_down", _cursor < n - 1):
		_cursor += 1; _dirty = true
	if hit("ui_accept"):
		# 沿環換裝（含「空」位＝卸下），對照舊選單能力頁 slot 的 cycle_eq。
		if MenuLogic.cycle_eq(m, String(MenuLogic.SLOTS[_cursor][0])):
			Derive.derive(m)
			AudioManager.sfx("learn.mp3")   # 對應 build_cq2.py L2144：換裝
			_dirty = true
		else:
			AudioManager.sfx("return.mp3")   # 無可換候選
	return "↑↓ 選部位　Enter 循環換裝(含卸下)　滑鼠可點候選　←→ 切子頁　Esc 返回"


func _input_skill(m: Dictionary) -> String:
	var learned := MenuLogic.skill_list(m)
	if move_hit("move_up", _cursor > 0):
		_cursor -= 1; _dirty = true
	if move_hit("move_down", _cursor < learned.size() - 1):
		_cursor += 1; _dirty = true
	if hit("ui_accept") and _cursor < learned.size():
		_upgrade_skill(m, learned[_cursor])
	return "↑↓ 選技能　Enter 升級　←→ 切子頁　Esc 返回"


# --- 動作（鍵盤＋滑鼠共用）---
func _alloc(attr: String) -> void:
	var ps := _get_party()
	if _member >= ps.size():
		return
	var m: Dictionary = ps[_member]
	if int(m.get("pts", 0)) > 0:
		m["attrs"][attr] = int(m["attrs"].get(attr, 0)) + 1
		m["pts"] = int(m["pts"]) - 1
		Derive.derive(m)
		AudioManager.sfx("select.mp3")   # 對應 build_cq2.py L2088-2090：配點
		_dirty = true
	else:
		AudioManager.sfx("return.mp3")   # 無屬性點可配


func _upgrade_skill(m: Dictionary, sk: SkillDef) -> void:
	if sk == null:
		return
	if int(m.get("spts", 0)) > 0 and int(m.get("sk", {}).get(sk.id, 0)) < MenuLogic.skill_max_lv():
		m["sk"][sk.id] = int(m["sk"][sk.id]) + 1
		m["spts"] = int(m["spts"]) - 1
		Derive.derive(m)
		AudioManager.sfx("learn.mp3")   # 對應 build_cq2.py L2179：升級技能
		_dirty = true
	else:
		AudioManager.sfx("return.mp3")   # 對應 build_cq2.py L2185：無技能點/已滿級


func _on_subtab_pressed(i: int) -> void:
	_level = 1
	_subtab = i
	_cursor = 0
	_dirty = true


func _on_member(delta: int) -> void:
	var ps := _get_party()
	_member = clampi(_member + delta, 0, max(0, ps.size() - 1))
	_dirty = true


func _on_equip_item(item_id: String) -> void:
	var ps := _get_party()
	if _member >= ps.size():
		return
	MenuLogic.equip_to(ps[_member], item_id)
	AudioManager.sfx("learn.mp3")   # 對應 build_cq2.py L2144：換裝
	_dirty = true


func _on_unequip(slot: String) -> void:
	var ps := _get_party()
	if _member >= ps.size():
		return
	MenuLogic.unequip(ps[_member], slot)
	AudioManager.sfx("select.mp3")   # 對應 build_cq2.py L2143：卸下
	_dirty = true


func _on_upgrade_pressed(skill_id: String) -> void:
	var ps := _get_party()
	if _member >= ps.size():
		return
	var m: Dictionary = ps[_member]
	_level = 1
	_upgrade_skill(m, _find_skill(m, skill_id))


func _find_skill(m: Dictionary, skill_id: String) -> SkillDef:
	for s in MenuLogic.skill_list(m):
		if s.id == skill_id:
			return s
	return null


func _on_alloc_pressed(attr: String) -> void:
	_level = 1
	_alloc(attr)


# =========================================================================
# 重建（只在 _dirty）
# =========================================================================
func page_refresh() -> void:
	if not _dirty:
		return
	_dirty = false
	if not ContentDB.is_loaded:
		return
	if _content != null:
		_content.queue_free()
	_subtab_btns.clear()
	_content = _build()
	add_child(_content)


func _build() -> Control:
	var root := HBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.add_theme_constant_override("separation", 14)

	var ps := _get_party()
	if ps.is_empty():
		root.add_child(PixelUI.label("隊伍是空的", PixelUI.F_NAME, PixelUI.DIM))
		return root
	_member = clampi(_member, 0, ps.size() - 1)
	var m: Dictionary = ps[_member]
	Derive.derive(m)

	var multi := ps.size() > 1
	if multi:
		root.add_child(_member_arrow(-1))
	root.add_child(_build_portrait(m))
	root.add_child(_build_right(m))
	if multi:
		root.add_child(_member_arrow(1))
	return root


## 整個角色分頁最左/最右的大箭頭（切換隊員）。delta=-1 左、+1 右。
func _member_arrow(delta: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = "◀" if delta < 0 else "▶"
	b.custom_minimum_size = Vector2(40, 0)
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", PixelUI.CYAN)
	b.add_theme_color_override("font_hover_color", PixelUI.SEL)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_color_override("font_outline_color", PixelUI.OUTLINE)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.039, 0.039, 0.078, 0.32)
	flat.set_border_width_all(2)
	flat.border_color = PixelUI.OUTLINE
	var hov := flat.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.137, 0.149, 0.235, 0.6)
	hov.border_color = PixelUI.SEL
	b.add_theme_stylebox_override("normal", flat)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.pressed.connect(_on_member.bind(delta))
	return b


func _build_portrait(m: Dictionary) -> Control:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var st := PixelUI.panel_style(Color(0.196, 0.212, 0.243, 1.0), 3, PixelUI.SEL if _level == 0 else PixelUI.OUTLINE)
	st.content_margin_left = 0
	st.content_margin_right = 0
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel", st)

	var art := TextureRect.new()
	art.anchor_right = 1.0
	art.anchor_bottom = 1.0
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := _portrait_texture(String(m.get("id", "")))
	if tex != null:
		art.texture = tex
	panel.add_child(art)

	# 底部漸層（透明→深，照 Spec；不用實心底色）
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(0.039, 0.039, 0.078, 0.0), Color(0.039, 0.039, 0.078, 0.92)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 8
	gt.height = 128
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var grad_rect := TextureRect.new()
	grad_rect.texture = gt
	grad_rect.stretch_mode = TextureRect.STRETCH_SCALE
	grad_rect.anchor_top = 1.0
	grad_rect.anchor_right = 1.0
	grad_rect.anchor_bottom = 1.0
	grad_rect.offset_top = -124.0
	grad_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(grad_rect)

	# 名牌（直接壓在立繪上，描邊字，無底色）
	var fv := VBoxContainer.new()
	fv.anchor_top = 1.0
	fv.anchor_right = 1.0
	fv.anchor_bottom = 1.0
	fv.offset_top = -78.0
	fv.offset_left = 14.0
	fv.offset_right = -14.0
	fv.offset_bottom = -12.0
	fv.add_theme_constant_override("separation", 2)
	panel.add_child(fv)
	var namerow := HBoxContainer.new()
	namerow.add_theme_constant_override("separation", 8)
	namerow.add_child(PixelUI.label(String(m.get("name", "")), 28, PixelUI.GOLD, 4))
	namerow.add_child(PixelUI.label("Lv" + str(m.get("lv", 1)), 15, PixelUI.WHITE, 3))
	fv.add_child(namerow)
	fv.add_child(PixelUI.label("職業：" + MenuLogic.cls_name(m), 16, PixelUI.WHITE, 3))
	return panel


func _portrait_texture(id: String) -> Texture2D:
	for p in ["res://assets/ui/menuart_%s.png" % id, "res://assets/ui/portrait_%s.png" % id]:
		if ResourceLoader.exists(p):
			return load(p)
	return null


func _build_right(m: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)

	# 子頁列
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	for i in SUBTABS.size():
		var b := PixelUI.button(SUBTABS[i], PixelUI.GOLD if (_level == 1 and i == _subtab) else PixelUI.SUBTLE, 17)
		if _level == 1 and i == _subtab:
			var sb := PixelUI.selected_style(true)
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sb)
		b.pressed.connect(_on_subtab_pressed.bind(i))
		bar.add_child(b)
		_subtab_btns.append(b)
	col.add_child(bar)

	# body 面板
	var body := PixelUI.panel(PixelUI.PANEL_BG, 3)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 12)
	scroll.add_child(inner)

	match _subtab:
		ST_ATTR:
			_build_attr(inner, m)
		ST_EQUIP:
			_build_equip(inner, m)
		ST_SKILL:
			_build_skill(inner, m)
		_:
			_build_story(inner, m)
	col.add_child(body)
	return col


# ---- 屬性 ----
func _build_attr(box: VBoxContainer, m: Dictionary) -> void:
	# HP/MP
	var hpmp := HBoxContainer.new()
	hpmp.add_theme_constant_override("separation", 16)
	hpmp.add_child(_stat_bar("HP", m.get("hp", 0), m.get("maxhp", 0), PixelUI.HP))
	hpmp.add_child(_stat_bar("MP", m.get("mp", 0), m.get("maxmp", 0), PixelUI.MP))
	box.add_child(hpmp)

	# 衍生 6 格
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	for pair in MenuLogic.DERIVED6:
		var dk := String(pair[0])
		var dtxt: String
		if dk == "critdmg":
			dtxt = "×" + MenuLogic.num(m.get(dk, 0))            # 爆傷倍率，如 ×1.4
		elif dk == "critV" or dk == "critresV":
			dtxt = MenuLogic.num(m.get(dk, 0)) + "%"            # 會心/抗爆為百分比
		else:
			dtxt = MenuLogic.num(m.get(dk, 0))
		grid.add_child(_derived_cell(String(pair[1]), dtxt))
	box.add_child(grid)

	# 配點
	var alloc := PixelUI.panel(PixelUI.PANEL_BG2, 2)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 10)
	alloc.add_child(av)
	var pts := int(m.get("pts", 0))
	var head := HBoxContainer.new()
	head.add_child(PixelUI.label("主屬性配點", 18, PixelUI.WHITE))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	head.add_child(PixelUI.label("剩餘屬性點 %d" % pts, 16, PixelUI.SEL if pts > 0 else PixelUI.DIM))
	av.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in MenuLogic.PRIMARY.size():
		var key := String(MenuLogic.PRIMARY[i][0])
		var nm := String(MenuLogic.PRIMARY[i][1])
		row.add_child(_alloc_block(nm, key, int(m["attrs"].get(key, 0)), pts > 0, _level == 1 and _subtab == ST_ATTR and _cursor == i))
	av.add_child(row)
	box.add_child(alloc)

	# 詳細（佔位為主）
	var det := PixelUI.panel(PixelUI.PANEL_BG2, 2)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	det.add_child(dv)
	dv.add_child(PixelUI.label("◆ 詳細屬性", 17, PixelUI.GOLD))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 20)
	line.add_child(_kv("幸運", "—", PixelUI.DIM))
	line.add_child(_kv("特別加護", "—", PixelUI.DIM))
	var eqt := TitlesData.equipped_name()
	line.add_child(_kv("稱號", eqt if eqt != "" else "無", PixelUI.GOLD if eqt != "" else PixelUI.DIM))
	dv.add_child(line)
	dv.add_child(PixelUI.label("武器類型熟練（敬請期待）", 14, PixelUI.DIM))
	dv.add_child(_placeholder_grid(MenuLogic.WEAPON_TYPES))
	dv.add_child(PixelUI.label("屬性攻擊加護（敬請期待）", 14, PixelUI.DIM))
	dv.add_child(_placeholder_grid(MenuLogic.ELEMENTS))
	box.add_child(det)


func _stat_bar(name_: String, cur: Variant, mx: Variant, color: Color) -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	top.add_child(PixelUI.label(name_, 16, PixelUI.WHITE, 3))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(sp)
	top.add_child(PixelUI.label("%s/%s" % [MenuLogic.num(cur), MenuLogic.num(mx)], 16, PixelUI.WHITE, 3))
	wrap.add_child(top)
	var pb := PixelUI.progress(color, 120)
	pb.max_value = maxf(1.0, float(mx))
	pb.value = float(cur)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(pb)
	return wrap


func _derived_cell(name_: String, value: String) -> Control:
	var p := PixelUI.panel(Color(0.117, 0.133, 0.211, 0.8), 2, PixelUI.OUTLINE)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var n := PixelUI.label(name_, 13, PixelUI.SUBTLE, 2)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var val := PixelUI.label(value, 22, PixelUI.CYAN, 3)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	v.add_child(val)
	return p


func _alloc_block(nm: String, key: String, value: int, can_add: bool, focused: bool) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := PixelUI.selected_style(true) if focused else PixelUI.panel_style(Color(0.039, 0.039, 0.078, 0.35), 2, PixelUI.OUTLINE)
	p.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var nl := PixelUI.label(nm, 16, PixelUI.WHITE, 3)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nl)
	var ctl := HBoxContainer.new()
	ctl.alignment = BoxContainer.ALIGNMENT_CENTER
	ctl.add_theme_constant_override("separation", 8)
	var minus := PixelUI.button("−", PixelUI.DIM, 20)
	minus.disabled = true   # 原版不可退點（pts 只減不加），保留版面停用
	ctl.add_child(minus)
	var vv := PixelUI.label(str(value), 24, PixelUI.SEL, 4)
	vv.custom_minimum_size = Vector2(34, 0)
	vv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctl.add_child(vv)
	var plus := PixelUI.button("＋", PixelUI.GOLD if can_add else PixelUI.DIM, 20)
	plus.disabled = not can_add
	plus.pressed.connect(_on_alloc_pressed.bind(key))
	ctl.add_child(plus)
	v.add_child(ctl)
	return p


func _placeholder_grid(names: Array) -> Control:
	var g := HBoxContainer.new()
	g.add_theme_constant_override("separation", 5)
	for nm in names:
		var p := PixelUI.panel(Color(0.039, 0.039, 0.078, 0.4), 2, PixelUI.OUTLINE)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		p.add_child(v)
		var n := PixelUI.label(String(nm), 13, PixelUI.SUBTLE, 2)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var z := PixelUI.label("—", 15, PixelUI.DIM, 2)
		z.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n); v.add_child(z)
		g.add_child(p)
	return g


func _kv(k: String, v: String, vc: Color) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(PixelUI.label(k, 15, PixelUI.SUBTLE, 3))
	h.add_child(PixelUI.label(v, 15, vc, 3))
	return h


# ---- 裝備 ----
func _build_equip(box: VBoxContainer, m: Dictionary) -> void:
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 14)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 左：slot 清單
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(230, 0)
	left.add_theme_constant_override("separation", 7)
	var eqd: Dictionary = m.get("eq", {})
	for i in MenuLogic.SLOTS.size():
		var slot := String(MenuLogic.SLOTS[i][0])
		var label_ := String(MenuLogic.SLOTS[i][1])
		var eid: Variant = eqd.get(slot, "")
		var ename := "— 未裝備"
		if eid != null and String(eid) != "":
			var ed: EquipmentDef = ContentDB.get_equipment(String(eid))
			if ed != null:
				ename = ed.display_name
		left.add_child(_slot_row(slot, label_, ename, _level == 1 and _subtab == ST_EQUIP and _cursor == i))
	wrap.add_child(left)

	# 右：選定 slot 詳情 ＋ 可更換候選
	var sel_slot := String(MenuLogic.SLOTS[_cursor][0]) if _cursor < MenuLogic.SLOTS.size() else "weapon"
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	right.add_child(_equip_detail(m, sel_slot))
	right.add_child(PixelUI.label("可更換（%s）" % MenuLogic.slot_label(sel_slot), 15, PixelUI.GOLD))
	var cands := MenuLogic.bag_for_slot(MenuLogic.slot_type(sel_slot))
	if cands.is_empty():
		right.add_child(PixelUI.label("（背包沒有可換的%s）" % MenuLogic.slot_label(sel_slot), 14, PixelUI.DIM))
	for c in cands:
		right.add_child(_candidate_row(m, c))
	wrap.add_child(right)
	box.add_child(wrap)


func _slot_row(slot: String, label_: String, ename: String, focused: bool) -> Control:
	var p := PanelContainer.new()
	var st := PixelUI.selected_style(true) if focused else PixelUI.panel_style(Color(0.078, 0.086, 0.149, 0.6), 2, PixelUI.OUTLINE)
	p.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(PixelUI.slot_icon(MenuLogic.slot_type(slot), 30))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(PixelUI.label(label_, 12, PixelUI.SUBTLE, 2))
	v.add_child(PixelUI.label(ename, 16, PixelUI.WHITE if ename != "— 未裝備" else PixelUI.DIM, 3))
	h.add_child(v)
	return p


func _equip_detail(m: Dictionary, slot: String) -> Control:
	var p := PixelUI.panel(PixelUI.PANEL_BG2, 2)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var eqd: Dictionary = m.get("eq", {})
	var eid: Variant = eqd.get(slot, "")
	if eid == null or String(eid) == "":
		v.add_child(PixelUI.label("%s：未裝備" % MenuLogic.slot_label(slot), 20, PixelUI.DIM))
		v.add_child(PixelUI.label("選下方候選裝上。", 14, PixelUI.SUBTLE))
		return p
	var ed: EquipmentDef = ContentDB.get_equipment(String(eid))
	if ed == null:
		v.add_child(PixelUI.label("（裝備資料缺失）", 16, PixelUI.BAD))
		return p
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 9)
	head.add_child(PixelUI.label(ed.display_name, 22, PixelUI.GOLD, 4))
	head.add_child(PixelUI.chip(String(MenuLogic.SLOTN.get(ed.slot, ed.slot)), PixelUI.SUBTLE))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	var off := PixelUI.button("卸下", PixelUI.BAD, 15)
	off.pressed.connect(_on_unequip.bind(slot))
	head.add_child(off)
	v.add_child(head)
	if ed.desc != "":
		var d := PixelUI.label(ed.desc, 14, PixelUI.SUBTLE, 2)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
	var dd := MenuLogic.eq_desc(ed)
	v.add_child(PixelUI.label("屬性：" + (dd if dd != "" else "（無加成）"), 15, PixelUI.CYAN, 3))
	return p


func _candidate_row(m: Dictionary, c: Dictionary) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var st := PixelUI.panel_style(Color(0.078, 0.086, 0.149, 0.7), 2, PixelUI.OUTLINE)
	b.add_theme_stylebox_override("normal", st)
	var hov := PixelUI.panel_style(Color(0.137, 0.149, 0.235, 0.8), 2, PixelUI.SEL)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.pressed.connect(_on_equip_item.bind(String(c["id"])))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.anchor_right = 1.0
	h.add_theme_constant_override("separation", 10)
	b.add_child(h)
	var ed: EquipmentDef = c["def"]
	var xn := (" ×%d" % int(c["count"])) if int(c["count"]) > 1 else ""
	var nm := PixelUI.label(ed.display_name + xn, 15, PixelUI.WHITE, 3)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nm)
	for d in MenuLogic.equip_diff(m, String(c["id"])):
		var arrow := " ▲" if d["up"] else " ▼"
		h.add_child(PixelUI.label("%s %s→%s%s" % [d["name"], d["from"], d["to"], arrow], 13, PixelUI.GOOD if d["up"] else PixelUI.BAD, 2))
	# 讓按鈕高度合理
	b.custom_minimum_size = Vector2(0, 34)
	return b


# ---- 技能 ----
func _build_skill(box: VBoxContainer, m: Dictionary) -> void:
	var head := HBoxContainer.new()
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	head.add_child(PixelUI.label("技能點 %d" % int(m.get("spts", 0)), 15, PixelUI.SEL, 3))
	box.add_child(head)

	var learned := MenuLogic.skill_list(m)
	if learned.is_empty():
		box.add_child(PixelUI.label("（尚未習得技能）", 14, PixelUI.DIM))
	for i in learned.size():
		box.add_child(_skill_card(m, learned[i], i, _level == 1 and _subtab == ST_SKILL and _cursor == i, false))
	var locked := MenuLogic.locked_skills(m)
	for s in locked:
		box.add_child(_skill_card(m, s, -1, false, true))


func _skill_card(m: Dictionary, sk: SkillDef, idx: int, focused: bool, locked: bool) -> Control:
	var p := PanelContainer.new()
	var border := PixelUI.SEL if focused else PixelUI.OUTLINE
	var st := PixelUI.panel_style(Color(0.078, 0.086, 0.149, 0.7), 2, border)
	p.add_theme_stylebox_override("panel", st)
	if locked:
		p.modulate = Color(1, 1, 1, 0.55)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	var titlerow := HBoxContainer.new()
	titlerow.add_theme_constant_override("separation", 8)
	titlerow.add_child(PixelUI.label(sk.display_name, 18, PixelUI.WHITE, 3))
	# 元素/type tag＝佔位（用 kind 粗分），敘述＝佔位。
	var tag := "治療" if sk.kind == "heal" else "物理"
	titlerow.add_child(PixelUI.chip(tag, PixelUI.GOOD if sk.kind == "heal" else PixelUI.BAD))
	titlerow.add_child(PixelUI.label("MP%d" % sk.mp, 13, PixelUI.SUBTLE, 2))
	if locked:
		titlerow.add_child(PixelUI.label("Lv%d 習得" % sk.unlock_lv, 13, PixelUI.DIM, 2))
	else:
		var slv := int(m.get("sk", {}).get(sk.id, 0))
		var mult := "%.2f" % (sk.mult * MenuLogic.sk_pow(slv))
		titlerow.add_child(PixelUI.label("威力×%s" % mult, 13, PixelUI.SUBTLE, 2))
	v.add_child(titlerow)
	if not locked:
		var slv2 := int(m.get("sk", {}).get(sk.id, 0))
		var mxlv := MenuLogic.skill_max_lv()
		var lvrow := HBoxContainer.new()
		lvrow.add_theme_constant_override("separation", 8)
		lvrow.add_child(PixelUI.label("Lv%d/%d" % [slv2, mxlv], 13, PixelUI.GOLD, 2))
		var pb := PixelUI.progress(Color(0.816, 0.522, 0.290), 100)
		pb.max_value = float(mxlv); pb.value = float(slv2)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lvrow.add_child(pb)
		v.add_child(lvrow)
	h.add_child(v)

	if not locked:
		var up := PixelUI.button("升級", PixelUI.GOLD, 15)
		up.pressed.connect(_on_upgrade_pressed.bind(sk.id))
		h.add_child(up)
	return p


# ---- 故事 ----
func _build_story(box: VBoxContainer, m: Dictionary) -> void:
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 10)
	chips.add_child(_kv("年齡", "—", PixelUI.DIM))
	chips.add_child(_kv("出身", "—", PixelUI.DIM))
	chips.add_child(_kv("武器傾向", "—", PixelUI.DIM))
	box.add_child(chips)

	var p := PixelUI.panel(PixelUI.PANEL_BG2, 2)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(PixelUI.label("◆ 人物誌", 17, PixelUI.GOLD))
	var pdef: PartyMemberDef = ContentDB.get_party_member(String(m.get("id", "")))
	var story: Array = pdef.story if (pdef != null and pdef.story.size() > 0) else ["（沒有相關紀錄）"]
	for line in story:
		var l := PixelUI.label(String(line), 15, Color(0.843, 0.863, 0.921), 2)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	box.add_child(p)
