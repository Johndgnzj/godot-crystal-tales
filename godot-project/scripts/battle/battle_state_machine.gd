extends Node2D
## MOD-E　戰鬥系統主狀態機（specs/BATTLE_FORMULAS.md F-3~F-9、TASKS/05_戰鬥ATB.md）。
##
## 對應 build_cq2.py BATTLE_JS 全段的 ATB 主狀態機（L2708 起）＋ `initB()`（L2842）／`openCmd()`
## （L2829）／`applyOne()`（L2961）／`applyAll()`（L3002）／`foeAct()`（L3019）／`checkEnd()`
## （L3084）／`back()`（L2819）。狀態值對應 `b.state`：
##
##   run　　　　── ATB 蓄力中，等待任一單位蓄滿（見 atb.gd）
##   anim　　　── 演出/訊息停留（含 initB() 開場、每次行動後的短暫停頓）
##   menu　　　── 英雄指令選單（攻/技/道/防禦/逃）
##   skill　　　── 選技能
##   item　　　── 選道具
##   target　　── 選攻擊目標（敵方）
##   target_ally ── 選治療/道具對象（我方）
##   win / lose ── 結算畫面，等待玩家確認後呼叫 SceneRouter.battle_result()
##
## **`target_ally` 說明**：TASKS/05_戰鬥ATB.md 列出的狀態清單只寫了
## run/anim/menu/target/skill/item/win/lose 八種，沒有列這一種。回 build_cq2.py 核對後發現治療技能
## 與道具都需要選我方目標（L2762「else if(sk.target==="ally")b.state="target_ally"」、
## L2780「b.state="target_ally"」），原始碼確實有這個獨立狀態，這裡照原始碼補上，不是自創需求——
## 沒有它，治療技能/補血道具就選不了對象。
##
## 我方戰鬥數值一律用 MOD-F 的 `Derive.derive()` 算（不自己重算，見 `_init_battle()`）。
## 傷害/治療/機率算式全部委派給 `damage_calc.gd`（F-3~F-6、F-8）／`atb.gd`（F-7）／
## `exp_scale.gd`（F-9）／`auto_battle.gd`（自動戰鬥）。
##
## ## 資料形狀
##
## `heroes`：`GameState.party` 前 4 名成員的深複製 + `Derive.derive()` 處理結果 + 戰鬥暫態欄位
## （`side`/`slot`/`alive`/`atb`/`defending`）。**深複製**是刻意設計——battle 內的傷害/升級變動不會
## 直接寫回 `GameState.party`，要等 `_sync_party_to_game_state()`（對應原始碼 `saveParty()`，只在
## 逃跑成功／獲勝時呼叫）或 `_settle_lose()`（戰敗：捨棄本場戰鬥所有變動，只把血量/魔力重置滿，其餘
## 完全比照戰前狀態，對應原始碼 `checkEnd()` 的 `ha===0` 分支重新從 `g_party` 讀一份全新的）才會真的
## 影響 `GameState.party`。
##
## `foes`：由 `ContentDB.get_enemy(id)` 建構出的 Dictionary，欄位刻意跟 heroes **不**共用「hero 專屬」
## 欄位（沒有 `attrs`/`patk`/`pdef`/... 這些 key）——`damage_calc.gd`/`atb.gd` 到處用
## `dict.has("attrs")` 判斷角色 vs 敵人，跟 build_cq2.py 的 `att.attrs ? X : Y` 寫法對應，這裡的欄位
## 形狀差異是刻意的，不要為了「統一」而幫 foes 補上空的 `attrs:{}`。
##
## ## UI 現況
##
## MOD-D（選單/HUD 美術）尚未開工，本檔案用 `battle.tscn` 裡最簡陋的 Label/ProgressBar 頂著（見
## TASKS/11_並行協作規則.md「MOD-A 若比 MOD-D 早完工，可先做最簡陋版本頂著」同款先例）。之後 MOD-D
## 換裝時只需要重寫 `_build_ui_rows()`/`_refresh_ui()` 與 `battle.tscn` 的節點，狀態機/戰鬥邏輯
## （`_process_*`/`_apply_*`/`_foe_act`/`_check_end` 等）不需要跟著改。
##
## 目前只支援鍵盤操作（`InputBridge` 的 `ui_up`/`ui_down`/`ui_left`/`ui_right`/`ui_accept`/
## `ui_cancel`/`battle_auto`），沒有做觸控/滑鼠點擊命中判定（原始碼的 `clickOn()` 那一套）——
## 這也是 MOD-D 換裝時要一併補的項目，記錄在 TASKS/05_戰鬥ATB.md「已知風險」。


# =========================================================================
# 戰鬥狀態
# =========================================================================

var state: String = "run"
var heroes: Array = []
var foes: Array = []
var front_row: Array = []   ## 純視覺分組，不影響任何傷害/命中規則，見 _init_battle() 內註解
var back_row: Array = []

var actor: Variant = null   ## Dictionary or null，目前行動中的英雄（對應 b.actor）
var pend: Variant = null    ## Dictionary or null，{t:"atk"/"skill"/"item", sk?, item?}（對應 b.pend）

var sel: int = 0     ## 指令選單游標（0~4：攻/技/道/防禦/逃）
var s_sel: int = 0   ## 技能選單游標
var i_sel: int = 0   ## 道具選單游標
var t_sel: int = 0   ## 選標游標

var anim_t: float = 0.0
var msg: String = ""

var enc: String = ""
var scripted: bool = false
var survive_acts: int = 3
var acted: int = 0
var story_end: bool = false

var win_msg: String = ""
var end_state: String = ""

var _hero_rows: Array = []
var _foe_rows: Array = []


func _ready() -> void:
	_init_battle()


func _process(delta: float) -> void:
	_handle_auto_toggle()
	match state:
		"run":
			_process_run(delta)
		"anim":
			_process_anim(delta)
		"menu":
			_process_menu()
		"skill":
			_process_skill()
		"item":
			_process_item()
		"target":
			_process_target()
		"target_ally":
			_process_target_ally()
		"win", "lose":
			_process_end()
	_refresh_ui()


# =========================================================================
# 初始化（對應 initB()，build_cq2.py L2842-2882）
# =========================================================================

func _init_battle() -> void:
	enc = GameState.encounter
	if enc == "":
		enc = "forest"

	var encounter_def: EncounterDef = ContentDB.get_encounter(enc)
	if encounter_def == null or encounter_def.formations.is_empty():
		encounter_def = ContentDB.get_encounter("forest")
	var group: Array = []
	if encounter_def != null and not encounter_def.formations.is_empty():
		group = encounter_def.formations[randi() % encounter_def.formations.size()]

	scripted = (enc == "prologue_demon")
	survive_acts = 3
	acted = 0

	heroes.clear()
	for i in range(mini(GameState.party.size(), 4)):
		var src = GameState.party[i]
		if typeof(src) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = (src as Dictionary).duplicate(true)
		Derive.derive(m)
		m["side"] = "hero"
		m["slot"] = i
		m["alive"] = float(m.get("hp", 0)) > 0.0
		m["atb"] = randf() * Atb.HERO_INITIAL_ATB_MAX   # see specs/BATTLE_FORMULAS.md F-7
		m["defending"] = false
		heroes.append(m)

	foes.clear()
	for i in range(mini(group.size(), 4)):
		var eid := String(group[i])
		var ed: EnemyDef = ContentDB.get_enemy(eid)
		if ed == null:
			continue
		foes.append({
			"id": ed.id,
			"name": ed.display_name,
			"sprite": ed.sprite,
			"hp": ed.hp,
			"maxhp": ed.hp,
			"atk": ed.atk,
			"def": ed.def_stat,
			"spd": ed.spd,
			"exp": ed.exp,
			"gold": ed.gold,
			"big": ed.big,
			"healer": ed.healer,
			"allAttack": ed.all_attack,
			"foeSkills": ed.foe_skills,
			"drops": ed.drops,
			"side": "foe",
			"slot": i,
			"alive": true,
			"atb": randf() * Atb.FOE_INITIAL_ATB_MAX,   # see specs/BATTLE_FORMULAS.md F-7
		})

	# 陣型：前排／後排。純視覺分組，供 UI 排版用——build_cq2.py L2864-2868 的 frontRow/backRow
	# 只用在 layout() 算座標，沒有任何地方拿它判斷傷害/目標選取，這裡忠實保留同一套規則，供 MOD-D
	# 換裝時直接沿用 foe["row"] 欄位排版，不代表這個模組本身需要它來算傷害。
	front_row.clear()
	back_row.clear()
	for f in foes:
		if bool(f.get("big", false)):
			back_row.append(f)
		else:
			front_row.append(f)
	while front_row.size() > 2 and front_row.size() > back_row.size() + 1:
		back_row.append(front_row.pop_back())
	for f in foes:
		f["row"] = "back" if back_row.has(f) else "front"

	state = "anim"
	anim_t = 1.0
	story_end = false
	win_msg = ""
	msg = "異變的魔影擋在面前……撐過牠的 3 次攻擊！" if scripted else "遭遇敵人！行動條蓄滿即可下令"
	sel = 0
	s_sel = 0
	i_sel = 0
	t_sel = 0

	_build_ui_rows()


# =========================================================================
# 自動戰鬥開關（對應 build_cq2.py L2702-2706）
# =========================================================================

func _handle_auto_toggle() -> void:
	if state == "win" or state == "lose":
		return
	if InputBridge.is_action_hit("battle_auto"):
		var enabled := AutoBattle.toggle()
		_banner("自動戰鬥：" + ("開啟──我方自動普攻" if enabled else "關閉"))
		if enabled and state == "menu" and actor != null:
			_auto_attack(actor)


# =========================================================================
# run（ATB 蓄力，F-7）
# =========================================================================

func _process_run(delta: float) -> void:
	Atb.tick(heroes + foes, delta)
	var ready_hero = Atb.find_ready_hero(heroes)
	if ready_hero != null:
		_open_cmd(ready_hero)
	else:
		var ready_foe = Atb.find_ready_foe(foes)
		if ready_foe != null:
			_foe_act(ready_foe)


func _open_cmd(h: Dictionary) -> void:
	h["defending"] = false
	if AutoBattle.is_enabled() and _auto_attack(h):
		return
	state = "menu"
	actor = h
	sel = 0
	_banner(String(h.get("name", "")) + " 的回合──選擇指令")


func _auto_attack(h: Dictionary) -> bool:
	var target = AutoBattle.pick_target(foes)
	if target == null:
		return false
	actor = h
	h["defending"] = false
	pend = {"t": "atk"}
	state = "target"
	t_sel = 0
	_apply_one([target])
	return true


# =========================================================================
# anim（演出/訊息停留，對應 b.state==="anim" 分支 L2722-2727）
# =========================================================================

func _process_anim(delta: float) -> void:
	anim_t -= delta
	if anim_t <= 0.0:
		if story_end:
			_sync_party_to_game_state()
			SceneRouter.battle_result("story")
			return
		if not _check_end():
			state = "run"


# =========================================================================
# menu（英雄指令選單，對應 L2728-2746）
# =========================================================================

func _process_menu() -> void:
	if InputBridge.is_action_hit("ui_left"):
		sel = (sel + 4) % 5
	if InputBridge.is_action_hit("ui_right"):
		sel = (sel + 1) % 5
	if InputBridge.is_action_hit("ui_up") or InputBridge.is_action_hit("ui_down"):
		# 原始碼不分上/下，兩者做同一個「切換到另一排」映射（L2732）：0,1,2 是上排，3,4 是下排。
		sel = (sel - 3) if sel >= 3 else mini(4, sel + 3)
	if InputBridge.is_action_hit("ui_accept"):
		_pick_menu(sel)


func _pick_menu(pick: int) -> void:
	if pick == 0:
		pend = {"t": "atk"}
		state = "target"
		t_sel = 0
	elif pick == 1:
		state = "skill"
		s_sel = 0
	elif pick == 2:
		state = "item"
		i_sel = 0
	elif pick == 3:
		actor["defending"] = true
		_banner(String(actor.get("name", "")) + " 擺出防禦姿態（物理傷害減半）")
		_end_action(0.45)
	elif pick == 4:
		# 逃跑成功條件：不是 scripted 戰鬥，也不是 ch1_boss（見 specs/BATTLE_FORMULAS.md 抄錄自
		# build_cq2.py L2744：這兩個條件是 && 短路，任一為真直接判定失敗，連機率都不擲）。
		var can_flee: bool = (not scripted) and enc != "ch1_boss"
		if can_flee and randf() < 0.7:
			_sync_party_to_game_state()
			SceneRouter.battle_result("flee")
			return
		_banner(String(actor.get("name", "")) + " 想逃跑，但是失敗了！")
		_end_action(0.6)


# =========================================================================
# skill（選技能，對應 L2747-2765）
# =========================================================================

func _process_skill() -> void:
	var sl := _skills_for(actor)
	if InputBridge.is_action_hit("ui_up") and s_sel > 0:
		s_sel -= 1
	if InputBridge.is_action_hit("ui_down") and s_sel < sl.size() - 1:
		s_sel += 1
	if InputBridge.is_action_hit("ui_cancel"):
		state = "menu"
		return
	if InputBridge.is_action_hit("ui_accept") and s_sel < sl.size():
		var sk: SkillDef = sl[s_sel]
		if float(actor.get("mp", 0)) < float(sk.mp):
			_banner("MP 不足！")
		else:
			pend = {"t": "skill", "sk": sk}
			t_sel = 0
			if sk.target == "enemy":
				state = "target"
			elif sk.target == "ally":
				state = "target_ally"
			else:
				_apply_all(sk)


func _skills_for(m: Dictionary) -> Array:
	# 對應 skillsFor()，L2663-2668：依 C.skills 原始順序，篩出 m.sk 裡有記錄的技能。
	var out: Array = []
	var sk_table: Dictionary = m.get("sk", {})
	for skill in ContentDB.get_all_skills():
		var sd: SkillDef = skill
		if sk_table.get(sd.id, 0):
			out.append(sd)
	return out


# =========================================================================
# item（選道具，對應 L2766-2781）
# =========================================================================

func _process_item() -> void:
	var items := _battle_items()
	if i_sel >= items.size():
		i_sel = maxi(0, items.size() - 1)
	if InputBridge.is_action_hit("ui_up") and i_sel > 0:
		i_sel -= 1
	if InputBridge.is_action_hit("ui_down") and i_sel < items.size() - 1:
		i_sel += 1
	if InputBridge.is_action_hit("ui_cancel"):
		state = "menu"
		return
	if InputBridge.is_action_hit("ui_accept"):
		if items.is_empty():
			_banner("沒有可用的道具！")
			return
		var picked: Dictionary = items[i_sel]
		var meta: ItemDef = picked["meta"]
		if not DamageCalc.item_usable_in_battle(meta):
			_banner(meta.display_name + " 無法在戰鬥中使用")
			return
		pend = {"t": "item", "item": picked["id"]}
		state = "target_ally"
		t_sel = 0


func _battle_items() -> Array:
	# 對應 battleItems()，L2634-2639：依 C.items 原始順序，篩出背包裡數量 > 0 的 consumable。
	var out: Array = []
	for item in ContentDB.get_all_items():
		var it: ItemDef = item
		if it.cat == "consumable":
			var n: int = GameState.inv_get(it.id)
			if n > 0:
				out.append({"id": it.id, "n": n, "meta": it})
	return out


# =========================================================================
# target / target_ally（選目標，對應 L2782-2811）
# =========================================================================

func _process_target() -> void:
	var alive: Array = foes.filter(func(u): return bool(u.get("alive", false)))
	if alive.is_empty():
		if InputBridge.is_action_hit("ui_cancel"):
			state = "menu"
		return
	if InputBridge.is_action_hit("ui_up") or InputBridge.is_action_hit("ui_left"):
		t_sel = (t_sel + alive.size() - 1) % alive.size()
	if InputBridge.is_action_hit("ui_down") or InputBridge.is_action_hit("ui_right"):
		t_sel = (t_sel + 1) % alive.size()
	if InputBridge.is_action_hit("ui_cancel"):
		state = "menu"
		return
	if InputBridge.is_action_hit("ui_accept"):
		var chosen: Dictionary = alive[t_sel % alive.size()]
		_apply_one([chosen])


func _process_target_ally() -> void:
	var alive: Array = heroes.filter(func(u): return bool(u.get("alive", false)))
	if alive.is_empty():
		if InputBridge.is_action_hit("ui_cancel"):
			state = "menu"
		return
	if InputBridge.is_action_hit("ui_up") or InputBridge.is_action_hit("ui_left"):
		t_sel = (t_sel + alive.size() - 1) % alive.size()
	if InputBridge.is_action_hit("ui_down") or InputBridge.is_action_hit("ui_right"):
		t_sel = (t_sel + 1) % alive.size()
	if InputBridge.is_action_hit("ui_cancel"):
		state = "menu"
		return
	if InputBridge.is_action_hit("ui_accept"):
		var chosen: Dictionary = alive[t_sel % alive.size()]
		_apply_one([chosen])


# =========================================================================
# 行動執行（對應 applyOne() L2961-3001 / applyAll() L3002-3018）
# =========================================================================

func _apply_one(ts: Array) -> void:
	var a: Dictionary = actor
	var pd: Dictionary = pend
	var t: Dictionary = ts[0]
	var msg_out := ""

	if pd["t"] == "atk":
		if DamageCalc.is_dodge(a, t):
			msg_out = String(t.get("name", "")) + " 靈巧地閃開了！"
		else:
			var r := DamageCalc.phys_damage(a, t)
			t["hp"] = float(t.get("hp", 0)) - float(r["dmg"])
			msg_out = String(a.get("name", "")) + " 攻擊 " + String(t.get("name", "")) + "，造成 " \
				+ str(r["dmg"]) + " 傷害" + ("（會心！）" if r["crit"] else "")
			_kill(t)

	elif pd["t"] == "skill":
		var sk: SkillDef = pd["sk"]
		a["mp"] = float(a.get("mp", 0)) - float(sk.mp)
		var actor_sk: Dictionary = a.get("sk", {})
		var slv: int = int(actor_sk.get(sk.id, 1))
		var sk_tag := "「" + sk.display_name + (" Lv" + str(slv) if slv > 1 else "") + "」"
		if sk.kind == "damage":
			var dmg := DamageCalc.skill_damage(a, t, sk)
			t["hp"] = float(t.get("hp", 0)) - dmg
			msg_out = String(a.get("name", "")) + sk_tag + "！" + String(t.get("name", "")) \
				+ " 受到 " + str(dmg) + " 傷害"
			_kill(t)
		else:
			var heal := DamageCalc.skill_heal(a, sk)
			var before: float = float(t.get("hp", 0))
			t["hp"] = minf(float(t.get("maxhp", 0)), before + heal)
			msg_out = String(a.get("name", "")) + sk_tag + "！" + String(t.get("name", "")) \
				+ " 恢復 " + str(int(t["hp"] - before)) + " HP"

	elif pd["t"] == "item":
		var item_id: String = pd["item"]
		var meta: ItemDef = ContentDB.get_item(item_id)
		var kind := "heal"
		var power := 60
		var item_name := "藥水"
		if meta != null:
			var eff := DamageCalc.item_effect(meta)
			kind = eff["kind"]
			power = eff["power"]
			item_name = meta.display_name
		GameState.inv_use(item_id)
		if kind == "mp":
			var before_mp: float = float(t.get("mp", 0))
			t["mp"] = minf(float(t.get("maxmp", 0)), before_mp + power)
			msg_out = String(a.get("name", "")) + " 使用" + item_name + "！" + String(t.get("name", "")) \
				+ " 恢復 " + str(int(t["mp"] - before_mp)) + " MP"
		else:
			var before_hp: float = float(t.get("hp", 0))
			t["hp"] = minf(float(t.get("maxhp", 0)), before_hp + power)
			msg_out = String(a.get("name", "")) + " 使用" + item_name + "！" + String(t.get("name", "")) \
				+ " 恢復 " + str(int(t["hp"] - before_hp)) + " HP"

	_banner(msg_out)
	_end_action(0.75)


func _apply_all(sk: SkillDef) -> void:
	var a: Dictionary = actor
	a["mp"] = float(a.get("mp", 0)) - float(sk.mp)
	var list: Array = foes.filter(func(u): return bool(u.get("alive", false)))
	var tot := 0
	for f in list:
		var target: Dictionary = f
		var dmg := DamageCalc.skill_damage(a, target, sk)
		target["hp"] = float(target.get("hp", 0)) - dmg
		tot += dmg
		_kill(target)
	var actor_sk: Dictionary = a.get("sk", {})
	var slv: int = int(actor_sk.get(sk.id, 1))
	_banner(String(a.get("name", "")) + "「" + sk.display_name + (" Lv" + str(slv) if slv > 1 else "") \
		+ "」橫掃全體敵人！共 " + str(tot) + " 傷害")
	_end_action(0.8)


func _end_action(t: float) -> void:
	if actor != null:
		Atb.reset(actor)
	actor = null
	pend = null
	state = "anim"
	anim_t = t


# =========================================================================
# 敵人行動（對應 foeAct()，L3019-3068；精確算式見 specs/BATTLE_FORMULAS.md F-8 v1.1）
# =========================================================================

func _foe_act(a: Dictionary) -> void:
	Atb.reset(a)
	if scripted:
		acted += 1

	# 第 1 段：healer
	if bool(a.get("healer", false)):
		var low: Array = foes.filter(func(u):
			return bool(u.get("alive", false)) \
				and float(u.get("hp", 0)) < float(u.get("maxhp", 0)) * 0.55 \
				and u != a
		)
		if not low.is_empty():
			var t2: Dictionary = low[0]
			var heal := DamageCalc.foe_heal_amount()
			t2["hp"] = minf(float(t2.get("maxhp", 0)), float(t2.get("hp", 0)) + heal)
			_banner(String(a.get("name", "")) + " 治療了 " + String(t2.get("name", "")) + "（+" + str(heal) + " HP）")
			_finish_foe()
			return

	var alive: Array = heroes.filter(func(u): return bool(u.get("alive", false)))
	if alive.is_empty():
		_check_end()
		return

	# 第 2 段：具名技能（40%）
	var foe_skills: Array = a.get("foeSkills", [])
	if not foe_skills.is_empty() and randf() < 0.4:
		var fsk: Dictionary = foe_skills[randi() % foe_skills.size()]
		var mult: float = float(fsk.get("mult", 1.0))
		if String(fsk.get("target", "")) == "all":
			var tot := 0
			for h in alive:
				var hero: Dictionary = h
				var r := DamageCalc.foe_named_skill_damage(a, hero, mult)
				hero["hp"] = float(hero.get("hp", 0)) - float(r["dmg"])
				tot += r["dmg"]
				_kill(hero)
			_banner(String(a.get("name", "")) + " 使出【" + String(fsk.get("name", "")) + "】！全體共受到 " + str(tot) + " 傷害")
			_finish_foe()
			return
		else:
			var t3: Dictionary = alive[randi() % alive.size()]
			if DamageCalc.is_dodge(a, t3):
				_banner(String(t3.get("name", "")) + " 閃開了 " + String(a.get("name", "")) + " 的【" + String(fsk.get("name", "")) + "】！")
				_finish_foe()
				return
			var r2 := DamageCalc.foe_named_skill_damage(a, t3, mult)
			t3["hp"] = float(t3.get("hp", 0)) - float(r2["dmg"])
			_kill(t3)
			_banner(String(a.get("name", "")) + " 使出【" + String(fsk.get("name", "")) + "】，對 " + String(t3.get("name", "")) \
				+ " 造成 " + str(r2["dmg"]) + " 傷害" + ("（會心！）" if r2["crit"] else ""))
			_finish_foe()
			return

	# 第 3 段：allAttack（30%，只在第 2 段沒觸發時才擲）
	if bool(a.get("allAttack", false)) and randf() < 0.3:
		var tot2 := 0
		for h in alive:
			var hero2: Dictionary = h
			var r3 := DamageCalc.phys_damage(a, hero2)
			hero2["hp"] = float(hero2.get("hp", 0)) - float(r3["dmg"])
			tot2 += r3["dmg"]
			_kill(hero2)
		_banner(String(a.get("name", "")) + " 的橫掃攻擊！全體共受到 " + str(tot2) + " 傷害")
		_finish_foe()
		return

	# 第 4 段：一般單體攻擊（fallback）
	var t: Dictionary = alive[randi() % alive.size()]
	if DamageCalc.is_dodge(a, t):
		_banner(String(t.get("name", "")) + " 靈巧地閃開了 " + String(a.get("name", "")) + " 的攻擊！")
		_finish_foe()
		return
	var r4 := DamageCalc.phys_damage(a, t)
	t["hp"] = float(t.get("hp", 0)) - float(r4["dmg"])
	_kill(t)
	_banner(String(a.get("name", "")) + " 攻擊 " + String(t.get("name", "")) + "，造成 " + str(r4["dmg"]) + " 傷害" \
		+ ("（會心！）" if r4["crit"] else "") + ("（防禦中）" if bool(t.get("defending", false)) else ""))
	_finish_foe()


func _finish_foe() -> void:
	if scripted and acted >= survive_acts:
		story_end = true
	state = "anim"
	anim_t = 0.75


func _kill(u: Dictionary) -> void:
	if float(u.get("hp", 0)) <= 0.0:
		u["hp"] = 0
		if scripted and String(u.get("side", "")) == "hero":
			u["hp"] = 1   # scripted 戰鬥（序章強制戰）英雄不會真的死，對應 kill() L2958-2960
			return
		u["alive"] = false


func _banner(m: String) -> void:
	msg = m


# =========================================================================
# 勝敗結算（對應 checkEnd()，L3084-3145）
# =========================================================================

func _check_end() -> bool:
	if scripted:
		return false
	var ha := heroes.filter(func(u): return bool(u.get("alive", false))).size()
	var fa := foes.filter(func(u): return bool(u.get("alive", false))).size()

	if fa == 0:
		_settle_win()
		return true
	if ha == 0:
		_settle_lose()
		return true
	return false


func _settle_win() -> void:
	var raw_exp := 0
	var gold := 0
	for f in foes:
		raw_exp += int(f.get("exp", 0))
		gold += int(f.get("gold", 0))

	# see specs/BATTLE_FORMULAS.md F-9（EXPSCALE 現場計算，見 exp_scale.gd 檔頭說明）
	var scale := ExpScale.compute(enc)
	var exp := maxi(1, int(roundf(float(raw_exp) * scale)))

	GameState.gold += gold

	var members: Array = heroes.filter(func(h2): return not bool(h2.get("guest", false)))
	var each := int(ceil(float(exp) / float(maxi(1, members.size()))))
	var gain: Array = []
	var any_up := false
	var d: DerivedParams = ContentDB.get_derived()

	for h in members:
		var m: Dictionary = h
		m["exp"] = int(m.get("exp", 0)) + each
		var ups := 0
		var learned: Array = []
		while int(m["exp"]) >= ExpNeed.exp_need(int(m.get("lv", 1))):
			m["exp"] = int(m["exp"]) - ExpNeed.exp_need(int(m.get("lv", 1)))
			m["lv"] = int(m.get("lv", 1)) + 1
			ups += 1
			var tmpl: PartyMemberDef = ContentDB.get_party_member(String(m.get("id", "")))
			var growth: Dictionary = tmpl.growth if tmpl != null else {}
			var attrs: Dictionary = m.get("attrs", {})
			attrs["str"] = float(attrs.get("str", 0)) + float(growth.get("str", 0))
			attrs["agi"] = float(attrs.get("agi", 0)) + float(growth.get("agi", 0))
			attrs["int"] = float(attrs.get("int", 0)) + float(growth.get("int", 0))
			m["attrs"] = attrs
			m["pts"] = int(m.get("pts", 0)) + int(d.points_per_level)
			m["spts"] = int(m.get("spts", 0)) + int(d.skill_points_per_level)
			var sk_table: Dictionary = m.get("sk", {})
			for skill in ContentDB.get_all_skills():
				var sd: SkillDef = skill
				if sd.char_class == String(m.get("cls", "")) and sd.unlock_lv == int(m["lv"]) and not sk_table.get(sd.id, 0):
					sk_table[sd.id] = 1
					learned.append(sd.display_name)
			m["sk"] = sk_table
			Derive.derive(m)
			m["hp"] = m["maxhp"]
			m["mp"] = m["maxmp"]
		if ups > 0:
			any_up = true
			var line := String(m.get("name", "")) + " 升級 Lv" + str(m["lv"]) + "！"
			if not learned.is_empty():
				line += "　習得『" + "』『".join(PackedStringArray(learned)) + "』！"
			gain.append(line)

	_sync_party_to_game_state()

	var drop_count: Dictionary = {}
	for f in foes:
		var drops: Array = f.get("drops", [])
		for drop in drops:
			var dd: Dictionary = drop
			if randf() < float(dd.get("rate", 0.0)):
				var did := String(dd.get("id", ""))
				drop_count[did] = int(drop_count.get(did, 0)) + 1
	var drop_names: Array = []
	for did: String in drop_count.keys():
		GameState.inv_add(did, drop_count[did])
		var item_def: ItemDef = ContentDB.get_item(did)
		var dnm := item_def.display_name if item_def != null else did
		drop_names.append(dnm + (" ×" + str(drop_count[did]) if drop_count[did] > 1 else ""))
	var drop_msg := ""
	if not drop_names.is_empty():
		drop_msg = "\n獲得道具：「" + "」「".join(PackedStringArray(drop_names)) + "」"

	# 特殊戰役獎勵（對應 checkEnd() L3124-3129，寫死的兩場劇情 boss 戰）
	if enc == "ch1_boss":
		GameState.flag_set("ch1", 2)
		GameState.eq_inv.append("leather_vest")
		GameState.eq_inv.append("hunter_bracer")
		drop_msg += "\n獲得『皮革護胸』『獵人護腕』！（選單→裝備 分頁）"
	if enc == "ch2_bear":
		GameState.flag_set("ch2", 2)
		GameState.eq_inv.append("swift_boots")
		drop_msg += "\n擊退了狂暴洞熊！獲得『疾風靴』！崩塌的礦道鬆動了……"

	win_msg = "獲得 " + str(exp) + " 經驗值 · " + str(gold) + " 金幣" + drop_msg
	if not gain.is_empty():
		win_msg += "\n" + "\n".join(PackedStringArray(gain))
	if any_up:
		win_msg += "\n（獲得屬性點與技能點——在選單→角色 分配）"

	end_state = "win"
	state = "win"


func _settle_lose() -> void:
	# 對應 checkEnd() 的 ha===0 分支：捨棄本場戰鬥所有變動，直接從（未被本場戰鬥碰過的）
	# GameState.party 重新 derive 一份、血/魔滿血，不使用 heroes（本場戰鬥的深複製）。
	for m in GameState.party:
		if typeof(m) == TYPE_DICTIONARY:
			Derive.derive(m)
			m["hp"] = m["maxhp"]
			m["mp"] = m["maxmp"]
	win_msg = "隊伍全滅……被送回了鎮上"
	end_state = "lose"
	state = "lose"


## 對應 saveParty()（L3073-3083）：只把 hp/mp/lv/exp/pts/spts/sk/eq/attrs 這 9 個欄位寫回
## GameState.party 裡 id 相同的既有項目，**不寫回**衍生屬性（maxhp/patk/...），維持
## 「GameState.party 不內建衍生屬性」的既有約定（見 game_state.gd 檔頭）。
func _sync_party_to_game_state() -> void:
	for h in heroes:
		var hero: Dictionary = h
		for i in range(GameState.party.size()):
			var m = GameState.party[i]
			if typeof(m) == TYPE_DICTIONARY and m.get("id") == hero.get("id"):
				m["hp"] = maxi(1, int(hero.get("hp", 0)))
				m["mp"] = hero.get("mp", 0)
				m["lv"] = hero.get("lv", 1)
				m["exp"] = hero.get("exp", 0)
				m["pts"] = hero.get("pts", 0)
				m["spts"] = hero.get("spts", 0)
				m["sk"] = hero.get("sk", {})
				m["eq"] = hero.get("eq", {})
				m["attrs"] = hero.get("attrs", {})
				break


func _process_end() -> void:
	if InputBridge.is_action_hit("ui_accept"):
		# SceneRouter.battle_result() 內建 "lose" -> Town/shrine 的覆寫規則，這裡不用重複判斷。
		SceneRouter.battle_result(state)


# =========================================================================
# UI（最簡陋 Label/ProgressBar 版本，MOD-D 之後換裝，見檔頭「UI 現況」）
# =========================================================================

@onready var _ui_banner: Label = $UI/Banner
@onready var _ui_boss_name: Label = $UI/BossName
@onready var _ui_boss_hp: ProgressBar = $UI/BossHpBar
@onready var _ui_hero_list: VBoxContainer = $UI/HeroList
@onready var _ui_foe_list: VBoxContainer = $UI/FoeList
@onready var _ui_cmd_menu: VBoxContainer = $UI/CmdMenu
@onready var _ui_skill_menu: VBoxContainer = $UI/SkillMenu
@onready var _ui_item_menu: VBoxContainer = $UI/ItemMenu
@onready var _ui_target_hint: Label = $UI/TargetHint
@onready var _ui_auto_label: Label = $UI/AutoLabel
@onready var _ui_result_panel: Control = $UI/ResultPanel
@onready var _ui_result_title: Label = $UI/ResultPanel/ResultTitle
@onready var _ui_result_msg: Label = $UI/ResultPanel/ResultMsg
@onready var _ui_result_hint: Label = $UI/ResultPanel/ContHint


func _build_ui_rows() -> void:
	for c in _ui_hero_list.get_children():
		c.queue_free()
	for c in _ui_foe_list.get_children():
		c.queue_free()
	_hero_rows.clear()
	_foe_rows.clear()

	for h in heroes:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(360, 0)
		row.add_child(name_label)
		var hp_bar := ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(120, 16)
		hp_bar.show_percentage = false
		row.add_child(hp_bar)
		var atb_bar := ProgressBar.new()
		atb_bar.custom_minimum_size = Vector2(120, 16)
		atb_bar.show_percentage = false
		row.add_child(atb_bar)
		_ui_hero_list.add_child(row)
		_hero_rows.append({"unit": h, "name": name_label, "hp": hp_bar, "atb": atb_bar})

	for f in foes:
		var frow := HBoxContainer.new()
		var fname := Label.new()
		fname.custom_minimum_size = Vector2(220, 0)
		frow.add_child(fname)
		var fhp := ProgressBar.new()
		fhp.custom_minimum_size = Vector2(120, 12)
		fhp.show_percentage = false
		frow.add_child(fhp)
		_ui_foe_list.add_child(frow)
		_foe_rows.append({"unit": f, "name": fname, "hp": fhp})


func _refresh_ui() -> void:
	_ui_banner.text = msg

	for row in _hero_rows:
		var h: Dictionary = row["unit"]
		var alive := bool(h.get("alive", false))
		var maxhp := maxf(1.0, float(h.get("maxhp", 1)))
		var maxmp := maxf(1.0, float(h.get("maxmp", 1)))
		var hp := float(h.get("hp", 0))
		var mp := float(h.get("mp", 0))
		var atb := float(h.get("atb", 0))
		var name_lbl: Label = row["name"]
		name_lbl.text = "%s Lv%d%s  HP %d/%d  MP %d/%d" % [
			String(h.get("name", "")), int(h.get("lv", 1)),
			("〔防〕" if bool(h.get("defending", false)) else ""),
			int(maxf(0.0, hp)), int(maxhp), int(mp), int(maxmp)
		]
		if not alive:
			name_lbl.modulate = Color(0.47, 0.47, 0.51)
		elif actor == h:
			name_lbl.modulate = Color(1.0, 0.96, 0.67)
		elif atb >= 100.0:
			name_lbl.modulate = Color(1.0, 0.88, 0.47)
		else:
			name_lbl.modulate = Color.WHITE
		var hp_bar: ProgressBar = row["hp"]
		hp_bar.max_value = maxhp
		hp_bar.value = clampf(hp, 0.0, maxhp)
		var atb_bar: ProgressBar = row["atb"]
		atb_bar.max_value = 100.0
		atb_bar.value = clampf(atb, 0.0, 100.0)

	var boss: Variant = null
	for row in _foe_rows:
		var f: Dictionary = row["unit"]
		var alive := bool(f.get("alive", false))
		var big := bool(f.get("big", false))
		if big and alive:
			boss = f
		var show_row := alive and not big
		row["name"].visible = show_row
		row["hp"].visible = show_row
		if show_row:
			row["name"].text = String(f.get("name", ""))
			var fmaxhp := maxf(1.0, float(f.get("maxhp", 1)))
			var hp_bar2: ProgressBar = row["hp"]
			hp_bar2.max_value = fmaxhp
			hp_bar2.value = clampf(float(f.get("hp", 0)), 0.0, fmaxhp)

	var is_end := state == "win" or state == "lose"
	var show_boss := boss != null and not is_end
	_ui_boss_name.visible = show_boss
	_ui_boss_hp.visible = show_boss
	if show_boss:
		var b: Dictionary = boss
		# see specs/BATTLE_FORMULAS.md F-8：Boss 血條只顯示「☠ 名稱」不露數字，血條本身仍會畫。
		_ui_boss_name.text = "☠ " + String(b.get("name", ""))
		var bmaxhp := maxf(1.0, float(b.get("maxhp", 1)))
		_ui_boss_hp.max_value = bmaxhp
		_ui_boss_hp.value = clampf(float(b.get("hp", 0)), 0.0, bmaxhp)

	var hero_turn := actor != null and String(actor.get("side", "")) == "hero"

	var show_cmd := hero_turn and state == "menu"
	_ui_cmd_menu.visible = show_cmd
	if show_cmd:
		var labels := ["攻擊", "技能", "道具", "防禦", "逃跑"]
		var children := _ui_cmd_menu.get_children()
		for i in range(mini(children.size(), labels.size())):
			var lbl: Label = children[i]
			lbl.text = ("▶ " if i == sel else "　") + labels[i]
			lbl.modulate = Color(1.0, 0.92, 0.47) if i == sel else Color.WHITE

	var show_skill := hero_turn and state == "skill"
	_ui_skill_menu.visible = show_skill
	if show_skill:
		var sl := _skills_for(actor)
		var actor_sk: Dictionary = actor.get("sk", {})
		var children2 := _ui_skill_menu.get_children()
		for i in range(children2.size()):
			var lbl2: Label = children2[i]
			if i < sl.size():
				var sd: SkillDef = sl[i]
				var slv := int(actor_sk.get(sd.id, 1))
				lbl2.visible = true
				lbl2.text = ("▶" if i == s_sel else "　") + sd.display_name + " Lv" + str(slv) + " (" + str(sd.mp) + "MP)"
				var affordable := float(actor.get("mp", 0)) >= float(sd.mp)
				if not affordable:
					lbl2.modulate = Color(0.47, 0.47, 0.51)
				elif i == s_sel:
					lbl2.modulate = Color(1.0, 0.92, 0.47)
				else:
					lbl2.modulate = Color.WHITE
			else:
				lbl2.visible = false

	var show_item := hero_turn and state == "item"
	_ui_item_menu.visible = show_item
	if show_item:
		var items := _battle_items()
		var children3 := _ui_item_menu.get_children()
		for i in range(children3.size()):
			var lbl3: Label = children3[i]
			if i < items.size():
				var it: Dictionary = items[i]
				var meta: ItemDef = it["meta"]
				lbl3.visible = true
				lbl3.text = ("▶" if i == i_sel else "　") + meta.display_name + " x" + str(it["n"])
				lbl3.modulate = Color.WHITE if DamageCalc.item_usable_in_battle(meta) else Color(0.47, 0.47, 0.51)
			elif i == 0 and items.is_empty():
				lbl3.visible = true
				lbl3.text = "（沒有可用的道具）"
				lbl3.modulate = Color(0.47, 0.47, 0.51)
			else:
				lbl3.visible = false

	_ui_target_hint.visible = state == "target" or state == "target_ally"
	if state == "target":
		_ui_target_hint.text = "選擇攻擊目標（←→ 切換、Enter 確定、Esc 返回）"
	elif state == "target_ally":
		_ui_target_hint.text = "選擇對象（←→ 切換、Enter 確定、Esc 返回）"

	_ui_auto_label.text = ("⚙ 自動:開" if AutoBattle.is_enabled() else "⚙ 自動:關") + "　[A]"

	_ui_result_panel.visible = is_end
	if is_end:
		_ui_result_title.text = "勝　利！" if state == "win" else "戰　敗"
		_ui_result_msg.text = win_msg
		_ui_result_hint.text = "繼續" if state == "win" else "回到鎮上"
