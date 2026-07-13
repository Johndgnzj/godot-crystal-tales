class_name PacingParams
extends Resource
## 對應 CONTENT.json 的 pacing{} 頂層物件（節奏設計參數，供關卡設計端對照，非戰鬥公式本體）。

@export var party_size: int = 0        ## 來源 JSON key: "partySize"
@export var maps: Dictionary = {}      ## map_id -> {entryLv, targetLv, battles, party?}


static func from_dict(d: Dictionary) -> PacingParams:
	var result := PacingParams.new()
	result.party_size = int(d.get("partySize", 0))
	result.maps = d.get("maps", {})
	return result


func get_map(map_id: String) -> Dictionary:
	return maps.get(map_id, {})
