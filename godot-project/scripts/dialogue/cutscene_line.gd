class_name CutsceneLine
extends Resource
## 過場的一句台詞，對應 specs/DIALOGUE_SPEC.md D-3 的 cuts[].lines[] 元素。
## speaker 為空字串＝旁白／系統提示（無名字框）。
##
## v3.0（2026-07-18）起 CutsceneEntry.lines 從 Array[Dictionary{speaker,text}] 改用
## Array[CutsceneLine]，讓過場台詞能在 Godot Inspector 逐句編輯（每句 speaker/text 兩欄），
## 與 DLG 的編輯體驗一致。

@export var speaker: String = ""
@export_multiline var text: String = ""


static func from_dict(d: Dictionary) -> CutsceneLine:
	var r := CutsceneLine.new()
	r.speaker = str(d.get("speaker", ""))
	r.text = str(d.get("text", ""))
	return r
