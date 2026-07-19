class_name EncounterDef
extends Resource
## 對應單一地圖的遭遇表（原 CONTENT.json 的 encounters{} 某地圖 key）。
## formations 每個元素是一組「帶權重的敵方編成」Dictionary：
##   {
##     "weight": 3.0,                                          # 選填，加權抽組用，預設 1.0
##     "members": [{"id": "goblin", "min": 1, "max": 3}, ...]  # 每種怪的數量範圍（同隻可複數）
##   }
## 遇敵時 roll() 依 weight 加權抽一組，再對每個 member 在 [min,max] 間隨機決定隻數，
## 展開成敵人 id 陣列。boss/精英與隨從只要放進同一組 members 即可。詳見 specs/BATTLE_FORMULAS.md F-11。

const MAX_FOES := 5   ## 一場戰鬥的敵人硬上限（＝battle_state_machine 的 FOE_SLOTS 槽位數），see F-11

@export var map_id: String = ""
@export var formations: Array = []   ## Array[Dictionary]，格式見檔頭

## scripted 劇情戰：>0＝「撐過 N 次敵方行動後以 story 結果收場」（我方保底不死），對應必敗/序章橋段。
## 0＝一般可勝可敗戰鬥。取代 battle_state_machine 原本寫死的 `enc=="prologue_demon"`，see F-11。
@export var scripted_survive: int = 0
## 戰後過場：本場以 story 結果（scripted 撐過）收場時要播的 cutscene id（空＝無）。
@export var story_cut: String = ""
## 戰後過場：本場以 win 結果收場時要播的 cutscene id（空＝無）。
@export var win_cut: String = ""


static func from_dict(map_id: String, formations: Array) -> EncounterDef:
	var result := EncounterDef.new()
	result.map_id = map_id
	result.formations = formations
	return result


## 加權抽一組編成，展開成敵人 id 陣列（數量隨機／洗牌／上限截斷／保底 1 隻）。
## 純資料層不查 ContentDB；未知 id 交由呼叫端（battle）自行略過。see F-11
func roll() -> Array:
	if formations.is_empty():
		return []
	var chosen = _pick_weighted()
	if typeof(chosen) != TYPE_DICTIONARY:
		return []
	var members: Array = chosen.get("members", [])
	var out: Array = []
	for m in members:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var eid := String(m.get("id", ""))
		if eid == "":
			continue
		var lo := maxi(0, int(m.get("min", 1)))
		var hi := maxi(lo, int(m.get("max", lo)))
		var count := lo + (randi() % (hi - lo + 1))
		for _i in count:
			out.append(eid)
	if out.is_empty():   # 全員 min=0 剛好都抽到 0 → 保底補第一個有效成員 1 隻，避免空戰鬥
		for m in members:
			if typeof(m) == TYPE_DICTIONARY and String(m.get("id", "")) != "":
				out.append(String(m.get("id", "")))
				break
	out.shuffle()
	if out.size() > MAX_FOES:
		out.resize(MAX_FOES)
	return out


## 依 weight 加權隨機挑一組 formation（回傳該 Dictionary）。weight 全 0/缺省時退化為均勻隨機。
func _pick_weighted():
	var total := 0.0
	for f in formations:
		if typeof(f) == TYPE_DICTIONARY:
			total += maxf(0.0, float(f.get("weight", 1.0)))
	if total <= 0.0:
		return formations[randi() % formations.size()]
	var r := randf() * total
	for f in formations:
		if typeof(f) != TYPE_DICTIONARY:
			continue
		r -= maxf(0.0, float(f.get("weight", 1.0)))
		if r <= 0.0:
			return f
	return formations[formations.size() - 1]
