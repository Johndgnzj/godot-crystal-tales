extends Node2D
## MOD-E　戰鬥系統主狀態機（specs/BATTLE_FORMULAS.md F-3~F-8、TASKS/05_戰鬥ATB.md）。
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
## `auto_battle.gd`（自動戰鬥）。
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
	AudioManager.play_bgm("bgm_battle.mp3", true)   # 對應 build_cq2.py L2870（戰鬥循環）；transient＝不覆蓋場景循環曲記憶
	AudioManager.play_bgm_overlay("bgm_battle_opening.mp3")   # 開場層：非 loop，疊在戰鬥循環上一次性播放
	_init_battle()


func _process(delta: float) -> void:
	_view_time += delta
	if _lunge_unit != null:
		_lunge_t += delta
		if not _lunge_sfx_done and _lunge_t >= _lunge_impact:
			for _s in _lunge_sfx:
				AudioManager.sfx(_s)
			_lunge_sfx_done = true
		_tick_fx_queue()
		if _lunge_t >= _lunge_dur:
			_lunge_unit = null
	if not _pending_hits.is_empty():
		_pending_hit_timer -= delta
		if _pending_hit_timer <= 0.0:
			_apply_pending_hits()   # 音效播完 → 扣血＋被打聲＋死亡判定
	if _shake_t > 0.0:
		_shake_t -= delta
	_tick_screen_shake(delta)
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
	# 小節1（ch1_step<=2，路德單人/低等）：隨機遭遇最多 2 隻，避免走到熊之前就被群毆掛掉（John 2026-07-27）。
	if int(GameState.flag_get("ch1_step")) <= 2 and group.size() > 2:
		group.resize(2)

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
	for i in range(mini(group.size(), FOE_X.size())):
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
			"battle_scale": ed.battle_scale,   # 戰鬥圖顯示倍率（EnemyDef 定義，只影響大小）
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

	# 本次我方 lunge 時序：普攻分階段位移（移動→停 0.2s→攻擊→返回）；技能/道具原位。
	# 須在 _defer_hits 之前設定（_pending_hit_timer 依 _lunge_impact 計）。
	if String(a.get("side", "")) == "hero":
		_fx_queue.clear()
		if pd["t"] == "atk":
			_lunge_dur = LM_APPROACH + LM_WAIT + LM_ATTACK + LM_RETURN
			_lunge_impact = LM_APPROACH + LM_WAIT + LM_SWING
		else:
			_lunge_dur = SKILL_LUNGE_DUR
			_lunge_impact = SKILL_IMPACT

	if pd["t"] == "atk":
		anim = "attack"   # 作法 B：通用 attack 動畫（音效改由 _atk_sfx() 決定）
		if DamageCalc.is_dodge(a, t):
			msg_out = String(t.get("name", "")) + " 靈巧地閃開了！"
			var msfx := _sfx_or("att_miss.mp3", "select.mp3")   # 閃避/揮空音效（缺檔 fallback select.mp3）
			sfx.append(msfx)
			if String(a.get("side", "")) == "hero":
				_defer_hits([{"t": t, "miss": true}], msfx)   # Miss 飄字也等揮空音效播完才出
			else:
				_popup_miss(t)
		else:
			var r := DamageCalc.phys_damage(a, t)
			msg_out = String(a.get("name", "")) + " 攻擊 " + String(t.get("name", "")) + "，造成 " \
				+ str(r["dmg"]) + " 傷害" + ("（會心！）" if r["crit"] else "")
			if String(a.get("side", "")) == "hero":
				# 我方普攻：只先播攻擊音效（新音效有 lead-in）；扣血＋被打聲＋死亡判定延到音效播完
				var wsfx := _atk_sfx(a)
				sfx.append(_sfx_or(wsfx, "att_sword.mp3"))
				_defer_hits([{"t": t, "dmg": float(r["dmg"]), "crit": bool(r["crit"])}], wsfx)
				_queue_fx(t, _phys_fx(a), LM_APPROACH + LM_WAIT)   # 與 attack 動畫同時起
			else:
				# 敵方：立即扣血＋怪物揮擊聲＋被打聲（維持原時序）
				t["hp"] = float(t.get("hp", 0)) - float(r["dmg"])
				sfx.append("att_monster_punch.mp3")
				sfx.append("hurt.wav")
				_popup_damage(t, int(r["dmg"]), bool(r["crit"]))
				_play_hit_fx(t, _phys_fx(a))
				_kill(t)

	elif pd["t"] == "skill":
		var sk: SkillDef = pd["sk"]
		a["mp"] = float(a.get("mp", 0)) - float(sk.mp)
		var actor_sk: Dictionary = a.get("sk", {})
		var slv: int = int(actor_sk.get(sk.id, 1))
		var sk_tag := "「" + sk.display_name + (" Lv" + str(slv) if slv > 1 else "") + "」"
		if sk.kind == "damage":
			anim = "attack"
			var dmg := DamageCalc.skill_damage(a, t, sk)
			msg_out = String(a.get("name", "")) + sk_tag + "！" + String(t.get("name", "")) \
				+ " 受到 " + str(dmg) + " 傷害"
			# 技能傷害同普攻：只先播技能音效，扣血＋被打聲＋死亡判定延到音效播完
			var sksfx := _skill_sfx(a, sk)
			sfx.append(_sfx_or(sksfx, "att_magic.mp3"))
			_defer_hits([{"t": t, "dmg": float(dmg), "crit": false}], sksfx)
			_queue_fx(t, _skill_fx(a, sk.attr), 0.0)   # 與 attack 動畫同時起
		else:
			anim = "attack"
			var heal := DamageCalc.skill_heal(a, sk)
			var before: float = float(t.get("hp", 0))
			t["hp"] = minf(float(t.get("maxhp", 0)), before + heal)
			msg_out = String(a.get("name", "")) + sk_tag + "！" + String(t.get("name", "")) \
				+ " 恢復 " + str(int(t["hp"] - before)) + " HP"
			sfx.append(_sfx_or(sk.sfx if sk.sfx != "" else "heal.wav", "heal.wav"))   # 補血技音效
			_popup_heal(t, int(t["hp"] - before), "HP")
			_play_hit_fx(t, "heal")

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
			_popup_heal(t, int(t["mp"] - before_mp), "MP")
			_play_hit_fx(t, "heal")
		else:
			var before_hp: float = float(t.get("hp", 0))
			t["hp"] = minf(float(t.get("maxhp", 0)), before_hp + power)
			msg_out = String(a.get("name", "")) + " 使用" + item_name + "！" + String(t.get("name", "")) \
				+ " 恢復 " + str(int(t["hp"] - before_hp)) + " HP"
			_popup_heal(t, int(t["hp"] - before_hp), "HP")
			_play_hit_fx(t, "heal")

	if String(a.get("side", "")) == "hero":
		_lunge_unit = a
		_lunge_t = 0.0
		_lunge_anim = anim
		_lunge_move = (pd["t"] == "atk")          # 普攻才移動到目標；技能原位施放
		_lunge_target = (t if pd["t"] == "atk" else null)
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
	_fx_queue.clear()
	_lunge_dur = SKILL_LUNGE_DUR      # 全體技：原位施放時序
	_lunge_impact = SKILL_IMPACT
	var list: Array = foes.filter(func(u): return bool(u.get("alive", false)))
	var tot := 0
	var hits: Array = []
	var fx_kind := _skill_fx(a, sk.attr)
	for f in list:
		var target: Dictionary = f
		var dmg := DamageCalc.skill_damage(a, target, sk)
		tot += dmg
		hits.append({"t": target, "dmg": float(dmg), "crit": false})
		_queue_fx(target, fx_kind, 0.0)   # 與 attack 動畫同時起
	var anim := "attack"
	var sksfx := _skill_sfx(a, sk)
	var sfx: Array = [_sfx_or(sksfx, "att_magic.mp3")]   # 全體技能音效（扣血＋被打聲延到音效播完）
	_defer_hits(hits, sksfx)
	if String(a.get("side", "")) == "hero":
		_lunge_unit = a
		_lunge_t = 0.0
		_lunge_anim = anim
		_lunge_move = false          # 全體技：原位施放
		_lunge_target = null
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
		if bool(h.get("miss", false)):
			_popup_miss(t)
			continue
		t["hp"] = float(t.get("hp", 0)) - float(h.get("dmg", 0))
		_popup_damage(t, int(h.get("dmg", 0)), bool(h.get("crit", false)))
		_kill(t)
		last_t = t
	if not last_t.is_empty():
		AudioManager.sfx("hurt.wav")
		_start_shake(last_t)   # 多體時震動最後命中者作代表
	_refresh_ui()


## 設定延後傷害清單，並依 sound 長度算「音效播完」的時機（命中點＋音效長度）。
func _defer_hits(hits: Array, sound: String) -> void:
	_pending_hits = hits
	_pending_hit_timer = _lunge_impact + AudioManager.sfx_length(sound)


## 讓被攻擊對象震動一下（敵/我皆可）；渲染端由 _shake_offset_for() 套用位移。
func _start_shake(u: Variant) -> void:
	_shake_unit = u
	_shake_t = SHAKE_DUR


## 回傳某單位當前的震動位移；非震動對象或已結束回 0。
func _shake_offset_for(u: Variant) -> Vector2:
	if _shake_unit == null or not is_same(u, _shake_unit) or _shake_t <= 0.0:
		return Vector2.ZERO
	return Vector2(cos(_shake_t * 90.0) * SHAKE_AMP * (_shake_t / SHAKE_DUR), 0.0)


## 普攻位移目標點：目標單位的右前方（我方在右），但**y 維持攻擊者自己那一排**。
## 站位用 y 造假深度，若直接跟到目標的 y，打後排敵人時角色會在 0.18s 內垂直上飄 36~128px
## （2D 沒有透視縮放，看起來像浮空，John 2026-07-28 回報）。只取目標的 x。
func _lunge_target_front(fallback_base: Vector2) -> Vector2:
	if _lunge_target == null:
		return fallback_base
	var tn = _foe_node_of(_lunge_target)
	if tn == null:
		return Vector2(ATTACK_POS.x, fallback_base.y)
	var tb: Vector2 = tn["base"]
	return Vector2(tb.x + ATTACK_FRONT_GAP, fallback_base.y)


## 該單位是否正在被攻擊震動中（用來切到 hurt 圖）。
func _is_shaking(u: Variant) -> bool:
	return _shake_unit != null and is_same(u, _shake_unit) and _shake_t > 0.0


# =========================================================================
# 傷害飄字／受擊特效／畫面震動（2026-07-28 John 驗收回饋）
#
# 飄字與特效都掛在被攻擊單位的「可見像素」座標上（node["head"]/node["mid"]，於 _build_unit 量測），
# 不是畫布中心——立繪畫布留白不一致，用畫布中心會偏掉。生命週期交給 Tween，結束自行 queue_free。
# =========================================================================

## 取單位的顯示節點（敵/我皆可）。
func _node_of(u: Variant) -> Variant:
	var n = _hero_node_of(u)
	return n if n != null else _foe_node_of(u)


## 飄字本體。crit=true 走「彈出放大＋大字紅色」的強調演出。
func _popup(u: Variant, text: String, color: Color, size: int, crit: bool, y_off: float = 0.0) -> void:
	if _root == null:
		return
	var node = _node_of(u)
	if node == null:
		return
	var lbl := PixelUI.label(text, size, color, 7 if crit else 5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_launch_popup(u, lbl, crit, Vector2(240.0, float(size) + 12.0), y_off)


## 飄字/飄數字的共用起飛：掛到被作用單位頭頂、上升＋淡出，crit 另加彈出放大。
func _launch_popup(u: Variant, ctrl: Control, crit: bool, node_size: Vector2, y_off: float = 0.0) -> void:
	var node = _node_of(u)
	if node == null:
		ctrl.queue_free()
		return
	var anchor: Vector2 = (node["wrap"] as Control).position + Vector2(node.get("head", Vector2.ZERO))
	ctrl.size = node_size
	ctrl.pivot_offset = node_size * 0.5
	ctrl.position = anchor + Vector2(-node_size.x * 0.5, -58.0 + y_off + randf_range(-6.0, 6.0))
	_root.add_child(ctrl)
	var tw := create_tween()
	if crit:
		ctrl.scale = Vector2(0.35, 0.35)
		tw.tween_property(ctrl, "scale", Vector2(1.4, 1.4), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(ctrl, "scale", Vector2(1.1, 1.1), 0.1)
	tw.tween_property(ctrl, "position:y", ctrl.position.y - POP_RISE, POP_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ctrl, "modulate:a", 0.0, POP_DUR * 0.55).set_delay(POP_DUR * 0.45)
	tw.tween_callback(ctrl.queue_free)


## 圖片數字：把整數排成一列 AtlasTexture（素材＝一列 10 格等寬 0..9、透明底）。
## **素材缺檔就回傳 null**，呼叫端沿用描邊字型 Label——數字圖還沒驗收進專案時遊戲照跑。
func _digits_node(n: int, target_h: float, tint: Color) -> Control:
	if _digits_tex == null:
		return null
	var full: Vector2 = _digits_tex.get_size()
	var cell := Vector2(full.x / float(DIGITS_COUNT), full.y)
	if cell.x <= 0.0 or cell.y <= 0.0:
		return null
	var s: float = target_h / cell.y
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := 0.0
	for ch in str(maxi(n, 0)):
		var at := AtlasTexture.new()
		at.atlas = _digits_tex
		at.region = Rect2(cell.x * float(int(ch)), 0.0, cell.x, cell.y)
		var tr := TextureRect.new()
		tr.texture = at
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 數字圖是平滑浮雕（非像素），縮小走 Linear
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tr.size = cell * s
		tr.position = Vector2(x, 0.0)
		tr.modulate = tint
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
		x += cell.x * s * DIGIT_KERN
	box.custom_minimum_size = Vector2(x, cell.y * s)
	return box


## 傷害數字：有數字圖就用圖（會心染紅、字更大），沒有就退回描邊字型。
## 會心另加畫面震動＋彈出放大（不加「會心一擊！」字樣，John 2026-07-28）。
func _popup_damage(u: Variant, dmg: int, crit: bool) -> void:
	if crit:
		_shake_screen(CRIT_SHAKE_AMP, SCREEN_SHAKE_DUR)
	var box := _digits_node(dmg, CRIT_DIGIT_H if crit else DMG_DIGIT_H, PixelUI.CRIT if crit else Color.WHITE)
	if box != null:
		_launch_popup(u, box, crit, box.custom_minimum_size)
	elif crit:
		_popup(u, str(dmg), PixelUI.CRIT, 54, true)
	else:
		_popup(u, str(dmg), Color(1.0, 0.87, 0.85), 34, false)


func _popup_heal(u: Variant, amount: int, kind: String) -> void:
	if amount <= 0:
		return
	_popup(u, "+" + str(amount) + " " + kind, PixelUI.GOOD if kind == "HP" else PixelUI.MP, 30, false)


func _popup_miss(u: Variant) -> void:
	_popup(u, "Miss!!", Color(0.85, 0.92, 1.0), 32, false)


## 普攻受擊特效種類：角色專屬（SPRITE_FX）優先，否則依攻擊者武器類別（有刃＝斬光、其餘＝白火花）。
## 敵人沒有 sprite 對映也沒有 weapon_type → 白火花。
func _phys_fx(a: Dictionary) -> String:
	var own := String(SPRITE_FX.get(String(a.get("sprite", "")), ""))
	if own != "":
		return own
	return String(WTYPE_FX.get(_weapon_type(a), "blunt"))


## 技能命中特效：角色專屬（SPRITE_SKILL_FX）優先，否則依技能屬性（魔法系＝藍星爆、物理系＝紅橙爆）。
func _skill_fx(a: Dictionary, attr: String) -> String:
	var own := String(SPRITE_SKILL_FX.get(String(a.get("sprite", "")), ""))
	if own != "":
		return own
	return "magic" if attr == "int" else "burst"


## 排入「跟攻擊動畫同時起」的受擊特效：at＝相對本次 lunge 起點的秒數（普攻＝動畫階段開始、技能＝0）。
## 傷害數字/震動仍走 _apply_pending_hits（等音效的 lead-in 播完），兩者刻意分開。
func _queue_fx(t: Dictionary, kind: String, at: float) -> void:
	_fx_queue.append({"t": t, "kind": kind, "at": at})


func _tick_fx_queue() -> void:
	for i in range(_fx_queue.size() - 1, -1, -1):
		var e: Dictionary = _fx_queue[i]
		if _lunge_t >= float(e["at"]):
			_play_hit_fx(e["t"], String(e["kind"]))
			_fx_queue.remove_at(i)


## 受擊特效：在目標身上播一組幀圖（kind 見 FX_FRAMES）。
##
## 方向：素材原方向＝我方打敵人，所以只有「打在我方身上」（＝敵人揮來）才水平翻轉。
## 大小：斬光是斜掃的長條，要比單位大才看得出來（h×1.8）；放射狀的火花/爆/魔光用 h×1.3。
## 幀數：多幀逐幀播；單幀改用縮放彈出＋淡出製造打擊感（素材只有一張也能有動態）。
func _play_hit_fx(u: Variant, kind: String) -> void:
	if _root == null:
		return
	var node = _node_of(u)
	if node == null:
		return
	var frames: Array = []
	for n in FX_FRAMES.get(kind, []):
		var t := _tex("res://assets/battle/" + String(n))
		if t != null:
			frames.append(t)
	if frames.is_empty():
		return
	var h := float(node["h"])
	# 斬光是斜掃長條、刺擊是更細更長的直線（要能穿過目標才有穿透感），放射狀（火花/爆/魔光/治療）最小。
	var s: float = clampf(h * 1.8, 120.0, 230.0) if kind == "slash" else clampf(h * 1.3, 130.0, 200.0)
	if kind == "stab":
		s = clampf(h * 2.6, 180.0, 320.0)
	elif kind == "stab_skill":
		s = clampf(h * 2.2, 170.0, 290.0)   # 斜向長條，比平刺短一點；技能命中不要蓋掉整個畫面
	var spr := TextureRect.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 手繪筆觸特效走平滑取樣（像素立繪仍各自 Nearest）
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spr.flip_h = bool(node["is_hero"])
	spr.size = Vector2(s, s)
	spr.pivot_offset = Vector2(s * 0.5, s * 0.5)
	spr.texture = frames[0]
	spr.position = (node["wrap"] as Control).position + Vector2(node.get("mid", Vector2.ZERO)) - Vector2(s * 0.5, s * 0.5)
	_root.add_child(spr)
	var tw := create_tween()
	if frames.size() >= 2:
		for i in range(1, frames.size()):
			var tex: Texture2D = frames[i]
			tw.tween_callback(func(): spr.texture = tex).set_delay(FX_DT)
		tw.tween_callback(spr.queue_free).set_delay(FX_DT)
	else:
		spr.scale = Vector2(0.6, 0.6)
		tw.tween_property(spr, "scale", Vector2(1.15, 1.15), FX_PUNCH).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(spr, "scale", Vector2(1.3, 1.3), FX_PUNCH * 1.4)
		tw.parallel().tween_property(spr, "modulate:a", 0.0, FX_PUNCH * 1.4)
		tw.tween_callback(spr.queue_free)


## 畫面震動（會心一擊）：整個 Root 隨機抖動、隨剩餘時間衰減，結束歸位。
func _shake_screen(amp: float, dur: float) -> void:
	_screen_shake_amp = maxf(_screen_shake_amp, amp)
	_screen_shake_t = maxf(_screen_shake_t, dur)


func _tick_screen_shake(delta: float) -> void:
	if _root == null or _screen_shake_t <= 0.0:
		return
	_screen_shake_t -= delta
	if _screen_shake_t <= 0.0:
		_root.position = _root_base
		_screen_shake_amp = 0.0
		return
	var k := clampf(_screen_shake_t / SCREEN_SHAKE_DUR, 0.0, 1.0)
	_root.position = _root_base + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _screen_shake_amp * k


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
	_lunge_move = false                       # 敵方走自己的 sin 位移（見 foe 渲染），不走分階段
	_lunge_target = null
	_lunge_dur = LUNGE_DUR                     # 敵方 lunge 沿用原時序
	_lunge_impact = LUNGE_DUR * IMPACT_FRAC
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
			_popup_heal(t2, heal, "HP")
			_play_hit_fx(t2, "heal")
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
				_popup_damage(hero, int(r["dmg"]), bool(r["crit"]))
				_play_hit_fx(hero, "magic")
				_kill(hero)
			AudioManager.sfx("att_monster_punch.mp3")   # 對應 build_cq2.py L3222/L3239（敵方傷害）
			AudioManager.sfx("hurt.wav")
			_banner(String(a.get("name", "")) + " 使出【" + String(fsk.get("name", "")) + "】！全體共受到 " + str(tot) + " 傷害")
			_finish_foe()
			return
		else:
			var t3: Dictionary = alive[randi() % alive.size()]
			if DamageCalc.is_dodge(a, t3):
				_popup_miss(t3)
				_banner(String(t3.get("name", "")) + " 閃開了 " + String(a.get("name", "")) + " 的【" + String(fsk.get("name", "")) + "】！")
				_finish_foe()
				return
			var r2 := DamageCalc.foe_named_skill_damage(a, t3, mult)
			t3["hp"] = float(t3.get("hp", 0)) - float(r2["dmg"])
			_popup_damage(t3, int(r2["dmg"]), bool(r2["crit"]))
			_play_hit_fx(t3, "magic")
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
			_popup_damage(hero2, int(r3["dmg"]), bool(r3["crit"]))
			_play_hit_fx(hero2, _phys_fx(a))
			_kill(hero2)
		AudioManager.sfx("att_monster_punch.mp3")
		AudioManager.sfx("hurt.wav")
		_banner(String(a.get("name", "")) + " 的橫掃攻擊！全體共受到 " + str(tot2) + " 傷害")
		_finish_foe()
		return

	# 第 4 段：一般單體攻擊（fallback）
	var t: Dictionary = alive[randi() % alive.size()]
	if DamageCalc.is_dodge(a, t):
		_popup_miss(t)
		_banner(String(t.get("name", "")) + " 靈巧地閃開了 " + String(a.get("name", "")) + " 的攻擊！")
		_finish_foe()
		return
	var r4 := DamageCalc.phys_damage(a, t)
	t["hp"] = float(t.get("hp", 0)) - float(r4["dmg"])
	_popup_damage(t, int(r4["dmg"]), bool(r4["crit"]))
	_play_hit_fx(t, _phys_fx(a))
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
	# F-9 EXPSCALE 已於 spec v4.2 移除：實得 EXP＝敵人資料表原始值總和，與設定集標示一致。
	var exp := 0
	var gold := 0
	for f in foes:
		exp += int(f.get("exp", 0))
		gold += int(f.get("gold", 0))
	exp = maxi(1, exp)

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
		# need == 0 ＝ 已達經驗表的滿級（see specs/BATTLE_FORMULAS.md F-2）；沒有這個條件會無限迴圈。
		while ExpNeed.exp_need(int(m.get("lv", 1))) > 0 and int(m["exp"]) >= ExpNeed.exp_need(int(m.get("lv", 1))):
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
	if enc == "bear_rematch":
		GameState.inv_add("fire_honey", 1)
		GameState.flag_set("got_honey", 1)
		drop_msg += "\n這次，我沒有逃。老樹上的『烈火蜂蜜』到手了！"
	if enc == "necro":
		GameState.flag_set("marin_curse", 1)
		drop_msg += "\n擊退了死靈術士……但瑪琳的手腕，浮現出一圈黑色咒印。"

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

## 站位（2026-07-30 John 指定）：最前排的腳點＝下方面板上緣往上 15px，往後每排再上移一個 step；
## 越靠下＝越前面（圖層由 _sort_units_by_depth() 依腳點 y 重排，不用 z_index 以免蓋到下方面板）。
const PANEL_TOP := 556.0                       # 下方「行動」面板上緣（見 _build_action_panel）
const FRONT_GAP := 15.0                        # 最前排腳點離面板上緣
const ROW_Y0 := PANEL_TOP - FRONT_GAP          # 541：最前排的地面線
const FOE_ROW_STEP := 56.0
const HERO_X := [1074.0, 1180.0, 1044.0, 1160.0]   # 非三人時的交錯站位
const HERO_ROW_STEP := 70.0                    # 非三人時每往後一排上移的距離
## 三人隊伍：共用同一個 x、一排一排往上疊（座標讀自 John 2026-07-30 的截圖標記，誤差約 ±10px）。
const HERO_X_ALIGNED := 975.0
const HERO_ROW_STEP_ALIGNED := 120.0           # 三人時的排距（腳點 541 / 421 / 301）
const FOE_X := [300.0, 190.0, 324.0, 168.0, 300.0]   # 第 5 槽為敵人數上限 5 新增
const HERO_H := 250.0   # 我方戰鬥立繪：2026-07-27 放大成 2 倍（208）→ 2026-07-30 John 再 +20%
const FOE_H := 98.0     # 原 82，2026-07-30 同步 +20%；只在敵人貼圖量不到可見像素時當退路（見 FOE_GEO）
const BOSS_H := 168.0   # 原 140，2026-07-30 同步 +20%
## 敵人立繪的統一顯示量級：以「可見像素的幾何均值」√(可見寬 × 可見高) 為基準，不再把畫布塞進固定框。
## 為什麼改（2026-07-30 John 實機回饋「狼偏小、離血條很遠、沒有靠下對齊」）：敵人貼圖畫布比例落差極大
## （野狼 112×50、骷髏 41×60），固定框 88×98 ＋ KEEP_ASPECT 會讓寬扁的四足獸被寬度卡住——野狼只畫出
## 88×39（幾何均值 58.9），骷髏卻是 67×98（81.0）；且 KEEP_ASPECT 是**置中**，狼腳浮在地面線上方 29px，
## 而血條掛在地面線下 6px，看起來就是「浮空又離血條很遠」。我方立繪本來就有 _build_fits 做等身校正，
## 敵人這條路徑先前完全沒有校正。
## 110＝John 從 76／110／150 三檔截圖挑定（2026-07-30）：76 是改動前全體幾何均值的中位數，一致但整體
## 偏小（骷髏只有我方 250px 的 37%）；110 讓骷髏約 53%、野狼 165×74，敵我比例合理；150 起兩隻狼會互相
## 重疊，且骷髏原生只有 41×60、放大 3 倍後像素塊變粗（敵人是放大、我方立繪是縮小，密度差看得出來——
## 要再大得等敵人戰鬥圖以更高解析度重產）。個別單位要再大或再小，用 EnemyDef.battle_scale 在 .tres
## 微調（bear_dire 已在用）。
const FOE_GEO := 110.0
const BOSS_GEO := 188.0   # big 敵人（劇情 boss）；比例沿用改動前的 BOSS_H / FOE_H ≈ 1.71
const HERO_RATIO := {"ludo": 0.75, "marin": 0.58, "alan": 0.80}   # 由目前戰鬥幀的角色畫布比例換算；Ludo 已改用 HD Pixel idle 四幀
## 攻擊/技能幀的**額外**放大倍率（藝術倍率）。基準倍率由 _build_unit() 自動算出：把攻擊 strip 中主體
## 最高的一幀對齊該角色 idle 的主體高度（各角色攻擊幀畫布比例都不同——ludo 628×678、marin 900×850、
## alan 802×640，idle 都是 3:4——KEEP_ASPECT 會讓角色忽大忽小）。
## 基準倍率**整段動畫共用一個值**（不逐幀算，否則蹲低的幀會被放大成一呼一吸）。
## 2026-07-29 John 回饋「攻擊時放大又上移」：舊做法拿「可見高度」對齊（被舉起的劍拉高→角色被縮小），
## 再用 ludo 1.40 硬補回來，總倍率變成 idle 的 1.3 倍。改成量主體高度後不需要藝術倍率，一律 1.0。
const ATTACK_SCALE := {}
## 傷害數字用的圖片字：一張橫向 10 格等寬的 0..9、透明底。缺檔＝自動退回描邊字型（見 _digits_node）。
const DIGITS_PATH := "res://assets/ui/dmg_digits.png"
const DIGITS_COUNT := 10
const DMG_DIGIT_H := 40.0             # 一般傷害的數字顯示高（px）
const CRIT_DIGIT_H := 62.0            # 會心傷害的數字顯示高
const DIGIT_KERN := 0.82              # 字距：每位往右推 (格寬 × 此值)，<1＝略為靠攏
const ARROW_H := 32.0                 # marker_arrow 三角高＋間隙：箭頭尖端離頭頂的距離
const POP_RISE := 46.0                # 飄字上升距離
const POP_DUR := 0.8                  # 飄字停留時間
const CRIT_SHAKE_AMP := 13.0          # 會心一擊畫面震動幅度（px）
const SCREEN_SHAKE_DUR := 0.34        # 畫面震動時長
## 受擊特效幀（素材規格見 docs/design/戰鬥立繪規格.md「六、受擊特效」）。多幀＝逐幀播；
## 單幀＝縮放彈出＋淡出（見 _play_hit_fx()）。換圖只要覆蓋同名檔，這裡不用改。
const FX_FRAMES := {
	"slash": ["fx_slash_0.png", "fx_slash_1.png", "fx_slash_2.png", "fx_slash_3.png"],
	"blunt": ["fx_blunt_0.png"],
	"burst": ["fx_burst_0.png"],
	"magic": ["fx_magic_0.png", "fx_magic_1.png", "fx_magic_2.png", "fx_magic_3.png", "fx_magic_4.png"],
	"stab_skill": ["fx_stab_skill_0.png", "fx_stab_skill_1.png", "fx_stab_skill_2.png", "fx_stab_skill_3.png", "fx_stab_skill_4.png"],
	"heal": ["fx_heal_0.png", "fx_heal_1.png", "fx_heal_2.png", "fx_heal_3.png"],
	"stab": ["fx_stab_0.png", "fx_stab_1.png", "fx_stab_2.png", "fx_stab_3.png"],
}
const WTYPE_FX := {"sword": "slash", "dagger": "slash", "claw": "slash"}   # 有刃武器＝斬光；其餘（杖/鈍器/徒手/敵人）＝白火花
## 角色專屬的普攻特效，**優先於 WTYPE_FX**（2026-07-30 John：只有瑪琳用刺擊，不是所有匕首）。
## 之所以綁 sprite 而不是武器類別：這是「這個角色怎麼打」的演出設定，換武器不該換掉她的招式感。
## 之後若每個角色都要專屬特效，再改成 PartyMemberDef 的資料欄位（現在只有一筆，不值得動資料層）。
const SPRITE_FX := {"marin": "stab"}
## 同上，但用於**技能**命中（優先於「attr==int → magic、其餘 → burst」的預設）。
const SPRITE_SKILL_FX := {"marin": "stab_skill"}
const FX_DT := 0.07                   # 受擊特效每幀秒數（多幀）
const FX_PUNCH := 0.09                # 單幀特效每段秒數（縮放彈出）
const FRAME_DT := 0.18
# 我方發動攻擊時向前（敵方在左＝-x）踏步出招再回位。
const LUNGE_DUR := 0.55
const LUNGE_DIST := 120.0
const ATTACK_POS := Vector2(820, 480)   # 攻擊時角色直接移到的「隊伍前出場位」（隊伍在右、敵在左）
const ATTACK_FRONT_GAP := 150.0         # 普攻位移：停在目標右前方（我方在右）此距離處
# 我方普攻分階段時序（2026-07-27 John 指定）：移動到目標前→停 0.2s→演攻擊動畫(配音效)→目標震動→返回原位。
const LM_APPROACH := 0.18   # 移動到目標前方
const LM_WAIT := 0.20       # 到位停頓
const LM_ATTACK := 0.45     # 攻擊動畫演示
const LM_SWING := 0.14      # 攻擊階段內「揮出命中」時點（相對 attack 起點，觸發音效/傷害/震動）
const LM_RETURN := 0.20     # 返回原位
const SKILL_LUNGE_DUR := 0.6   # 技能/道具：原位演示總時長
const SKILL_IMPACT := 0.18     # 技能命中時點
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
var _lunge_move: bool = false        # 本次 lunge 是否位移：普攻＝移動到目標前方再回位；技能＝原位施放
var _lunge_target: Variant = null    # 普攻位移的目標單位（用來求其前方站位）
var _lunge_dur: float = LUNGE_DUR             # 本次 lunge 總時長（依 普攻/技能/敵方 各異）
var _lunge_impact: float = LUNGE_DUR * IMPACT_FRAC   # 本次 lunge 揮出命中時點（音效/傷害/震動）
var _fx_queue: Array = []            # 依 _lunge_t 觸發的受擊特效 [{t, kind, at}]（特效跟攻擊動畫同時起，不等傷害結算）
var _pending_hits: Array = []        # 我方攻擊/技能：延到音效播完才套用的傷害清單 [{t, dmg}, ...]
var _pending_hit_timer: float = 0.0  # delta 倒數，歸零時套用 _pending_hit（音效先完、再扣血＋被打聲）
var _shake_unit: Variant = null      # 被攻擊而震動中的對象（敵/我皆可）
var _shake_t: float = 0.0            # 震動剩餘時間（delta 倒數）
var _boss_disp_r: float = 1.0        # boss 血條顯示比例（漸減動畫用）
var _screen_shake_t: float = 0.0     # 畫面震動剩餘時間
var _digits_tex: Texture2D = null    # 傷害數字圖（DIGITS_PATH）；null＝素材未進專案，改用描邊字型
var _screen_shake_amp: float = 0.0   # 畫面震動幅度
var _root_base: Vector2 = Vector2.ZERO   # Root 原位（震動歸位用）
static var _log_visible: bool = false    # 上方戰鬥訊息：預設不顯示（2026-07-28 John），同 session 記住玩家的切換
var _root: Control
var _bg: TextureRect
var _boss_name: Label
var _boss_bar_bg: ColorRect
var _boss_bar_fill: ColorRect
var _log_label: Label
var _log_bg: PanelContainer
var _log_btn: Button
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
var _cursor: Control
var _actor_arrow: Control
var _result_overlay: Control
var _result_title: Label
var _result_msg: Label
var _result_hint: Label
var _result_btn: Button


func _build_view() -> void:
	_root = $View/Root
	_root_base = _root.position
	_digits_tex = _tex(DIGITS_PATH)
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
	_sort_units_by_depth()

	# --- 目標游標 + 行動者箭頭 ---
	var MarkerArrow := load("res://scripts/battle/marker_arrow.gd")
	_cursor = MarkerArrow.new()          # 選取目標游標（向下三角）
	_cursor.visible = false
	_root.add_child(_cursor)
	_actor_arrow = MarkerArrow.new()     # 行動者指示（同造型）
	_actor_arrow.visible = false
	_root.add_child(_actor_arrow)

	# --- 上方：戰鬥訊息（預設隱藏，右上「訊息」鈕可開；傷害改用頭上飄字表達）---
	_log_bg = PixelUI.panel(Color(0.047, 0.055, 0.102, 0.42), 2)
	_log_bg.position = Vector2(30, 18)
	_log_bg.custom_minimum_size = Vector2(700, 0)
	_log_bg.visible = _log_visible
	_log_label = PixelUI.label("", 19, Color(0.922, 0.922, 0.96), 3)
	_log_label.custom_minimum_size = Vector2(672, 0)
	_log_bg.add_child(_log_label)
	_root.add_child(_log_bg)

	# --- 上方右：訊息顯示切換鈕 ---
	_log_btn = PixelUI.button("訊息　關", PixelUI.CYAN, 17)
	_log_btn.anchor_left = 1.0
	_log_btn.anchor_right = 1.0
	_log_btn.offset_left = -300.0
	_log_btn.offset_right = -166.0
	_log_btn.offset_top = 18.0
	_log_btn.offset_bottom = 56.0
	_log_btn.pressed.connect(_on_log_pressed)
	_root.add_child(_log_btn)

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


## 槽位座標：第 0 槽最靠下（最前），往後每槽上移一個 step。我方剛好三人時三人共用同一個 x。
func _slot_pos(is_hero: bool, idx: int) -> Vector2:
	if is_hero:
		if heroes.size() == 3:
			return Vector2(HERO_X_ALIGNED, ROW_Y0 - HERO_ROW_STEP_ALIGNED * float(idx))
		return Vector2(HERO_X[idx % HERO_X.size()], ROW_Y0 - HERO_ROW_STEP * float(idx))
	return Vector2(FOE_X[idx % FOE_X.size()], ROW_Y0 - FOE_ROW_STEP * float(idx))


## 越靠下＝越前面：在 _root 的子節點順序裡把所有單位依腳點 y 由小到大重排（後畫的蓋在前畫的上面）。
## 只重排「單位」這一段（背景固定 index 0，游標/箭頭/面板都在單位之後建立，順序不受影響），
## 刻意不用 z_index——單位一旦 z_index > 0 就會蓋在下方指令面板與血條上。
func _sort_units_by_depth() -> void:
	var wraps: Array = []
	for n in _foe_nodes:
		wraps.append(n["wrap"])
	for n2 in _hero_nodes:
		wraps.append(n2["wrap"])
	wraps.sort_custom(func(a, b): return (a as Control).position.y < (b as Control).position.y)
	for i in range(wraps.size()):
		_root.move_child(wraps[i], 1 + i)   # index 0＝背景


## 建一個站在地面上的單位（敵人或英雄）。foot-anchor：wrap 在腳點，sprite 從 -h 到 0。
func _build_unit(u: Dictionary, is_hero: bool) -> Dictionary:
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.position = _slot_pos(is_hero, int(u.get("slot", 0)))
	_root.add_child(wrap)

	var frames := _load_frames(u, is_hero)
	var anim_frames: Dictionary = _load_anim_frames(u) if is_hero else {}
	# 我方受傷/死亡單張（hero_<id>_hurt/death.png；缺檔則沿用 idle＋既有處理）
	var hurt_tex: Texture2D = null
	var death_tex: Texture2D = null
	if is_hero:
		var sid := String(u.get("sprite", ""))
		var hpath := "res://assets/battle/hero_%s_hurt.png" % sid
		var dpath := "res://assets/battle/hero_%s_death.png" % sid
		if ResourceLoader.exists(hpath):
			hurt_tex = load(hpath)
		if ResourceLoader.exists(dpath):
			death_tex = load(dpath)
	# 敵人高度＝（big 用 BOSS_H、其餘 FOE_H）× EnemyDef.battle_scale（劇情 boss 的壓迫感由資料調，見 enemy_def.gd）
	var default_foe_h: float = BOSS_H if bool(u.get("big", false)) else FOE_H
	var foe_h: float = float(u.get("battle_height", default_foe_h)) * maxf(0.1, float(u.get("battle_scale", 1.0)))
	var h: float = HERO_H if is_hero else foe_h
	var ratio: float = (float(HERO_RATIO.get(String(u.get("sprite", "")), 0.8)) if is_hero else 0.9)
	var w := h * ratio

	# 敵人：改用「可見像素正規化＋貼底」（見 FOE_GEO／_foe_fit）。量不到像素（缺圖、壓縮貼圖）就沿用固定框。
	var foe_fit: Dictionary = {}
	if not is_hero and not frames.is_empty():
		var geo_base: float = BOSS_GEO if bool(u.get("big", false)) else FOE_GEO
		foe_fit = _foe_fit(frames[0], geo_base * maxf(0.1, float(u.get("battle_scale", 1.0))))
	if not foe_fit.is_empty():
		w = float(foe_fit["vis_w"])   # 名字／血條／箭頭／飄字都改掛在可見像素的寬高上
		h = float(foe_fit["vis_h"])

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
	# 敵人走 _foe_fit 時，size/pos 是「整張畫布」等比放大後的值（KEEP_ASPECT 剛好填滿、不留白），
	# 位移已把可見底邊推到 wrap 原點；其餘情況維持舊的固定框擺法。
	var spr_pos := Vector2(-w * 0.5, -h)
	spr.size = Vector2(w, h) if foe_fit.is_empty() else Vector2(foe_fit["size"])
	if not foe_fit.is_empty():
		spr_pos = Vector2(foe_fit["pos"])
	spr.position = spr_pos
	spr.pivot_offset = -spr_pos   # 可見腳底中心＝wrap 原點：選中放大時原地長大不位移
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

	# 走 _foe_fit 的敵人已經把可見像素對齊了（水平中心 x=0、底邊 y=0），錨點直接由可見高度推出。
	var anchors := ({"head": Vector2(0.0, -h), "mid": Vector2(0.0, -h * 0.5)} if not foe_fit.is_empty()
			else _visible_anchors(frames, w, h))
	var fits := _build_fits(String(u.get("sprite", "")), frames, anim_frames, hurt_tex, death_tex, w, h)

	return {"unit": u, "wrap": wrap, "sprite": spr, "name": name_lbl, "hp_fill": hp_fill, "frames": frames, "anim_frames": anim_frames, "hurt_tex": hurt_tex, "death_tex": death_tex, "is_hero": is_hero, "h": h, "base": wrap.position, "spr_y": spr_pos.y, "head": anchors["head"], "mid": anchors["mid"], "fits": fits}


## 把「非 idle」的每張貼圖校正到與 idle 相同的人物大小與地面線，回傳 Texture2D → {s, off} 對照表。
## idle 是基準（s=1、off=0，不入表）；查不到的貼圖一律當基準處理，所以敵人不需要這張表。
##
## 為什麼要校正：同一角色的 idle／attack／hurt／death 是分批產的，畫布尺寸與角色在畫布裡的佔比都不同
## （例：ludo idle 543×724、attack 628×678、hurt/death 1086×1448），KEEP_ASPECT 直接播會忽大忽小、
## 腳離地。校正分兩種：
##   - **直立姿勢**（attack strip／hurt）：用「主體高度」（排除舉起的武器，見 _body_height）對齊 idle。
##     attack **整段共用一個倍率**（取 strip 中主體最高的一幀當基準），否則蹲低的幀會被放大成一呼一吸。
##   - **躺姿**（death）：主體高度沒有可比性（人是橫的），維持素材原始比例（s=1）只做貼底。
## attack 沿用素材已鎖定的共同腳點，只以首幀算一次貼底補正；hurt／death 則各自貼底。
func _build_fits(sprite_id: String, frames: Array, anim_frames: Dictionary, hurt_tex: Texture2D, death_tex: Texture2D, w: float, h: float) -> Dictionary:
	var fits := {}
	if frames.is_empty():
		return fits
	var idle_bottom: float = float(_frame_metrics(frames[0], w, h)["bottom"])
	var idle_body := _body_height(frames[0], w, h)

	var atks: Array = anim_frames.get("attack", [])
	if not atks.is_empty():
		var max_body := 0.0
		for at in atks:
			max_body = maxf(max_body, _body_height(at, w, h))
		var s := 1.0
		if idle_body > 0.0 and max_body > 0.0:
			s = idle_body / max_body
		s *= float(ATTACK_SCALE.get(sprite_id, 1.0))
		# Attack strip 已在素材階段鎖定共同腳點；整段共用首幀的貼底補正，避免蹲低／跨步幀
		# 因另一隻腳底較低而被 runtime 逐幀重新上推，破壞已核可的水平／垂直錨點。
		var attack_off := idle_bottom - float(_frame_metrics(atks[0], w, h)["bottom"]) * s
		for at2 in atks:
			fits[at2] = {"s": s, "off": attack_off}

	if hurt_tex != null:
		var hb := _body_height(hurt_tex, w, h)
		var hs: float = (idle_body / hb) if (idle_body > 0.0 and hb > 0.0) else 1.0
		fits[hurt_tex] = {"s": hs, "off": idle_bottom - float(_frame_metrics(hurt_tex, w, h)["bottom"]) * hs}

	if death_tex != null:
		fits[death_tex] = {"s": 1.0, "off": idle_bottom - float(_frame_metrics(death_tex, w, h)["bottom"])}
	return fits


## 敵人立繪的正規化擺放：把 tex 的可見像素縮到 geo 量級（幾何均值），並讓可見底邊踩在 wrap 原點
## （＝地面線）、可見水平中心對齊 wrap 的 x。回傳 sprite 該用的 size/position 與正規化後的可見寬高；
## 量不到（缺圖／壓縮貼圖／全透明）回傳空 Dictionary，呼叫端退回固定框擺法。see FOE_GEO
##
## 只用 idle 第 0 幀當基準，其餘幀共用同一組 size/position——逐幀重量會讓兩幀 idle 的可見範圍差異
## 變成一呼一吸的抖動（跟我方 _build_fits 刻意整段共用一個倍率同理）。
func _foe_fit(tex: Texture2D, geo: float) -> Dictionary:
	if tex == null:
		return {}
	var img: Image = tex.get_image()
	if img == null or img.is_compressed():
		return {}
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return {}
	var k: float = geo / sqrt(float(used.size.x) * float(used.size.y))
	return {
		"size": Vector2(float(img.get_width()) * k, float(img.get_height()) * k),
		"pos": Vector2(-(float(used.position.x) + float(used.size.x) * 0.5) * k,
				-(float(used.position.y) + float(used.size.y)) * k),
		"vis_w": float(used.size.x) * k,
		"vis_h": float(used.size.y) * k,
	}


## 量一張貼圖在「w×h ＋ STRETCH_KEEP_ASPECT」框內的可見像素幾何。
## vis_h＝可見部分的顯示高度（px）；bottom＝可見底邊相對「地面」（wrap 原點）的 y（負值＝在地面上方）。
func _frame_metrics(tex: Texture2D, w: float, h: float) -> Dictionary:
	if tex == null:
		return {"vis_h": h, "bottom": 0.0}
	var img: Image = tex.get_image()
	if img == null or img.is_compressed():
		return {"vis_h": h, "bottom": 0.0}
	var used := img.get_used_rect()
	if used.size.y <= 0:
		return {"vis_h": h, "bottom": 0.0}
	var tw := float(img.get_width())
	var th := float(img.get_height())
	var k: float = minf(w / tw, h / th)
	var top := (h - th * k) * 0.5     # KEEP_ASPECT 置中留白
	return {"vis_h": float(used.size.y) * k, "bottom": top + float(used.position.y + used.size.y) * k - h}


## 一列要有多少比例的不透明像素才算「主體」（而非舉起的劍/法杖等細長物）。頭部寬度遠超這個門檻。
const BODY_ROW_COVER := 0.10

## 量「主體」的顯示高度（px）＝頭頂（第一條達到 BODY_ROW_COVER 覆蓋率的橫排）到可見底邊（腳）。
## 量不到（缺圖／壓縮貼圖／全透明）時回傳 0，呼叫端自行退回不校正。
func _body_height(tex: Texture2D, w: float, h: float) -> float:
	if tex == null:
		return 0.0
	var img: Image = tex.get_image()
	if img == null or img.is_compressed():
		return 0.0
	var used := img.get_used_rect()
	if used.size.y <= 0:
		return 0.0
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate() as Image
		img.convert(Image.FORMAT_RGBA8)
	var wpx := img.get_width()
	var data := img.get_data()
	var need: int = maxi(16, int(float(wpx) * BODY_ROW_COVER))
	var step := 2                          # 每兩像素取一點：夠判斷覆蓋率，省掉一半掃描量
	var body_top := -1
	for y in range(used.position.y, used.position.y + used.size.y):
		var cnt := 0
		var base: int = y * wpx * 4
		for x in range(0, wpx, step):
			if data[base + x * 4 + 3] > 8:
				cnt += step
				if cnt >= need:
					body_top = y
					break
		if body_top >= 0:
			break
	if body_top < 0:
		return 0.0
	var k: float = minf(w / float(wpx), h / float(img.get_height()))
	return float(used.position.y + used.size.y - body_top) * k


## 量出立繪「實際可見像素」的頭頂與身體中心（相對 wrap 原點＝腳點），供箭頭/游標/飄字/特效定位。
## 立繪畫布留白左右不對稱、角色也不一定貼齊畫布底（例：hero_ludo_idle_0 的可見框中心在畫布 61% 處），
## 只用畫布中心會讓箭頭偏一邊、飄字浮在半空。缺圖或無法讀像素時退回畫布幾何中心。
func _visible_anchors(frames: Array, w: float, h: float) -> Dictionary:
	var head := Vector2(0.0, -h)
	var mid := Vector2(0.0, -h * 0.5)
	if not frames.is_empty():
		var img: Image = (frames[0] as Texture2D).get_image()
		if img != null and not img.is_compressed():
			var used := img.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				var tw := float(img.get_width())
				var th := float(img.get_height())
				var k: float = minf(w / tw, h / th)       # STRETCH_KEEP_ASPECT：等比縮到 rect 內、置中
				var ox := -w * 0.5 + (w - tw * k) * 0.5
				var oy := -h + (h - th * k) * 0.5
				var cx: float = ox + (float(used.position.x) + float(used.size.x) * 0.5) * k
				head = Vector2(cx, oy + float(used.position.y) * k)
				mid = Vector2(cx, oy + (float(used.position.y) + float(used.size.y) * 0.5) * k)
	return {"head": head, "mid": mid}


func _load_frames(u: Dictionary, is_hero: bool) -> Array:
	var out: Array = []
	var s := String(u.get("sprite", ""))
	if is_hero:
		for i in range(4):
			var p := "res://assets/battle/hero_%s_idle_%d.png" % [s, i]
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


## 普攻音效。2026-07-28 John 要求「技能與攻擊音效互換」：普攻改播原本的技能音
## （杖＝att_magic，其餘＝att_sword_skill），技能改播武器音（見 _skill_sfx()）。要換回舊配置就把這兩個函式互換。
func _atk_sfx(a: Dictionary) -> String:
	return "att_magic.mp3" if _weapon_type(a) == "staff" else "att_sword_skill.mp3"


## 技能音效（與普攻互換後＝武器類別音效）。`sk.sfx` 有明確指定時仍以它為準。
func _skill_sfx(a: Dictionary, sk: SkillDef) -> String:
	if sk.sfx != "":
		return sk.sfx
	return String(WTYPE_SFX.get(_weapon_type(a), "att_sword.mp3"))


## 作法 B（2026-07-27）：每角一套通用 attack 動畫（不再分 slash/thrust/spellcast）。
## 素材命名 hero_<id>_attack_0..N（見 docs/pipeline/battle_art/ Step 8）；載入器掃連號。
func _load_anim_frames(u: Dictionary) -> Dictionary:
	var s := String(u.get("sprite", ""))
	var out := {}
	var arr: Array = []
	for i in range(16):
		var p := "res://assets/battle/hero_%s_attack_%d.png" % [s, i]
		if ResourceLoader.exists(p):
			arr.append(load(p))
	if not arr.is_empty():
		out["attack"] = arr
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


## 換貼圖＋套上該貼圖的校正（見 _build_fits）：pivot 在框底中心，縮放原地長大，再用 off 把腳踩回
## idle 的地面線。查不到校正的貼圖（idle 幀、敵人）＝基準值，直接還原 scale/position。
func _set_frame(node: Dictionary, tex: Texture2D) -> void:
	var spr: TextureRect = node["sprite"]
	spr.texture = tex
	var fit: Dictionary = node.get("fits", {}).get(tex, {})
	var s := float(fit.get("s", 1.0))
	var target := Vector2(s, s)
	if spr.scale != target:
		spr.scale = target
	spr.position.y = float(node["spr_y"]) + float(fit.get("off", 0.0))


func _on_log_pressed() -> void:
	_log_visible = not _log_visible
	if _log_bg != null:
		_log_bg.visible = _log_visible
	AudioManager.sfx("select.mp3")


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


## 用 is_same()（同一個 Dictionary 實例）比對，不能用 ==：Godot 4 的 Dictionary == 是逐內容比較，
## 兩隻數值相同的同種敵人會比中同一筆，飄字/特效就會跑到錯的那隻身上。
func _hero_node_of(u: Variant) -> Variant:
	for n in _hero_nodes:
		if is_same(n["unit"], u):
			return n
	return null


func _foe_node_of(u: Variant) -> Variant:
	for n in _foe_nodes:
		if is_same(n["unit"], u):
			return n
	return null


func _refresh_ui() -> void:
	if _root == null:
		return
	if _log_visible:
		_log_label.text = msg
	var frame := int(_view_time / FRAME_DT)
	var hero_turn := actor != null and String(actor.get("side", "")) == "hero"
	var is_end := state == "win" or state == "lose"

	# 選取中的目標敵人（供其圖片微放大）
	var sel_foe: Variant = null
	if state == "target":
		var fpool: Array = foes.filter(func(u): return bool(u.get("alive", false)))
		if not fpool.is_empty():
			sel_foe = fpool[t_sel % fpool.size()]

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
		node["sprite"].scale = Vector2(1.12, 1.12) if is_same(node["unit"], sel_foe) else Vector2.ONE
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
		var alive := bool(h.get("alive", false))
		var lunging := _lunge_unit != null and is_same(node["unit"], _lunge_unit) and _lunge_t < _lunge_dur
		var anims: Dictionary = node.get("anim_frames", {})
		var atk_frames: Array = (anims.get(_lunge_anim, []) if lunging else [])   # 道具 _lunge_anim=="" → 不揮擊
		# 普攻分階段：0..t1 移動到目標前方 → t1..t2 停頓 0.2s → t2..t3 攻擊動畫 → t3.. 返回原位
		var t1 := LM_APPROACH
		var t2 := t1 + LM_WAIT
		var t3 := t2 + LM_ATTACK
		var in_attack_phase := lunging and _lunge_move and _lunge_t >= t2 and _lunge_t < t3
		if lunging and _lunge_move:
			var front := _lunge_target_front(base)
			var pos: Vector2
			if _lunge_t < t1:
				pos = base.lerp(front, _lunge_t / LM_APPROACH)        # 移動到目標前方
			elif _lunge_t < t3:
				pos = front                                            # 停頓＋攻擊：定在目標前
			else:
				pos = front.lerp(base, clampf((_lunge_t - t3) / LM_RETURN, 0.0, 1.0))   # 返回原位
			wnode.position = pos + _shake_offset_for(node["unit"])
		else:
			wnode.position = base + _shake_offset_for(node["unit"])
		# 貼圖優先序：死亡 > 受傷 > 攻擊動畫（普攻限攻擊階段；技能/原位整段）> idle
		var show_atk := not atk_frames.is_empty() and (in_attack_phase or (lunging and not _lunge_move))
		if not alive and node["death_tex"] != null:
			_set_frame(node, node["death_tex"])
		elif _is_shaking(node["unit"]) and node["hurt_tex"] != null:
			_set_frame(node, node["hurt_tex"])
		elif show_atk:
			var span: float = LM_ATTACK if _lunge_move else _lunge_dur
			var t0: float = t2 if _lunge_move else 0.0
			var si := clampi(int((_lunge_t - t0) / span * atk_frames.size()), 0, atk_frames.size() - 1)
			_set_frame(node, atk_frames[si])
		elif not frames.is_empty():
			_set_frame(node, frames[frame % frames.size()])
		wnode.visible = not is_end
		node["sprite"].modulate = Color.WHITE if (alive or node["death_tex"] != null) else Color(0.4, 0.4, 0.45, 0.9)

	# --- 行動者箭頭（對齊可見像素的頭頂中心，不是畫布中心）---
	_actor_arrow.visible = hero_turn and (state == "menu" or state == "skill" or state == "item")
	if _actor_arrow.visible:
		var hn = _hero_node_of(actor)
		if hn != null:
			var w: Control = hn["wrap"]
			var head: Vector2 = hn.get("head", Vector2(0.0, -float(hn["h"])))
			_actor_arrow.position = w.position + head - Vector2(0.0, ARROW_H)

	# --- 目標游標 ---
	_cursor.visible = state == "target" or state == "target_ally"
	if _cursor.visible:
		var pool: Array = (foes if state == "target" else heroes).filter(func(u): return bool(u.get("alive", false)))
		if not pool.is_empty():
			var tgt: Dictionary = pool[t_sel % pool.size()]
			var tn = (_foe_node_of(tgt) if state == "target" else _hero_node_of(tgt))
			if tn != null:
				var tw: Control = tn["wrap"]
				var thead: Vector2 = tn.get("head", Vector2(0.0, -float(tn["h"])))
				_cursor.position = tw.position + thead - Vector2(0.0, ARROW_H)   # 目標頭頂正上方

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

	# --- 自動鈕／訊息鈕 ---
	var auto_on := AutoBattle.is_enabled()
	_auto_btn.text = "自動　開" if auto_on else "自動　關"
	_auto_btn.add_theme_color_override("font_color", PixelUI.SEL if auto_on else PixelUI.CYAN)
	_log_btn.text = "訊息　開" if _log_visible else "訊息　關"
	_log_btn.add_theme_color_override("font_color", PixelUI.SEL if _log_visible else PixelUI.CYAN)

	# --- 勝敗結算 ---
	_result_overlay.visible = is_end
	if is_end:
		_result_title.text = "勝　利！" if state == "win" else "敗　北"
		_result_title.add_theme_color_override("font_color", PixelUI.GOLD if state == "win" else PixelUI.HP)
		_result_msg.text = win_msg
		_result_btn.text = "繼續" if state == "win" else "回到鎮上"
