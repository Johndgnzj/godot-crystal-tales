class_name EquipmentDef
extends Resource
## 對應 CONTENT.json 的 equipment[] 元素。
## 屬性加成欄位（patk/pdef/matk/mdef/hp/mp/crit/dodge）在來源資料裡是「有才出現」的稀疏欄位，
## 統一收進 stats{}，對應 specs/BATTLE_FORMULAS.md F-1 的 eqStat(m,k) 通用查表語意
## （沒有該屬性視為 0，不要每個欄位各開一個 @export，否則之後 CONTENT.json 新增屬性種類要跟著改 schema）。

## v4.0（屬性系統擴充）起，裝備也能加「主屬性」(str/agi/int/luck) 與新戰鬥維度
## (spd 行動力 / acc 命中 / critres 抗爆 / critdmg 爆傷)。主屬性由 Derive 先疊進有效 attrs
## 再算衍生（見 specs/BATTLE_FORMULAS.md F-1），其餘照 eqStat 加總語意。
const STAT_KEYS := ["patk", "pdef", "matk", "mdef", "hp", "mp", "crit", "dodge",
	"str", "agi", "int", "luck", "spd", "acc", "critres", "critdmg"]

@export var id: String = ""
@export var display_name: String = ""   ## 來源 JSON key: "name"
@export var slot: String = ""           ## weapon / armor / boots / wrist / acc
@export var desc: String = ""
@export var buy: int = 0
@export var sell: int = 0
@export var tier: int = 1               ## 未標示視為 1（第一章基礎裝備）
@export var stats: Dictionary = {}      ## 見 STAT_KEYS
@export var icon: String = ""           ## res:// 圖示路徑；留空＝美術尚未產出，UI 端 fallback 用 slot 預設圖示
@export_enum("common", "uncommon", "rare", "epic") var rarity: String = "common"  ## 稀有度色階，見 docs/design/道具武器設計.md
@export var attr_type: String = ""      ## ""/str/agi/int 力量/敏捷/法力型分類，僅 weapon/armor/boots（@export_enum 首選項不可為空字串，Godot 4.7 會 parse error，故用純 String）
@export var weapon_type: String = ""    ## ""/sword/dagger/claw/staff 武器類別，決定普攻的動畫＋音效；留空＝依 attr_type 推定（str→sword、agi→dagger、int→staff）。見 battle_state_machine WTYPE_*
## 適用（同一部位下的三型是平行的養成路線，非戰力高低之分；acc/wrist 不分型，留空）。見 docs/design/道具武器設計.md。


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
	result.icon = d.get("icon", "")
	result.rarity = d.get("rarity", "common")
	result.attr_type = d.get("attr_type", "")
	result.weapon_type = d.get("weapon_type", "")
	return result


func get_stat(key: String) -> float:
	return float(stats.get(key, 0))
