class_name EquipmentDef
extends Resource
## 對應 CONTENT.json 的 equipment[] 元素。
## 屬性加成欄位（patk/pdef/matk/mdef/hp/mp/crit/dodge）在來源資料裡是「有才出現」的稀疏欄位，
## 統一收進 stats{}，對應 specs/BATTLE_FORMULAS.md F-1 的 eqStat(m,k) 通用查表語意
## （沒有該屬性視為 0，不要每個欄位各開一個 @export，否則之後 CONTENT.json 新增屬性種類要跟著改 schema）。

const STAT_KEYS := ["patk", "pdef", "matk", "mdef", "hp", "mp", "crit", "dodge"]

@export var id: String = ""
@export var display_name: String = ""   ## 來源 JSON key: "name"
@export var slot: String = ""           ## weapon / armor / boots / wrist / acc
@export var desc: String = ""
@export var buy: int = 0
@export var sell: int = 0
@export var tier: int = 1               ## 未標示視為 1（第一章基礎裝備）
@export var stats: Dictionary = {}      ## 見 STAT_KEYS


static func from_dict(d: Dictionary) -> EquipmentDef:
	var result := EquipmentDef.new()
	result.id = d.get("id", "")
	result.display_name = d.get("name", "")
	result.slot = d.get("slot", "")
	result.desc = d.get("desc", "")
	result.buy = int(d.get("buy", 0))
	result.sell = int(d.get("sell", 0))
	result.tier = int(d.get("tier", 1))
	for key in STAT_KEYS:
		if d.has(key):
			result.stats[key] = d[key]
	return result


func get_stat(key: String) -> float:
	return float(stats.get(key, 0))
