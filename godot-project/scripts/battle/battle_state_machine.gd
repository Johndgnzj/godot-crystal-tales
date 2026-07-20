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

var sel: int = 0     ## 指令選單游標（0~3：攻/技/道/逃——防禦已依 John 要求移除）
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
	AudioManager.play_bgm("bgm_battle.mp3")   # 對應 build_cq2.py L2870
	_init_battle()


func _process(delta: float) -> void:
	_view_time += delta
	if _lunge_unit != null:
		_lunge_t += delta
		if not _lunge_sfx_done and _lunge_t >= LUNGE_DUR * IMPACT_FRAC:
			for _s in _lunge_sfx:
				AudioManager.sfx(_s)
			_lunge_sfx_done = true
		if _lunge_t >= LUNGE_DUR:
			_lunge_unit = null
	if not _pending_hits.is_empty():
		_pending_hit_timer -= delta
		if _pending_hit_timer <= 0.0:
			_apply_pending_hits()   # 音效播完 → 扣血＋被打聲＋死亡判定
	if _shake_t > 0.0:
		_shake_t -= delta
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
		group = encounter_def.roll()   # 加權抽組＋數量展開＋上限截斷，see EncounterDef / F-11

	scripted = encounter_def != null and encounter_def.scripted_survive > 0
	survive_acts = encounter_def.scripted_survive if scripted else 3
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
	for i in range(mini(group.size(), FOE_SLOTS.size())):
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
			"luck": ed.luck,   # v4.0：敵方會心/抗爆/閃避加成（see specs/BATTLE_FORMULAS.md F-1）
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
	msg = ("強敵當前，實力懸殊……先撐過牠的 %d 波攻勢！" % survive_acts) if scripted else "遭遇敵人！行動條蓄滿即可下令"
	sel = 0
	s_sel = 0
	i_sel = 0
	t_sel = 0

	_build_view()


# =========================================================================
# 自動戰鬥開關（對應 build_cq2.py L2702-2706）
# =========================================================================

func _handle_auto_toggle() -> void:
	if state == "win" or state == "lose":
		return
	if InputBridge.is_action_hit("battle_auto"):
		var enabled := AutoBattle.toggle()
		AudioManager.sfx("select.mp3")   # 對應 build_cq2.py L2885
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
	# 2×2 指令格：攻擊(0) 技能(1) / 道具(2) 逃跑(3)（防禦已移除）。
	if InputBridge.is_action_hit("ui_left"):
		sel = (sel + 3) % 4
		AudioManager.sfx("cursor.mp3")
	if InputBridge.is_action_hit("ui_right"):
		sel = (sel + 1) % 4
		AudioManager.sfx("cursor.mp3")
	if InputBridge.is_action_hit("ui_up") or InputBridge.is_action_hit("ui_down"):
		sel = (sel + 2) % 4   # 上下＝切換另一排（0↔2、1↔3）
		AudioManager.sfx("cursor.mp3")
	if InputBridge.is_action_hit("ui_accept"):
		AudioManager.sfx("select.mp3")   # 對應 build_cq2.py L2918-2924：選指令一律 select.wav
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
		# 逃跑（原 index 4，防禦移除後遞補為 3）。逃跑成功條件：不是 scripted 戰鬥，也不是 ch1_boss
		# （見 specs/BATTLE_FORMULAS.md 抄錄自 build_cq2.py L2744：這兩個條件 && 短路，任一為真直接判失敗）。
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
		AudioManager.sfx("cursor.mp3")
	if InputBridge.is_action_hit("ui_down") and s_sel < sl.size() - 1:
		s_sel += 1
		AudioManager.sfx("cursor.mp3")
	if InputBridge.is_action_hit("ui_cancel"):
		state = "menu"
		AudioManager.sfx("return.mp3")
		return
	if InputBridge.is_action_hit("ui_accept") and s_sel < sl.size():
		var sk: SkillDef = sl[s_sel]
		if float(actor.get("mp", 0)) < float(sk.mp):
			_banner("MP 不足！")
			AudioManager.sfx("return.mp3")
		else:
			AudioManager.sfx("select.mp3")
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
		AudioManager.sfx("cursor.mp3")
	if InputBridge.is_action_hit("ui_down") and i_sel < items.size() - 1:
		i_sel += 1
		AudioManager.sfx("cursor.mp3")
	if InputBridge.is_action_hit("ui_cancel"):
		state = "menu"
		AudioManager.sfx("return.mp3")
		return
	if InputBridge.is_action_hit("ui_accept"):
		if items.is_empty():
			_banner("沒有可用的道具！")
			AudioManager.sfx("return.mp3")
			return
		var picked: Dictionary = items[i_sel]
		var meta: ItemDef = picked["meta"]
		if not DamageCalc.item_usable_in_battle(meta):
			_banner(meta.display_name + " 無法在戰鬥中使用")
			AudioManager.sfx("return.mp3")
			return
		AudioManager.sfx("select.mp3")
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
		AudioManager.sfx("cursor.mp3")
	if InputBridge.is_action_hit("ui_down") or InputBridge.is_action_hit("ui_right"):
		t_sel = (t_sel + 1) % alive.size()
		AudioManager.sfx("cursor.mp3")
	if InputBridge.is_action_hit("ui_cancel"):
		state = "menu"
		AudioManager.sfx("return.mp3")
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
		AudioManager.sfx("cursor.mp3")
	if InputBridge.is_action_hit("ui_down") or InputBridge.is_action_hit("ui_right"):
		t_sel = (t_sel + 1) % alive.size()
		AudioManager.sfx("cursor.mp3")
	if InputBridge.is_action_hit("ui_cancel"):
		state = "menu"
		AudioManager.sfx("return.mp3")
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
	var sfx: Array = []
	var anim := ""

	if pd["t"] == "atk":
		var wt := _weapon_type(a)
		anim = WTYPE_ANIM.get(wt, "slash")
		if DamageCalc.is_dodge(a, t):
			msg_out = String(t.get("name", "")) + " 靈巧地閃開了！"
			sfx.append(_sfx_or("att_miss.mp3", "select.mp3"))   # 閃避/揮空音效（缺檔 fallback select.mp3）
		else:
			var r := DamageCalc.phys_damage(a, t)
			msg_out = String(a.get("name", "")) + " 攻擊 " + String(t.get("name", "")) + "，造成 " \
				+ str(r["dmg"]) + " 傷害" + ("（會心！）" if r["crit"] else "")
			if String(a.get("side", "")) == "hero":
				# 我方普攻：只先播武器音效（新音效有 lead-in）；扣血＋被打聲＋死亡判定延到音效播完
				var wsfx := String(WTYPE_SFX.get(wt, "att_sword.mp3"))
				sfx.append(_sfx_or(wsfx, "att_sword.mp3"))
				_defer_hits([{"t": t, "dmg": float(r["dmg"])}], wsfx)
			else:
				# 敵方：立即扣血＋怪物揮擊聲＋被打聲（維持原時序）
				t["hp"] = float(t.get("hp", 0)) - float(r["dmg"])
				sfx.append("att_monster_punch.mp3")
				sfx.append("hurt.wav")
				_kill(t)

	elif pd["t"] == "skill":
		var sk: SkillDef = pd["sk"]
		a["mp"] = float(a.get("mp", 0)) - float(sk.mp)
		var actor_sk: Dictionary = a.get("sk", {})
		var slv: int = int(actor_sk.get(sk.id, 1))
		var sk_tag := "「" + sk.display_name + (" Lv" + str(slv) if slv > 1 else "") + "」"
		if sk.kind == "damage":
			anim = ("spellcast" if sk.attr == "int" else ("thrust" if sk.attr == "agi" else "slash"))
			var dmg := DamageCalc.skill_damage(a, t, sk)
			msg_out = String(a.get("name", "")) + sk_tag + "！" + String(t.get("name", "")) \
				+ " 受到 " + str(dmg) + " 傷害"
			# 技能傷害同普攻：只先播技能音效，扣血＋被打聲＋死亡判定延到音效播完
			var sksfx := String(sk.sfx if sk.sfx != "" else ("att_magic.mp3" if sk.attr == "int" else "att_sword_skill.mp3"))
			sfx.append(_sfx_or(sksfx, "att_magic.mp3"))
			_defer_hits([{"t": t, "dmg": float(dmg)}], sksfx)
		else:
			anim = "spellcast"
			var heal := DamageCalc.skill_heal(a, sk)
			var before: float = float(t.get("hp", 0))
			t["hp"] = minf(float(t.get("maxhp", 0)), before + heal)
			msg_out = String(a.get("name", "")) + sk_tag + "！" + String(t.get("name", "")) \
				+ " 恢復 " + str(int(t["hp"] - before)) + " HP"
			sfx.append(_sfx_or(sk.sfx if sk.sfx != "" else "heal.wav", "heal.wav"))   # 補血技音效

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
		sfx.append("heal.wav")   # 對應 build_cq2.py L3174/L3177
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

	if String(a.get("side", "")) == "hero":
		_lunge_unit = a
		_lunge_t = 0.0
		_lunge_anim = anim
		_lunge_sfx = sfx
		_lunge_sfx_done = false
	else:
		for _s in sfx:
			AudioManager.sfx(_s)

	_banner(msg_out)
	if not _pending_hits.is_empty():
		# 延後扣血：回合暫停撐到「音效播完＋扣血」後再 0.4s，確保 _check_end 在扣血後才判勝負
		_end_action(_pending_hit_timer + 0.4)
	else:
		_end_action(0.75)


func _apply_all(sk: SkillDef) -> void:
	var a: Dictionary = actor
	a["mp"] = float(a.get("mp", 0)) - float(sk.mp)
	var list: Array = foes.filter(func(u): return bool(u.get("alive", false)))
	var tot := 0
	var hits: Array = []
	for f in list:
		var target: Dictionary = f
		var dmg := DamageCalc.skill_damage(a, target, sk)
		tot += dmg
		hits.append({"t": target, "dmg": float(dmg)})
	var anim := ("spellcast" if sk.attr == "int" else ("thrust" if sk.attr == "agi" else "slash"))
	var sksfx := String(sk.sfx if sk.sfx != "" else ("att_magic.mp3" if sk.attr == "int" else "att_sword_skill.mp3"))
	var sfx: Array = [_sfx_or(sksfx, "att_magic.mp3")]   # 全體技能音效（扣血＋被打聲延到音效播完）
	_defer_hits(hits, sksfx)
	if String(a.get("side", "")) == "hero":
		_lunge_unit = a
		_lunge_t = 0.0
		_lunge_anim = anim
		_lunge_sfx = sfx
		_lunge_sfx_done = false
	else:
		for _s in sfx:
			AudioManager.sfx(_s)
	var actor_sk: Dictionary = a.get("sk", {})
	var slv: int = int(actor_sk.get(sk.id, 1))
	_banner(String(a.get("name", "")) + "「" + sk.display_name + (" Lv" + str(slv) if slv > 1 else "") \
		+ "」橫掃全體敵人！共 " + str(tot) + " 傷害")
	_end_action(_pending_hit_timer + 0.4 if not _pending_hits.is_empty() else 0.8)


func _end_action(t: float) -> void:
	if actor != null:
		Atb.reset(actor)
	actor = null
	pend = null
	state = "anim"
	anim_t = t


## 我方攻擊/技能延後結算：音效播完後才扣血＋播被打聲＋死亡判定（由 _process 的 _pending_hit_timer 觸發）。
func _apply_pending_hits() -> void:
	var hits: Array = _pending_hits
	_pending_hits = []
	if hits.is_empty():
		return
	var last_t: Dictionary = {}
	for h in hits:
		var t: Dictionary = h.get("t", {})
		if t.is_empty():
			continue
		t["hp"] = float(t.get("hp", 0)) - float(h.get("dmg", 0))
		_kill(t)
		last_t = t
	AudioManager.sfx("hurt.wav")
	if not last_t.is_empty():
		_start_shake(last_t)   # 多體時震動最後命中者作代表
	_refresh_ui()


## 設定延後傷害清單，並依 sound 長度算「音效播完」的時機（命中點＋音效長度）。
func _defer_hits(hits: Array, sound: String) -> void:
	_pending_hits = hits
	_pending_hit_timer = LUNGE_DUR * IMPACT_FRAC + AudioManager.sfx_length(sound)


## 讓被攻擊對象震動一下（敵/我皆可）；渲染端由 _shake_offset_for() 套用位移。
func _start_shake(u: Variant) -> void:
	_shake_unit = u
	_shake_t = SHAKE_DUR


## 回傳某單位當前的震動位移；非震動對象或已結束回 0。
func _shake_offset_for(u: Variant) -> Vector2:
	if _shake_unit == null or not is_same(u, _shake_unit) or _shake_t <= 0.0:
		return Vector2.ZERO
	return Vector2(cos(_shake_t * 90.0) * SHAKE_AMP * (_shake_t / SHAKE_DUR), 0.0)


# =========================================================================
# 敵人行動（對應 foeAct()，L3019-3068；精確算式見 specs/BATTLE_FORMULAS.md F-8 v1.1）
# =========================================================================

func _foe_act(a: Dictionary) -> void:
	Atb.reset(a)
	if scripted:
		acted += 1
	# 敵方行動：前進一下（lunge，讓玩家看得出是誰在動）；不借用我方命中音效機制，故 sfx 清空
	_lunge_unit = a
	_lunge_t = 0.0
	_lunge_anim = ""
	_lunge_sfx = []
	_lunge_sfx_done = true

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
			AudioManager.sfx("heal.wav")
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
			AudioManager.sfx("att_monster_punch.mp3")   # 對應 build_cq2.py L3222/L3239（敵方傷害）
			AudioManager.sfx("hurt.wav")
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
			AudioManager.sfx("att_monster_punch.mp3")
			AudioManager.sfx("hurt.wav")
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
		AudioManager.sfx("att_monster_punch.mp3")
		AudioManager.sfx("hurt.wav")
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
	_start_shake(t)
	AudioManager.sfx("att_monster_punch.mp3")
	AudioManager.sfx("hurt.wav")
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
			attrs["luck"] = float(attrs.get("luck", 0)) + float(growth.get("luck", 0))   # v4.0
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

	# v4.0 F-10：隊伍幸運加成掉寶。取全隊最高 luckV（Derive 算好、含裝備效果），+drop_per_luck%/luck。
	var party_luck := 0.0
	for h in heroes:
		party_luck = maxf(party_luck, float((h as Dictionary).get("luckV", 0.0)))
	var luck_drop_bonus := party_luck * d.drop_per_luck / 100.0

	var drop_count: Dictionary = {}
	for f in foes:
		var drops: Array = f.get("drops", [])
		for drop in drops:
			var dd: Dictionary = drop
			var did := String(dd.get("id", ""))
			# see specs/BATTLE_FORMULAS.md F-10：最終掉率 = clamp(物品基礎率 × 怪物加成倍率 + 幸運加成, 0, 1)
			var mult := float(dd.get("rate", 0.0))
			var idef: ItemDef = ContentDB.get_item(did)
			var base_rate := idef.base_drop_rate if idef != null else 1.0
			if randf() < clampf(base_rate * mult + luck_drop_bonus, 0.0, 1.0):
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

	# 勝利短曲（bgm/ 底下）：停掉 battle BGM、播一次不循環；升級時用專屬版本。
	# 原版是 sfx(levelup/win) 疊在戰鬥音樂上（L3325），這裡改成 John 提供的專屬勝利小段。
	AudioManager.play_bgm_oneshot("bgm_battle_level_up.mp3" if any_up else "bgm_battle_win.mp3")
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
	AudioManager.sfx("lose.wav")   # 對應 build_cq2.py L3333
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
		AudioManager.sfx("select.mp3")   # 對應 build_cq2.py L2994
		# SceneRouter.battle_result() 內建 "lose" -> Town/shrine 的覆寫規則，這裡不用重複判斷。
		SceneRouter.battle_result(state)


# =========================================================================
# UI（Canvas-2.dc.html 戰鬥設計的落地；MOD-D 換裝——狀態機/戰鬥邏輯不動，見檔頭「UI 現況」）
#
# 程序化建 Control 節點樹（沿用 PixelUI 色票/描邊/面板）：背景（下方為地面，角色站其上）、
# 左側敵人／右側我方最多四人站位、上方戰鬥訊息＋自動鈕、底部 行動格／行動者頭像／狀態列、勝敗結算。
# battle.tscn 只提供 Node2D 根＋View(CanvasLayer)/Root(Control)，其餘節點都在這裡建。
# =========================================================================

const HERO_SLOTS := [Vector2(1074, 500), Vector2(1180, 464), Vector2(1044, 410), Vector2(1160, 372)]
const FOE_SLOTS := [Vector2(300, 500), Vector2(190, 464), Vector2(324, 410), Vector2(168, 372), Vector2(300, 336)]   # 第 5 槽為敵人數上限 5 新增（座標為估值，待實機微調）
const HERO_H := 104.0   # 原 156 縮成 2/3（John 要求）
const FOE_H := 82.0     # 原 122 縮成 2/3
const BOSS_H := 140.0   # 原 210 縮成 2/3
const HERO_RATIO := {"ludo": 1.77, "marin": 0.58, "alan": 0.80}   # 由 assets/battle/hero_dims.json 換算（w/h）；ludo 改用含揮劍弧的寬幅 LPC 戰鬥幀（idle+slash 同框）
const FRAME_DT := 0.18
# 我方發動攻擊時向前（敵方在左＝-x）踏步出招再回位。
const LUNGE_DUR := 0.55
const LUNGE_DIST := 120.0
const ATTACK_POS := Vector2(820, 480)   # 攻擊時角色直接移到的「隊伍前出場位」（隊伍在右、敵在左）
const IMPACT_FRAC := 0.7                 # 命中音效在動畫此比例處播（≈揮擊命中瞬間）
const SHAKE_DUR := 0.25                   # 被攻擊對象震動時長（秒）
const SHAKE_AMP := 7.0                    # 震動最大水平位移（px），隨時間衰減
const HP_DRAIN_STEP := 0.045              # 血條每幀往目標值逼近量（≈0.25s 掉滿條）
const FOE_LUNGE_DIST := 90.0             # 敵方攻擊前進位移（+x 朝我方）
const WTYPE_ANIM := {"sword": "slash", "dagger": "thrust", "claw": "slash", "staff": "spellcast"}          # 武器類別→普攻動畫
const WTYPE_SFX := {"sword": "att_sword.mp3", "dagger": "att_blade.mp3", "claw": "att_blade.mp3", "staff": "att_staff.mp3"}  # 武器類別→普攻音效（claw 暫共用刃音效；無對應武器時 fallback att_sword.mp3）
const ATTR_WTYPE := {"str": "sword", "agi": "dagger", "int": "staff"}   # weapon_type 留空時依 attr_type 推定

var _view_time: float = 0.0
var _lunge_unit: Variant = null
var _lunge_t: float = 0.0
var _lunge_anim: String = ""     # 本次攻擊要播的動畫組："slash"/"thrust"/"spellcast"／""＝無（沿用滑步）
var _lunge_sfx: Array = []       # 延到命中瞬間才播的音效（我方攻擊用）
var _lunge_sfx_done: bool = false
var _pending_hits: Array = []        # 我方攻擊/技能：延到音效播完才套用的傷害清單 [{t, dmg}, ...]
var _pending_hit_timer: float = 0.0  # delta 倒數，歸零時套用 _pending_hit（音效先完、再扣血＋被打聲）
var _shake_unit: Variant = null      # 被攻擊而震動中的對象（敵/我皆可）
var _shake_t: float = 0.0            # 震動剩餘時間（delta 倒數）
var _boss_disp_r: float = 1.0        # boss 血條顯示比例（漸減動畫用）
var _root: Control
var _bg: TextureRect
var _boss_name: Label
var _boss_bar_bg: ColorRect
var _boss_bar_fill: ColorRect
var _log_label: Label
var _auto_btn: Button
var _cmd_labels: Array = []
var _skill_box: VBoxContainer
var _skill_labels: Array = []
var _item_box: VBoxContainer
var _item_labels: Array = []
var _portrait: TextureRect
var _status_rows: Array = []
var _foe_nodes: Array = []
var _hero_nodes: Array = []
var _cursor: TextureRect
var _actor_arrow: Label
var _result_overlay: Control
var _result_title: Label
var _result_msg: Label
var _result_hint: Label
var _result_btn: Button


func _build_view() -> void:
	_root = $View/Root
	for c in _root.get_children():
		c.queue_free()
	_foe_nodes.clear()
	_hero_nodes.clear()
	_status_rows.clear()
	_cmd_labels.clear()
	_skill_labels.clear()
	_item_labels.clear()

	# --- 背景（cover 全螢幕；圖本身下方即地面，角色站其上）---
	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 高解析背景縮放走平滑（角色 sprite 仍各自 Nearest）
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bgt := _battle_bg_texture()
	if bgt != null:
		_bg.texture = bgt
	_root.add_child(_bg)

	# --- 單位：敵人（左）／我方最多四人（右）站位 ---
	for f in foes:
		_foe_nodes.append(_build_unit(f, false))
	for h in heroes:
		_hero_nodes.append(_build_unit(h, true))

	# --- 目標游標 + 行動者箭頭 ---
	_cursor = TextureRect.new()
	_cursor.texture = _tex("res://assets/ui/cursor.png")
	_cursor.custom_minimum_size = Vector2(40, 40)
	_cursor.size = Vector2(40, 40)
	_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = false
	_root.add_child(_cursor)
	_actor_arrow = PixelUI.label("▼", 28, PixelUI.SEL, 4)
	_actor_arrow.visible = false
	_root.add_child(_actor_arrow)

	# --- 上方：戰鬥訊息 ---
	var logbg := PixelUI.panel(Color(0.047, 0.055, 0.102, 0.42), 2)
	logbg.position = Vector2(30, 18)
	logbg.custom_minimum_size = Vector2(700, 0)
	_log_label = PixelUI.label("", 19, Color(0.922, 0.922, 0.96), 3)
	_log_label.custom_minimum_size = Vector2(672, 0)
	logbg.add_child(_log_label)
	_root.add_child(logbg)

	# --- 上方右：自動戰鬥鈕（滑鼠可點；A 鍵仍可切）---
	_auto_btn = PixelUI.button("自動　關", PixelUI.CYAN, 17)
	_auto_btn.anchor_left = 1.0
	_auto_btn.anchor_right = 1.0
	_auto_btn.offset_left = -156.0
	_auto_btn.offset_right = -22.0
	_auto_btn.offset_top = 18.0
	_auto_btn.offset_bottom = 56.0
	_auto_btn.pressed.connect(_on_auto_pressed)
	_root.add_child(_auto_btn)

	_build_action_panel()
	_build_portrait_panel()
	_build_status_panel()
	_build_boss_bar()
	_build_result_overlay()


## 建一個站在地面上的單位（敵人或英雄）。foot-anchor：wrap 在腳點，sprite 從 -h 到 0。
func _build_unit(u: Dictionary, is_hero: bool) -> Dictionary:
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slots: Array = HERO_SLOTS if is_hero else FOE_SLOTS
	wrap.position = slots[int(u.get("slot", 0)) % slots.size()]
	_root.add_child(wrap)

	var frames := _load_frames(u, is_hero)
	var anim_frames: Dictionary = _load_anim_frames(u) if is_hero else {}
	var default_foe_h: float = BOSS_H if bool(u.get("big", false)) else FOE_H
	var h: float = HERO_H if is_hero else float(u.get("battle_height", default_foe_h))
	var ratio: float = (float(HERO_RATIO.get(String(u.get("sprite", "")), 0.8)) if is_hero else 0.9)
	var w := h * ratio

	if frames.is_empty():
		var ph := ColorRect.new()   # 無戰鬥圖的敵人（bear/orc/ogre/necro…）用佔位塊，仍看得到名字/血條
		ph.color = Color(0.1, 0.11, 0.16, 0.55)
		ph.size = Vector2(w, h)
		ph.position = Vector2(-w * 0.5, -h)
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(ph)

	var spr := TextureRect.new()
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spr.flip_h = false   # 都不翻轉：素材我方本就面朝左、敵方面朝右（John 回饋我方原本翻反了）
	spr.size = Vector2(w, h)
	spr.position = Vector2(-w * 0.5, -h)
	if not frames.is_empty():
		spr.texture = frames[0]
	wrap.add_child(spr)

	var name_lbl: Label = null
	var hp_fill: ColorRect = null
	# 一般敵人：名字在頭頂、血條在腳下。boss（big）不畫，改用畫面中上的 boss 血條。
	if not is_hero and not bool(u.get("big", false)):
		name_lbl = PixelUI.label(String(u.get("name", "")), 15, PixelUI.WHITE, 3)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.size = Vector2(160, 22)
		name_lbl.position = Vector2(-80, -h - 26)
		wrap.add_child(name_lbl)
		var barbg := ColorRect.new()
		barbg.color = PixelUI.OUTLINE
		barbg.size = Vector2(100, 10)
		barbg.position = Vector2(-50, 6)
		barbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(barbg)
		hp_fill = ColorRect.new()
		hp_fill.color = PixelUI.HP
		hp_fill.size = Vector2(96, 6)
		hp_fill.position = Vector2(-48, 8)
		hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(hp_fill)

	return {"unit": u, "wrap": wrap, "sprite": spr, "name": name_lbl, "hp_fill": hp_fill, "frames": frames, "anim_frames": anim_frames, "is_hero": is_hero, "h": h, "base": wrap.position}


func _load_frames(u: Dictionary, is_hero: bool) -> Array:
	var out: Array = []
	var s := String(u.get("sprite", ""))
	if is_hero:
		for i in range(4):
			var p := "res://assets/battle/hero_%s_f%d.png" % [s, i]
			if ResourceLoader.exists(p):
				out.append(load(p))
	else:
		for i in range(8):
			var p := "res://assets/battle/foe_%s_%d.png" % [s, i]
			if ResourceLoader.exists(p):
				out.append(load(p))
	return out


## 取行動者裝備武器的類別（weapon_type；留空則依 attr_type 推定）。敵人/徒手回 ""。
func _weapon_type(a: Dictionary) -> String:
	var wid := String(a.get("eq", {}).get("weapon", ""))
	if wid == "":
		return ""
	var w: EquipmentDef = ContentDB.get_equipment(wid)
	if w == null:
		return ""
	if w.weapon_type != "":
		return w.weapon_type
	return ATTR_WTYPE.get(w.attr_type, "")


## 音效檔存在就用它，否則回 fallback（新音效未備齊前沿用現有 atk/magic）。
func _sfx_or(name: String, fallback: String) -> String:
	return name if ResourceLoader.exists("res://assets/sfx/" + name) else fallback


func _load_anim_frames(u: Dictionary) -> Dictionary:
	var s := String(u.get("sprite", ""))
	var out := {}
	for anim in ["slash", "thrust", "spellcast"]:
		var arr: Array = []
		for i in range(16):
			var p := "res://assets/battle/hero_%s_%s_%d.png" % [s, anim, i]
			if ResourceLoader.exists(p):
				arr.append(load(p))
		if not arr.is_empty():
			out[anim] = arr
	return out


func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _battle_bg_texture() -> Texture2D:
	var area := ""
	var ed: EncounterDef = ContentDB.get_encounter(enc)
	if ed != null:
		area = ed.map_id
	var name_ := "forest"
	if "cave" in area:
		name_ = "cave"
	elif "mine" in area:
		name_ = "mine"
	elif area.begins_with("eforest"):
		name_ = "forest_depths"
	for p in ["res://assets/ui/battlebg_%s.png" % name_, "res://assets/ui/battlebg.png"]:
		if ResourceLoader.exists(p):
			return load(p)
	return null


## 中上：Boss（大敵）名稱＋血條。一般敵人血條在腳下，boss 太大改放畫面中上（對齊 Canvas-2 設計）。
func _build_boss_bar() -> void:
	_boss_name = PixelUI.label("", 22, PixelUI.WHITE, 4)
	_boss_name.anchor_left = 0.0
	_boss_name.anchor_right = 1.0
	_boss_name.offset_left = 0.0
	_boss_name.offset_right = 0.0
	_boss_name.offset_top = 50.0
	_boss_name.offset_bottom = 82.0
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.visible = false
	_root.add_child(_boss_name)
	_boss_bar_bg = ColorRect.new()
	_boss_bar_bg.color = PixelUI.OUTLINE
	_boss_bar_bg.position = Vector2(340, 88)
	_boss_bar_bg.size = Vector2(600, 16)
	_boss_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_bg.visible = false
	_root.add_child(_boss_bar_bg)
	_boss_bar_fill = ColorRect.new()
	_boss_bar_fill.color = PixelUI.HP
	_boss_bar_fill.position = Vector2(343, 91)
	_boss_bar_fill.size = Vector2(594, 10)
	_boss_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_fill.visible = false
	_root.add_child(_boss_bar_fill)


## 區塊面板（行動／狀態）：半透明格子＋標題頁籤，頁籤垂直中線卡在格子上邊線（對齊 Canvas-2 設計）。
func _titled_panel(title: String, pos: Vector2, sz: Vector2) -> void:
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", PixelUI.panel_style(Color(0.345, 0.357, 0.482, 0.46), 3))
	box.position = pos
	box.size = sz
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var tab := PixelUI.panel(Color(0.071, 0.078, 0.11, 1.0), 2)
	var tst := tab.get_theme_stylebox("panel") as StyleBoxFlat
	tst.content_margin_left = 12
	tst.content_margin_right = 12
	tst.content_margin_top = 2
	tst.content_margin_bottom = 2
	tab.add_child(PixelUI.label(title, 16, PixelUI.GOLD, 3))
	tab.position = pos + Vector2(18, -13)
	_root.add_child(tab)


func _build_action_panel() -> void:
	_titled_panel("行動", Vector2(30, 556), Vector2(432, 150))
	# 指令 2×2：攻擊/技能 上排、道具/逃跑 下排
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(62, 588)
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 16)
	for nm in ["攻擊", "技能", "道具", "逃跑"]:
		var l := PixelUI.label(String(nm), 26, PixelUI.WHITE, 4)
		l.custom_minimum_size = Vector2(150, 0)
		grid.add_child(l)
		_cmd_labels.append(l)
	_root.add_child(grid)
	# 技能／道具清單（覆在行動面板區，依狀態切換顯示）
	_skill_box = VBoxContainer.new()
	_skill_box.position = Vector2(52, 574)
	_skill_box.add_theme_constant_override("separation", 3)
	_root.add_child(_skill_box)
	for i in range(5):
		var sl := PixelUI.label("", 18, PixelUI.WHITE, 3)
		_skill_box.add_child(sl)
		_skill_labels.append(sl)
	_item_box = VBoxContainer.new()
	_item_box.position = Vector2(52, 574)
	_item_box.add_theme_constant_override("separation", 3)
	_root.add_child(_item_box)
	for i in range(5):
		var il := PixelUI.label("", 18, PixelUI.WHITE, 3)
		_item_box.add_child(il)
		_item_labels.append(il)


func _build_portrait_panel() -> void:
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", PixelUI.panel_style(Color(0.051, 0.059, 0.094, 1.0), 3))
	bg.position = Vector2(478, 556)
	bg.size = Vector2(156, 150)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.position = Vector2(484, 562)
	_portrait.size = Vector2(144, 138)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_portrait)


func _build_status_panel() -> void:
	_titled_panel("狀態", Vector2(650, 556), Vector2(600, 150))
	var col := VBoxContainer.new()
	col.position = Vector2(664, 586)
	col.custom_minimum_size = Vector2(576, 0)
	col.add_theme_constant_override("separation", 9)
	_root.add_child(col)
	for h in heroes:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(576, 26)
		row.add_theme_constant_override("separation", 6)
		var nm := _srow_label(String(h.get("name", "")), 19, PixelUI.GOLD, 54.0)
		row.add_child(nm)
		row.add_child(_srow_label("HP", 13, Color(0.62, 0.77, 0.74), 0.0))
		var hp := _bar(PixelUI.HP, 98.0)
		row.add_child(hp["wrap"])
		var hptxt := _srow_label("", 15, Color(0.84, 0.94, 0.91), 66.0)
		row.add_child(hptxt)
		row.add_child(_srow_label("MP", 13, Color(0.64, 0.72, 0.83), 0.0))
		var mp := _bar(PixelUI.MP, 78.0)
		row.add_child(mp["wrap"])
		var mptxt := _srow_label("", 15, Color(0.88, 0.92, 0.96), 48.0)
		row.add_child(mptxt)
		row.add_child(_srow_label("行動", 13, Color(0.71, 0.67, 0.82), 0.0))
		var atb := _bar(Color(0.76, 0.72, 0.91), 54.0)
		row.add_child(atb["wrap"])
		col.add_child(row)
		_status_rows.append({"unit": h, "name": nm, "hp": hp, "hptxt": hptxt, "mp": mp, "mptxt": mptxt, "atb": atb})


## 狀態列元素：垂直置中對齊、同一基準線（解決名稱/血條/文字高度不統一）。w>0 給固定寬。
func _srow_label(txt: String, size: int, color: Color, w: float) -> Label:
	var l := PixelUI.label(txt, size, color, 2)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if w > 0.0:
		l.custom_minimum_size = Vector2(w, 0)
	return l


## 固定寬度的條（bg + fill），垂直置中。fill 寬度在 _refresh_ui 依比例設定。回傳 {wrap, fill, w}。
func _bar(color: Color, w: float) -> Dictionary:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(w, 14)
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.12, 0.16, 0.55)
	bg.size = Vector2(w, 14)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(2, 2)
	fill.size = Vector2(w - 4, 10)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(fill)
	return {"wrap": wrap, "fill": fill, "w": w}


func _build_result_overlay() -> void:
	_result_overlay = Control.new()
	_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.visible = false
	_root.add_child(_result_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.06, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_overlay.add_child(dim)
	_result_title = PixelUI.label("", 84, PixelUI.GOLD, 6)
	_result_title.anchor_left = 0.0
	_result_title.anchor_right = 1.0
	_result_title.offset_left = 0.0
	_result_title.offset_right = 0.0
	_result_title.offset_top = 168.0
	_result_title.offset_bottom = 300.0
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_overlay.add_child(_result_title)
	_result_msg = PixelUI.label("", 24, PixelUI.WHITE, 3)
	_result_msg.anchor_right = 1.0
	_result_msg.offset_left = 120.0
	_result_msg.offset_right = -120.0
	_result_msg.offset_top = 312.0
	_result_msg.offset_bottom = 520.0
	_result_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_overlay.add_child(_result_msg)
	_result_hint = PixelUI.label("", 16, PixelUI.DIM, 2)
	_result_overlay.add_child(_result_hint)
	_result_btn = PixelUI.button("繼續", PixelUI.WHITE, 24)
	_result_btn.anchor_left = 0.5
	_result_btn.anchor_right = 0.5
	_result_btn.offset_left = -150.0
	_result_btn.offset_right = 150.0
	_result_btn.anchor_top = 1.0
	_result_btn.anchor_bottom = 1.0
	_result_btn.offset_top = -110.0
	_result_btn.offset_bottom = -60.0
	_result_btn.pressed.connect(_on_result_confirm)
	_result_overlay.add_child(_result_btn)


func _on_auto_pressed() -> void:
	if state == "win" or state == "lose":
		return
	var enabled := AutoBattle.toggle()
	_banner("自動戰鬥：" + ("開啟──我方自動普攻" if enabled else "關閉"))
	if enabled and state == "menu" and actor != null:
		_auto_attack(actor)


func _on_result_confirm() -> void:
	if state == "win" or state == "lose":
		SceneRouter.battle_result(state)


func _hero_node_of(u: Variant) -> Variant:
	for n in _hero_nodes:
		if n["unit"] == u:
			return n
	return null


func _foe_node_of(u: Variant) -> Variant:
	for n in _foe_nodes:
		if n["unit"] == u:
			return n
	return null


func _refresh_ui() -> void:
	if _root == null:
		return
	_log_label.text = msg
	var frame := int(_view_time / FRAME_DT)
	var hero_turn := actor != null and String(actor.get("side", "")) == "hero"
	var is_end := state == "win" or state == "lose"

	# --- 敵人 sprite/名稱/血條 ---
	for node in _foe_nodes:
		var f: Dictionary = node["unit"]
		var alive := bool(f.get("alive", false))
		# 血條漸減：disp_r 追向目標比例（掉血動畫，與扣血時機解耦）
		var target_r := clampf(float(f.get("hp", 0)) / maxf(1.0, float(f.get("maxhp", 1))), 0.0, 1.0)
		var disp_r: float = move_toward(float(node.get("disp_r", target_r)), target_r, HP_DRAIN_STEP)
		node["disp_r"] = disp_r
		if node["hp_fill"] != null:
			var hpf: ColorRect = node["hp_fill"]
			hpf.size = Vector2(96.0 * disp_r, hpf.size.y)
		# 死亡：血條掉完（disp_r≈0）才消失並播 enemy_down（一次）；活著或血條還在掉都保持顯示
		var showing := (alive or disp_r > 0.01) and not is_end
		node["wrap"].visible = showing
		if not alive and disp_r <= 0.01 and not bool(node.get("death_sfx", false)):
			AudioManager.sfx("enemy_down.mp3")
			node["death_sfx"] = true
		if not showing:
			continue
		# 位置：敵方攻擊前進（lunge，+x 朝我方）＋被攻擊震動
		var base_pos: Vector2 = node["base"]
		var foe_off := 0.0
		if _lunge_unit != null and is_same(node["unit"], _lunge_unit) and _lunge_t < LUNGE_DUR:
			foe_off = FOE_LUNGE_DIST * sin(PI * _lunge_t / LUNGE_DUR)
		node["wrap"].position = base_pos + Vector2(foe_off, 0.0) + _shake_offset_for(node["unit"])
		var frames: Array = node["frames"]
		if not frames.is_empty():
			node["sprite"].texture = frames[frame % frames.size()]
		if node["name"] != null:
			node["name"].text = ("☠ " if bool(f.get("big", false)) else "") + String(f.get("name", ""))

	# --- Boss（大敵）名稱＋血條→畫面中上 ---
	var boss: Variant = null
	for f2 in foes:
		if bool(f2.get("big", false)) and bool(f2.get("alive", false)):
			boss = f2
			break
	var show_boss := boss != null and not is_end
	_boss_name.visible = show_boss
	_boss_bar_bg.visible = show_boss
	_boss_bar_fill.visible = show_boss
	if show_boss:
		var b: Dictionary = boss
		_boss_name.text = "☠ " + String(b.get("name", ""))
		var br := clampf(float(b.get("hp", 0)) / maxf(1.0, float(b.get("maxhp", 1))), 0.0, 1.0)
		_boss_disp_r = move_toward(_boss_disp_r, br, HP_DRAIN_STEP)
		_boss_bar_fill.size = Vector2(594.0 * _boss_disp_r, _boss_bar_fill.size.y)

	# --- 我方 sprite（陣亡變暗；攻擊時直接移到出場位＋依性質播動畫；無對應動畫則沿用滑步）---
	for node in _hero_nodes:
		var h: Dictionary = node["unit"]
		var wnode: Control = node["wrap"]
		var base: Vector2 = node["base"]
		var frames: Array = node["frames"]
		var lunging := _lunge_unit != null and is_same(node["unit"], _lunge_unit) and _lunge_t < LUNGE_DUR
		var anims: Dictionary = node.get("anim_frames", {})
		var atk_frames: Array = (anims.get(_lunge_anim, []) if lunging else [])
		if lunging and not atk_frames.is_empty():
			wnode.position = ATTACK_POS + _shake_offset_for(node["unit"])   # 直接移到隊伍前出場位
			var si := clampi(int(_lunge_t / LUNGE_DUR * atk_frames.size()), 0, atk_frames.size() - 1)
			node["sprite"].texture = atk_frames[si]
		else:
			var off := (-LUNGE_DIST * sin(PI * _lunge_t / LUNGE_DUR) if lunging else 0.0)
			wnode.position = base + Vector2(off, 0.0) + _shake_offset_for(node["unit"])
			if not frames.is_empty():
				node["sprite"].texture = frames[frame % frames.size()]
		wnode.visible = not is_end
		node["sprite"].modulate = Color(0.4, 0.4, 0.45, 0.9) if not bool(h.get("alive", false)) else Color.WHITE

	# --- 行動者箭頭 ---
	_actor_arrow.visible = hero_turn and (state == "menu" or state == "skill" or state == "item")
	if _actor_arrow.visible:
		var hn = _hero_node_of(actor)
		if hn != null:
			var w: Control = hn["wrap"]
			_actor_arrow.position = w.position + Vector2(-10.0, -float(hn["h"]) - 54.0)

	# --- 目標游標 ---
	_cursor.visible = state == "target" or state == "target_ally"
	if _cursor.visible:
		var pool: Array = (foes if state == "target" else heroes).filter(func(u): return bool(u.get("alive", false)))
		if not pool.is_empty():
			var tgt: Dictionary = pool[t_sel % pool.size()]
			var tn = (_foe_node_of(tgt) if state == "target" else _hero_node_of(tgt))
			if tn != null:
				var tw: Control = tn["wrap"]
				_cursor.position = tw.position + Vector2(-20.0, -float(tn["h"]) - 48.0)

	# --- 狀態列（HP/MP/行動條）---
	for row in _status_rows:
		var h: Dictionary = row["unit"]
		var maxhp := maxf(1.0, float(h.get("maxhp", 1)))
		var maxmp := maxf(1.0, float(h.get("maxmp", 1)))
		var hp := maxf(0.0, float(h.get("hp", 0)))
		var hpf2: ColorRect = row["hp"]["fill"]
		var mpf: ColorRect = row["mp"]["fill"]
		var atbf: ColorRect = row["atb"]["fill"]
		hpf2.size = Vector2((float(row["hp"]["w"]) - 4.0) * clampf(hp / maxhp, 0.0, 1.0), hpf2.size.y)
		mpf.size = Vector2((float(row["mp"]["w"]) - 4.0) * clampf(float(h.get("mp", 0)) / maxmp, 0.0, 1.0), mpf.size.y)
		atbf.size = Vector2((float(row["atb"]["w"]) - 4.0) * clampf(float(h.get("atb", 0)) / 100.0, 0.0, 1.0), atbf.size.y)
		row["hptxt"].text = "%d/%d" % [int(hp), int(maxhp)]
		row["mptxt"].text = "%d/%d" % [int(float(h.get("mp", 0))), int(maxmp)]
		var nm: Label = row["name"]
		if not bool(h.get("alive", false)):
			nm.add_theme_color_override("font_color", PixelUI.DIM)
		elif actor == h:
			nm.add_theme_color_override("font_color", PixelUI.SEL)
		else:
			nm.add_theme_color_override("font_color", PixelUI.GOLD)

	# --- 行動者頭像（無人行動時用預設圖 assets/ui/face_default.png）---
	if hero_turn:
		var pt := _tex("res://assets/ui/face_%s.png" % String(actor.get("sprite", "")))
		if pt != null:
			_portrait.texture = pt
	else:
		var pd := _tex("res://assets/ui/face_default.png")
		if pd != null:
			_portrait.texture = pd

	# --- 行動格（攻/技/道/逃）：永遠顯示；非本回合選單時淡化（不可操作但字還在）；技能/道具子選單開啟時讓位 ---
	var show_cmd := hero_turn and state == "menu"
	var cmd_hidden := hero_turn and (state == "skill" or state == "item")
	for i in _cmd_labels.size():
		var l: Label = _cmd_labels[i]
		l.visible = not cmd_hidden
		l.add_theme_color_override("font_color", (PixelUI.SEL if i == sel else PixelUI.WHITE) if show_cmd else PixelUI.DIM)

	# --- 技能清單 ---
	var show_skill := hero_turn and state == "skill"
	_skill_box.visible = show_skill
	if show_skill:
		var sl := _skills_for(actor)
		var ask: Dictionary = actor.get("sk", {})
		for i in _skill_labels.size():
			var lbl: Label = _skill_labels[i]
			if i < sl.size():
				var sd: SkillDef = sl[i]
				var slv := int(ask.get(sd.id, 1))
				lbl.visible = true
				lbl.text = ("▶ " if i == s_sel else "　") + sd.display_name + " Lv" + str(slv) + "（" + str(sd.mp) + "MP）"
				var afford := float(actor.get("mp", 0)) >= float(sd.mp)
				lbl.add_theme_color_override("font_color", PixelUI.SEL if (i == s_sel and afford) else (PixelUI.WHITE if afford else PixelUI.DIM))
			else:
				lbl.visible = false

	# --- 道具清單 ---
	var show_item := hero_turn and state == "item"
	_item_box.visible = show_item
	if show_item:
		var items := _battle_items()
		for i in _item_labels.size():
			var lbl2: Label = _item_labels[i]
			if i < items.size():
				var it: Dictionary = items[i]
				var meta: ItemDef = it["meta"]
				lbl2.visible = true
				lbl2.text = ("▶ " if i == i_sel else "　") + meta.display_name + " ×" + str(it["n"])
				lbl2.add_theme_color_override("font_color", PixelUI.SEL if i == i_sel else PixelUI.WHITE)
			elif i == 0 and items.is_empty():
				lbl2.visible = true
				lbl2.text = "（沒有可用的道具）"
				lbl2.add_theme_color_override("font_color", PixelUI.DIM)
			else:
				lbl2.visible = false

	# --- 自動鈕 ---
	var auto_on := AutoBattle.is_enabled()
	_auto_btn.text = "自動　開" if auto_on else "自動　關"
	_auto_btn.add_theme_color_override("font_color", PixelUI.SEL if auto_on else PixelUI.CYAN)

	# --- 勝敗結算 ---
	_result_overlay.visible = is_end
	if is_end:
		_result_title.text = "勝　利！" if state == "win" else "敗　北"
		_result_title.add_theme_color_override("font_color", PixelUI.GOLD if state == "win" else PixelUI.HP)
		_result_msg.text = win_msg
		_result_btn.text = "繼續" if state == "win" else "回到鎮上"
