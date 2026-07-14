class_name DamageCalc
extends RefCounted
## F-3~F-6、F-8　傷害/治療/道具/敵人技能計算（specs/BATTLE_FORMULAS.md）。
##
## 純函式集合，不持有戰鬥狀態。所有函式吃的 `attacker`/`defender`/`target` 都是 Dictionary，用
## `dict.has("attrs")` 判斷「這是角色還是敵人」——對應 build_cq2.py 到處都是的 `att.attrs ? X : Y`
## 寫法（角色的戰鬥 Dictionary 一定有 `attrs`，敵人的戰鬥 Dictionary 一律沒有這個 key，見
## `battle_state_machine.gd` 建構 heroes/foes 兩個陣列時的欄位形狀）。
##
## `rng` 參數統一放最後、預設 `null`：傳 `null` 時用 GDScript 全域 `randf()`（正式遊玩路徑）；
## 傳一個 `RandomNumberGenerator` 時用該實例的 `randf()`（供之後 CORE-7/GUT 單元測試注入固定種子，
## 目前這個執行環境沒有 Godot 執行檔可以真的跑 GUT，但先把注入點留好，之後補測試不需要回來改函式簽名）。


static func _randf(rng: RandomNumberGenerator) -> float:
	if rng != null:
		return rng.randf()
	return randf()


## F-3　普攻傷害（build_cq2.py `phys()` L2945-2953）。回傳 {dmg:int, crit:bool}。
static func phys_damage(attacker: Dictionary, defender: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	# see specs/BATTLE_FORMULAS.md F-3
	var atk: float = float(attacker.get("patk", 0.0)) if attacker.has("attrs") else float(attacker.get("atk", 0.0))
	var df: float = float(defender.get("pdef", 0.0)) if defender.has("attrs") else float(defender.get("def", 0.0))
	var base: float = atk * 1.8 - df
	if base < 1.0:
		base = 1.0
	if bool(defender.get("defending", false)):
		base *= 0.5
	var crit_chance: float
	if attacker.has("attrs"):
		crit_chance = float(attacker.get("critV", 0.0)) / 100.0
	else:
		# 敵方一律用基礎會心率，沒有個別敵人會心加成（F-3 明文規則）
		crit_chance = ContentDB.get_derived().crit_base / 100.0
	var is_crit: bool = _randf(rng) < crit_chance
	var mult: float = 0.85 + _randf(rng) * 0.15
	var dmg: float = roundf(base * mult * (1.5 if is_crit else 1.0))
	if dmg < 1.0:
		dmg = 1.0
	return {"dmg": int(dmg), "crit": is_crit}


## F-4　閃避判定（build_cq2.py `dodge()` L2938-2944）。回傳命中閃避的機率百分比（0~dodgeCap）。
static func dodge_chance(attacker: Dictionary, defender: Dictionary) -> float:
	# see specs/BATTLE_FORMULAS.md F-4
	var d: DerivedParams = ContentDB.get_derived()
	var dv: float
	if defender.has("attrs"):
		dv = float(defender.get("dodgeV", 0.0))
	else:
		dv = float(defender.get("spd", 0.0)) * d.dodge_per_agi
	var av: float
	if attacker.has("attrs"):
		var attrs: Dictionary = attacker.get("attrs", {})
		av = float(attrs.get("agi", 0.0)) * d.dodge_per_agi
	else:
		av = float(attacker.get("spd", 0.0)) * d.dodge_per_agi
	return clampf(dv - av, 0.0, d.dodge_cap)


## 是否命中閃避。**只有普攻（F-3）與敵人具名單體技能（F-8）會呼叫這個**——玩家技能傷害
## （`applyOne`/`applyAll` 的 `sk.kind==="damage"` 分支）刻意不判閃避，見 F-4 說明。
static func is_dodge(attacker: Dictionary, defender: Dictionary, rng: RandomNumberGenerator = null) -> bool:
	return _randf(rng) * 100.0 < dodge_chance(attacker, defender)


## F-5　技能威力倍率 `skPow`（build_cq2.py L2669）。
static func skill_power(actor: Dictionary, skill: SkillDef) -> float:
	# see specs/BATTLE_FORMULAS.md F-5
	var sk_table: Dictionary = actor.get("sk", {})
	var slv: int = int(sk_table.get(skill.id, 0))
	if slv <= 0:
		slv = 1
	return 1.0 + ContentDB.get_derived().skill_power_per_lv * float(slv - 1)


## F-5　技能基礎值 `skBase`（build_cq2.py L2670-2673）。
static func skill_base(actor: Dictionary, skill: SkillDef) -> float:
	# see specs/BATTLE_FORMULAS.md F-5
	if skill.attr == "int":
		if actor.has("attrs"):
			return float(actor.get("matk", 0.0))
		return roundf(float(actor.get("atk", 0.0)) * 0.8)
	if actor.has("attrs"):
		return float(actor.get("patk", 0.0))
	return float(actor.get("atk", 0.0))


## F-5　技能防禦值 `skDef`（build_cq2.py L2954-2957）。
static func skill_def(target: Dictionary, skill: SkillDef) -> float:
	# see specs/BATTLE_FORMULAS.md F-5
	if skill.attr == "int":
		if target.has("attrs"):
			return float(target.get("mdef", 0.0))
		return roundf(float(target.get("def", 0.0)) * 0.5)
	if target.has("attrs"):
		return float(target.get("pdef", 0.0))
	return float(target.get("def", 0.0))


## F-5　單體/全體技能傷害（`applyOne` L2975-2981／`applyAll` L3002-3017 共用同一條公式）。
## 注意係數：`skDef * 0.6`（普攻吃全額防禦，技能只吃六成），不是筆誤。技能傷害不判閃避（見 F-4）。
static func skill_damage(actor: Dictionary, target: Dictionary, skill: SkillDef, rng: RandomNumberGenerator = null) -> int:
	# see specs/BATTLE_FORMULAS.md F-5
	var pw: float = skill_power(actor, skill)
	var base: float = skill_base(actor, skill) * skill.mult + skill.flat
	var df: float = skill_def(target, skill) * 0.6
	var mult: float = 0.85 + _randf(rng) * 0.15
	var dmg: float = roundf((base * pw - df) * mult)
	if dmg < 1.0:
		dmg = 1.0
	return int(dmg)


## F-5　治療技能（`sk.kind !== "damage"` 分支，L2982-2987）。沒有隨機項、沒有防禦修正。
## 呼叫端負責 `min(target.maxhp, target.hp + heal)` 的 clamp（本函式只回傳治療量）。
static func skill_heal(actor: Dictionary, skill: SkillDef) -> int:
	# see specs/BATTLE_FORMULAS.md F-5
	var pw: float = skill_power(actor, skill)
	var base: float = skill_base(actor, skill) * skill.mult + skill.flat
	return int(roundf(base * pw))


## F-6　道具是否可在戰鬥中使用（`itemUsableInBattle()` L2632）。
static func item_usable_in_battle(item: ItemDef) -> bool:
	# see specs/BATTLE_FORMULAS.md F-6
	return item.kind == "heal" or item.kind == "mp"


## F-6　道具效果（`applyOne` 的 `pd.t==="item"` 分支，L2988-2997）。回傳 {kind, power}，
## `kind==="mp"` 由呼叫端加到 mp，其餘（含 `"heal"`）加到 hp，兩者都要 clamp 到對應上限。
static func item_effect(item: ItemDef) -> Dictionary:
	# see specs/BATTLE_FORMULAS.md F-6
	return {"kind": item.kind, "power": int(item.power)}


## F-8　敵人具名技能傷害（`foeAct()` 的 `a.foeSkills` 分支，L3033-3050）。傷害＝`phys()` 的結果
## （已含隨機/會心）再乘 `mult`、四捨五入、下限 1——不是重新走一次獨立公式。呼叫端自行決定是否要先
## 呼叫 `is_dodge()`（單體目標要判，全體目標不判，見 specs/BATTLE_FORMULAS.md F-8）。
static func foe_named_skill_damage(attacker: Dictionary, defender: Dictionary, mult: float, rng: RandomNumberGenerator = null) -> Dictionary:
	# see specs/BATTLE_FORMULAS.md F-8
	var base: Dictionary = phys_damage(attacker, defender, rng)
	var d: float = roundf(float(base["dmg"]) * mult)
	if d < 1.0:
		d = 1.0
	return {"dmg": int(d), "crit": base["crit"]}


## F-8　敵人 healer 治療量：`20 + round(random()*10)`，跟屬性無關的寫死公式（L3025）。
static func foe_heal_amount(rng: RandomNumberGenerator = null) -> int:
	# see specs/BATTLE_FORMULAS.md F-8
	return 20 + int(roundf(_randf(rng) * 10.0))
