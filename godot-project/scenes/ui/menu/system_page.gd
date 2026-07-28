extends MenuPage
## 系統分頁：左選單 存檔/讀檔/刪除存檔/操作教學/離開遊戲，右面板隨選單切換。
##
## 存檔槽**數量無上限**（2026-07-28，見 autoload/save_manager.gd 檔頭）：右面板列出目前所有存檔槽，
## 「存檔」頁最後多一列「＋ 新增存檔」（配下一個空號）、「刪除存檔」頁按兩次 Enter 才真的刪。清單放在
## ScrollContainer 裡，槽再多也捲得到（游標移動時自動捲到選取列）。
## 兩層：level0 左選單(↑↓ 選、Enter 進入)、level1 右面板(↑↓ 選項、Enter 執行、Esc 返回)。

const MENU := ["存檔", "讀檔", "刪除存檔", "操作教學", "離開遊戲"]
const M_SAVE := 0
const M_LOAD := 1
const M_DELETE := 2
const M_HELP := 3
const M_EXIT := 4

## 存檔列顯示的地名。painted 主線場景（NM*＝北方礦山、EF*＝東之森）走前綴判斷，其餘查 MenuLogic.LOC。
const AREA_PREFIX := [["NM", "北方礦山"], ["EFD", "東之森深處"], ["EF", "東之森"]]

const HELP := [
	["方向鍵", "移動 / 選擇"],
	["Enter / 空白", "確定 / 互動 / 推進對話"],
	["Esc", "返回 / 關閉選單"],
	["M", "開關選單"],
	["← →", "切換選單分頁"],
	["戰鬥中", "方向鍵＋Enter 或 滑鼠點擊"],
]

var _level := 0
var _menu := 0
var _sub := 0
var _msg := ""
var _dirty := true
var _content: Control
## SaveManager.list_saves() 的快取；存/刪檔後與進頁時重讀（每幀重掃目錄太浪費）。
var _saves: Array[Dictionary] = []
## 刪除的二次確認對象（槽號；0＝沒有待確認的刪除）。
var _pending_delete := 0
## 目前選取列的節點與外層 ScrollContainer，重建版面後用來把選取列捲進視野。
var _sel_row: Control
var _scroll: ScrollContainer


func page_enter() -> void:
	_level = 0
	_menu = 0
	_sub = 0
	_msg = ""
	_pending_delete = 0
	_reload()


func at_top_zone() -> bool:
	return _level == 0


func page_back() -> bool:
	if _level == 1:
		_level = 0
		_msg = ""
		_pending_delete = 0
		_dirty = true
		return true
	return false


func page_input() -> String:
	if _level == 0:
		if move_hit("move_up", _menu > 0):
			_menu -= 1; _dirty = true
		if move_hit("move_down", _menu < MENU.size() - 1):
			_menu += 1; _dirty = true
		if hit("ui_accept"):
			_level = 1; _sub = 0; _msg = ""; _pending_delete = 0
			_reload()
			AudioManager.sfx("select.mp3")
		return "↑↓ 選項目　Enter 進入　←→ 切分頁　Esc 關閉"

	# level 1
	match _menu:
		M_SAVE, M_LOAD, M_DELETE:
			var n := _row_count()
			if move_hit("move_up", _sub > 0):
				_sub -= 1; _pending_delete = 0; _dirty = true
			if move_hit("move_down", _sub < n - 1):
				_sub += 1; _pending_delete = 0; _dirty = true
			if hit("ui_accept"):
				_activate_row(_sub)
			if _menu == M_DELETE:
				return "↑↓ 選存檔　Enter 刪除（需按兩次）　Esc 返回"
			return "↑↓ 選存檔槽　Enter 執行　Esc 返回"
		M_EXIT:
			if move_hit("move_up", _sub > 0):
				_sub -= 1; _dirty = true
			if move_hit("move_down", _sub < 1):
				_sub += 1; _dirty = true
			if hit("ui_accept"):
				if _sub == 0:
					_do_exit()
				else:
					_level = 0; _dirty = true
					AudioManager.sfx("return.mp3")
			return "↑↓ 選擇　Enter 確認　Esc 返回"
		_:
			return "操作說明　Esc 返回"


## 目前右面板的可選列數：存檔頁多一列「＋ 新增存檔」。
func _row_count() -> int:
	if _menu == M_SAVE:
		return _saves.size() + 1
	return _saves.size()


func _reload() -> void:
	_saves = SaveManager.list_saves()
	_sub = clampi(_sub, 0, maxi(0, _row_count() - 1))
	_dirty = true


func _activate_row(row: int) -> void:
	if row < 0 or row >= _row_count():
		return
	# 存檔頁的最後一列＝新增存檔（slot 0 交給 SaveManager 配新槽）。
	var slot := 0 if row >= _saves.size() else int(_saves[row]["slot"])
	match _menu:
		M_SAVE:
			var written := SaveManager.save_to_slot(slot)
			if written > 0:
				AudioManager.sfx("win.wav")   # 對應 build_cq2.py L1688：存檔
				_msg = "已存檔（槽 %d）" % written
			else:
				AudioManager.sfx("return.mp3")
				_msg = "存檔失敗，請查看主控台訊息"
			_reload()
		M_LOAD:
			if slot > 0 and SaveManager.load_game(slot):
				# 讀檔後切到存檔場景（load_game 已設 result=resume 與 return 座標）。
				AudioManager.sfx("select.mp3")
				SceneRouter.go_to(SaveManager.loaded_scene, "")
			else:
				AudioManager.sfx("return.mp3")   # 讀不到（檔案壞掉/已被刪）
		M_DELETE:
			if slot <= 0:
				return
			if _pending_delete != slot:
				# 第一次 Enter 只是問「真的要刪？」，避免一鍵誤刪。
				_pending_delete = slot
				AudioManager.sfx("cursor.mp3")
				_msg = "再按一次 Enter 刪除槽 %d（Esc 取消）" % slot
				_dirty = true
				return
			SaveManager.delete_save(slot)
			AudioManager.sfx("return.mp3")
			_pending_delete = 0
			_msg = "已刪除槽 %d" % slot
			_reload()


func _do_exit() -> void:
	AudioManager.sfx("select.mp3")
	var mroot := _find_menu_root()
	if mroot != null and mroot.has_method("quit_to_title"):
		mroot.quit_to_title()
	else:
		get_tree().change_scene_to_file("res://scenes/title/title.tscn")


func _find_menu_root() -> Node:
	var n: Node = self
	while n != null:
		if n.is_in_group("cq_menu"):
			return n
		n = n.get_parent()
	return null


# --- 滑鼠 ---
func _on_menu(i: int) -> void:
	_menu = i; _level = 1; _sub = 0; _msg = ""; _pending_delete = 0
	_reload()


func _on_row(i: int) -> void:
	_level = 1
	if _sub != i:
		_sub = i
		_pending_delete = 0
	_activate_row(i)


func _on_exit_btn(do_exit: bool) -> void:
	if do_exit:
		_do_exit()
	else:
		_level = 0; _dirty = true


# =========================================================================
## 系統頁不做 hover：hover 的底與字色都設成跟 normal 一樣。原本滑鼠 hover 高亮會跟鍵盤選取指示
## 撞在一起，看不出目前選的是哪項（John 回饋：hover 讓「離開」項不見）。在 normal 定案後呼叫。
func _no_hover(b: Button, base_color: Color) -> void:
	b.add_theme_color_override("font_hover_color", base_color)
	b.add_theme_stylebox_override("hover", b.get_theme_stylebox("normal"))


func page_refresh() -> void:
	if not _dirty:
		return
	_dirty = false
	if _content != null:
		_content.queue_free()
	_sel_row = null
	_scroll = null
	_content = _build()
	add_child(_content)
	if _scroll != null and _sel_row != null:
		_scroll.call_deferred("ensure_control_visible", _sel_row)


func _build() -> Control:
	var wrap := HBoxContainer.new()
	wrap.anchor_right = 1.0
	wrap.anchor_bottom = 1.0
	wrap.add_theme_constant_override("separation", 14)

	# 左選單
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(200, 0)
	left.add_theme_constant_override("separation", 8)
	for i in MENU.size():
		var col := PixelUI.GOLD if i == _menu else PixelUI.SUBTLE
		var b := PixelUI.button(MENU[i], col, 18)
		b.custom_minimum_size = Vector2(0, 44)
		if i == _menu:
			b.add_theme_stylebox_override("normal", PixelUI.selected_style(_level == 0))
		_no_hover(b, col)
		b.pressed.connect(_on_menu.bind(i))
		left.add_child(b)
	wrap.add_child(left)

	# 右面板
	var right := PixelUI.panel(PixelUI.PANEL_BG, 3)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	right.add_child(rv)
	match _menu:
		M_SAVE:
			_build_slots(rv, M_SAVE)
		M_LOAD:
			_build_slots(rv, M_LOAD)
		M_DELETE:
			_build_slots(rv, M_DELETE)
		M_HELP:
			_build_help(rv)
		M_EXIT:
			_build_exit(rv)
	wrap.add_child(right)
	return wrap


func _build_slots(box: VBoxContainer, mode: int) -> void:
	box.add_child(PixelUI.label(MENU[mode], 20, PixelUI.GOLD, 4))
	if _msg != "":
		box.add_child(PixelUI.label(_msg, 15, PixelUI.GOOD if _pending_delete == 0 else PixelUI.BAD, 3))
	if _saves.is_empty() and mode != M_SAVE:
		box.add_child(PixelUI.label("— 目前沒有任何存檔 —", 16, PixelUI.DIM, 3))
		return

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	_scroll.add_child(list)
	box.add_child(_scroll)

	for i in _saves.size():
		list.add_child(_slot_row(i, _saves[i], mode))
	if mode == M_SAVE:
		list.add_child(_new_slot_row(_saves.size()))
	box.add_child(PixelUI.label("＊存檔槽數量無上限；自動存檔寫入目前這局使用的槽。", 13, PixelUI.DIM, 2))


func _row_button(focused: bool, row: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 62)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := PixelUI.selected_style(true) if focused else PixelUI.panel_style(Color(0.078, 0.086, 0.149, 0.7), 2, PixelUI.OUTLINE)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)   # 不做 hover：比照 normal（見 _no_hover）
	b.pressed.connect(_on_row.bind(row))
	if focused:
		_sel_row = b
	return b


func _slot_row(row: int, info: Dictionary, mode: int) -> Control:
	var slot := int(info["slot"])
	var b := _row_button(_level == 1 and row == _sub, row)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.anchor_right = 1.0
	h.add_theme_constant_override("separation", 12)
	b.add_child(h)
	var num_col := PixelUI.SEL if slot == SaveManager.current_slot else PixelUI.CYAN
	h.add_child(PixelUI.label("%d" % slot, 24, num_col, 3))

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := "%s　Lv%d　%dG" % [_area_name(String(info["scene"])), int(info["lv"]), int(info["gold"])]
	if slot == SaveManager.current_slot:
		head += "　（本局）"
	v.add_child(PixelUI.label(head, 16, PixelUI.WHITE, 3))
	var names := PackedStringArray(info["names"])
	var sub := _time_text(int(info["at"]))
	if names.size() > 0:
		sub += "　" + "・".join(names)
	v.add_child(PixelUI.label(sub, 13, PixelUI.SUBTLE, 2))
	h.add_child(v)

	var act := "覆寫"
	var act_col := PixelUI.GOLD
	if mode == M_LOAD:
		act = "讀取"
	elif mode == M_DELETE:
		act = "確認刪除" if _pending_delete == slot else "刪除"
		act_col = PixelUI.BAD
	h.add_child(PixelUI.label(act, 15, act_col, 3))
	return b


func _new_slot_row(row: int) -> Control:
	var b := _row_button(_level == 1 and row == _sub, row)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.anchor_right = 1.0
	h.add_theme_constant_override("separation", 12)
	b.add_child(h)
	h.add_child(PixelUI.label("＋", 24, PixelUI.GOOD, 3))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(PixelUI.label("新增存檔", 16, PixelUI.WHITE, 3))
	v.add_child(PixelUI.label("存到新的一格（槽 %d）" % SaveManager.next_free_slot(), 13, PixelUI.SUBTLE, 2))
	h.add_child(v)
	h.add_child(PixelUI.label("存檔", 15, PixelUI.GOLD, 3))
	return b


## 存檔列的地名。painted 場景 id 走前綴表，其餘查 MenuLogic.LOC；都查不到就顯示原始 id。
func _area_name(scene_id: String) -> String:
	if scene_id == "":
		return "旅途中"
	if MenuLogic.LOC.has(scene_id):
		return String(MenuLogic.LOC[scene_id])
	for pair in AREA_PREFIX:
		if scene_id.begins_with(String(pair[0])):
			return String(pair[1])
	return scene_id


## 存檔時間（本機時區）。at=0（舊存檔沒有這個欄位）顯示佔位字。
func _time_text(at: int) -> String:
	if at <= 0:
		return "存檔時間不明"
	var tz: Dictionary = Time.get_time_zone_from_system()
	var d := Time.get_datetime_dict_from_unix_time(at + int(tz.get("bias", 0)) * 60)
	return "%04d/%02d/%02d %02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"]]


func _build_help(box: VBoxContainer) -> void:
	box.add_child(PixelUI.label("操作教學", 20, PixelUI.GOLD, 4))
	for row in HELP:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		var k := PixelUI.label(String(row[0]), 16, PixelUI.SEL, 3)
		k.custom_minimum_size = Vector2(150, 0)
		h.add_child(k)
		h.add_child(PixelUI.label(String(row[1]), 16, PixelUI.WHITE, 3))
		box.add_child(h)
	box.add_child(PixelUI.label("旅店（瑪琳家）與神殿可免費全恢復。", 14, PixelUI.CYAN, 2))


func _build_exit(box: VBoxContainer) -> void:
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := PixelUI.label("確定要離開遊戲嗎？", 22, PixelUI.WHITE, 4)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var w := PixelUI.label("未存檔的進度將會遺失！", 15, PixelUI.BAD, 3)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(w)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var yes := PixelUI.button("離開", PixelUI.BAD, 18)
	if _level == 1 and _sub == 0:
		yes.add_theme_stylebox_override("normal", PixelUI.selected_style(true))
	_no_hover(yes, PixelUI.BAD)
	yes.pressed.connect(_on_exit_btn.bind(true))
	row.add_child(yes)
	var no := PixelUI.button("取消", PixelUI.WHITE, 18)
	if _level == 1 and _sub == 1:
		no.add_theme_stylebox_override("normal", PixelUI.selected_style(true))
	_no_hover(no, PixelUI.WHITE)
	no.pressed.connect(_on_exit_btn.bind(false))
	row.add_child(no)
	box.add_child(row)
