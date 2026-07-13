class_name PartyMemberDef
extends Resource
## 對應 CONTENT.json 的 party[] 元素（隊伍成員模板）。
## 規格來源：../../../../gd-crystal-tales/projects/crystal-quest/CONTENT.json（唯讀，見 CORE-2）

@export var id: String = ""
@export var display_name: String = ""   ## 來源 JSON key: "name"
@export var char_class: String = ""     ## 來源 JSON key: "class"（GDScript 保留字，改名避開）
@export var main_attr: String = ""      ## str / agi / int，來源 JSON key: "mainAttr"
@export var sprite: String = ""
@export var base: Dictionary = {}       ## {str,agi,int}
@export var growth: Dictionary = {}     ## {str,agi,int}，guest 角色可能是空 dict
@export var start_level: int = 1
@export var start_eq: Dictionary = {}   ## slot -> equipment id
@export var story: Array = []           ## Array[String]
@export var guest: bool = false


static func from_dict(d: Dictionary) -> PartyMemberDef:
	var result := PartyMemberDef.new()
	result.id = d.get("id", "")
	result.display_name = d.get("name", "")
	result.char_class = d.get("class", "")
	result.main_attr = d.get("mainAttr", "")
	result.sprite = d.get("sprite", "")
	result.base = d.get("base", {})
	result.growth = d.get("growth", {})
	result.start_level = int(d.get("startLevel", 1))
	result.start_eq = d.get("startEq", {})
	result.story = d.get("story", [])
	result.guest = bool(d.get("guest", false))
	return result
