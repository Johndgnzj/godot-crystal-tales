extends Node
## ContentDB — 內容資料的唯讀查詢介面（autoload 單例，註冊名稱 "ContentDB"）。
##
## 資料真相源：res://resources/content/ 下的原生 .tres（設計員在 Godot 編輯器 Inspector 直接編輯個別實體）。
## 這些 .tres 由 ContentDatabase 聚合資源 content_db.tres 以 typed @export 陣列引用；本 autoload 只 load()
## 這一個聚合檔即拿到全部——匯出（.pck）安全（不靠 DirAccess 掃 res:// 目錄）、型別安全。
##
## 匯入來源（僅在「要從 GDevelop 重新匯入」時才用）：
##   ../../../GDevelop/projects/crystal-quest/CONTENT.json 是最初的資料種子
##     -> scripts/content/sync_content.py -> res://resources/content/content.json
##     -> scripts/content/build_tres.gd  -> resources/content/**/*.tres ＋ content_db.tres
## 切斷 GDevelop 臍帶後（2026-07-14，CORE-2 決策更新）：.tres 才是唯一真相源，平時直接編輯 .tres，
## 不再走 CONTENT.json；content.json / sync_content.py 淪為「重新匯入」的可選工具。

const DB_PATH := "res://resources/content/content_db.tres"

var is_loaded: bool = false

var _party_members: Dictionary = {}   # id -> PartyMemberDef
var _equipment: Dictionary = {}       # id -> EquipmentDef
var _skills: Dictionary = {}          # id -> SkillDef
var _items: Dictionary = {}           # id -> ItemDef
var _enemies: Dictionary = {}         # id -> EnemyDef
var _encounters: Dictionary = {}      # map_id -> EncounterDef
var _shops: Dictionary = {}           # id -> ShopDef
var _chests: Dictionary = {}          # id -> ChestDef
var _derived: DerivedParams
var _pacing: PacingParams


func _ready() -> void:
	_load()


func _load() -> void:
	if not ResourceLoader.exists(DB_PATH):
		push_error("ContentDB: 找不到 %s，請先跑 scripts/content/build_tres.gd 產生 .tres" % DB_PATH)
		return
	var db: ContentDatabase = load(DB_PATH)
	if db == null:
		push_error("ContentDB: 載入 %s 失敗（不是合法 ContentDatabase）" % DB_PATH)
		return

	_party_members.clear()
	for m in db.party:
		_party_members[m.id] = m
	_equipment.clear()
	for e in db.equipment:
		_equipment[e.id] = e
	_skills.clear()
	for s in db.skills:
		_skills[s.id] = s
	_items.clear()
	for it in db.items:
		_items[it.id] = it
	_enemies.clear()
	for en in db.enemies:
		_enemies[en.id] = en
	_encounters.clear()
	for enc in db.encounters:
		_encounters[enc.map_id] = enc
	_shops.clear()
	for sh in db.shops:
		_shops[sh.id] = sh
	_chests.clear()
	for c in db.chests:
		_chests[c.id] = c
	_derived = db.derived
	_pacing = db.pacing

	is_loaded = true


# ---- 查詢介面：模組任務一律透過這層拿資料，不直接讀檔案（見 TASKS/11_並行協作規則.md）----

func get_party_member(id: String) -> PartyMemberDef:
	return _party_members.get(id)

func get_all_party_members() -> Array:
	return _party_members.values()

func get_derived() -> DerivedParams:
	return _derived

func get_equipment(id: String) -> EquipmentDef:
	return _equipment.get(id)

func get_all_equipment() -> Array:
	return _equipment.values()

func get_skill(id: String) -> SkillDef:
	return _skills.get(id)

func get_all_skills() -> Array:
	return _skills.values()

func get_pacing() -> PacingParams:
	return _pacing

func get_item(id: String) -> ItemDef:
	return _items.get(id)

func get_all_items() -> Array:
	return _items.values()

func get_enemy(id: String) -> EnemyDef:
	return _enemies.get(id)

func get_all_enemies() -> Array:
	return _enemies.values()

func get_encounter(map_id: String) -> EncounterDef:
	return _encounters.get(map_id)

func get_shop(id: String) -> ShopDef:
	return _shops.get(id)

func get_all_shops() -> Array:
	return _shops.values()

func get_chest(id: String) -> ChestDef:
	return _chests.get(id)

func get_all_chests() -> Array:
	return _chests.values()
