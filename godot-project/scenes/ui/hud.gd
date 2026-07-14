extends CanvasLayer
## hud.tscn 的控制腳本 —— 隊伍血條/金幣/目標提示 HUD。
##
## 對應 build_cq2.py 的 HUD 段落（L2394-2418）：
##   HudParty（隊伍成員 名字 Lv HP/maxHP）、HudGold（佩戴稱號＋金幣＋[M]選單提示）、
##   HudGoal（依劇情旗標的當前目標指引）。
##
## 即時反映 GameState 異動：GameState 是純資料容器、不發 signal（見 autoload/game_state.gd 檔頭），
## 所以照 build_cq2 的每幀重算模型，在 _process 每幀刷新（成本低——最多數名隊員、字串組裝）。
## 這不是「每幀跑巨大玩法邏輯」的反模式（CLAUDE.md L87 禁止的是玩法邏輯），只是唯讀顯示層的刷新。
##
## 依賴（皆唯讀呼叫）：GameState（party/gold/flags）、ContentDB（derive 需要）、Derive.derive()、
## TitlesData（佩戴稱號名）。
##
## scene_id：HudGoal 第一個分支（step==0 且在芳蕾鎮）需要知道目前世界場景 id（對照 build_cq2
## CFG.SCENE==="Town"）。HUD 自身不知道所在場景，由世界場景控制器（MOD-C／整合端）在載入場景時呼叫
## set_scene_id() 告知；預設 "" 時該分支退化為「跟著亞倫深入礦山」，不會誤顯示鎮上提示。

@onready var _party_label: Label = $Root/HudParty
@onready var _gold_label: Label = $Root/HudGold
@onready var _goal_label: Label = $Root/HudGoal

var scene_id: String = ""


func _ready() -> void:
	_gold_label.add_theme_color_override("font_color", _party_label.get_theme_color("gold", "CQ"))
	_goal_label.add_theme_color_override("font_color", _party_label.get_theme_color("accent", "CQ"))
	_refresh()


func set_scene_id(id: String) -> void:
	scene_id = id


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	_party_label.text = _party_text()
	_gold_label.text = _gold_text()
	_goal_label.text = _goal_text()


## 對應 L2395-2396：ps.map(derive → name+" Lv"+lv+" "+hp+"/"+maxhp).join("   ")。
func _party_text() -> String:
	var parts: PackedStringArray = []
	for m in GameState.party:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		if ContentDB.is_loaded:
			Derive.derive(m)
		var hp = m.get("hp", 0)
		var maxhp = m.get("maxhp", hp)
		parts.append("%s Lv%s %s/%s" % [m.get("name", ""), m.get("lv", 1), hp, maxhp])
	return "   ".join(parts)


## 對應 L2397-2402：佩戴稱號〈…〉＋金幣＋[M]選單。
func _gold_text() -> String:
	var eq_name := TitlesData.equipped_name()
	var prefix := ("〈%s〉　" % eq_name) if eq_name != "" else ""
	return "%s金幣 %d　[M]選單" % [prefix, GameState.gold]


## 對應 L2403-2418：依旗標 step/reg/ch1/ch2 決定當前目標指引（第一個分支另需 scene_id=="Town"）。
func _goal_text() -> String:
	var step := GameState.flag_get("step")
	var reg := GameState.flag_get("reg")
	var ch1 := GameState.flag_get("ch1")
	var ch2 := GameState.flag_get("ch2")
	if step == 0 and scene_id == "Town":
		return "▶ 逛逛鎮子，準備好就從北出口前往礦山"
	elif step == 0:
		return "▶ 跟著亞倫深入礦山（往北）"
	elif step < 3:
		return "▶ 逃出洞穴"
	elif reg == 0:
		return "▶ 到公會找緹娜登錄冒險者"
	elif ch1 == 0:
		return "▶ 找緹娜接委託"
	elif ch1 == 1:
		return "▶ 討伐東之森深處的哥布林頭目"
	elif ch1 == 2:
		return "▶ 回公會向緹娜回報"
	elif ch1 == 3 and ch2 == 0:
		return "▶ 找水井旁的老葛雷打聽礦山的委託"
	elif ch2 == 1:
		return "▶ 前往北方礦山外圍，查明礦工失蹤真相"
	elif ch2 == 2:
		return "▶ 回鎮上向老葛雷回報所見"
	return "▶ 第二章完！深入礦坑洞穴、追查邪氣源頭（第三章敬請期待）"
