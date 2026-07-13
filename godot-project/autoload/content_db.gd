extends Node
## ContentDB — CONTENT.json 的唯讀查詢介面（autoload 單例，註冊名稱 "ContentDB"）。
##
## 資料流向（見 ../../CLAUDE.md「權威來源與資料流向」與
## ../../TASKS/00_核心任務.md CORE-2 段落的定案理由）：
##   ../../../gd-crystal-tales/projects/crystal-quest/CONTENT.json（唯一資料源，唯讀）
##     -> scripts/content/sync_content.py（同步腳本，帶輕量 schema 檢查）
##     -> res://resources/content/content.json（同步後的副本，隨 repo 一起 commit）
##     -> ContentDB._load()（run-time JSON.parse_string，本檔案）
##
## 決定：run-time 直接 parse JSON，不做 build-time .tres 轉存。理由：CONTENT.json 目前仍隨 GDevelop
## 端開發頻繁變動（John 常改數值），run-time parse 省去「改完 CONTENT.json 還要在 Godot 編輯器內重新
## 匯出/儲存 .tres」這道額外同步步驟；.tres 需要 Godot 執行檔才能產生，而這個 CORE-2 執行環境目前拿不到
## Godot 執行檔（見 CORE-1 驗收現況），run-time parse 也讓「純 Python 腳本驗證資料正確性」變得可行，不用
## 依賴引擎起得來。缺點（每次啟動要花時間 parse 一次 JSON、拿不到 .tres 的型別檢查與編輯器 Inspector
## 預覽）在目前資料量級（561 行來源 JSON）下可忽略。之後如果資料量大到影響啟動時間，可以再補一支
## build-time 轉存腳本，兩者介面（ContentDB 的 get_xxx() API）不需要跟著變。

const CONTENT_PATH := "res://resources/content/content.json"

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
	if not FileAccess.file_exists(CONTENT_PATH):
		push_error("ContentDB: 找不到 %s，請先跑 godot-project/scripts/content/sync_content.py" % CONTENT_PATH)
		return

	var file := FileAccess.open(CONTENT_PATH, FileAccess.READ)
	if file == null:
		push_error("ContentDB: 開檔失敗 %s（error=%s）" % [CONTENT_PATH, FileAccess.get_open_error()])
		return
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ContentDB: content.json 格式錯誤，頂層必須是物件")
		return

	_party_members.clear()
	for entry in parsed.get("party", []):
		var m := PartyMemberDef.from_dict(entry)
		_party_members[m.id] = m

	_derived = DerivedParams.from_dict(parsed.get("derived", {}))

	_equipment.clear()
	for entry in parsed.get("equipment", []):
		var e := EquipmentDef.from_dict(entry)
		_equipment[e.id] = e

	_skills.clear()
	for entry in parsed.get("skills", []):
		var s := SkillDef.from_dict(entry)
		_skills[s.id] = s

	_pacing = PacingParams.from_dict(parsed.get("pacing", {}))

	_items.clear()
	for entry in parsed.get("items", []):
		var it := ItemDef.from_dict(entry)
		_items[it.id] = it

	_enemies.clear()
	for entry in parsed.get("enemies", []):
		var en := EnemyDef.from_dict(entry)
		_enemies[en.id] = en

	_encounters.clear()
	var encounters_raw: Dictionary = parsed.get("encounters", {})
	for map_id in encounters_raw.keys():
		_encounters[map_id] = EncounterDef.from_dict(map_id, encounters_raw[map_id])

	_shops.clear()
	var shops_raw: Dictionary = parsed.get("shops", {})
	for shop_id in shops_raw.keys():
		_shops[shop_id] = ShopDef.from_dict(shop_id, shops_raw[shop_id])

	_chests.clear()
	for entry in parsed.get("chests", []):
		var c := ChestDef.from_dict(entry)
		_chests[c.id] = c

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
