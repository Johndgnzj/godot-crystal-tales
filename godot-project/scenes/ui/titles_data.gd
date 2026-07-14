class_name TitlesData
extends RefCounted

## 稱號資料表（對應 build_cq2.py L2448-2455 的 TITLES_DATA）。
##
## 這份資料在 GDevelop 端是 build_cq2.py 內嵌的 Python 常數（TITLES_DATA），不在 CONTENT.json 裡，
## 因此不經 ContentDB。它屬於「稱號分頁」這個已實作 UI 的一部分（MOD-D 範圍），收斂成單一 const，
## 供 hud.gd（顯示佩戴中稱號名）與 menu_root.gd（稱號分頁）共用，避免兩處各抄一份。
##
## req 格式：`<flag><==|>=><num>`（見 build_cq2.py titleEarned() L1841-1847）。

const ALL: Array = [
	{"id": "t_rookie", "name": "礦山生還者", "req": "step>=3", "desc": "歷經礦山的意外而歸來", "hint": "完成序章"},
	{"id": "t_f", "name": "F級冒險者", "req": "reg>=1", "desc": "完成冒險者公會登錄", "hint": "到公會找緹娜登錄"},
	{"id": "t_gob", "name": "哥布林剋星", "req": "ch1>=2", "desc": "討伐東之森的哥布林頭目", "hint": "完成第一章討伐委託"},
	{"id": "t_pride", "name": "芳蕾鎮的驕傲", "req": "ch1>=3", "desc": "向公會回報討伐成果", "hint": "回公會領取委託報酬"},
	{"id": "t_miner", "name": "礦山的見證者", "req": "ch2>=2", "desc": "揭開失蹤礦工的真相", "hint": "查明礦山外圍的異變"},
	{"id": "t_relic", "name": "故人之託", "req": "relic>=2", "desc": "送還礦工阿吉的遺物", "hint": "在礦山深處找回並上繳頭盔"},
]


## 對應 build_cq2.py titleEarned()（L1841-1847）：解析 req 的 `flag(==|>=)num`，用 GameState.flag_get 比對。
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
