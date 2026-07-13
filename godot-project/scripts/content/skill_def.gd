class_name SkillDef
extends Resource
## 對應 CONTENT.json 的 skills[] 元素。公式語意見 ../../../specs/BATTLE_FORMULAS.md F-5。

@export var id: String = ""
@export var display_name: String = ""   ## 來源 JSON key: "name"
@export var char_class: String = ""     ## 來源 JSON key: "class"（GDScript 保留字，改名避開）
@export var unlock_lv: int = 1
@export var mp: int = 0
@export var kind: String = ""           ## damage / heal
@export var attr: String = ""           ## str / agi / int（決定用 patk 還是 matk 當基礎值）
@export var mult: float = 0.0
@export var flat: float = 0.0
@export var target: String = ""         ## enemy / ally / all_enemies


static func from_dict(d: Dictionary) -> SkillDef:
	var result := SkillDef.new()
	result.id = d.get("id", "")
	result.display_name = d.get("name", "")
	result.char_class = d.get("class", "")
	result.unlock_lv = int(d.get("unlockLv", 1))
	result.mp = int(d.get("mp", 0))
	result.kind = d.get("kind", "")
	result.attr = d.get("attr", "")
	result.mult = float(d.get("mult", 0))
	result.flat = float(d.get("flat", 0))
	result.target = d.get("target", "")
	return result
