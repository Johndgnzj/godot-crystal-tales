class_name MenuLogic
extends RefCounted

## 選單的「模型層」——從舊 menu_root.gd 原樣搬出的常數＋純邏輯，供重設後的各 page 共用。
##
## 全部對照 build_cq2.py（行號見各函式），是已驗證的算法：換裝環 cycle_eq、飾品槽 acc_slot_for、
## 裝備屬性描述 eq_desc、技能清單 skill_list/威力 sk_pow、建議等級 lv_range、整數化顯示 num。
## 重設只換「畫法」（view，見 pixel_ui.gd 與各 page），這裡的「算什麼」不動，避免行為飄移。
##
## 依賴（皆唯讀，除 cycle_eq 會就地 mutate 傳入的 member 與 GameState.eq_inv）：
## ContentDB / GameState / Derive。呼叫端需自行確保 ContentDB.is_loaded。

const TABS := ["角色", "道具", "地圖", "稱號", "系統"]   # 重設後頂部 5 分頁（裝備併入角色子頁）
const SLOTS := [["weapon", "武器"], ["armor", "防具"], ["boots", "靴子"], ["wrist", "護腕"], ["acc1", "飾品Ⅰ"], ["acc2", "飾品Ⅱ"]]
const SLOTN := {"weapon": "武器", "armor": "防具", "boots": "靴子", "wrist": "護腕", "acc": "飾品"}
const EQSTAT_N := {"patk": "物攻", "matk": "魔攻", "pdef": "物防", "mdef": "魔防", "dodge": "閃避", "crit": "會心", "hp": "生命", "mp": "法力",
	"str": "力量", "agi": "敏捷", "int": "智力", "luck": "幸運", "spd": "行動", "acc": "命中", "critres": "抗爆", "critdmg": "爆傷"}   # v4.0 裝備可加主屬性/新戰鬥維度
const CLS_NAME := {"explorer": "探索者", "veteran": "A級冒險者"}
const LOC := {"Town": "芳蕾鎮", "Forest": "東之森", "Forest2": "東之森深處", "Mine": "礦山外圍", "Cave": "礦山洞穴"}
const SORD := {"weapon": 0, "armor": 1, "boots": 2, "wrist": 3, "acc": 4}
const DIFFK := [["patk", "物攻"], ["matk", "魔攻"], ["pdef", "物防"], ["mdef", "魔防"], ["dodgeV", "閃避"], ["critV", "會心"], ["accV", "命中"], ["critresV", "抗爆"], ["critdmg", "爆傷"], ["maxhp", "HP上限"], ["maxmp", "MP上限"]]

# 衍生格（屬性子頁；對應 derive 後欄位）：key → 顯示名。v4.0 增命中/抗爆/爆傷，格數 6→9（GridContainer 自動換行）。
const DERIVED6 := [["patk", "物攻"], ["matk", "魔攻"], ["pdef", "物防"], ["mdef", "魔防"], ["dodgeV", "閃避"], ["critV", "會心"], ["accV", "命中"], ["critresV", "抗爆"], ["critdmg", "爆傷"]]
# 佔位系統（設計稿有版面、遊戲無資料）。
const WEAPON_TYPES := ["劍", "槍", "斧", "盾", "投射", "杖", "鎚"]
const ELEMENTS := ["土", "火", "風", "水", "冰", "雷", "光", "暗"]
const PRIMARY := [["str", "力量"], ["agi", "敏捷"], ["int", "智力"], ["luck", "幸運"]]   # v4.0 新增幸運


static func cls_name(m: Dictionary) -> String:
	var cls := String(m.get("cls", ""))
	return String(CLS_NAME.get(cls, cls))


## 對應 eqDesc()（L1850-1854）：依 EQSTAT_N 順序列出非零屬性加成。
static func eq_desc(e: EquipmentDef) -> String:
	var out: Array = []
	for k in EQSTAT_N.keys():
		var v := e.get_stat(String(k))
		if v != 0.0:
			out.append(String(EQSTAT_N[k]) + "+" + num(v))
	return " ".join(out)


## 對應 skillList()（L1347-1352）：CONTENT.skills 順序中、該成員已學（sk[id] 為真）的技能。
static func skill_list(m: Dictionary) -> Array:
	var out: Array = []
	var sk: Dictionary = m.get("sk", {})
	for s in ContentDB.get_all_skills():
		if int(sk.get(s.id, 0)) > 0:
			out.append(s)
	return out


## 該成員同職、尚未習得（unlock_lv > 目前等級 或 未在 sk 表）的技能——屬性/技能頁灰階顯示用。
static func locked_skills(m: Dictionary) -> Array:
	var out: Array = []
	var sk: Dictionary = m.get("sk", {})
	var cls := String(m.get("cls", ""))
	for s in ContentDB.get_all_skills():
		if s.char_class == cls and int(sk.get(s.id, 0)) <= 0:
			out.append(s)
	return out


static func skill_max_lv() -> int:
	return int(ContentDB.get_derived().skill_max_lv)


## 對應 skPow()（L1848）：1 + skillPowerPerLv*((slv||1)-1)。
static func sk_pow(slv: int) -> float:
	return 1.0 + ContentDB.get_derived().skill_power_per_lv * float(max(slv, 1) - 1)


static func slot_type(slot: String) -> String:
	return "acc" if (slot == "acc1" or slot == "acc2") else slot


static func slot_label(sk: String) -> String:
	for pair in SLOTS:
		if pair[0] == sk:
			return pair[1]
	return sk


## 對應 accSlotFor()（L1837-1838）：飾品自動找空的 acc1/acc2，其他部位照原 slot。
static func acc_slot_for(m: Dictionary, it: EquipmentDef) -> String:
	if it.slot != "acc":
		return it.slot
	var eq: Dictionary = m.get("eq", {})
	if String(eq.get("acc1", "")) == "":
		return "acc1"
	if String(eq.get("acc2", "")) == "":
		return "acc2"
	return "acc1"


## 對應 cycleEq()（L1855-1873）：卸下 + 背包同部位裝備 依 id 排序組成穩定環，Enter 沿環前進。
static func cycle_eq(m: Dictionary, slot: String) -> bool:
	var tp := slot_type(slot)
	var inv: Array = GameState.eq_inv
	var cur: Variant = m.get("eq", {}).get(slot, null)
	if cur != null and String(cur) == "":
		cur = null
	var set_ids := {}
	for id in inv:
		var ed: EquipmentDef = ContentDB.get_equipment(String(id))
		if ed != null and ed.slot == tp:
			set_ids[id] = 1
	if cur != null:
		set_ids[cur] = 1
	var keys: Array = set_ids.keys()
	keys.sort()
	var ring: Array = [null]
	ring.append_array(keys)
	if ring.size() < 2:
		return false
	var cur_idx := ring.find(cur)
	var nxt: Variant = ring[(cur_idx + 1) % ring.size()]
	if nxt == cur:
		return false
	if cur != null:
		inv.append(cur)
	if nxt != null:
		inv.erase(nxt)
		if not m.has("eq"):
			m["eq"] = {}
		m["eq"][slot] = nxt
	else:
		m.get("eq", {}).erase(slot)
	return true


## 把某件裝備裝到某成員（對應 _tab_equip who 模式的 Enter 分支）：卸下原件回背包、扣袋內一件。
static func equip_to(m: Dictionary, item_id: String) -> void:
	var it: EquipmentDef = ContentDB.get_equipment(item_id)
	if it == null:
		return
	var inv: Array = GameState.eq_inv
	if not inv.has(item_id):
		return
	Derive.derive(m)
	var slot := acc_slot_for(m, it)
	inv.erase(item_id)
	var cur: Variant = m.get("eq", {}).get(slot, null)
	if cur != null and String(cur) != "":
		inv.append(cur)
	if not m.has("eq"):
		m["eq"] = {}
	m["eq"][slot] = item_id
	Derive.derive(m)


## 卸下某 slot 的裝備回背包（設計稿「卸下」鈕）。
static func unequip(m: Dictionary, slot: String) -> void:
	var eq: Dictionary = m.get("eq", {})
	var cur: Variant = eq.get(slot, null)
	if cur == null or String(cur) == "":
		return
	GameState.eq_inv.append(cur)
	eq.erase(slot)
	Derive.derive(m)


## 模擬把 item 裝到 m 後、相對現況的屬性差異字串陣列（對應 _tab_equip who 模式 DIFFK 差異）。
static func equip_diff(m: Dictionary, item_id: String) -> Array:
	var it: EquipmentDef = ContentDB.get_equipment(item_id)
	if it == null:
		return []
	Derive.derive(m)
	var slot := acc_slot_for(m, it)
	var sim: Dictionary = m.duplicate(true)
	if not sim.has("eq"):
		sim["eq"] = {}
	sim["eq"][slot] = item_id
	Derive.derive(sim)
	var difs: Array = []
	for dk in DIFFK:
		var a0: Variant = m.get(dk[0])
		var b0: Variant = sim.get(dk[0])
		if a0 != b0:
			difs.append({"name": String(dk[1]), "from": num(a0), "to": num(b0), "up": float(b0) > float(a0)})
	return difs


## 背包內某 slot 類型的可換裝備（去重＋數量），依 SORD/id 穩定排序。回傳 [{id, count, def}]。
static func bag_for_slot(slot_type_: String) -> Array:
	var cnt := {}
	var order: Array = []
	for id in GameState.eq_inv:
		var ed: EquipmentDef = ContentDB.get_equipment(String(id))
		if ed == null or ed.slot != slot_type_:
			continue
		if not cnt.has(id):
			cnt[id] = 0
			order.append(id)
		cnt[id] = int(cnt[id]) + 1
	order.sort()
	var out: Array = []
	for id in order:
		out.append({"id": String(id), "count": int(cnt[id]), "def": ContentDB.get_equipment(String(id))})
	return out


static func lv_range(k: String) -> String:
	var mp: Dictionary = ContentDB.get_pacing().get_map(k)
	if mp.is_empty():
		return "—"
	return "Lv" + str(mp.get("entryLv", 0)) + "-" + str(mp.get("targetLv", 0))


## 整數化顯示（build_cq2 數值多為整數；float 剛好整數時去掉小數點）。
static func num(v: Variant) -> String:
	var f := float(v)
	if is_equal_approx(f, round(f)):
		return str(int(round(f)))
	return str(f)
