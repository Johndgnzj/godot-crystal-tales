extends Node
## DialogueSystem — autoload（註冊名稱 "DialogueSystem"，見 ../../project.godot [autoload]）。
##
## NPC 對話（DLG）與過場劇情（CUTS）引擎，取代 build_cq2.py 的 st.dlg/st.dlgIdx（openOwnerDlg,
## L1516）與 st.cut/st.cutIdx/st.queue（劇情佇列, L1620-1625, L1676-1709）。
##
## 規格來源：specs/DIALOGUE_SPEC.md D-1（matchWhen／FlagMatcher）、D-2（DLG）、D-3（CUTS）。
## 資料來源：resources/content/dialogue/dialogue_db.tres（DialogueDatabase 聚合，設計員在 Godot
## Inspector 直接編輯個別 NPC／過場 .tres）。dialogue.json 已降級為「種子」，由
## scripts/dialogue/build_dialogue_tres.gd 轉成 .tres；json 本身由 extract_dialogue.py 從
## build_cq2.py 抽取（見該腳本檔頭）。
##
## 依賴（重要，見 TASKS/01_對話劇情.md 與 11_並行協作規則.md）：
## - `FlagMatcher`（res://scripts/dialogue/flag_matcher.gd）：**指定由 MOD-B 建立**，本檔案假設它
##   存在並直接呼叫 `FlagMatcher.matches(flags, when)`（D-1 簽名）。MOD-A 這邊執行當下這個檔案大概率
##   還不存在——這是刻意的，協調者合併 MOD-A/MOD-B 兩個分支後這個依賴才會補上，不代表本檔案有 bug。
## - `SaveManager`（CORE-3，autoload）：**目前連暫時性 stub 都還沒有**（不像 GameState/SceneRouter）。
##   為了不讓本檔案的可解析性綁死在一個連 stub 都不存在的 autoload 上，存檔呼叫一律透過
##   `get_node_or_null("/root/SaveManager")` 的動態查找（找不到就靜默跳過，不報錯），等 CORE-3
##   真的把 SaveManager 註冊進 [autoload] 之後不需要改本檔案任何一行就會自動生效。
##
## 不是本檔案職責範圍（其他 MOD 任務擁有，見 11_並行協作規則.md 衝突矩陣）：
## - NPC 貼近偵測／告示板／寶箱互動：MOD-B（`scripts/world/*_zone.gd`）／地圖場景本身。
## - 隊伍衍生屬性（maxhp/maxmp/patk/...）：MOD-F（`scripts/content/derive.gd`，尚未建立）。本檔案的
##   `heal` action 與 `_apply_party()` 因此只能操作/讀取既有欄位，不會、也不應該自己重算公式——這是
##   已知限制，見下方對應函式的註解與最終任務報告。
## - 對話框視覺呈現：`scenes/ui/dialogue_box.tscn`（MOD-A 先做堪用版，MOD-D 之後換裝，只透過下面的
##   signal 驅動，不直接碰 UI 節點）。

signal dialogue_started(npc_id: String, entry: DialogueEntry)
signal dialogue_line_changed(speaker: String, text: String)
signal dialogue_ended(npc_id: String)

signal cutscene_started(cut_id: String)
signal cutscene_line_changed(speaker: String, text: String)
signal cutscene_ended(cut_id: String)

## 對話/過場結束後的具名 side-effect 想開店 UI 時發這個，MOD-D 的商店 UI 負責監聽並開啟畫面。
signal shop_requested(shop_id: String)
## 過場帶 "battle" 欄位時發這個；世界場景（知道 CFG.SCENE／玩家座標）負責呼叫
## `SceneRouter.start_battle(encounter_id, 目前場景, 玩家x, 玩家y)`，本檔案不知道這些場景細節。
signal battle_requested(encounter_id: String)
## 過場帶 "transfer" 欄位時發這個；世界場景負責呼叫 `SceneRouter.go_to(to_scene, spawn_id)`。
signal scene_transfer_requested(to_scene: String, spawn_id: String)

const DB_PATH := "res://resources/content/dialogue/dialogue_db.tres"

var is_loaded: bool = false

var _dlg: Dictionary = {}    # npc_id(String) -> Array[DialogueEntry]
var _cuts: Dictionary = {}   # cut_id(String) -> CutsceneEntry

# ---- 目前對話狀態（對應 st.dlg / st.dlgIdx）----
var _current_npc_id: String = ""
var _current_dlg: DialogueEntry = null
var _dlg_idx: int = 0

# ---- 目前過場狀態（對應 st.cut / st.cutIdx）----
var _current_cut_id: String = ""
var _current_cut: CutsceneEntry = null
var _cut_idx: int = 0

# ---- 過場佇列（對應 st.queue，每幀從頭取一個播放）----
var _cut_queue: Array[String] = []


func _ready() -> void:
	_load()


func _load() -> void:
	if not ResourceLoader.exists(DB_PATH):
		push_error("DialogueSystem: 找不到 %s，請先跑 scripts/dialogue/build_dialogue_tres.gd 產生 .tres" % DB_PATH)
		return
	var db: DialogueDatabase = load(DB_PATH)
	if db == null:
		push_error("DialogueSystem: 載入 %s 失敗（不是合法 DialogueDatabase）" % DB_PATH)
		return

	_dlg.clear()
	for npc in db.npcs:
		_dlg[npc.id] = npc.entries

	_cuts.clear()
	for cut in db.cutscenes:
		_cuts[cut.id] = cut

	is_loaded = true


# =========================================================================
# 查詢
# =========================================================================

## 對話或過場任一種正在播放中（供呼叫端做移動/互動 lock，對應 GDevelop 的 `lock` 旗標）。
func is_busy() -> bool:
	return _current_dlg != null or _current_cut != null


func is_in_dialogue() -> bool:
	return _current_dlg != null


func is_in_cutscene() -> bool:
	return _current_cut != null


# =========================================================================
# NPC 對話（D-2 / openOwnerDlg L1516）
# =========================================================================

## 開啟指定 NPC 的對話：由上到下找第一個 matchWhen(when) 成立的條目（見 D-2「順序即優先權」），
## 找不到就什麼都不做並回傳 false。室外貼近 NPC 對話（L1783-1789）與室內建築物主人對話
## （openOwnerDlg, L1516）在 GDevelop 端是同一份 DLG 表、同一套邏輯，這裡統一用同一支函式服務兩者，
## 呼叫端（NPC 貼近偵測/室內互動，屬於其他 MOD 任務）只要給 npc_id 即可。
func open_npc_dialogue(npc_id: String) -> bool:
	if is_busy():
		return false
	var entries: Array = _dlg.get(npc_id, [])
	var flags: Dictionary = GameState.flags
	for entry in entries:
		if FlagMatcher.matches(flags, entry.when):
			_current_npc_id = npc_id
			_current_dlg = entry
			_dlg_idx = 0
			AudioManager.sfx("select.mp3")   # 對應 build_cq2.py L1566：開啟對話
			dialogue_started.emit(npc_id, entry)
			dialogue_line_changed.emit(entry.speaker, entry.lines[0] if entry.lines.size() > 0 else "")
			return true
	return false


## 開啟某主人「指定 cmd」的第一個 when 命中條目（對應 openOwnerCmd L1564-1567）。室內選單（interior.gd）
## 用這支：`交談`→cmd="talk"、`功能`→trade/quest/rest/pray、`一次性事件`→該事件 cmd。與 open_npc_dialogue
## 的差別只在多了 cmd 過濾（cmd 空字串視為 "talk"，對齊原始碼 `e.cmd||"talk"`）。找不到回傳 false。
func open_owner_cmd(npc_id: String, cmd: String = "talk") -> bool:
	if is_busy():
		return false
	if cmd == "":
		cmd = "talk"
	var flags: Dictionary = GameState.flags
	for entry in _dlg.get(npc_id, []):
		var ecmd: String = entry.cmd if entry.cmd != "" else "talk"
		if ecmd != cmd:
			continue
		if FlagMatcher.matches(flags, entry.when):
			_current_npc_id = npc_id
			_current_dlg = entry
			_dlg_idx = 0
			AudioManager.sfx("select.mp3")   # 對應 build_cq2.py L1566
			dialogue_started.emit(npc_id, entry)
			dialogue_line_changed.emit(entry.speaker, entry.lines[0] if entry.lines.size() > 0 else "")
			return true
	return false


## 依主人清單掃出室內動態指令選單（對應 buildIntCmds L1575-1582）：
##   [交談] ＋ [功能(trade/quest/rest/pray，每種只一次、建表不檢查 when)] ＋ [符合 when 且未完成的一次性事件] ＋ [離開]
## 回傳 [{cmd, label, who?}]；`交談`/`離開` 無 who（interior.gd 用主人清單自行處理接力）。
func get_interior_commands(owner_ids: Array) -> Array:
	var flags: Dictionary = GameState.flags
	var cmds: Array = [{"cmd": "talk", "label": "交談"}]
	var func_seen: Dictionary = {}
	for oid in owner_ids:
		for entry in _dlg.get(str(oid), []):
			var k: String = entry.cmd if entry.cmd != "" else "talk"
			if k == "talk":
				continue
			if k == "trade" or k == "quest" or k == "rest" or k == "pray":
				if not func_seen.has(k):
					func_seen[k] = true
					cmds.append({"cmd": k, "label": entry.label if entry.label != "" else k, "who": oid})
			elif FlagMatcher.matches(flags, entry.when) and not (entry.done != "" and int(flags.get(entry.done, 0)) != 0):
				cmds.append({"cmd": k, "label": entry.label if entry.label != "" else "？", "who": oid})
	cmds.append({"cmd": "leave", "label": "離開"})
	return cmds


## 不透過 DLG 表、臨時顯示一段訊息的對話框（對應告示板 boardLines()／寶箱開啟訊息 openChest()
## 那種「動態組字串、非 DLG 表驅動」的 st.dlg 用法，見 build_cq2.py L1616/L1791）。action 留給呼叫端
## 之後若也想掛副作用；目前已知用途（告示板/寶箱）都不需要 action。
func show_message(speaker: String, lines: PackedStringArray, action: String = "") -> bool:
	if is_busy():
		return false
	var entry := DialogueEntry.new()
	entry.when = "always"
	entry.speaker = speaker
	entry.lines = lines
	entry.action = action
	_current_npc_id = ""
	_current_dlg = entry
	_dlg_idx = 0
	AudioManager.sfx("select.mp3")   # 對應 build_cq2.py L1866：告示板/臨時訊息開啟
	dialogue_started.emit("", entry)
	dialogue_line_changed.emit(entry.speaker, entry.lines[0] if entry.lines.size() > 0 else "")
	return true


## 由呼叫端（對話框 UI／輸入層）驅動，對應「按下確認鍵」；同一時間只有對話或過場其中一種在播。
func advance() -> void:
	if _current_dlg != null:
		_advance_dialogue()
	elif _current_cut != null:
		_advance_cutscene()


func _advance_dialogue() -> void:
	_dlg_idx += 1
	if _dlg_idx < _current_dlg.lines.size():
		dialogue_line_changed.emit(_current_dlg.speaker, _current_dlg.lines[_dlg_idx])
		return

	var action := _current_dlg.action
	var npc_id := _current_npc_id
	_current_dlg = null
	_current_npc_id = ""
	_dlg_idx = 0

	if action != "":
		_run_action(action)
		_try_save()

	dialogue_ended.emit(npc_id)
	_drain_cut_queue()


# =========================================================================
# 過場劇情（D-3）
# =========================================================================

## 觸發來源（trigger/戰後劇情推進等，見 MOD-B／世界場景）呼叫這個把 cut_id 排進佇列，對應
## `st.queue.push(cut_id)`。`once` 旗標已完成時直接忽略（對應 D-4「該過場未播過才 push」的閘門，
## 這裡收斂進 DialogueSystem 統一檢查，觸發端不用自己查 GameState.flags）。
func play_cutscene(cut_id: String) -> bool:
	if not _cuts.has(cut_id):
		push_warning("DialogueSystem: 找不到 cutscene id=%s" % cut_id)
		return false
	var cut: CutsceneEntry = _cuts[cut_id]
	if cut.once != "" and GameState.flag_get(cut.once) != 0:
		return false
	_cut_queue.append(cut_id)
	_drain_cut_queue()
	return true


## 對應 __lose__ 特例（L1439/L1623）：戰敗時的固定旁白，不在 CUTS 表裡、沒有 once/battle/transfer，
## 只有一句話。呼叫端（戰鬥結算，屬於 MOD-E）在戰敗時呼叫這個，不用自己組 CutsceneEntry。
func play_defeat_narration() -> bool:
	if is_busy():
		_cut_queue.append("__lose__")
		return true
	_start_defeat_narration()
	return true


func _start_defeat_narration() -> void:
	var cut := CutsceneEntry.new()
	var line := CutsceneLine.new()
	line.text = "你們在芳蕾鎮教堂的祭壇前醒來……蓋婭女神接住了倒下的旅人。（隊伍已完全恢復）"
	cut.lines.append(line)
	_current_cut_id = ""
	_current_cut = cut
	_cut_idx = 0
	cutscene_started.emit("")
	cutscene_line_changed.emit("", cut.lines[0].text)


func _drain_cut_queue() -> void:
	if is_busy():
		return
	if _cut_queue.is_empty():
		return
	var key: String = _cut_queue.pop_front()
	if key == "__lose__":
		_start_defeat_narration()
	else:
		_start_cutscene(key)


func _start_cutscene(cut_id: String) -> void:
	var cut: CutsceneEntry = _cuts.get(cut_id)
	if cut == null:
		return
	_current_cut_id = cut_id
	_current_cut = cut
	_cut_idx = 0
	AudioManager.sfx("select.mp3")   # 對應 build_cq2.py L1695：過場開啟
	cutscene_started.emit(cut_id)
	if cut.lines.size() > 0:
		var line: CutsceneLine = cut.lines[0]
		cutscene_line_changed.emit(line.speaker, line.text)


func _advance_cutscene() -> void:
	_cut_idx += 1
	if _cut_idx < _current_cut.lines.size():
		var line: CutsceneLine = _current_cut.lines[_cut_idx]
		cutscene_line_changed.emit(line.speaker, line.text)
		return

	var cut := _current_cut
	var cut_id := _current_cut_id
	_current_cut = null
	_current_cut_id = ""
	_cut_idx = 0
	_finish_cutscene(cut, cut_id)


## 對應 L1685-1706：once/setstep/party 一律先套用（不論後面有沒有 battle/transfer），
## 然後才依序檢查 battle → transfer（GDevelop 端兩者互斥，一個 cutscene 最多只會有其中一種，見資料）。
func _finish_cutscene(cut: CutsceneEntry, cut_id: String) -> void:
	if cut.once != "":
		GameState.flag_set(cut.once, 1)
	if cut.setstep >= 0:
		GameState.flag_set("step", cut.setstep)
	if cut.party.size() > 0:
		_apply_party(cut.party)
	if cut.once != "" or cut.setstep >= 0 or cut.party.size() > 0:
		_try_save()

	cutscene_ended.emit(cut_id)

	if cut.battle != "":
		battle_requested.emit(cut.battle)
		return
	if cut.transfer.size() >= 2:
		scene_transfer_requested.emit(cut.transfer[0], cut.transfer[1])
		return

	_drain_cut_queue()


## 對應 mkMember()/party() 的隊伍組成替換（L997 town_start 的 "party":["ludo","marin"]）：
## 已在隊上的成員保留原本存檔資料（等級/裝備/hp 等），新加入的用樣板建立。
##
## 已知限制：這裡刻意不重算 maxhp/maxmp/patk/matk/pdef/mdef/dodgeV/critV/spd（GDevelop 版 derive()
## 的職責，Godot 端對應 MOD-F 的 scripts/content/derive.gd，本任務執行當下尚未建立，見
## TASKS/11_並行協作規則.md 衝突矩陣「不允許任何模組自己重算衍生屬性」）。新加入成員的 Dictionary
## 因此不會有 maxhp 等欄位，呼叫端／MOD-F 整合完成前，這些欄位要視為未定義，不能假設已經算好。
func _apply_party(ids: PackedStringArray) -> void:
	var old: Array = GameState.party
	var new_list: Array = []
	for id in ids:
		var existing: Dictionary = {}
		var found := false
		for m in old:
			if typeof(m) == TYPE_DICTIONARY and m.get("id") == id:
				existing = m
				found = true
				break
		if found:
			new_list.append(existing)
		else:
			new_list.append(_make_party_member(id))
	GameState.party = new_list


func _make_party_member(id: String) -> Dictionary:
	var def: PartyMemberDef = ContentDB.get_party_member(id)
	if def == null:
		push_warning("DialogueSystem: 找不到 party member 樣板 id=%s" % id)
		return {"id": id}
	return {
		"id": def.id,
		"name": def.display_name,
		"cls": def.char_class,
		"mainAttr": def.main_attr,
		"sprite": def.sprite,
		"guest": def.guest,
		"lv": def.start_level,
		"exp": 0,
		"pts": 0,
		"spts": 0,
		"attrs": def.base.duplicate(),
		"eq": def.start_eq.duplicate(),
	}


# =========================================================================
# action side-effects（D-2「action」欄位；對應 build_cq2.py L1758-1779 的 if/else 鏈）
# =========================================================================

## 每個分支對應原始碼一行（或一小段），刻意保留跟原始 action id 相同的字面比對方式，方便回頭核對。
## 未知 action id（不在下面清單）只記警告、不擋流程——避免資料檔打字錯誤直接讓對話卡死。
func _run_action(action: String) -> void:
	match action:
		"heal":
			_heal_all()
		"register":
			GameState.flag_set("reg", 1)
		"ch1_take":
			GameState.flag_set("ch1", 1)
		"ch1_reward":
			GameState.flag_set("ch1", 3)
			GameState.gold += 200
		"shop_gid":
			shop_requested.emit("gid")
		"shop_hank":
			shop_requested.emit("hank")
		"give_sword":
			# 漢克臨別贈言（build_cq2.py L1836，cmd hank_gift／done gotSword）：贈鐵劍，不開店。
			if GameState.flag_get("gotSword") == 0:
				GameState.flag_set("gotSword", 1)
				GameState.eq_inv.append("iron_sword")
		"give_potion":
			# 吉德新客招待（build_cq2.py L1837，cmd gid_gift／done gotPotion）：贈藥水×2，不開店。
			if GameState.flag_get("gotPotion") == 0:
				GameState.flag_set("gotPotion", 1)
				GameState.inv_add("potion", 2)
		"give_ring":
			if GameState.flag_get("gotRing") == 0:
				GameState.flag_set("gotRing", 1)
				GameState.eq_inv.append("vital_ring")
		"give_earring":
			# 注意：目前 dialogue.json 沒有任何條目使用這個 action（build_cq2.py L1769 有實作但
			# DLG 表裡沒有引用到——疑似既有的死碼／保留供未來用）。保留實作以求跟原始碼行為對稱一致。
			if GameState.flag_get("gotEar") == 0:
				GameState.flag_set("gotEar", 1)
				GameState.eq_inv.append("focus_earring")
		"ch2_take":
			GameState.flag_set("ch2", 1)
		"ch2_report":
			GameState.flag_set("ch2", 3)
			GameState.gold += 150
			GameState.inv_add("potion", 2)
		"mira_start":
			if GameState.flag_get("gotEar") == 0:
				GameState.flag_set("gotEar", 1)
				GameState.flag_set("mira2", 1)
				GameState.eq_inv.append("focus_earring")
		"mira_reward":
			GameState.flag_set("mira2", 2)
			GameState.inv_add("potion", 3)
		"relic_turnin":
			GameState.flag_set("relic", 2)
			GameState.gold += 100
			GameState.inv_add("miner_helmet", -1)
		_:
			push_warning("DialogueSystem: 未知的 action id=%s（略過，不擋對話流程）" % action)


## 對應 healAll()（L1375）：隊伍全恢復。**已知限制**：GDevelop 版 healAll() 會先呼叫 derive(ps[i])
## 重算 maxhp/maxmp 再回滿，本檔案不重算衍生屬性（MOD-F 職責，見上方 _apply_party 註解），只信任
## 既有 Dictionary 裡已經有的 maxhp/maxmp 欄位；若成員尚未被算過（例如剛加入隊伍、MOD-F 尚未整合），
## fallback 成「維持原本 hp/mp 不變」而不是報錯，避免整個對話流程掛掉。
func _heal_all() -> void:
	var party: Array = GameState.party
	for m in party:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		if m.has("maxhp"):
			m["hp"] = m["maxhp"]
		if m.has("maxmp"):
			m["mp"] = m["maxmp"]
	GameState.party = party


func _try_save() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr != null and save_mgr.has_method("save_game"):
		save_mgr.save_game()
