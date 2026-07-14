extends RefCounted
class_name Derive

## F-1　衍生屬性計算（specs/BATTLE_FORMULAS.md F-1）。
##
## MOD-F 的核心產出：GDevelop 版有**兩份**幾乎相同的 `derive()`——WORLD_JS
## （build_cq2.py L1326-1345）與 BATTLE_JS（L2641-2661），DEV_開發指南.md L63 記載「改公式要同步兩處」
## 是已知技術債。這裡合併成**唯一一份**，供 MOD-C（世界場景 HUD）與 MOD-E（戰鬥數值）共用
## （見 TASKS/11_並行協作規則.md 衝突矩陣：「不允許任何模組自己重算衍生屬性」）。
##
## ## 刻意行為修正：critV 取一位小數
##
## 兩份原始碼逐行比對後唯一的差異在 critV：
##   WORLD 版（L1338）：`m.critV=Math.round((d.critBase+m.attrs.agi*d.critPerAgi+eqStat(m,"crit"))*10)/10;`
##   BATTLE 版（L2650）：`m.critV=d.critBase+m.attrs.agi*d.critPerAgi+eqStat(m,"crit");`（沒有 round）
## specs/BATTLE_FORMULAS.md F-1 註記＋「待確認事項」都明講這是不一致、要統一採用 WORLD 版「取一位小數」
## 的寫法。本檔案下方 `derive()` 的 critV 計算即為此修正點（見該行內註解）——這是本次 GDevelop→Godot
## 遷移**唯一一處**相對現況的刻意行為修正，其餘公式原樣照搬。若之後有人回報「戰鬥數值跟 GDevelop 版對
## 不上」，先檢查是不是踩到這裡（尤其是拿 BATTLE_JS 的舊數值來對照的情況——那份本來就有技術債）。
##
## ## 輸入/輸出形狀
##
## 純函式，輸入輸出都是 Dictionary，對應 `GameState.party` 元素（Array[Dictionary]，見
## autoload/game_state.gd）與 dialogue_system.gd `_make_party_member()` 產生的欄位形狀：
##   {id, name, cls, mainAttr, sprite, guest, lv, exp, pts, spts, attrs:{str,agi,int}, eq?, hp?, mp?, sk?}
## `derive()` 原地修改並回傳同一個 Dictionary（照搬 GDevelop 版 mutate-in-place 語意；呼叫端如果不想
## 修改原本的 Dictionary，自己先 `duplicate(true)` 再傳入）。呼叫端需自行確保 `ContentDB.is_loaded`
## 為 true（本函式不重複檢查，維持單一職責）。


## 對應 build_cq2.py `derive(m)`（WORLD L1326 / BATTLE L2641，見上方檔頭關於兩版差異的說明）。
static func derive(member: Dictionary) -> Dictionary:
	var d: DerivedParams = ContentDB.get_derived()
	var attrs: Dictionary = member.get("attrs", {})

	# m.eq === undefined -> 套用 CONTENT.party 同 id 模板的 startEq（F-1 第二段）
	if not member.has("eq"):
		var eq: Dictionary = {}
		var tmpl: PartyMemberDef = ContentDB.get_party_member(String(member.get("id", "")))
		if tmpl != null:
			for slot in tmpl.start_eq.keys():
				eq[slot] = tmpl.start_eq[slot]
		member["eq"] = eq

	var str_v: float = float(attrs.get("str", 0))
	var agi_v: float = float(attrs.get("agi", 0))
	var int_v: float = float(attrs.get("int", 0))
	var main_attr: String = String(member.get("mainAttr", ""))
	var main_v: float = float(attrs.get(main_attr, 0))

	member["maxhp"] = d.hp_base + str_v * d.hp_per_str + _eq_stat(member, "hp")
	member["maxmp"] = d.mp_base + int_v * d.mp_per_int + _eq_stat(member, "mp")
	member["patk"] = d.weapon_atk + main_v * 2.0 + _eq_stat(member, "patk")
	member["matk"] = roundf(int_v * d.matk_per_int) + _eq_stat(member, "matk")
	member["pdef"] = str_v + _eq_stat(member, "pdef")
	member["mdef"] = roundf(int_v * d.mdef_per_int) + _eq_stat(member, "mdef")
	member["dodgeV"] = roundf(agi_v * d.dodge_per_agi) + _eq_stat(member, "dodge")
	# critV：見檔頭「刻意行為修正」——統一採用 WORLD 版取一位小數的寫法（round(x*10)/10）。
	# see specs/BATTLE_FORMULAS.md F-1
	member["critV"] = roundf((d.crit_base + agi_v * d.crit_per_agi + _eq_stat(member, "crit")) * 10.0) / 10.0
	member["spd"] = agi_v

	# hp/mp 初值：未定義或超過上限時 clamp 到 maxhp/maxmp（嚴格對應 m.hp===undefined||m.hp>m.maxhp，
	# 不是「永遠回滿」，裝備變動導致 maxhp 下降時現有 hp 只會被夾住，不會被治療到滿血以外）。
	if not member.has("hp") or float(member["hp"]) > float(member["maxhp"]):
		member["hp"] = member["maxhp"]
	if not member.has("mp") or float(member["mp"]) > float(member["maxmp"]):
		member["mp"] = member["maxmp"]

	# sk（已學技能表）：JS 原始碼是 `if(!m.sk)` 真假值判斷，不是 `===undefined` 嚴格判斷——JS 裡空物件
	# {} 是 truthy，所以「sk 已存在但剛好是空表」不會被重新初始化，跟其他欄位的 undefined 判斷不同，這裡
	# 刻意精確複製這個差異（用 null 判斷，不是「空 Dictionary 視為未設定」，避免誤觸發重算把玩家手動清空
	# 的技能表洗掉）。
	var sk_val = member.get("sk", null)
	# JS `if(!m.sk)`：dict（含空 {}）為 truthy 保留、null/非 dict 才重算。用型別判斷避免 Dictionary==bool 型別錯誤。
	if not (sk_val is Dictionary):
		var sk: Dictionary = {}
		var cls: String = String(member.get("cls", ""))
		var lv: int = int(member.get("lv", 1))
		for skill in ContentDB.get_all_skills():
			var sd: SkillDef = skill
			if sd.char_class == cls and lv >= sd.unlock_lv:
				sk[sd.id] = 1
		member["sk"] = sk

	if not member.has("spts"):
		member["spts"] = 0

	return member


## 對應 `eqStat(m,k)`（build_cq2.py L1324/L2640）：把 m.eq 裡每個部位對應的
## CONTENT.equipment[eqId][k] 加總，沒有該屬性視為 0。
static func _eq_stat(member: Dictionary, key: String) -> float:
	var total := 0.0
	var eq: Dictionary = member.get("eq", {})
	for slot in eq.keys():
		var eq_id = eq[slot]
		var def: EquipmentDef = ContentDB.get_equipment(String(eq_id))
		if def != null:
			total += def.get_stat(key)
	return total
