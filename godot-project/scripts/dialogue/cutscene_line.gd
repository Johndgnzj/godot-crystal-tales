class_name CutsceneLine
extends Resource
## 過場的一句台詞，對應 specs/DIALOGUE_SPEC.md D-3 的 cuts[].lines[] 元素。
## speaker 為空字串＝旁白／系統提示（無名字框）。
##
## v3.0（2026-07-18）起 CutsceneEntry.lines 從 Array[Dictionary{speaker,text}] 改用
## Array[CutsceneLine]，讓過場台詞能在 Godot Inspector 逐句編輯（每句 speaker/text 兩欄），
## 與 DLG 的編輯體驗一致。
##
## v3.1（2026-08-16）事件演出欄位（規格＝docs/design/事件演出規格.md）：
##   - image：res:// 事件 CG 路徑。非空＝這一行起顯示／切換全螢幕 CG；空＝沿用當前狀態；
##     過場結束由 dialogue_box 自動收掉。
##   - style：""＝一般對話框；"timecard"＝黑幕置中字卡（時間跳躍／章名卡，蓋住對話框）。
## 兩欄皆有安全預設值，未填的既有 .tres 行為完全不變。

@export var speaker: String = ""
@export_multiline var text: String = ""
@export var image: String = ""
@export var style: String = ""


static func from_dict(d: Dictionary) -> CutsceneLine:
	var r := CutsceneLine.new()
	r.speaker = str(d.get("speaker", ""))
	r.text = str(d.get("text", ""))
	r.image = str(d.get("image", ""))
	r.style = str(d.get("style", ""))
	return r
