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
@onready var _portrait: TextureRect = $Box/Portrait
@onready var _speaker_label: Label = $Box/SpeakerLabel
@onready var _text_label: Label = $Box/TextLabel

# 立繪幾何（換算自 build_cq2.py setFace L1417-1420，座標系與 GDevelop 相同＝1280x720）：
# 目標高 380；等比換寬，過寬（拖擺長袍等）限 470；貼近左緣 x=14；底邊固定在 y=540（對話框上緣附近）。
const PORTRAIT_H := 380.0
const PORTRAIT_MAX_W := 470.0
const PORTRAIT_X := 14.0
const PORTRAIT_BASELINE_Y := 540.0


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
	_set_portrait(speaker)


## 依當前說話者顯示名切換半身立繪（NPC 對話與過場共用；比照 build_cq2.py setFace L1410-1421）。
## 對照走 PortraitMap（顯示名→立繪 id）；查不到（旁白/無立繪角色）或素材缺檔一律隱藏，不擋對話。
func _set_portrait(speaker: String) -> void:
	# 立繪＋選單式室內：室內已有右下角的大型主人立繪（interior.gd），對話框不再重複顯示小頭像
	# （對應 build_cq2.py setFace L1414：intMode==="menu" 時 hide DlgArt）。
	var interior := get_tree().get_first_node_in_group("cq_interior")
	if interior != null and interior.has_method("is_open") and interior.is_open():
		_portrait.visible = false
		return
	var pid := PortraitMap.portrait_id(speaker)
	if pid == "":
		_portrait.visible = false
		return
	var path := "res://assets/ui/portrait_%s.png" % pid
	if not ResourceLoader.exists(path):
		push_warning("dialogue_box: 找不到立繪 %s（speaker=%s），改為不顯示" % [path, speaker])
		_portrait.visible = false
		return
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("dialogue_box: 立繪載入失敗 %s（speaker=%s），改為不顯示" % [path, speaker])
		_portrait.visible = false
		return
	# 等比換算尺寸（see build_cq2.py L1417-1420）：先以高 380 算寬，過寬則改以寬 470 回算高。
	var native := tex.get_size()
	var h := PORTRAIT_H
	var w := PORTRAIT_H
	if native.y > 0.0:
		var nr: float = native.x / native.y
		w = round(h * nr)
		if w > PORTRAIT_MAX_W:
			w = PORTRAIT_MAX_W
			h = round(w / nr)
	_portrait.texture = tex
	_portrait.size = Vector2(w, h)
	_portrait.position = Vector2(PORTRAIT_X, PORTRAIT_BASELINE_Y - h)  # 底邊對齊 y=540
	_portrait.visible = true


func _on_ended(_npc_id: String) -> void:
	_box.visible = false


func _on_cutscene_ended(_cut_id: String) -> void:
	_box.visible = false
