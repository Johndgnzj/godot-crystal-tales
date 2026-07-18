class_name CutsceneEntry
extends Resource
## 對應 dialogue.json 的 cuts[cut_id] 元素（一段過場劇情）。
## 規格：specs/DIALOGUE_SPEC.md D-3。來源 build_cq2.py L991-1011（經 extract_dialogue.py 種子抽取）。
##
## v3.0（2026-07-18）：
##   - lines 從 Array[Dictionary{speaker,text}] 改用 Array[CutsceneLine]（子資源），讓過場台詞能在
##     Inspector 逐句編輯（取代 v1.1/D-8 原定案的 Dictionary 陣列）。
##   - 新增 id 欄位（原本是 dict 的 key）：.tres 分檔後每段過場需自我識別，供聚合／查表使用。
## battle/transfer/setstep/party 四欄是 v1.1 從原始碼補回的既有欄位（demon_pre/demon_post/town_start）。

@export var id: String = ""                   ## cutscene id（__lose__ 特例不經此表，見 DialogueSystem）
@export var once: String = ""                 ## 空字串＝無 once 旗標（每次都可重播）
@export var lines: Array[CutsceneLine] = []   ## 有序台詞；元素 speaker 空＝旁白
@export var battle: String = ""               ## 空字串＝播完不觸發戰鬥；見 encounter id
@export var transfer: PackedStringArray = PackedStringArray()  ## [to_scene, spawn_id]，空＝不轉場
@export var setstep: int = -1                 ## -1＝不改 step；>=0 時播完寫入 GameState.flags.step
@export var party: PackedStringArray = PackedStringArray()     ## 播完生效的隊伍組成，空＝不改隊伍


static func from_dict(cut_id: String, d: Dictionary) -> CutsceneEntry:
	var result := CutsceneEntry.new()
	result.id = cut_id

	var once_raw = d.get("once")
	result.once = once_raw if once_raw != null else ""

	var raw_lines: Array = d.get("lines", [])
	var conv: Array[CutsceneLine] = []
	for l in raw_lines:
		conv.append(CutsceneLine.from_dict(l))
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
