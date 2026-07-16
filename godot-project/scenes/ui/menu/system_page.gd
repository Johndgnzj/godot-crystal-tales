extends MenuPage
## 系統分頁（3a 版）：左選單 存檔/讀檔/操作教學/離開遊戲，右面板隨選單切換。
##
## 真實：操作教學(靜態)、離開→回標題(對照舊 _quit_to_title)、存檔槽1(SaveManager.save_game 零參數)、
## 讀檔槽1(SaveManager.load_game + SceneRouter.go_to)。佔位：存/讀檔槽 2/3（單槽存檔，其餘停用）。
## 兩層：level0 左選單(↑↓ 選、Enter 進入)、level1 右面板(↑↓ 選項、Enter 執行、Esc 返回)。

const MENU := ["存檔", "讀檔", "操作教學", "離開遊戲"]
const M_SAVE := 0
const M_LOAD := 1
const M_HELP := 2
const M_EXIT := 3
const SLOTS := 3

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


func page_enter() -> void:
	_level = 0
	_menu = 0
	_sub = 0
	_msg = ""
	_dirty = true


func at_top_zone() -> bool:
	return _level == 0


func page_back() -> bool:
	if _level == 1:
		_level = 0
		_msg = ""
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
			_level = 1; _sub = 0; _msg = ""; _dirty = true
			AudioManager.sfx("select.mp3")
		return "↑↓ 選項目　Enter 進入　←→ 切分頁　Esc 關閉"

	# level 1
	match _menu:
		M_SAVE, M_LOAD:
			if move_hit("move_up", _sub > 0):
				_sub -= 1; _dirty = true
			if move_hit("move_down", _sub < SLOTS - 1):
				_sub += 1; _dirty = true
			if hit("ui_accept"):
				_activate_slot(_sub)
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


func _activate_slot(slot: int) -> void:
	if slot != 0:
		AudioManager.sfx("return.mp3")   # 單槽存檔：僅槽 1 可用，槽 2/3 佔位停用
		return
	if _menu == M_SAVE:
		SaveManager.save_game()
		AudioManager.sfx("win.wav")   # 對應 build_cq2.py L1688：存檔
		_msg = "已存檔（槽 1）"
		_dirty = true
	elif _menu == M_LOAD:
		if SaveManager.has_save() and SaveManager.load_game():
			# 讀檔後切到存檔場景（load_game 已設 result=resume 與 return 座標）。
			AudioManager.sfx("select.mp3")
			SceneRouter.go_to(SaveManager.loaded_scene, "")
		else:
			AudioManager.sfx("return.mp3")   # 無存檔可讀


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
	_menu = i; _level = 1; _sub = 0; _msg = ""; _dirty = true


func _on_slot(i: int) -> void:
	_level = 1; _sub = i; _activate_slot(i)


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
	_content = _build()
	add_child(_content)


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
			_build_slots(rv, true)
		M_LOAD:
			_build_slots(rv, false)
		M_HELP:
			_build_help(rv)
		M_EXIT:
			_build_exit(rv)
	wrap.add_child(right)
	return wrap


func _build_slots(box: VBoxContainer, is_save: bool) -> void:
	box.add_child(PixelUI.label("存檔" if is_save else "讀檔", 20, PixelUI.GOLD, 4))
	if _msg != "":
		box.add_child(PixelUI.label(_msg, 15, PixelUI.GOOD, 3))
	var has := SaveManager.has_save()
	for i in SLOTS:
		box.add_child(_slot_row(i, is_save, has))
	box.add_child(PixelUI.label("＊本作為單一存檔槽，槽 2／3 敬請期待。", 13, PixelUI.DIM, 2))


func _slot_row(i: int, is_save: bool, has_save: bool) -> Control:
	var enabled := i == 0 and (is_save or has_save)
	var focused := _level == 1 and i == _sub
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 60)
	var st := PixelUI.selected_style(true) if focused else PixelUI.panel_style(Color(0.078, 0.086, 0.149, 0.7), 2, PixelUI.OUTLINE)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("disabled", st)
	b.add_theme_stylebox_override("hover", st)   # 不做 hover：比照 normal（見 _no_hover）
	b.pressed.connect(_on_slot.bind(i))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.anchor_right = 1.0
	h.add_theme_constant_override("separation", 12)
	b.add_child(h)
	h.add_child(PixelUI.label("%d" % (i + 1), 24, PixelUI.CYAN, 3))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if i == 0:
		if SaveManager.has_save():
			v.add_child(PixelUI.label("遊戲進度存檔", 16, PixelUI.WHITE, 3))
			v.add_child(PixelUI.label("已有存檔紀錄", 13, PixelUI.SUBTLE, 2))
		else:
			v.add_child(PixelUI.label("— 空的存檔欄 —", 16, PixelUI.DIM, 3))
	else:
		v.add_child(PixelUI.label("— 空的存檔欄 —", 16, PixelUI.DIM, 3))
		v.add_child(PixelUI.label("（敬請期待）", 12, PixelUI.DIM, 2))
	h.add_child(v)
	var act := ("覆寫" if (is_save and SaveManager.has_save()) else "存檔") if is_save else "讀取"
	h.add_child(PixelUI.label(act if enabled else "—", 15, PixelUI.GOLD if enabled else PixelUI.DIM, 3))
	return b


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
