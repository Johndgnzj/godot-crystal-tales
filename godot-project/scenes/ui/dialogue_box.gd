extends CanvasLayer
## dialogue_box.tscn 的控制腳本 —— 對話框 UI。
##
## 由 MOD-A 建立的最簡陋堪用版，MOD-D 在此做「視覺換裝」：套用 ui_theme（統一面板底/accent 青名字）、
## 加上底部面板框與推進指示符（▽）。**對外契約完全不變**（見 TASKS/04_選單UI.md 開工前說明）：
## - 場景路徑維持 res://scenes/ui/dialogue_box.tscn（world_scene.tscn/MOD-H 以 instance 引用）。
## - 根節點仍是 CanvasLayer。
## - 仍純粹訂閱 DialogueSystem 的既有 signal（dialogue_started/line_changed/ended、
##   cutscene_started/line_changed/ended）來更新畫面，不碰 DialogueSystem 內部狀態、不改其介面。
## 只有內部節點結構與視覺換新（MOD-A 檔頭與 01_對話劇情.md 都明示 MOD-D 可直接重做節點結構）。
##
## 推進輸入維持 event 驅動（ui_accept＋滑鼠左鍵＋觸控點按），涵蓋 InputBridge 沒有處理的滑鼠/觸控點按；
## 對話推進在 GDevelop 版本來就吃「點畫面任一處」，故保留 _unhandled_input 事件式判斷。

@onready var _box: Control = $Box
@onready var _speaker_label: Label = $Box/SpeakerLabel
@onready var _text_label: Label = $Box/TextLabel


func _ready() -> void:
	_box.visible = false
	_speaker_label.add_theme_color_override("font_color", _box.get_theme_color("accent", "CQ"))
	DialogueSystem.dialogue_started.connect(_on_started)
	DialogueSystem.dialogue_line_changed.connect(_on_line_changed)
	DialogueSystem.dialogue_ended.connect(_on_ended)
	DialogueSystem.cutscene_started.connect(_on_cutscene_started)
	DialogueSystem.cutscene_line_changed.connect(_on_line_changed)
	DialogueSystem.cutscene_ended.connect(_on_cutscene_ended)


func _unhandled_input(event: InputEvent) -> void:
	if not DialogueSystem.is_busy():
		return
	var confirm := false
	if event.is_action_pressed("ui_accept"):
		confirm = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		confirm = true
	elif event is InputEventScreenTouch and event.pressed:
		confirm = true
	if confirm:
		DialogueSystem.advance()
		get_viewport().set_input_as_handled()


func _on_started(_npc_id: String, _entry: DialogueEntry) -> void:
	_box.visible = true


func _on_cutscene_started(_cut_id: String) -> void:
	_box.visible = true
	_speaker_label.visible = false  # 過場旁白（speaker==""）常見，line_changed 會再依內容切回顯示


func _on_line_changed(speaker: String, text: String) -> void:
	_speaker_label.visible = speaker != ""
	_speaker_label.text = speaker
	_text_label.text = text


func _on_ended(_npc_id: String) -> void:
	_box.visible = false


func _on_cutscene_ended(_cut_id: String) -> void:
	_box.visible = false
