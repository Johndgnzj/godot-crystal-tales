class_name MapDef
extends Resource
## 一張程序生成地圖的 recipe（生成器 dev-time 輸入，非 runtime 資料）。
## 對應 gen-region region config 裡 maps[] 的元素（見 TASKS/12_地圖生成器.md）。
## kind 決定地形主題與預設 layout；layout 'open'=自然開闊、'maze'=完美迷宮。

@export var id: String = ""                  ## 地圖 id（＝輸出 scenes/world/<id>.tscn、encounters/<id>.tres 的 key）
@export var scene_name: String = ""          ## 場景邏輯名（world_scene.gd scene_id / SceneRouter key）；空＝用 id
@export_enum("mine", "cave", "forest", "grassland") var kind: String = "forest"
@export var w: int = 40                      ## 地圖寬（tile 數）
@export var h: int = 28                      ## 地圖高（tile 數）
@export var layout: String = ""              ## ""＝依 kind 預設（mine/cave→maze，其餘→open）；或 "open"/"maze"
@export_enum("wide", "medium", "tight") var openness: String = "medium"  ## open layout 的路寬（障礙覆蓋率）
@export_enum("low", "medium", "high") var complexity: String = "medium"  ## maze layout 的房間數
@export var level_band: Array[int] = [1, 3]  ## [lo, hi]：自動選怪的難度帶
@export var enemies: Array[String] = []      ## 明列常規敵人 id；空＝依 level_band 自動選（"auto"）
@export var entries: Array[String] = []      ## 設定外場景（如 "Town"）進入本圖時，會建 from_<場景> 落點
@export var exits: Array[MapExitDef] = []    ## 本圖的出口
@export var boss_enemy: String = ""          ## boss 敵人 id；空＝無 boss
@export var boss_show_when: String = ""      ## boss 顯示條件（FlagMatcher 語法）
@export var boss_adds: bool = true           ## boss 戰是否帶小怪


static func from_dict(d: Dictionary) -> MapDef:
	var result := MapDef.new()
	result.id = d.get("id", "")
	result.scene_name = d.get("scene_name", result.id)
	result.kind = d.get("kind", "forest")
	result.w = int(d.get("w", 40))
	result.h = int(d.get("h", 28))
	result.layout = d.get("layout", "")
	result.openness = d.get("openness", "medium")
	result.complexity = d.get("complexity", "medium")

	var band: Array = d.get("level_band", [1, 3])
	result.level_band.clear()   # level_band 是 typed Array[int]，逐一 append 避免 untyped literal 賦值錯誤
	result.level_band.append(int(band[0]) if band.size() > 0 else 1)
	result.level_band.append(int(band[1]) if band.size() > 1 else 3)

	# enemies：JSON 可能是 "auto"（字串）或 id 陣列；統一成 Array[String]，空＝auto。
	var spec: Variant = d.get("enemies", "auto")
	if spec is Array:
		for e in spec:
			result.enemies.append(str(e))
	for s in d.get("entries", []):
		result.entries.append(str(s))
	for e in d.get("exits", []):
		result.exits.append(MapExitDef.from_dict(e))

	var boss: Variant = d.get("boss", null)
	if boss is Dictionary:
		result.boss_enemy = boss.get("enemy", "")
		result.boss_show_when = boss.get("show_when", "")
		result.boss_adds = bool(boss.get("adds", true))
	return result


## layout 的實效值（空字串時依 kind 給預設）。
func effective_layout() -> String:
	if layout != "":
		return layout
	return "maze" if kind in ["mine", "cave"] else "open"
