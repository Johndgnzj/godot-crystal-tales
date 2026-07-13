class_name CutsceneEntry
extends Resource
## 對應 resources/content/dialogue.json 的 cuts[cut_id] 元素（一段過場劇情）。
## 規格：specs/DIALOGUE_SPEC.md D-3。來源 build_cq2.py L991-1011（經
## scripts/dialogue/extract_dialogue.py 轉寫）。
##
## D-8「待確認事項」在本次抽取時定案：lines 用 Dictionary 陣列（{speaker,text}），不是陣列的陣列。
## battle/transfer/setstep/party 四個欄位是抽取時從原始碼發現、原本沒寫進 D-3 spec 的既有欄位
## （見 build_cq2.py L995-997 demon_pre/demon_post/town_start 三個實例），已回填更新 D-3（v1.1）。

@export var once: String = ""                ## 空字串＝無 once 旗標（每次都可重播；只有 __lose__ 特例沒有 key）
@export var lines: Array = []                ## Array[Dictionary{speaker:String, text:String}]
@export var battle: String = ""              ## 空字串＝播完不觸發戰鬥；見 encounter id
@export var transfer: PackedStringArray = PackedStringArray()  ## [to_scene, spawn_id]，空陣列＝不轉場
@export var setstep: int = -1                ## -1＝不改 step；>=0 時播完寫入 GameState.flags.step
@export var party: PackedStringArray = PackedStringArray()     ## 播完要生效的隊伍組成（member id 陣列），空＝不改隊伍


static func from_dict(d: Dictionary) -> CutsceneEntry:
	var result := CutsceneEntry.new()
	var once_raw = d.get("once")
	result.once = once_raw if once_raw != null else ""

	var raw_lines: Array = d.get("lines", [])
	var conv: Array = []
	for l in raw_lines:
		conv.append({"speaker": l.get("speaker", ""), "text": l.get("text", "")})
	result.lines = conv

	var battle_raw = d.get("battle")
	result.battle = battle_raw if battle_raw != null else ""

	var transfer_raw = d.get("transfer")
	result.transfer = PackedStringArray(transfer_raw) if transfer_raw != null else PackedStringArray()

	var setstep_raw = d.get("setstep")
	result.setstep = int(setstep_raw) if setstep_raw != null else -1

	var party_raw = d.get("party")
	result.party = PackedStringArray(party_raw) if party_raw != null else PackedStringArray()

	return result
