extends Node2D

## 標題頁：新遊戲 / 繼續冒險。方向鍵 ↑↓ 選、Enter（ui_accept）確認。
## 新遊戲 → GameFlow.new_game() + 進 Town；繼續 → SaveManager.load_game() + 回存檔場景。
## 存檔槽無上限（見 autoload/save_manager.gd）；標題的「繼續冒險」固定讀**最近存的那一槽**
## （`load_game()` 零參數＝latest_slot()），要挑槽讀請進遊戲後走選單→系統→讀檔。
## 選項用 GDevelop 端烘好的描邊文字 PNG（t_new/t_cont）呈現；$Menu 為隱藏的狀態文字鏡射，
## 供 tests/check_title_flow.gd 讀取（該測試檔不在本任務可改範圍，故保留此節點）。
##
## 觸控（TASKS/21 階段 2）：兩個選項圖直接點就選＋確認，不必先移游標；底部提示文字跟著改。

const OPTIONS := ["新遊戲", "繼續冒險"]
const COL_SEL := Color(1, 1, 1)
const COL_IDLE := Color(0.58, 0.588, 0.635)
const COL_DISABLED := Color(0.35, 0.36, 0.42, 0.55)

var _sel := 0
var _has_save := false

@onready var _opt_new: TextureRect = $OptNew
@onready var _opt_cont: TextureRect = $OptCont
@onready var _label: Label = $Menu
@onready var _help: Label = $Help


func _ready() -> void:
	_has_save = SaveManager.has_save()
	_sel = 1 if _has_save else 0   # 有存檔：預設游標停在「繼續冒險」；新遊戲位置不動、仍是第一個
	_setup_clickable_options()
	_render()
	AudioManager.play_bgm("bgm_title.mp3")   # 對應 build_cq2.py L3546


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_up"):
		_move(-1)
	elif Input.is_action_just_pressed("ui_down"):
		_move(1)
	elif Input.is_action_just_pressed("ui_accept"):
		_confirm()


## 選項圖本身可點（觸控／滑鼠都吃）：點下去＝選它＋確認，等同鍵盤移游標再按 Enter。
func _setup_clickable_options() -> void:
	for i in OPTIONS.size():
		var rect: TextureRect = _opt_new if i == 0 else _opt_cont
		rect.mouse_filter = Control.MOUSE_FILTER_STOP
		rect.gui_input.connect(_on_option_gui_input.bind(i))
	if TouchControls.is_active():
		_help.text = "點選項開始"


func _on_option_gui_input(event: InputEvent, index: int) -> void:
	var clicked: bool = event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT
	if not clicked:
		return
	if index == 1 and not _has_save:   # 無存檔時「繼續冒險」是 disabled 樣式，點了不該有反應
		return
	_sel = index
	_render()
	var rect: TextureRect = _opt_new if index == 0 else _opt_cont
	rect.accept_event()
	_confirm()


func _move(dir: int) -> void:
	if not _has_save:
		return
	_sel = wrapi(_sel + dir, 0, OPTIONS.size())
	AudioManager.sfx("cursor.mp3")
	_render()


func _confirm() -> void:
	if _sel == 0:
		AudioManager.sfx("select.mp3")
		GameFlow.new_game()
		SceneRouter.go_to("Town", "home")
	elif _has_save and SaveManager.load_game():
		AudioManager.sfx("select.mp3")
		SceneRouter.go_to(SaveManager.loaded_scene, "")


func _render() -> void:
	_opt_new.modulate = COL_SEL if _sel == 0 else COL_IDLE
	if _has_save:
		_opt_cont.modulate = COL_SEL if _sel == 1 else COL_IDLE
	else:
		_opt_cont.modulate = COL_DISABLED

	var lines := PackedStringArray()
	for i in OPTIONS.size():
		var text: String = ("▶ " if i == _sel else "   ") + OPTIONS[i]
		if i == 1 and not _has_save:
			text += "（無存檔）"
		lines.append(text)
	_label.text = "\n".join(lines)
