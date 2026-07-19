class_name DerivedParams
extends Resource
## 對應 CONTENT.json 的 derived{} 頂層物件（衍生屬性/戰鬥公式係數表）。
## 各欄位語意見 ../../../specs/BATTLE_FORMULAS.md F-1～F-5。

@export var hp_base: float = 0.0
@export var hp_per_str: float = 0.0
@export var mp_base: float = 0.0
@export var mp_per_int: float = 0.0
@export var weapon_atk: float = 0.0
@export var points_per_level: float = 0.0
@export var skill_points_per_level: float = 0.0
@export var skill_max_lv: float = 0.0
@export var skill_power_per_lv: float = 0.0
@export var exp_base: float = 0.0
@export var exp_coef: float = 0.0
@export var exp_pow: float = 0.0
@export var matk_per_int: float = 0.0
@export var mdef_per_int: float = 0.0
@export var dodge_per_agi: float = 0.0
@export var dodge_cap: float = 0.0
@export var crit_base: float = 0.0
@export var crit_per_agi: float = 0.0
## v4.0（屬性系統擴充，see specs/BATTLE_FORMULAS.md F-1）新增：幸運/命中/抗爆/爆傷係數。
## 舊種子（CONTENT.json / derived.tres）沒有這些欄位，from_dict 用預設值兜底。
@export var crit_per_luck: float = 0.1      ## 1 luck → 會心 +0.1%
@export var dodge_per_luck: float = 0.05    ## 1 luck → 閃避值 +0.05
@export var acc_per_agi: float = 1.5        ## 1 agi → 命中值 +1.5（＝dodge_per_agi，agi 相等時淨閃避不變）
@export var critres_per_luck: float = 0.1   ## 1 luck → 抗爆 +0.1%
@export var crit_dmg_base: float = 1.4      ## 爆擊傷害基礎倍率（裝備 critdmg 可疊加），取代舊寫死的 1.5
@export var crit_cap: float = 100.0         ## 有效會心率上限（%）
@export var drop_per_luck: float = 0.1      ## 1 luck → 掉寶率 +0.1%（F-10）


static func from_dict(d: Dictionary) -> DerivedParams:
	var result := DerivedParams.new()
	result.hp_base = float(d.get("hpBase", 0))
	result.hp_per_str = float(d.get("hpPerStr", 0))
	result.mp_base = float(d.get("mpBase", 0))
	result.mp_per_int = float(d.get("mpPerInt", 0))
	result.weapon_atk = float(d.get("weaponAtk", 0))
	result.points_per_level = float(d.get("pointsPerLevel", 0))
	result.skill_points_per_level = float(d.get("skillPointsPerLevel", 0))
	result.skill_max_lv = float(d.get("skillMaxLv", 0))
	result.skill_power_per_lv = float(d.get("skillPowerPerLv", 0))
	result.exp_base = float(d.get("expBase", 0))
	result.exp_coef = float(d.get("expCoef", 0))
	result.exp_pow = float(d.get("expPow", 0))
	result.matk_per_int = float(d.get("matkPerInt", 0))
	result.mdef_per_int = float(d.get("mdefPerInt", 0))
	result.dodge_per_agi = float(d.get("dodgePerAgi", 0))
	result.dodge_cap = float(d.get("dodgeCap", 0))
	result.crit_base = float(d.get("critBase", 0))
	result.crit_per_agi = float(d.get("critPerAgi", 0))
	# v4.0 新欄位：舊種子沒有，缺省沿用 @export 預設值（見上方宣告）。
	result.crit_per_luck = float(d.get("critPerLuck", result.crit_per_luck))
	result.dodge_per_luck = float(d.get("dodgePerLuck", result.dodge_per_luck))
	result.acc_per_agi = float(d.get("accPerAgi", result.acc_per_agi))
	result.critres_per_luck = float(d.get("critresPerLuck", result.critres_per_luck))
	result.crit_dmg_base = float(d.get("critDmgBase", result.crit_dmg_base))
	result.crit_cap = float(d.get("critCap", result.crit_cap))
	result.drop_per_luck = float(d.get("dropPerLuck", result.drop_per_luck))
	return result
