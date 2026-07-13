class_name ChestDef
extends Resource
## 對應 CONTENT.json 的 chests[] 元素。tx/ty 是地圖上的圖磚座標。

@export var id: String = ""
@export var map: String = ""
@export var tx: int = 0
@export var ty: int = 0
@export var tier: String = ""    ## common / hidden / rare
@export var loot: Array = []     ## Array[Dictionary]，元素為 {type:"item"|"eq"|"gold", id?, count?, amount?}


static func from_dict(d: Dictionary) -> ChestDef:
	var result := ChestDef.new()
	result.id = d.get("id", "")
	result.map = d.get("map", "")
	result.tx = int(d.get("tx", 0))
	result.ty = int(d.get("ty", 0))
	result.tier = d.get("tier", "")
	result.loot = d.get("loot", [])
	return result
