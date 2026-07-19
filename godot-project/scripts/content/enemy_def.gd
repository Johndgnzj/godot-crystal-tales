class_name EnemyDef
extends Resource
## 對應 CONTENT.json 的 enemies[] 元素。

@export var id: String = ""
@export var display_name: String = ""   ## 來源 JSON key: "name"
@export var sprite: String = ""
@export var hp: float = 0.0
@export var atk: float = 0.0
@export var def_stat: float = 0.0       ## 來源 JSON key: "def"（GDScript 保留字，改名避開）
@export var spd: float = 0.0
@export var luck: float = 0.0           ## v4.0 幸運：敵方會心/抗爆/閃避加成（see specs/BATTLE_FORMULAS.md F-1/F-3/F-4）。預設 0＝一般怪不受影響
@export var exp: int = 0
@export var gold: int = 0
@export var big: bool = false           ## boss/大型敵人旗標
@export var all_attack: bool = false    ## 來源 JSON key: "allAttack"
@export var healer: bool = false
@export var drops: Array = []           ## Array[Dictionary]，每個元素 {id, rate}；rate 是「加成倍率」，
                                        ## 最終掉率 = clamp(item.base_drop_rate × rate, 0, 1)，見 specs/BATTLE_FORMULAS.md F-10
@export var foe_skills: Array = []      ## 來源 JSON key: "foeSkills"，Array[Dictionary] {name,target,mult}
@export_multiline var description: String = ""   ## 圖鑑 flavor text（特色/故事/外觀）；真相源，docs/design/魔物圖鑑.md 由此彙整


static func from_dict(d: Dictionary) -> EnemyDef:
	var result := EnemyDef.new()
	result.id = d.get("id", "")
	result.display_name = d.get("name", "")
	result.sprite = d.get("sprite", "")
	result.hp = float(d.get("hp", 0))
	result.atk = float(d.get("atk", 0))
	result.def_stat = float(d.get("def", 0))
	result.spd = float(d.get("spd", 0))
	result.luck = float(d.get("luck", 0))
	result.exp = int(d.get("exp", 0))
	result.gold = int(d.get("gold", 0))
	result.big = bool(d.get("big", false))
	result.all_attack = bool(d.get("allAttack", false))
	result.healer = bool(d.get("healer", false))
	result.drops = d.get("drops", [])
	result.foe_skills = d.get("foeSkills", [])
	result.description = d.get("description", "")
	return result
