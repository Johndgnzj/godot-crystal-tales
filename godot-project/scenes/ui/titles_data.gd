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
## 【2026-08-19 全表重新對映】原六個稱號有四個掛在 `ch1`/`ch2`/`relic` 上——那是**舊三段式 POC 的遺留
## 旗標**：寫它們的 action（ch1_take／ch1_reward／ch2_take／ch2_report／relic_turnin）沒有任何對話資料
## 引用；掛 ch1_boss／ch2_bear 的 BossMark 只存在於舊 tile 版場景（forest2／mine／eforest3.tscn），而新
## 主線走 painted 版（EFA–EFI／NMA–NMF，見 SceneRouter），那些場景裡一個 BossMark 都沒有，boss 戰全由
## 過場的 battle 欄觸發 → 那四個稱號恆為「未取得」。第二章亦已定案改用 `ch2_step`（TASKS/16 CH2-I5），
## 舊旗標不會復活，故不修補而是把全表重新對映到新六小節主線的里程碑（John 2026-08-19 拍板）。
##
## 對映結果（依解鎖先後排列，全走新主線既有旗標、不新增 flag；劇情節點見 docs/story/第一章任務攻略.md）：
##   小節3 收尾 `ch1_step>=8`   礦山生還者   ← 原 `step>=3`，時機挪到真正的「從礦山歸來」
##   小節4     `reg>=1`         F級冒險者    ← 未動
##   小節4.5   `fq>=3`          初出茅廬     ← 原 t_gob「哥布林剋星」，新第一章沒有哥布林頭目戰
##   小節5     `got_honey>=1`   不屈的少年   ← 原 t_relic「故人之託」，阿吉頭盔支線新主線摸不到
##   小節6     `marin_curse>=1` 礦山的見證者 ← 原 `ch2>=2`，desc 本就對應小節6 死靈術士那段
##   小節6 完  `ch1_step>=13`   芳蕾鎮的驕傲 ← 原 `ch1>=3`
##
## id 一併改名（t_gob→t_fq、t_relic→t_rematch）：這兩個舊 id 沒有任何存檔拿得到（恆不可解鎖），改名
## 不會讓既有存檔的 eqTitle 失效。

const ALL: Array = [
	{"id": "t_rookie", "name": "礦山生還者", "req": "ch1_step>=8", "desc": "歷經礦山的意外，活著回到芳蕾鎮", "hint": "從北方礦山平安歸來"},
	{"id": "t_f", "name": "F級冒險者", "req": "reg>=1", "desc": "完成冒險者公會登錄", "hint": "到公會找緹娜登錄"},
	{"id": "t_fq", "name": "初出茅廬", "req": "fq>=3", "desc": "獨力辦妥了三件 F 級委託", "hint": "完成緹娜告示板上的三件委託"},
	{"id": "t_rematch", "name": "不屈的少年", "req": "got_honey>=1", "desc": "再次面對曾經敗北的熊，這一次沒有逃", "hint": "在東之森的老樹旁了結那段舊帳"},
	{"id": "t_miner", "name": "礦山的見證者", "req": "marin_curse>=1", "desc": "揭開失蹤礦工的真相", "hint": "查明礦山深處異變的源頭"},
	{"id": "t_pride", "name": "芳蕾鎮的驕傲", "req": "ch1_step>=13", "desc": "帶著黑水晶的真相回到公會", "hint": "完成第一章"},
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
