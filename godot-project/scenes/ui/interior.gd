extends CanvasLayer
## interior.tscn 的控制腳本 —— 立繪＋選單式室內（town 六棟主人）。
##
## 對應 build_cq2.py「立繪＋選單式室內（intMode==='menu'）」這條唯一 live path（走進式／物件擺放式
## 室內在原始碼裡是死碼，見遷移調查報告）。室內在 Godot 端做成「全螢幕 overlay UI」而非可走動場景：
## 進屋時蓋上一張不透明底＋室內手繪大圖（intc_<key>）＋主人立繪（portrait_<id>），再疊一個指令選單
## （交談／功能／一次性事件／離開）。玩家不走動、世界相機不動（overlay 直接遮住世界）。
##
## 分工：
##   - 門偵測、進出屋、玩家重定位、鎖移動 → world_scene.gd（本場景只負責室內 UI 與選單互動）。
##   - 指令表 → DialogueSystem.get_interior_commands()（buildIntCmds L1575-1582）。
##   - 對話內容與 action side-effect（回血／給道具／開商店／推進旗標）→ DialogueSystem（既有引擎）。
##   - 商店 UI（trade 觸發）→ shop.tscn（監聽 DialogueSystem.shop_requested）。
##
## 輸入協調（沿用 world_scene / shop 同一套）：選單導覽/確認走 _process + InputBridge.is_action_hit()；
## 對話進行中（DialogueSystem.is_busy()）或商店/選單開啟時，本選單停手，讓對應 UI 吃輸入。對話剛結束
## 或剛進門的那一次 ui_accept 用 release-gate 擋掉，避免同一次按壓結束對話又立刻觸發選單指令
## （對應原始碼 st.intJustEntered / st.dlgPrev 的防誤觸，見 build_cq2.py L1907）。

signal leave_requested   ## 玩家選「離開」；world_scene 負責重定位玩家＋world_state.exit_building()＋本場景 close()

const PROP_DIR := "res://assets/props"
const PORTRAIT_DIR := "res://assets/ui"
## 主人立繪高度＝室內大圖高度的 0.82，錨室內框右下（build_cq2.py setIntArt L1569-1573）。
const PORTRAIT_H_RATIO := 0.82
const PORTRAIT_X_NUDGE := 0.02   # 對應原始碼 round(dW*0.02) 的右移微調

@onready var _root: Control = $Root
@onready var _bg: TextureRect = $Root/Bg
@onready var _portrait: TextureRect = $Root/Portrait
@onready var _menu: Control = $Root/Menu

var _active := false
var _door: Dictionary = {}
var _owner_ids: Array = []          # 主人 id 陣列（多主人依序），已由 world 場景資料轉成 id
var _cmds: Array = []               # get_interior_commands() 結果：[{cmd,label,who?}]
var _cursor := 0
var _talk_kind := ""                # "talk"＝交談接力中；其餘＝單一功能/事件
var _talk_queue: Array = []         # 交談接力剩餘主人（talkRest）
var _row_labels: Array = []         # 指令列 Label，導覽時只更新前綴/顏色
var _img_rect := Rect2()            # 室內大圖實際顯示矩形（供立繪錨定）
var _accept_release_needed := false


func _ready() -> void:
	add_to_group("cq_interior")
	_root.visible = false
	DialogueSystem.dialogue_ended.connect(_on_dialogue_ended)


func is_open() -> bool:
	return _active


## 進屋（world_scene 在偵測到門＋確認鍵後呼叫）。door：{key,label,owners:[id...]}。
func open(door: Dictionary) -> void:
	_door = door
	_owner_ids = []
	for o in door.get("owners", []):
		_owner_ids.append(str(o))
	_talk_kind = ""
	_talk_queue = []
	_cursor = 0
	_load_bg(str(door.get("key", "")))
	_set_portrait(_owner_ids[0] if _owner_ids.size() > 0 else "")
	_rebuild_menu()
	_active = true
	_accept_release_needed = true   # 進門那次 ui_accept 不算選單確認
	_root.visible = true


func close() -> void:
	_active = false
	_root.visible = false


func _process(_delta: float) -> void:
	if not _active:
		return
	if _accept_release_needed and not Input.is_action_pressed("ui_accept"):
		_accept_release_needed = false
	# 對話進行中／商店或隊伍選單開啟時，本選單停手（對應原始碼 !st.dlg&&!st.cut&&!st.menu&&!st.shop）。
	if DialogueSystem.is_busy() or _shop_open() or _menu_open():
		return
	var n := _cmds.size()
	if n == 0:
		return
	if InputBridge.is_action_hit("move_up"):
		_cursor = (_cursor - 1 + n) % n
		AudioManager.sfx("cursor.mp3")
		_render_cursor()
	if InputBridge.is_action_hit("move_down"):
		_cursor = (_cursor + 1) % n
		AudioManager.sfx("cursor.mp3")
		_render_cursor()
	if not _accept_release_needed and InputBridge.is_action_hit("ui_accept"):
		_run_cmd(_cmds[_cursor])


## 執行選單指令（對應 runIntCmd L1584-1587）。
func _run_cmd(c: Dictionary) -> void:
	var cmd := str(c.get("cmd", ""))
	if cmd == "leave":
		leave_requested.emit()
		return
	if cmd == "talk":
		_talk_kind = "talk"
		_talk_queue = _owner_ids.slice(1)   # 其餘主人排隊接力
		var primary: String = _owner_ids[0] if _owner_ids.size() > 0 else ""
		_set_portrait(primary)
		DialogueSystem.open_owner_cmd(primary, "talk")
		return
	# trade/rest/pray/quest／一次性事件：跑對應條目，action 在對話結尾觸發。
	_talk_kind = cmd
	_talk_queue = []
	var who := str(c.get("who", _owner_ids[0] if _owner_ids.size() > 0 else ""))
	_set_portrait(who)
	DialogueSystem.open_owner_cmd(who, cmd)


## 對話結束回呼：交談接力（漢克→瑪莎）或回到選單並重建指令（事件完成後即時消失）。
func _on_dialogue_ended(_npc_id: String) -> void:
	if not _active:
		return
	if _talk_kind == "talk" and not _talk_queue.is_empty():
		var nxt := str(_talk_queue.pop_front())
		_set_portrait(nxt)
		if DialogueSystem.open_owner_cmd(nxt, "talk"):
			return
	# 回到選單
	_talk_kind = ""
	_talk_queue = []
	_set_portrait(_owner_ids[0] if _owner_ids.size() > 0 else "")
	_rebuild_menu()
	_accept_release_needed = true   # 結束對話那次 ui_accept 不算選單確認


# =========================================================================
# 視覺
# =========================================================================

func _view_size() -> Vector2:
	# viewport stretch 模式下＝基準解析度 1280x720（project.godot），overlay 座標即基準像素。
	return get_viewport().get_visible_rect().size


## 室內大圖：優先 intc_<key>（去底乾淨版），退回 int_<key>；等比縮到填滿螢幕高、置中、留黑邊。
func _load_bg(key: String) -> void:
	var vs := _view_size()
	var path := "%s/intc_%s.png" % [PROP_DIR, key]
	if not ResourceLoader.exists(path):
		path = "%s/int_%s.png" % [PROP_DIR, key]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_bg.texture = tex
	if tex == null:
		_img_rect = Rect2(Vector2.ZERO, vs)
		_bg.position = Vector2.ZERO
		_bg.size = vs
		return
	var nat := tex.get_size()
	var scale: float = minf(vs.x / nat.x, vs.y / nat.y) if nat.x > 0.0 and nat.y > 0.0 else 1.0
	var dsz := nat * scale
	var org := (vs - dsz) * 0.5
	_img_rect = Rect2(org, dsz)
	_bg.position = org
	_bg.size = dsz


## 主人立繪：高＝室內圖高×0.82，等比換寬，錨室內框右下（build_cq2.py setIntArt L1569-1573）。
func _set_portrait(id: String) -> void:
	if id == "":
		_portrait.visible = false
		return
	var path := "%s/portrait_%s.png" % [PORTRAIT_DIR, id]
	if not ResourceLoader.exists(path):
		_portrait.visible = false
		return
	var tex: Texture2D = load(path)
	if tex == null:
		_portrait.visible = false
		return
	var nat := tex.get_size()
	var ph := _img_rect.size.y * PORTRAIT_H_RATIO
	var pw: float = ph * (nat.x / nat.y) if nat.y > 0.0 else ph
	_portrait.texture = tex
	_portrait.position = Vector2(
		_img_rect.position.x + _img_rect.size.x - pw + _img_rect.size.x * PORTRAIT_X_NUDGE,
		_img_rect.position.y + _img_rect.size.y - ph
	)
	_portrait.size = Vector2(pw, ph)
	_portrait.visible = true


func _rebuild_menu() -> void:
	_cmds = DialogueSystem.get_interior_commands(_owner_ids)
	if _cursor >= _cmds.size():
		_cursor = 0
	_render_menu()


## 指令面板（左側，深色描邊面板＋描邊字；對齊 GDevelop IntCmdBg 左側佈局 L1894）。
func _render_menu() -> void:
	for c in _menu.get_children():
		c.queue_free()
	_row_labels = []
	var panel := PixelUI.panel()
	panel.position = Vector2(72, 388)
	panel.custom_minimum_size = Vector2(300, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var title := PixelUI.label(str(_door.get("label", "")), PixelUI.F_NAME, PixelUI.GOLD)
	vb.add_child(title)
	for _i in _cmds.size():
		var lbl := PixelUI.label("", PixelUI.F_ROW)
		vb.add_child(lbl)
		_row_labels.append(lbl)
	_menu.add_child(panel)
	_render_cursor()


func _render_cursor() -> void:
	for i in _row_labels.size():
		var sel: bool = i == _cursor
		var lbl: Label = _row_labels[i]
		lbl.text = ("▶ " if sel else "　") + str(_cmds[i].get("label", ""))
		lbl.add_theme_color_override("font_color", PixelUI.SEL if sel else Color(0.82, 0.84, 0.9))


func _shop_open() -> bool:
	var s := get_tree().get_first_node_in_group("cq_shop")
	return s != null and s.has_method("is_open") and s.is_open()


func _menu_open() -> bool:
	var m := get_tree().get_first_node_in_group("cq_menu")
	return m != null and m.has_method("is_open") and m.is_open()
