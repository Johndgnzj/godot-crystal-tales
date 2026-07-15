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
@export var icon: String = ""           ## res:// 圖示路徑；留空＝美術尚未產出，UI 端 fallback 用 cat 預設圖示
@export var rarity: String = "common"    ## common / uncommon / rare / key（稀有度，兼具掉落機率分級與 UI 呈現用途，見 F-10）
@export var base_drop_rate: float = 0.0  ## 物品自身基礎掉落率；怪物 drops.rate 為其加成倍率，
                                         ## 最終掉率見 specs/BATTLE_FORMULAS.md F-10


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
	result.icon = d.get("icon", "")
	result.rarity = d.get("rarity", "common")
	result.base_drop_rate = float(d.get("base_drop_rate", 0))
	return result
