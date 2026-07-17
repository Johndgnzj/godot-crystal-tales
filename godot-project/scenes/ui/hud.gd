extends CanvasLayer
## 世界場景 HUD —— 右上角「開選單」圖示鈕 ＋（debug build 才有的）除錯選單鈕。
##
## 一般顯示（角色/HP MP/目標/金幣）已移除，改由選單內查看。開選單：點選單圖示走 menu.request_open()
## （M 鍵仍可開）。世界場景自身的互動提示 `$HUD/Prompt` 是另一節點、不在此檔。
##
## 除錯選單（只在 OS.is_debug_build()）：選單圖示左邊多一顆 ⚙ 鈕，開後有
##   直接回城（SceneRouter.go_to Town）／立刻戰鬥（DebugHooks.force_encounter 目前區域遭遇）／
##   自動導航（列出本場景 ExitZone → 選定後關面板、自動走向該出口，走進去即換場景）。
## 自動導航靠 InputBridge.simulate_action_* 灌 move_* 給既有 PlayerController 走（含碰撞），
## 是直線趨近、非路徑尋徑，遇牆會卡住 → 有 NAV_TIMEOUT 保底。純除錯用，release 匯出不會出現。

@onready var _menu_btn: TextureButton = $Root/MenuBtn

var scene_id: String = ""

var _dbg_btn: Button
var _dbg_panel: Control
var _dbg_open := false

var _nav_active := false
var _nav_target := Vector2.ZERO
var _nav_time := 0.0
const NAV_DZ := 8.0
const NAV_ARRIVE := 12.0
const NAV_TIMEOUT := 12.0
const MOVE_ACTIONS := ["move_up", "move_down", "move_left", "move_right"]


func _ready() -> void:
	_menu_btn.pressed.connect(_on_menu_btn)
	if OS.is_debug_build():
		_build_debug_button()


func set_scene_id(id: String) -> void:
	scene_id = id


func _on_menu_btn() -> void:
	var m := get_tree().get_first_node_in_group("cq_menu")
	if m != null and m.has_method("request_open"):
		m.request_open()


# =========================================================================
# 自動導航驅動（灌 move_* 給玩家走）
# =========================================================================
func _process(delta: float) -> void:
	if not _nav_active:
		return
	_nav_time += delta
	var p := _find_player()
	if p == null or _nav_time > NAV_TIMEOUT:
		_stop_nav()
		return
	var d: Vector2 = _nav_target - p.global_position
	if d.length() <= NAV_ARRIVE:
		_stop_nav()
		return
	_hold("move_right", d.x > NAV_DZ)
	_hold("move_left", d.x < -NAV_DZ)
	_hold("move_down", d.y > NAV_DZ)
	_hold("move_up", d.y < -NAV_DZ)


func _hold(action: String, on: bool) -> void:
	if on:
		InputBridge.simulate_action_press(action)
	else:
		InputBridge.simulate_action_release(action)


func _stop_nav() -> void:
	_nav_active = false
	for a in MOVE_ACTIONS:
		InputBridge.simulate_action_release(a)


func _start_nav(target: Vector2) -> void:
	_nav_target = target
	_nav_time = 0.0
	_nav_active = true
	_close_debug()


func _find_player() -> Node2D:
	var ns := get_tree().get_nodes_in_group("player")
	if ns.size() > 0 and ns[0] is Node2D:
		return ns[0]
	return null


# =========================================================================
# 除錯選單
# =========================================================================
func _build_debug_button() -> void:
	_dbg_btn = Button.new()
	_dbg_btn.text = "⚙"
	_dbg_btn.focus_mode = Control.FOCUS_NONE
	_dbg_btn.anchor_left = 1.0
	_dbg_btn.anchor_right = 1.0
	_dbg_btn.offset_left = -116.0
	_dbg_btn.offset_right = -68.0
	_dbg_btn.offset_top = 10.0
	_dbg_btn.offset_bottom = 58.0
	_dbg_btn.add_theme_font_size_override("font_size", 22)
	_dbg_btn.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	_dbg_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.55))
	_dbg_btn.add_theme_constant_override("outline_size", 4)
	_dbg_btn.add_theme_color_override("font_outline_color", PixelUI.OUTLINE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.05, 0.82)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.85, 0.55, 0.2)
	sb.set_corner_radius_all(6)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.22, 0.15, 0.06, 0.9)
	_dbg_btn.add_theme_stylebox_override("normal", sb)
	_dbg_btn.add_theme_stylebox_override("hover", hov)
	_dbg_btn.add_theme_stylebox_override("pressed", hov)
	_dbg_btn.pressed.connect(_toggle_debug)
	$Root.add_child(_dbg_btn)


func _toggle_debug() -> void:
	if _dbg_open:
		_close_debug()
	else:
		_dbg_open = true
		_show_debug_main()


func _close_debug() -> void:
	_dbg_open = false
	if _dbg_panel != null:
		_dbg_panel.queue_free()
		_dbg_panel = null


func _show_debug_main() -> void:
	var enc_t := "不會遇敵：開" if DebugHooks.no_encounter else "不會遇敵：關"
	_rebuild_panel("除錯選單", [
		{"t": "直接回城", "cb": _dbg_go_town},
		{"t": "立刻戰鬥", "cb": _dbg_battle},
		{"t": enc_t, "cb": _dbg_toggle_enc},
		{"t": "自動導航", "cb": _show_debug_nav},
	])


func _dbg_toggle_enc() -> void:
	DebugHooks.no_encounter = not DebugHooks.no_encounter
	_show_debug_main()   # 就地重建面板反映新狀態，不關閉方便連續切


func _show_debug_nav() -> void:
	var items: Array = []
	for e in _scene_exits():
		items.append({"t": "→ " + String(e["label"]), "cb": _start_nav.bind(e["pos"])})
	if items.is_empty():
		items.append({"t": "（此區沒有出口）", "cb": Callable()})
	items.append({"t": "‹ 返回", "cb": _show_debug_main})
	_rebuild_panel("自動導航：選目的地", items)


func _rebuild_panel(title: String, items: Array) -> void:
	if _dbg_panel != null:
		_dbg_panel.queue_free()
	var panel := PixelUI.panel(Color(0.047, 0.055, 0.102, 0.95), 3)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -260.0
	panel.offset_right = -12.0
	panel.offset_top = 66.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(PixelUI.label(title, 15, PixelUI.GOLD, 3))
	for it in items:
		var b := PixelUI.button(String(it["t"]), PixelUI.WHITE, 17)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cb: Callable = it["cb"]
		if cb.is_valid():
			b.pressed.connect(cb)
		else:
			b.disabled = true
		v.add_child(b)
	$Root.add_child(panel)
	_dbg_panel = panel


func _dbg_go_town() -> void:
	_close_debug()
	SceneRouter.go_to("Town")


func _dbg_battle() -> void:
	_close_debug()
	DebugHooks.force_encounter(_current_enc())


func _current_enc() -> String:
	var scene := get_tree().current_scene
	if scene != null:
		var eg: Variant = scene.get("enc_group")
		if eg != null and String(eg) != "":
			return String(eg)
	return "forest"


func _scene_exits() -> Array:
	var out: Array = []
	var scene := get_tree().current_scene
	if scene == null:
		return out
	var zones := scene.get_node_or_null("Zones")
	if zones == null:
		return out
	for z in zones.get_children():
		if not (z is ExitZone):
			continue
		var ez := z as ExitZone
		if not ez.enabled:
			continue
		var label: String = ez.to_scene if ez.to_scene != "" else "出口"
		out.append({"label": label, "pos": ez.global_position})
	return out
