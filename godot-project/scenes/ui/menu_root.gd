extends CanvasLayer
## menu_root.tscn 的控制腳本 —— 六分頁選單（角色/裝備/道具/地圖/稱號/系統）。
##
## 這是 build_cq2.py `if(st.menu){…}` 段落（L1927-2166）的 Godot 移植，逐分頁對照原版的
## rows 組裝、游標移動、換裝/配點/升技/用道具/佩戴稱號流程。面板繪製交給共用的 CqMenuPanel
## （對應原版 renderPanel），本檔案只負責「狀態機＋組資料」。
##
## 輸入走 CORE-6 的 InputBridge 統一 action（不寫觸控專用分支——觸控 UI 會把同一組 action 灌回
## InputMap，見 input_bridge.gd 檔頭）。action 對應：
##   move_up/down/left/right ← 原版 Up/Down/Left/Right；ui_accept ← Enter/Space；
##   menu_toggle(M)＋ui_cancel(Esc) ← 原版 Escape/m（開關選單與子頁返回）；
##   stat_str/stat_agi/stat_int ← 原版 Num1/Num2/Num3（能力頁配點）。
## 原版另有 Q/E 快速切分頁（L1931-1933），Q/E 不在 InputMap（CORE-1 未定義）且與 Left/Right 完全
## 重複，故省略；分頁切換一律用 move_left/move_right（見任務報告「已知差異」）。
##
## 依賴（皆唯讀呼叫）：GameState（party/eq_inv/item_inv/gold/flags/inv_*）、ContentDB
## （get_equipment/get_item/get_all_skills/get_pacing/get_party_member）、Derive.derive()、
## ExpNeed.exp_need()、TitlesData（稱號分頁）。
##
## 開關協調：選單開啟時鎖世界移動由整合端（世界場景控制器）監聽 menu_opened/menu_closed 或查
## is_open() 處理（本檔案不改世界場景 .gd）。選單與商店互斥：開選單前確認商店未開，商店開啟時會
## 主動關掉選單（見 shop.gd）。
##
## scene_id：地圖分頁需要目前世界場景 id（對照原版 CFG.SCENE），由整合端呼叫 set_scene_id() 告知。

signal menu_opened
signal menu_closed

const TABS := ["角色", "裝備", "道具", "地圖", "稱號", "系統"]
const SLOTS := [["weapon", "武器"], ["armor", "防具"], ["boots", "靴子"], ["wrist", "護腕"], ["acc1", "飾品Ⅰ"], ["acc2", "飾品Ⅱ"]]
const SLOTN := {"weapon": "武器", "armor": "防具", "boots": "靴子", "wrist": "護腕", "acc": "飾品"}
const EQSTAT_N := {"patk": "物攻", "matk": "魔攻", "pdef": "物防", "mdef": "魔防", "dodge": "閃避", "crit": "會心", "hp": "生命", "mp": "法力"}
const CLS_NAME := {"explorer": "探索者", "veteran": "A級冒險者"}
const LOC := {"Town": "芳蕾鎮", "Forest": "東之森", "Forest2": "東之森深處", "Mine": "礦山外圍", "Cave": "礦山洞穴"}
const SORD := {"weapon": 0, "armor": 1, "boots": 2, "wrist": 3, "acc": 4}
const DIFFK := [["patk", "物攻"], ["matk", "魔攻"], ["pdef", "物防"], ["mdef", "魔防"], ["dodgeV", "閃避"], ["critV", "會心"], ["maxhp", "HP上限"], ["maxmp", "MP上限"]]

# 顏色常數（build_cq2 內以 "r;g;b" 字面出現、非 UI token 的一次性色；主 token 走 _panel.col_*）
const C_STORY := Color(0.843, 0.863, 0.921)      # 215;220;235
const C_EMPTY := Color(0.588, 0.627, 0.745)      # 150;160;190
const C_DIM2 := Color(0.431, 0.471, 0.549)       # 110;120;140
const C_MAT := Color(0.803, 0.803, 0.843)        # 205;205;215
const C_DIFF_OFF := Color(0.509, 0.549, 0.647)   # 130;140;165
const C_HELP := Color(0.667, 0.706, 0.863)       # 170;180;220
const C_UNUSABLE := Color(0.667, 0.588, 0.588)   # 170;150;150

@onready var _panel: CqMenuPanel = $Panel

var _open := false
var scene_id: String = ""

# --- 選單狀態（對應 st.tab/sel/mMode/mPage/sSel/eqMode/eqSel/eqWho/eqItem/iMode/iSel/iWho/confirmQuit）---
var tab := 0
var sel := 0
var m_mode := "list"
var m_page := 0
var s_sel := 0
var eq_mode := "list"
var eq_sel := 0
var eq_who := 0
var eq_item := ""
var i_mode := "list"
var i_sel := 0
var i_who := 0
var confirm_quit := false


func _ready() -> void:
	add_to_group("cq_menu")


func set_scene_id(id: String) -> void:
	scene_id = id


func is_open() -> bool:
	return _open


func _hit(action: String) -> bool:
	return InputBridge.is_action_hit(action)


func _process(_delta: float) -> void:
	if not _open:
		if not DialogueSystem.is_busy() and not _shop_open():
			if _hit("menu_toggle") or _hit("ui_cancel"):
				_open_menu()
		return

	# 開啟中：先處理返回/關閉（對應 build_cq2 L1918-1925 的子頁返回或整體關閉）
	if _hit("menu_toggle") or _hit("ui_cancel"):
		if tab == 0 and m_mode == "member":
			m_mode = "list"
		elif tab == 1 and eq_mode == "who":
			eq_mode = "list"
		elif tab == 2 and i_mode == "who":
			i_mode = "list"
		else:
			_close_menu()
			return

	if not ContentDB.is_loaded:
		return
	_tick_open()


func _open_menu() -> void:
	_open = true
	tab = 0
	sel = 0
	s_sel = 0
	m_mode = "list"
	m_page = 0
	eq_mode = "list"
	eq_sel = 0
	i_mode = "list"
	confirm_quit = false
	menu_opened.emit()


func _close_menu() -> void:
	_open = false
	_panel.close_panel()
	menu_closed.emit()


func _shop_open() -> bool:
	var s := get_tree().get_first_node_in_group("cq_shop")
	return s != null and s.has_method("is_open") and s.is_open()


# =========================================================================
# 主 tick：組 rows/bars 並丟給面板（對應 build_cq2 if(st.menu){…}）
# =========================================================================
func _tick_open() -> void:
	var ps: Array = GameState.party
	var in_member := (tab == 0 and m_mode == "member") or (tab == 1 and eq_mode == "who") or (tab == 2 and i_mode == "who")
	if not in_member:
		if _hit("move_left"):
			tab = (tab + TABS.size() - 1) % TABS.size()
			_reset_tab_cursors()
		if _hit("move_right"):
			tab = (tab + 1) % TABS.size()
			_reset_tab_cursors()

	var enter := _hit("ui_accept")
	var up := _hit("move_up")
	var down := _hit("move_down")
	var rows: Array = []
	var bars: Array = []
	var hint := "←→ 切換分頁　M/Esc 關閉"

	match tab:
		0:
			hint = _tab_chars(ps, enter, up, down, rows, bars)
		1:
			hint = _tab_equip(ps, enter, up, down, rows, bars)
		2:
			hint = _tab_items(ps, enter, up, down, rows, bars)
		3:
			hint = _tab_map(rows)
		4:
			hint = _tab_titles(enter, up, down, rows)
		_:
			hint = _tab_system(enter, up, down, rows)

	_panel.render(rows, bars, {"title": "選單", "hint": hint, "tab": _tab_strip()})


func _reset_tab_cursors() -> void:
	sel = 0
	eq_mode = "list"
	eq_sel = 0
	i_mode = "list"
	confirm_quit = false


func _tab_strip() -> String:
	var parts: Array = []
	for i in TABS.size():
		parts.append(("【%s】" % TABS[i]) if i == tab else (" %s " % TABS[i]))
	return "　".join(parts)


# ---- 角色分頁（L1944-2014）----
func _tab_chars(ps: Array, enter: bool, up: bool, down: bool, rows: Array, bars: Array) -> String:
	if m_mode == "list" or sel >= ps.size():
		if m_mode == "member" and sel >= ps.size():
			m_mode = "list"
		if up and sel > 0:
			sel -= 1
		if down and sel < ps.size() - 1:
			sel += 1
		rows.append({"t": "── 隊伍 ──", "c": _panel.col_accent})
		for i in ps.size():
			var mm: Dictionary = ps[i]
			Derive.derive(mm)
			var y0 := 214 + i * 76
			var has_pts := int(mm.get("pts", 0)) > 0 or int(mm.get("spts", 0)) > 0
			var star := "　★有可分配點數" if has_pts else ""
			rows.append({"t": ("▶ " if i == sel else "　 ") + String(mm.get("name", "")) + "　" + _cls_name(mm) + "　Lv" + str(mm.get("lv", 1)) + star, "sel": i == sel, "x": 180, "y": y0, "hw": 920})
			rows.append({"t": "HP " + str(mm.get("hp", 0)) + "/" + str(mm.get("maxhp", 0)), "x": 220, "y": y0 + 30})
			bars.append({"x": 390, "y": y0 + 38, "w": 170, "cur": mm.get("hp", 0), "max": mm.get("maxhp", 0), "kind": "hp"})
			rows.append({"t": "MP " + str(mm.get("mp", 0)) + "/" + str(mm.get("maxmp", 0)), "x": 620, "y": y0 + 30})
			bars.append({"x": 780, "y": y0 + 38, "w": 170, "cur": mm.get("mp", 0), "max": mm.get("maxmp", 0), "kind": "mp"})
		if enter and sel < ps.size():
			m_mode = "member"
			s_sel = 0
			m_page = 0
		return "↑↓ 選隊員　Enter 檢視/配點　←→ 分頁　Esc 關閉"

	# 成員頁（能力/故事）
	var m: Dictionary = ps[sel]
	Derive.derive(m)
	if _hit("move_left") or _hit("move_right"):
		m_page = m_page ^ 1
	rows.append({"t": String(m.get("name", "")) + "　" + _cls_name(m) + "　Lv" + str(m.get("lv", 1)) + "　EXP " + str(m.get("exp", 0)) + "/" + str(ExpNeed.exp_need(int(m.get("lv", 1)))) + "　　" + ("〔能力〕　故事▶" if m_page == 0 else "◀能力　〔故事〕"), "x": 180, "y": 140})

	if m_page == 1:
		rows.append({"t": "【個人故事】", "c": _panel.col_accent, "x": 180, "y": 196})
		var pdef: PartyMemberDef = ContentDB.get_party_member(String(m.get("id", "")))
		var stv: Array = pdef.story if (pdef != null and pdef.story.size() > 0) else ["（沒有相關紀錄）"]
		for i in min(stv.size(), 9):
			rows.append({"t": String(stv[i]), "x": 180, "y": 232 + i * 32, "c": C_STORY})
		return "←→ 切換 能力/故事　Esc 返回"

	# 能力頁：配點 / 換裝 / 升技
	var did := false
	if _hit("stat_str") and int(m.get("pts", 0)) > 0:
		m["attrs"]["str"] = int(m["attrs"]["str"]) + 1
		m["pts"] = int(m["pts"]) - 1
		did = true
	if _hit("stat_agi") and int(m.get("pts", 0)) > 0:
		m["attrs"]["agi"] = int(m["attrs"]["agi"]) + 1
		m["pts"] = int(m["pts"]) - 1
		did = true
	if _hit("stat_int") and int(m.get("pts", 0)) > 0:
		m["attrs"]["int"] = int(m["attrs"]["int"]) + 1
		m["pts"] = int(m["pts"]) - 1
		did = true

	var sl: Array = _skill_list(m)
	if sl.size() > 5:
		sl = sl.slice(0, 5)
	var n_items := SLOTS.size() + sl.size()
	if up and s_sel > 0:
		s_sel -= 1
	if down and s_sel < n_items - 1:
		s_sel += 1
	if enter:
		if s_sel < SLOTS.size():
			if _cycle_eq(m, SLOTS[s_sel][0]):
				did = true
		else:
			var sk0: SkillDef = sl[s_sel - SLOTS.size()]
			if sk0 != null and int(m.get("spts", 0)) > 0 and int(m.get("sk", {}).get(sk0.id, 0)) < _skill_max_lv():
				m["sk"][sk0.id] = int(m["sk"][sk0.id]) + 1
				m["spts"] = int(m["spts"]) - 1
				did = true
	if did:
		Derive.derive(m)

	rows.append({"t": "HP " + str(m.get("hp", 0)) + "/" + str(m.get("maxhp", 0)), "x": 180, "y": 168})
	bars.append({"x": 330, "y": 176, "w": 170, "cur": m.get("hp", 0), "max": m.get("maxhp", 0), "kind": "hp"})
	rows.append({"t": "MP " + str(m.get("mp", 0)) + "/" + str(m.get("maxmp", 0)), "x": 560, "y": 168})
	bars.append({"x": 700, "y": 176, "w": 170, "cur": m.get("mp", 0), "max": m.get("maxmp", 0), "kind": "mp"})

	var pts := int(m.get("pts", 0))
	rows.append({"t": "【屬性】屬性點 " + str(pts) + ("　（1=力 2=敏 3=智 分配）" if pts > 0 else ""), "x": 180, "y": 206, "c": _panel.col_gold if pts > 0 else _panel.col_accent})
	rows.append({"t": "力量  " + str(m["attrs"]["str"]), "x": 200, "y": 238})
	rows.append({"t": "敏捷  " + str(m["attrs"]["agi"]), "x": 380, "y": 238})
	rows.append({"t": "智力  " + str(m["attrs"]["int"]), "x": 560, "y": 238})
	var dc := _panel.col_accent
	rows.append({"t": "物攻  " + _num(m.get("patk", 0)), "x": 200, "y": 276, "c": dc})
	rows.append({"t": "物防  " + _num(m.get("pdef", 0)), "x": 380, "y": 276, "c": dc})
	rows.append({"t": "閃避  " + _num(m.get("dodgeV", 0)), "x": 560, "y": 276, "c": dc})
	rows.append({"t": "速度  " + _num(m.get("spd", 0)), "x": 740, "y": 276, "c": dc})
	rows.append({"t": "魔攻  " + _num(m.get("matk", 0)), "x": 200, "y": 304, "c": dc})
	rows.append({"t": "魔防  " + _num(m.get("mdef", 0)), "x": 380, "y": 304, "c": dc})
	rows.append({"t": "會心  " + _num(m.get("critV", 0)) + "%", "x": 560, "y": 304, "c": dc})
	rows.append({"t": "【裝備】（Enter 循環更換）", "x": 180, "y": 332, "c": _panel.col_accent})
	for i in SLOTS.size():
		var eid = m.get("eq", {}).get(SLOTS[i][0], "")
		var eqtxt := "——"
		if eid != null and String(eid) != "":
			var ed: EquipmentDef = ContentDB.get_equipment(String(eid))
			if ed != null:
				eqtxt = ed.display_name + "（" + _eq_desc(ed) + "）"
		rows.append({"t": ("▶ " if i == s_sel else "　 ") + SLOTS[i][1] + "：" + eqtxt, "sel": i == s_sel, "x": 180, "y": 360 + i * 28, "hw": 440})
	rows.append({"t": "【技能】技能點 " + str(int(m.get("spts", 0))) + "（Enter 升級）", "x": 650, "y": 332, "c": _panel.col_accent})
	for i in sl.size():
		var sk1: SkillDef = sl[i]
		var slv := int(m.get("sk", {}).get(sk1.id, 0))
		var si := SLOTS.size() + i
		var pw1 := _sk_pow(slv)
		var atk_lbl := "魔攻" if sk1.attr == "int" else "物攻"
		var mult_str := "%.2f" % (sk1.mult * pw1)
		var flat_str := ("+" + str(int(round(sk1.flat * pw1)))) if sk1.flat != 0.0 else ""
		rows.append({"t": ("▶ " if si == s_sel else "　 ") + sk1.display_name + "　Lv" + str(slv) + "/" + str(_skill_max_lv()) + "　MP" + str(sk1.mp) + "　" + atk_lbl + "×" + mult_str + flat_str, "sel": si == s_sel, "x": 650, "y": 360 + i * 28, "hw": 470})
	return "↑↓ 選擇　Enter 換裝/升技　1/2/3 配點　←→ 能力/故事　Esc 返回"


# ---- 裝備分頁（L2015-2068）----
func _tab_equip(ps: Array, enter: bool, up: bool, down: bool, rows: Array, _bars: Array) -> String:
	var inv: Array = GameState.eq_inv
	var uniq: Array = []
	var cnt := {}
	for id in inv:
		if ContentDB.get_equipment(String(id)) == null:
			continue
		if not cnt.has(id):
			cnt[id] = 0
			uniq.append(id)
		cnt[id] = int(cnt[id]) + 1
	uniq.sort_custom(_equip_sort)

	if eq_mode == "who" and (ContentDB.get_equipment(String(eq_item)) == null or not cnt.has(eq_item)):
		eq_mode = "list"

	if eq_mode == "list":
		if eq_sel >= uniq.size():
			eq_sel = max(0, uniq.size() - 1)
		if up and eq_sel > 0:
			eq_sel -= 1
		if down and eq_sel < uniq.size() - 1:
			eq_sel += 1
		rows.append({"t": "── 裝備袋（隊伍共用）──", "c": _panel.col_accent})
		if uniq.size() == 0:
			rows.append({"t": "（目前沒有備用裝備——多和鎮民聊聊、完成委託會有收穫）", "c": C_EMPTY})
		var base := max(0, min(eq_sel - 5, uniq.size() - 11))
		var i := base
		while i < uniq.size() and i < base + 11:
			var e: EquipmentDef = ContentDB.get_equipment(String(uniq[i]))
			var xn := (" ×" + str(cnt[uniq[i]])) if int(cnt[uniq[i]]) > 1 else ""
			rows.append({"t": ("▶ " if i == eq_sel else "　 ") + "［" + String(SLOTN.get(e.slot, e.slot)) + "］" + e.display_name + xn + "　" + _eq_desc(e), "sel": i == eq_sel, "x": 180, "y": 204 + (i - base) * 28, "hw": 900})
			i += 1
		if eq_sel < uniq.size():
			var e2: EquipmentDef = ContentDB.get_equipment(String(uniq[eq_sel]))
			var d2 := _eq_desc(e2)
			rows.append({"t": "效果：　" + (d2 if d2 != "" else "（無屬性加成）") + "　［" + String(SLOTN.get(e2.slot, e2.slot)) + "部位］", "c": _panel.col_accent, "x": 180, "y": 522})
		if enter and eq_sel < uniq.size():
			eq_mode = "who"
			eq_who = 0
			eq_item = String(uniq[eq_sel])
		return "↑↓ 選裝備　Enter 選擇要裝備的隊員　←→ 分頁　Esc 關閉"

	# who 模式：選要裝備的隊員，顯示前後差異
	var it: EquipmentDef = ContentDB.get_equipment(String(eq_item))
	if up and eq_who > 0:
		eq_who -= 1
	if down and eq_who < ps.size() - 1:
		eq_who += 1
	var d3 := _eq_desc(it)
	rows.append({"t": "要讓誰裝備：　" + it.display_name + "　［" + String(SLOTN.get(it.slot, it.slot)) + "］　" + (d3 if d3 != "" else "無屬性加成"), "c": _panel.col_accent})
	for i in ps.size():
		var mm: Dictionary = ps[i]
		Derive.derive(mm)
		var slot2 := _acc_slot_for(mm, it)
		var old2 = mm.get("eq", {}).get(slot2, null)
		var sim: Dictionary = mm.duplicate(true)
		sim["eq"][slot2] = eq_item
		Derive.derive(sim)
		var difs: Array = []
		for dk in DIFFK:
			var a0 = mm.get(dk[0])
			var b0 = sim.get(dk[0])
			if a0 != b0:
				difs.append(String(dk[1]) + " " + _num(a0) + "→" + _num(b0))
		var oldname := ContentDB.get_equipment(String(old2)).display_name if (old2 != null and String(old2) != "") else "（空）"
		rows.append({"t": ("▶ " if i == eq_who else "　 ") + String(mm.get("name", "")) + "　" + _slot_label(slot2) + "：" + oldname + " → " + it.display_name, "sel": i == eq_who, "x": 180, "y": 216 + i * 66, "hw": 900})
		rows.append({"t": "　　　" + ("　".join(difs) if difs.size() > 0 else "（能力值不變）"), "c": (_panel.col_good if i == eq_who else C_DIFF_OFF), "x": 180, "y": 216 + i * 66 + 28})
	if enter and eq_who < ps.size():
		var mr: Dictionary = ps[eq_who]
		Derive.derive(mr)
		var slot3 := _acc_slot_for(mr, it)
		inv.erase(eq_item)
		var cur_eq = mr.get("eq", {}).get(slot3, null)
		if cur_eq != null and String(cur_eq) != "":
			inv.append(cur_eq)
		mr["eq"][slot3] = eq_item
		Derive.derive(mr)
		eq_mode = "list"
	return "↑↓ 選隊員（顯示裝備前後差異）　Enter 裝備　Esc 返回"


# ---- 道具分頁（L2069-2126）----
func _tab_items(ps: Array, enter: bool, up: bool, down: bool, rows: Array, bars: Array) -> String:
	var iv: Dictionary = GameState.inv_all()
	var cons: Array = []
	var mats: Array = []
	var keys_: Array = []
	for it_def in ContentDB.get_all_items():
		var q := int(iv.get(it_def.id, 0))
		if q <= 0:
			continue
		var rec := {"id": it_def.id, "n": q, "meta": it_def}
		match it_def.cat:
			"consumable":
				cons.append(rec)
			"material":
				mats.append(rec)
			"key":
				keys_.append(rec)
	if i_sel >= cons.size():
		i_sel = max(0, cons.size() - 1)
	if i_mode == "who" and cons.size() == 0:
		i_mode = "list"

	if i_mode == "list":
		if up and i_sel > 0:
			i_sel -= 1
		if down and i_sel < cons.size() - 1:
			i_sel += 1
		rows.append({"t": "── 道具袋 ──　消耗品", "c": _panel.col_accent, "x": 180, "y": 150})
		if cons.size() == 0:
			rows.append({"t": "（沒有可用的消耗品——去吉德的道具店補貨吧）", "c": C_EMPTY, "x": 180, "y": 200})
		for i in min(cons.size(), 8):
			var c0: Dictionary = cons[i]
			rows.append({"t": ("▶ " if i == i_sel else "　 ") + c0["meta"].display_name + "　×" + str(c0["n"]), "sel": i == i_sel, "x": 180, "y": 200 + i * 30, "hw": 460})
		if i_sel < cons.size():
			var sc: ItemDef = cons[i_sel]["meta"]
			var usable := sc.kind == "heal" or sc.kind == "mp"
			rows.append({"t": "效果：　" + (sc.effect if sc.effect != "" else "（無說明）"), "c": _panel.col_accent, "x": 180, "y": 472, "hw": 520})
			rows.append({"t": ("→ Enter 選擇使用對象" if usable else "→ 此道具目前無法在選單中使用"), "c": (_panel.col_good if usable else C_UNUSABLE), "x": 180, "y": 504})
		var ry0 := 200
		rows.append({"t": "─ 素材 ─", "c": _panel.col_dim, "x": 700, "y": ry0})
		ry0 += 28
		if mats.size() == 0:
			rows.append({"t": "（無）", "c": C_DIM2, "x": 720, "y": ry0})
			ry0 += 26
		for i in min(mats.size(), 6):
			rows.append({"t": mats[i]["meta"].display_name + "　×" + str(mats[i]["n"]), "c": C_MAT, "x": 720, "y": ry0})
			ry0 += 26
		rows.append({"t": "─ 重要物品 ─", "c": _panel.col_dim, "x": 700, "y": ry0})
		ry0 += 28
		if keys_.size() == 0:
			rows.append({"t": "（無）", "c": C_DIM2, "x": 720, "y": ry0})
			ry0 += 26
		for i in min(keys_.size(), 4):
			rows.append({"t": keys_[i]["meta"].display_name, "c": C_MAT, "x": 720, "y": ry0})
			ry0 += 26
		if enter and i_sel < cons.size():
			var sc2: ItemDef = cons[i_sel]["meta"]
			if sc2.kind == "heal" or sc2.kind == "mp":
				i_mode = "who"
				i_who = 0
		return "↑↓ 選道具　Enter 使用　←→ 分頁　Esc 關閉"

	# who 模式：選使用對象
	var it2: Dictionary = cons[i_sel]
	var is_mp := it2["meta"].kind == "mp"
	if up and i_who > 0:
		i_who -= 1
	if down and i_who < ps.size() - 1:
		i_who += 1
	rows.append({"t": "對誰使用：　" + it2["meta"].display_name + "　×" + str(it2["n"]) + "　" + String(it2["meta"].effect), "c": _panel.col_accent, "x": 180, "y": 150, "hw": 900})
	for i in ps.size():
		var mm: Dictionary = ps[i]
		Derive.derive(mm)
		var y0 := 224 + i * 64
		rows.append({"t": ("▶ " if i == i_who else "　 ") + String(mm.get("name", "")) + "　Lv" + str(mm.get("lv", 1)), "sel": i == i_who, "x": 180, "y": y0, "hw": 820})
		rows.append({"t": "HP " + str(mm.get("hp", 0)) + "/" + str(mm.get("maxhp", 0)), "x": 220, "y": y0 + 30})
		bars.append({"x": 390, "y": y0 + 38, "w": 150, "cur": mm.get("hp", 0), "max": mm.get("maxhp", 0), "kind": "hp"})
		rows.append({"t": "MP " + str(mm.get("mp", 0)) + "/" + str(mm.get("maxmp", 0)), "x": 600, "y": y0 + 30})
		bars.append({"x": 760, "y": y0 + 38, "w": 150, "cur": mm.get("mp", 0), "max": mm.get("maxmp", 0), "kind": "mp"})
	if enter and i_who < ps.size():
		var tgt: Dictionary = ps[i_who]
		Derive.derive(tgt)
		var full := (float(tgt.get("mp", 0)) >= float(tgt.get("maxmp", 0))) if is_mp else (float(tgt.get("hp", 0)) >= float(tgt.get("maxhp", 0)))
		if not full:
			var pw := float(it2["meta"].power)
			if is_mp:
				tgt["mp"] = min(float(tgt.get("maxmp", 0)), float(tgt.get("mp", 0)) + pw)
			else:
				tgt["hp"] = min(float(tgt.get("maxhp", 0)), float(tgt.get("hp", 0)) + pw)
			GameState.inv_use(String(it2["id"]))
			if GameState.inv_get(String(it2["id"])) <= 0:
				i_mode = "list"
	return "↑↓ 選隊員　Enter 使用　Esc 返回"


# ---- 地圖分頁（L2127-2134）----
func _tab_map(rows: Array) -> String:
	var loc := String(LOC.get(scene_id, scene_id if scene_id != "" else "—"))
	rows.append({"t": "現在位置：%s　（南方大道/西方迷霧森林 目前封鎖中）" % loc, "c": _panel.col_gold})
	rows.append({"t": "建議等級　東之森 " + _lv_range("forest") + "　森林深處 " + _lv_range("forest2") + "　礦山 " + _lv_range("mine") + "　洞穴 " + _lv_range("cave"), "x": 330, "y": 512, "c": _panel.col_accent})
	return "←→ 分頁　Esc 關閉"


# ---- 稱號分頁（L2135-2148）----
func _tab_titles(enter: bool, up: bool, down: bool, rows: Array) -> String:
	if up and sel > 0:
		sel -= 1
	if down and sel < TitlesData.ALL.size() - 1:
		sel += 1
	rows.append({"t": "── 稱號（Enter 佩戴）──", "c": _panel.col_accent})
	var eq_title := String(GameState.flags.get("eqTitle", ""))
	for i in TitlesData.ALL.size():
		var tt: Dictionary = TitlesData.ALL[i]
		var got := TitlesData.title_earned(String(tt["req"]))
		var tag := "【佩戴中】" if eq_title == tt["id"] else ""
		var body := (String(tt["name"]) + "　" + tag + "　— " + String(tt["desc"])) if got else ("？？？　— " + String(tt["hint"]))
		var row := {"t": ("▶ " if i == sel else "　 ") + body, "sel": i == sel}
		if not got:
			row["c"] = C_DIM2
		rows.append(row)
	if enter:
		var tt2: Dictionary = TitlesData.ALL[sel]
		if TitlesData.title_earned(String(tt2["req"])):
			# eqTitle 存 title id（String）——刻意直接寫 GameState.flags 容器，不走 flag_set（那會 int 化）。
			# 見任務報告「已知風險：eqTitle 型別」。
			GameState.flags["eqTitle"] = tt2["id"]
	return "↑↓ 選稱號　Enter 佩戴　←→ 分頁　Esc 關閉"


# ---- 系統分頁（L2149-2164）----
func _tab_system(enter: bool, up: bool, down: bool, rows: Array) -> String:
	if up and sel > 0:
		sel -= 1
		confirm_quit = false
	if down and sel < 1:
		sel += 1
	rows.append({"t": ("▶ " if sel == 0 else "　 ") + "操作說明", "sel": sel == 0})
	var quit_text := "回到標題畫面（再按一次 Enter 確認，進度不保存！）" if confirm_quit else "回到標題畫面"
	var quit_row := {"t": ("▶ " if sel == 1 else "　 ") + quit_text, "sel": sel == 1}
	if confirm_quit:
		quit_row["c"] = _panel.col_warn
	rows.append(quit_row)
	rows.append({"t": ""})
	rows.append({"t": "　方向鍵：移動　空白鍵：交談/推進對話", "c": C_HELP})
	rows.append({"t": "　M / Esc：選單　戰鬥：方向鍵+Enter 或 滑鼠點擊", "c": C_HELP})
	rows.append({"t": "　旅店（瑪琳家）與神殿可免費全恢復", "c": C_HELP})
	if enter and sel == 1:
		if not confirm_quit:
			confirm_quit = true
		else:
			_quit_to_title()
	return "↑↓ 選擇　Enter 執行　←→ 分頁　Esc 關閉"


func _quit_to_title() -> void:
	_close_menu()
	# 對應 build_cq2 replaceScene("Title")。SceneRouter（CORE-5）目前仍是 stub，直接換場景到標題。
	get_tree().change_scene_to_file("res://scenes/title/title.tscn")


# =========================================================================
# 輔助函式（對應 build_cq2 同名工具函式）
# =========================================================================
func _cls_name(m: Dictionary) -> String:
	var cls := String(m.get("cls", ""))
	return String(CLS_NAME.get(cls, cls))


## 對應 eqDesc()（L1850-1854）：依 EQSTAT_N 順序列出非零屬性加成。
func _eq_desc(e: EquipmentDef) -> String:
	var out: Array = []
	for k in EQSTAT_N.keys():
		var v := e.get_stat(k)
		if v != 0.0:
			out.append(String(EQSTAT_N[k]) + "+" + _num(v))
	return " ".join(out)


## 對應 skillList()（L1347-1352）：CONTENT.skills 順序中、該成員已學（sk[id] 為真）的技能。
func _skill_list(m: Dictionary) -> Array:
	var out: Array = []
	var sk: Dictionary = m.get("sk", {})
	for s in ContentDB.get_all_skills():
		if int(sk.get(s.id, 0)) > 0:
			out.append(s)
	return out


func _skill_max_lv() -> int:
	return int(ContentDB.get_derived().skill_max_lv)


## 對應 skPow()（L1848）：1 + skillPowerPerLv*((slv||1)-1)。
func _sk_pow(slv: int) -> float:
	return 1.0 + ContentDB.get_derived().skill_power_per_lv * float(max(slv, 1) - 1)


func _slot_type(slot: String) -> String:
	return "acc" if (slot == "acc1" or slot == "acc2") else slot


func _slot_label(sk: String) -> String:
	for pair in SLOTS:
		if pair[0] == sk:
			return pair[1]
	return sk


## 對應 accSlotFor()（L1837-1838）：飾品自動找空的 acc1/acc2，其他部位照原 slot。
func _acc_slot_for(m: Dictionary, it: EquipmentDef) -> String:
	if it.slot != "acc":
		return it.slot
	var eq: Dictionary = m.get("eq", {})
	if String(eq.get("acc1", "")) == "":
		return "acc1"
	if String(eq.get("acc2", "")) == "":
		return "acc2"
	return "acc1"


## 對應 cycleEq()（L1855-1873）：卸下 + 背包同部位裝備 依 id 排序組成穩定環，Enter 沿環前進。
func _cycle_eq(m: Dictionary, slot: String) -> bool:
	var tp := _slot_type(slot)
	var inv: Array = GameState.eq_inv
	var cur = m.get("eq", {}).get(slot, null)
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
	var next = ring[(cur_idx + 1) % ring.size()]
	if next == cur:
		return false
	if cur != null:
		inv.append(cur)
	if next != null:
		inv.erase(next)
		if not m.has("eq"):
			m["eq"] = {}
		m["eq"][slot] = next
	else:
		m.get("eq", {}).erase(slot)
	return true


func _equip_sort(a, b) -> bool:
	var ea: EquipmentDef = ContentDB.get_equipment(String(a))
	var eb: EquipmentDef = ContentDB.get_equipment(String(b))
	var da := int(SORD.get(ea.slot, 9))
	var db := int(SORD.get(eb.slot, 9))
	if da != db:
		return da < db
	return String(a) < String(b)


func _lv_range(k: String) -> String:
	var mp: Dictionary = ContentDB.get_pacing().get_map(k)
	if mp.is_empty():
		return "—"
	return "Lv" + str(mp.get("entryLv", 0)) + "-" + str(mp.get("targetLv", 0))


## 整數化顯示（build_cq2 的數值多為整數 JS number；float 剛好整數時去掉小數點）。
func _num(v) -> String:
	var f := float(v)
	if is_equal_approx(f, round(f)):
		return str(int(round(f)))
	return str(f)
