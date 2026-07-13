class_name EncounterDef
extends Resource
## 對應 CONTENT.json 的 encounters{} 頂層物件裡，單一地圖 key 底下的遭遇表
## （例如 encounters.forest = [["bird","gslime"], ["goblin","goblin"], ...]）。
## 每個 formations 元素是一組敵人 id 陣列（一次遭遇戰的敵方編成）。

@export var map_id: String = ""
@export var formations: Array = []   ## Array[Array[String]]


static func from_dict(map_id: String, formations: Array) -> EncounterDef:
	var result := EncounterDef.new()
	result.map_id = map_id
	result.formations = formations
	return result


func get_formation(index: int) -> Array:
	return formations[index]


func formation_count() -> int:
	return formations.size()
