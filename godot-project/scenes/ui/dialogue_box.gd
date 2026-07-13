extends CanvasLayer
## dialogue_box.tscn 的控制腳本 —— MOD-A 的最簡陋堪用版對話框。
##
## 只做「顯示說話者名字/台詞、逐句推進」，沒有美術（面板/立繪/淡入淡出），對應 CLAUDE.md 對 MOD-A
## 的指示「簡陋版即可，MOD-D 之後會換裝」與 TASKS/11_並行協作規則.md 衝突矩陣「MOD-A 若比 MOD-D
## 早完工，可先做最簡陋版本頂著，之後由 MOD-D 換裝」。
##
## 純粹訂閱 DialogueSystem 的 signal 來更新畫面／決定顯示與否，不直接碰 DialogueSystem 的內部狀態，
## 也不假設呼叫端有 InputBridge（CORE-6 尚未完成）——推進輸入直接用 Godot 內建 `ui_accept` action
## 與滑鼠/觸控點按，之後 CORE-6 做好可以在這裡換成 InputBridge.is_action_hit() 等價呼叫，不影響
## DialogueSystem 那一側的介面。

@onready var _panel: Panel = $Panel
@onready var _speaker_label: Label = $Panel/SpeakerLabel
@onready var _text_label: Label = $Panel/TextLabel


func _ready() -> void:
	_panel.visible = false
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
	_panel.visible = true


func _on_cutscene_started(_cut_id: String) -> void:
	_panel.visible = true
	_speaker_label.visible = false  # 過場旁白（speaker==""）常見，line_changed 會再依內容切回顯示


func _on_line_changed(speaker: String, text: String) -> void:
	_speaker_label.visible = speaker != ""
	_speaker_label.text = speaker
	_text_label.text = text + "　▽"   # ▽ 對應 build_cq2.py 逐句推進提示符（L1680/L1752）


func _on_ended(_npc_id: String) -> void:
	_panel.visible = false


func _on_cutscene_ended(_cut_id: String) -> void:
	_panel.visible = false
