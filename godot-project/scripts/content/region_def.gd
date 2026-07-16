class_name RegionDef
extends Resource
## 一整個地區的生成 recipe：多張 MapDef 用 exits 連成連通圖。
## 生成器（scripts/map/region_generator.gd）的 dev-time 輸入；存 resources/map/regions/<region_id>.tres。
## 不進 content_db.tres（非 runtime 資料）。見 TASKS/12_地圖生成器.md。

@export var region_id: String = "region"
@export var seed: int = 51                   ## 生成亂數種子（換值＝換整區布局）
@export var maps: Array[MapDef] = []


static func from_dict(d: Dictionary) -> RegionDef:
	var result := RegionDef.new()
	result.region_id = d.get("region_id", "region")
	result.seed = int(d.get("seed", 51))
	for m in d.get("maps", []):
		result.maps.append(MapDef.from_dict(m))
	return result
