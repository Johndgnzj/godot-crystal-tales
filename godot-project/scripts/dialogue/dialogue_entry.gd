class_name DialogueEntry
extends Resource
## 對應 resources/content/dialogue.json 的 dlg[npc_id][] 元素（NPC 對話一個分支）。
## 規格：specs/DIALOGUE_SPEC.md D-2。來源 build_cq2.py L931-990（經
## scripts/dialogue/extract_dialogue.py 轉寫）。

@export var when: String = "always"     ## matchWhen 語法，見 D-1／FlagMatcher
@export var speaker: String = ""        ## 來源 JSON key: "speaker"（原 GDevelop 端叫 "name"，抽取時改名）
@export var lines: PackedStringArray = PackedStringArray()
@export var action: String = ""         ## 空字串＝無 action（來源可能是 JSON null）

## 以下三欄僅室內（立繪＋選單式室內，town 六棟主人）用到，戶外 NPC 一律空字串。
## 見 build_cq2.py buildIntCmds L1575-1582 與 dialogue_system.get_interior_commands()。
@export var cmd: String = ""            ## 指令分類：talk/quest/rest/pray/trade／一次性事件（hank_gift…）
@export var label: String = ""          ## 功能/事件在室內選單顯示的中文（cmd==talk 者為空）
@export var done: String = ""           ## 一次性事件的完成旗標名；旗標設立後此指令從選單消失


static func from_dict(d: Dictionary) -> DialogueEntry:
	var result := DialogueEntry.new()
	result.when = d.get("when", "always")
	result.speaker = d.get("speaker", "")
	var raw_lines: Array = d.get("lines", [])
	var arr := PackedStringArray()
	for l in raw_lines:
		arr.append(str(l))
	result.lines = arr
	result.action = _str_or_empty(d.get("action"))
	result.cmd = _str_or_empty(d.get("cmd"))
	result.label = _str_or_empty(d.get("label"))
	result.done = _str_or_empty(d.get("done"))
	return result


## JSON null（缺省欄位）→ ""，其餘轉字串。統一 action/cmd/label/done 的空值處理。
static func _str_or_empty(v: Variant) -> String:
	return str(v) if v != null else ""
