extends Node2D

## 標題頁（POC）：新遊戲 / 繼續冒險。鍵盤 ↑↓ 選、Enter 確認。
## 新遊戲 → GameFlow.new_game() + 進 Town；繼續 → SaveManager.load_game() + 回存檔場景。

const OPTIONS := ["新遊戲", "繼續冒險"]

var _sel := 0
var _has_save := false

@onready var _label: Label = $Menu


func _ready() -> void:
	_has_save = SaveManager.has_save()
	if not _has_save:
		_sel = 0
	_render()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_up"):
		_move(-1)
	elif Input.is_action_just_pressed("ui_down"):
		_move(1)
	elif Input.is_action_just_pressed("ui_accept"):
		_confirm()


func _move(dir: int) -> void:
	_sel = wrapi(_sel + dir, 0, OPTIONS.size())
	_render()


func _confirm() -> void:
	if _sel == 0:
		GameFlow.new_game()
		SceneRouter.go_to("Town", "home")
	elif _has_save and SaveManager.load_game():
		SceneRouter.go_to(SaveManager.loaded_scene, "")


func _render() -> void:
	var lines := PackedStringArray(["水晶奇譚 Crystal Tales", ""])
	for i in OPTIONS.size():
		var text: String = ("▶ " if i == _sel else "   ") + OPTIONS[i]
		if i == 1 and not _has_save:
			text += "（無存檔）"
		lines.append(text)
	_label.text = "\n".join(lines)
