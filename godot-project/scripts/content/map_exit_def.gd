class_name MapExitDef
extends Resource
## 一張地圖的單一出口：連到哪張圖、擺在哪個邊、對方場景的落點 spawn_id。
## 對應 gen-region region config 裡 map.exits[] 的元素（見 TASKS/12_地圖生成器.md）。

@export var to: String = ""                 ## 目標：本 region 內的 map id，或設定外既有場景（如 "Town"）
@export_enum("east", "west", "north", "south") var at: String = "east"  ## 擺在本圖哪個邊緣
@export var spawn: String = ""              ## 目標為設定外場景時，對方場景的落點 spawn_id


static func from_dict(d: Dictionary) -> MapExitDef:
	var result := MapExitDef.new()
	result.to = d.get("to", "")
	result.at = str(d.get("at", "east")).to_lower()
	result.spawn = d.get("spawn", "")
	return result
