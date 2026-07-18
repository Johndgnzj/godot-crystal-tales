class_name GameFlow
extends RefCounted

## 新遊戲起手流程（對應 build_cq2.py newGame() L3559-3572）。
##
## CORE-4 的 GameState 刻意不做「建立預設隊伍」（見 game_state.gd 檔頭：那會誘使呼叫端塞入未 derive 的
## 隊員資料）。這裡是「新遊戲流程層」：從 ContentDB 讀樣板 → 建初始隊伍 → Derive.derive() → 補滿血魔，
## 並設定起始 flags/gold/背包/裝備袋/spawn、清場景轉場暫態。呼叫端（title 場景「新遊戲」）在此之後自行
## `SceneRouter.go_to("Town", "home")` 進城。
##
## 注意：本檔 make_member() 與 dialogue_system._make_party_member() 產生的隊員形狀相同（前者多做
## derive+補血魔）；未來可統一成單一 builder（暫各自保留，避免動到 MOD-A 檔案）。

const START_PARTY: Array[String] = ["ludo", "alan"]


## 重置 GameState 成全新一局（不切場景——切場景由呼叫端決定）。對應 build_cq2 newGame() 的全域變數設定。
static func new_game() -> void:
	GameState.flags = {"step": 0, "reg": 0, "ch1": 0}
	GameState.party = []
	for id in START_PARTY:
		GameState.party.append(make_member(id))
	GameState.gold = 30
	GameState.item_inv = {"potion": 4}
	GameState.eq_inv = ["swift_boots", "lucky_coin"]
	GameState.chests = []
	GameState.auto_battle = false
	# 場景轉場暫態：spawn="home"（Town 的家門口出生點），其餘清空（對應 clrTransient()）。
	GameState.spawn = "home"
	GameState.encounter = ""
	GameState.return_scene = ""
	GameState.return_x = -1.0
	GameState.return_y = -1.0
	GameState.result = ""


## 從 ContentDB 的 PartyMemberDef 樣板建一個「已 derive、滿血魔」的隊員 Dictionary。
## 形狀對應 specs/SAVE_SCHEMA.md g_party 元素與 derive.gd 的輸入。
static func make_member(id: String) -> Dictionary:
	var def: PartyMemberDef = ContentDB.get_party_member(id)
	if def == null:
		push_warning("GameFlow: 找不到 party member 樣板 id=%s" % id)
		return {"id": id}
	var m: Dictionary = {
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
	# 不預設 sk：交給 derive 依職業/等級補起始技能（對齊 build_cq2 mk()，該處也不帶 sk）。
	Derive.derive(m)      # 補算 maxhp/maxmp/patk/matk/... ＋ sk，see derive.gd
	m["hp"] = m["maxhp"]
	m["mp"] = m["maxmp"]
	return m
