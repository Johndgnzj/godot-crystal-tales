class_name NpcDialogue
extends Resource
## 單一 NPC 的整張對話表（有序的 DialogueEntry 陣列），對應 specs/DIALOGUE_SPEC.md D-2 的 dlg[npc_id]。
## 一個 NPC 一個 .tres（resources/content/dialogue/npc/<id>.tres），比照 party/<id>.tres 的分檔慣例。
##
## entries 的陣列順序＝優先權（由上到下第一個 when 成立者勝出，見 D-2「順序即優先權」；越晚期的劇情
## 條件排越前面），.tres 化後這個順序語意由 Inspector 裡的陣列順序承載，不要用檔名或字母序取代。

@export var id: String = ""
@export var entries: Array[DialogueEntry] = []
