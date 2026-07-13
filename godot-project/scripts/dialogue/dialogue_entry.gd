class_name DialogueEntry
extends Resource
## 對應 resources/content/dialogue.json 的 dlg[npc_id][] 元素（NPC 對話一個分支）。
## 規格：specs/DIALOGUE_SPEC.md D-2。來源 build_cq2.py L931-990（經
## scripts/dialogue/extract_dialogue.py 轉寫）。

@export var when: String = "always"     ## matchWhen 語法，見 D-1／FlagMatcher
@export var speaker: String = ""        ## 來源 JSON key: "speaker"（原 GDevelop 端叫 "name"，抽取時改名）
@export var lines: PackedStringArray = PackedStringArray()
@export var action: String = ""         ## 空字串＝無 action（來源可能是 JSON null）


static func from_dict(d: Dictionary) -> DialogueEntry:
	var result := DialogueEntry.new()
	result.when = d.get("when", "always")
	result.speaker = d.get("speaker", "")
	var raw_lines: Array = d.get("lines", [])
	var arr := PackedStringArray()
	for l in raw_lines:
		arr.append(str(l))
	result.lines = arr
	var action_raw = d.get("action")
	result.action = action_raw if action_raw != null else ""
	return result
