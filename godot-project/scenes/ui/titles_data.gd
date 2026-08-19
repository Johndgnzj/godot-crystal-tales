class_name TitlesData
extends RefCounted

## 稱號資料表（對應 build_cq2.py L2602-2609 的 TITLES_DATA）。
##
## 這份資料在 GDevelop 端是 build_cq2.py 內嵌的 Python 常數（TITLES_DATA），不在 CONTENT.json 裡，
## 因此不經 ContentDB。它屬於「稱號分頁」這個已實作 UI 的一部分（MOD-D 範圍），收斂成單一 const，
## 供 hud.gd（顯示佩戴中稱號名）與 menu_root.gd（稱號分頁）共用，避免兩處各抄一份。
##
## req 格式：`<flag><==|>=><num>`（見 build_cq2.py titleEarned() L1922-1928）。
## 註：原版的序章進度旗標叫 `step`（build_cq2.py L1761 `f4.step=c.setstep`），Godot 端統一改名為
## `ch1_step`（game_flow.gd／dialogue_system.gd），故 t_rookie 的 req 對應改寫成 `ch1_step>=3`。
##
## ⚠ 可達性現況（2026-08-19 追查，**條件本身沒錯，是內容還沒接上**，故未改動 req）：
##   可達：t_rookie（小節1 `s1_bear` setstep=3）、t_f（小節4 action=register）。
##   不可達：t_gob/t_pride 需 `ch1`，但 action `ch1_take`/`ch1_reward` 沒有任何對話資料引用，
##           且新主線 boss 是 `eforest3_boss`（不寫 ch1），舊 forest2.tscn 的 BossMark 又要 `ch1==1`。
##           t_miner 需 `ch2`，同理卡在 `ch2_take` 未被引用 → mine.tscn BossMark `ch2==1` 不成立。
##           t_relic 需 `relic`，`relic_turnin` 未被引用、撿頭盔的 Pickup 又要 `ch2>=1`。
##   新六小節主線只推進 `ch1_step` 0→13（見 docs/story/第一章任務攻略.md 三、旗標總表）。
##   等第二章施工（TASKS/16）接上再回頭處理。

const ALL: Array = [
	{"id": "t_rookie", "name": "礦山生還者", "req": "ch1_step>=3", "desc": "歷經礦山的意外而歸來", "hint": "完成序章"},
	{"id": "t_f", "name": "F級冒險者", "req": "reg>=1", "desc": "完成冒險者公會登錄", "hint": "到公會找緹娜登錄"},
	{"id": "t_gob", "name": "哥布林剋星", "req": "ch1>=2", "desc": "討伐東之森的哥布林頭目", "hint": "完成第一章討伐委託"},
	{"id": "t_pride", "name": "芳蕾鎮的驕傲", "req": "ch1>=3", "desc": "向公會回報討伐成果", "hint": "回公會領取委託報酬"},
	{"id": "t_miner", "name": "礦山的見證者", "req": "ch2>=2", "desc": "揭開失蹤礦工的真相", "hint": "查明礦山外圍的異變"},
	{"id": "t_relic", "name": "故人之託", "req": "relic>=2", "desc": "送還礦工阿吉的遺物", "hint": "在礦山深處找回並上繳頭盔"},
]


## 對應 build_cq2.py titleEarned()（L1922-1928）：解析 req 的 `flag(==|>=)num`，用 GameState.flag_get 比對。
static func title_earned(req: String) -> bool:
	var re := RegEx.new()
	re.compile("^(\\w+)(==|>=)(\\d+)$")
	var m := re.search(req)
	if m == null:
		return false
	var val := GameState.flag_get(m.get_string(1))
	var num := int(m.get_string(3))
	if m.get_string(2) == "==":
		return val == num
	return val >= num


## 佩戴中稱號的顯示名（找不到回 ""）。eqTitle 存的是 title id（String），刻意不走 flag_get（那會 int 化），
## 直接讀 GameState.flags 容器。見 hud.gd／menu_root.gd 對 eqTitle 的說明。
static func equipped_name() -> String:
	var eq_id: String = String(GameState.flags.get("eqTitle", ""))
	if eq_id == "":
		return ""
	for t in ALL:
		if t["id"] == eq_id:
			return String(t["name"])
	return ""
