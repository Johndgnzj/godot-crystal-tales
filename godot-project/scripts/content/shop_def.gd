class_name ShopDef
extends Resource
## 對應 CONTENT.json 的 shops{} 頂層物件裡，單一商店 key 底下的內容
## （例如 shops.gid = {name, greet, sell:[...]}）。

@export var id: String = ""
@export var display_name: String = ""   ## 來源 JSON key: "name"
@export var greet: String = ""
## 來源 JSON key: "sell"，equipment/item id 陣列（改名避免與 equipment/item 自身的 sell 售價欄位混淆）
@export var sell_ids: Array = []


static func from_dict(shop_id: String, d: Dictionary) -> ShopDef:
	var result := ShopDef.new()
	result.id = shop_id
	result.display_name = d.get("name", "")
	result.greet = d.get("greet", "")
	result.sell_ids = d.get("sell", [])
	return result
