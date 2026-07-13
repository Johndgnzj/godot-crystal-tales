class_name ItemDef
extends Resource
## 對應 CONTENT.json 的 items[] 元素（consumable/material/key 三種 cat 共用同一 schema，
## 各分類實際只填自己會用到的欄位，其餘留預設值）。

@export var id: String = ""
@export var display_name: String = ""   ## 來源 JSON key: "name"
@export var cat: String = ""            ## consumable / material / key
@export var kind: String = ""           ## heal / mp / cure / revive / rest（僅 consumable 有）
@export var power: float = 0.0
@export var cure: String = ""           ## 狀態異常種類（僅 kind=="cure" 用到，目前狀態異常系統未上線）
@export var count: int = 0              ## 目前僅 potion 有填，語意待 MOD 任務確認（起始持有數？）
@export var effect: String = ""
@export var buy: int = 0
@export var sell: int = 0


static func from_dict(d: Dictionary) -> ItemDef:
	var result := ItemDef.new()
	result.id = d.get("id", "")
	result.display_name = d.get("name", "")
	result.cat = d.get("cat", "")
	result.kind = d.get("kind", "")
	result.power = float(d.get("power", 0))
	result.cure = d.get("cure", "")
	result.count = int(d.get("count", 0))
	result.effect = d.get("effect", "")
	result.buy = int(d.get("buy", 0))
	result.sell = int(d.get("sell", 0))
	return result
