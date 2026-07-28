extends Node
## SaveManager — autoload（註冊名稱 "SaveManager"，見 ../project.godot [autoload]）。
##
## CORE-3 正式產出。取代 GDevelop 的 `saveGame()`/`loadSave()`（`localStorage["cq_save"]`）。
##
## **存檔槽數量無上限**（2026-07-28 John 定案，取代原本的單槽設計）：每一槽是一個獨立檔案
## `user://cq_save_<n>.json`（n 從 1 開始遞增、不設上限），舊版單槽檔 `user://cq_save.json` 在
## `_ready()` 自動搬成槽 1（見 `_migrate_legacy_save()`）。`current_slot` 記住「目前這局在用哪一槽」，
## 自動存檔（進場／對話／撿取／買賣）一律寫回該槽；`current_slot == 0`（新遊戲後的狀態）時，第一次
## 自動存檔會自己配一個新槽，不會蓋掉別局的存檔。
##
## 規格來源：specs/SAVE_SCHEMA.md 全文，特別是「saveGame() 實際寫入的存檔物件」一節（欄位命名
## v/scene/x/y/flags/party/eqInv/itemInv/gold/chests/auto）與「Godot 端對應設計」一節（resume 交握）。
## 對照 build_cq2.py：saveGame() L1277-1290、invAdd()/invAll() L1293-1296、loadSave() L3387-3393、
## clrTransient() L3366。
##
## =========================================================================
## 介面設計：save_game() 的座標怎麼傳入
## =========================================================================
##
## SaveManager 是全域單例，不掛在任何世界場景節點下，不知道玩家物件在哪裡、也不知道玩家現在是不是在
## 室內子區域。GDevelop 版 `saveGame()` 能直接抓 `rs.__v`/`one("Player")`，是因為它是場景 runtime 的
## 一段 inline JS；Godot 版沒有這個捷徑，所以場景/座標**必須由呼叫端傳入**：
##
##   save_game(scene_name: String = "", x: float = NO_COORD, y: float = NO_COORD) -> int   # 回傳寫入的槽號
##
## - **呼叫端負責室內存門口外座標的校正**：若玩家目前在室內子區域（`rs.__v.inside && rs.__v.curDoor`
##   的 Godot 等價狀態，屬於世界場景控制器 MOD-C/MOD-H 的職責，見 game_state.gd 檔頭「lock/inside
##   欄位歸屬判斷」），呼叫端在呼叫 `save_game()` 前，要把 `x`/`y` 換成「門口外」座標（對應
##   `curDoor.tx*TS, (curDoor.ty+1)*TS`，見 SAVE_SCHEMA.md「室內存檔的特殊規則」），不是玩家當下座標
##   ——**SaveManager 完全不做這個判斷，只原封不動把收到的 x/y 寫進存檔**。
## - **三個參數都有預設值，但這不是「可以隨便省略」的邀請**，而是為了相容 MOD-A 已合併的
##   `scripts/dialogue/dialogue_system.gd` `_try_save()`（L417-420）：它透過
##   `get_node_or_null("/root/SaveManager")` 動態查找＋`has_method("save_game")` 呼叫，**呼叫時完全
##   不傳參數**（`save_mgr.save_game()`）——對話系統觸發的存檔（劇情推進/獎勵發放後）不知道也不需要知道
##   玩家世界座標，跟 GDevelop 版一樣。`scripts/world/pickup_zone.gd`（MOD-B）的 TODO 註解也是寫
##   `SaveManager.save_game()` 零參數呼叫。
##   當 `scene_name` 省略（維持預設空字串）時，`save_game()` **不覆蓋**存檔物件裡的 `scene`
##   欄位——沿用目前已存在的存檔檔案裡的舊值；`x`/`y` 省略（維持 `NO_COORD = -1.0`）時同理沿用舊值。
##   換句話說，零參數呼叫只更新 `flags/party/eqInv/itemInv/gold/chests/auto` 這幾個資料欄位，不動
##   `scene/x/y`。如果目前根本沒有既有存檔（例如整個遊戲流程第一次存檔就剛好是對話觸發，還沒有任何
##   世界場景呼叫過帶座標版本），退回哨兵值 `scene=""`、`x=y=NO_COORD`，`load_game()` 之後靠
##   `SceneRouter.should_use_return_position()` 的 `return_x >= 0` 檢查會自然判定「沒有可用座標」。
##   **世界場景控制器（MOD-C/MOD-H）進場/傳送時應該呼叫帶明確 `scene_name`/`x`/`y` 的版本**，讓上述
##   fallback 只在對話/撿取觸發的存檔情境下才會被用到（此時通常前一次帶座標的存檔已經寫過該欄位）。
##
## =========================================================================
## load_game() 與 SceneRouter 的 resume 交握方式
## =========================================================================
##
## `load_game()` 只還原 `GameState` 的持久化欄位＋依 scene_router.gd 檔頭建議設定
## `GameState.result = "resume"` 與 `GameState.return_x`/`return_y`，**不會**呼叫
## `SceneRouter.go_to()`——場景切換的時機（例如要不要先播一段轉場動畫、Title 場景的「繼續冒險」按鈕
## 什麼時候按下去）是呼叫端的職責，不是 SaveManager 的。
##
## 呼叫端（例如 Title 場景）讀出存檔場景要去哪，走這個介面：
##
##   if SaveManager.load_game():
##       SceneRouter.go_to(SaveManager.loaded_scene, "")
##
## `loaded_scene` 是 `load_game()` 成功時順便寫入的公開欄位（存檔物件的 `scene` 欄位，已比照
## build_cq2.py `loadSave()` L3390 的 `VALID` 白名單校驗，非法/缺漏值一律退回 `"Town"`）。這個小欄位
## 收斂在 SaveManager 身上，因為 scene 名稱本來就是存檔資料的一部分，`load_game()` 回傳值只是
## bool（是否讀檔成功），不足以同時帶出場景名稱，所以用一個成員變數承接，呼叫端讀取即可，不需要
## SaveManager 自己呼叫 `SceneRouter.go_to()`（該函式屬於 CORE-5 擁有，SaveManager 只讀不call）。
##
## `GameState.result="resume"` + `return_x`/`return_y` 這組交握寫法照抄 scene_router.gd 檔頭「resume
## （讀檔）流程」段落的建議：`go_to()` 只會覆寫 `GameState.spawn`，不會動 `result`/`return_x`/`return_y`，
## 兩者合成即可重現 build_cq2.py `loadSave()`（L3387-3393）的行為。
##
## =========================================================================
## 刻意不做的事
## =========================================================================
##
## - **不實作 `newGame()`/預設隊伍建立**：`has_save()` 為 false 時的「新遊戲」流程（建立初始隊伍
##   ludo/alan，牽涉 `derive()` 公式）屬於 MOD-F 完成後的整合任務範圍，跟 CORE-4 的排除範圍一致，
##   本檔案不提供任何「建立預設存檔」的方法。
## - **不做室內判斷**：見上方「介面設計」一節，SaveManager 不知道、也不查詢玩家是否在室內。
## - **不呼叫 `SceneRouter.go_to()`**：見上方「resume 交握方式」一節。

## 舊版單槽存檔檔名（2026-07-28 前）。仍存在時會在 `_ready()` 搬成槽 1。
const LEGACY_SAVE_NAME := "cq_save.json"
const SLOT_PREFIX := "cq_save_"
const SLOT_SUFFIX := ".json"

## 存檔格式版本，對應 saveGame() 寫入的 `v:1`。目前固定為 1，尚無需要遷移的版本差異；未來 Godot 版
## 存檔格式若跟這份 v1 不同，這裡要遞增並在 specs/SAVE_SCHEMA.md 記錄差異（見該文件「Godot 端對應
## 設計」一節）。
const SAVE_VERSION := 1

## `x`/`y`/`scene_name` 省略時的哨兵值，語意對應 build_cq2.py `clrTransient()` 用 `-1` 代表「沒有
## return 座標」的慣例（見 scene_router.gd `should_use_return_position()`）。
const NO_COORD := -1.0

## resume 讀檔時場景名稱的合法白名單。原照抄 build_cq2.py `loadSave()` L3391 的
## `{Town,Forest,Forest2,Mine,Cave}`；2026-07-19（第一章 Phase 2，TASKS/13 CH1-06）主線改走 painted
## 場景（芳蕾鎮 Town＋北礦 NMA-NMF＋東森 EFA-EFI），舊 tile 場景（Forest/Forest2/Mine/Cave）主線已不走、
## 待 CH1-15 封存，故白名單換成 painted 主線場景名。仍**不含** Title/Battle（讀檔不直接 resume 進戰鬥/標題）。
## 場景名對齊 SceneRouter.SCENE_PATHS 的 scene_id。
const VALID_RESUME_SCENES := [
	"Town",
	"NMA", "NMB", "NMC", "NMD", "NME", "NMF",
	"EFA", "EFB", "EFC", "EFD", "EFE", "EFF", "EFG", "EFH", "EFI",
]
const DEFAULT_RESUME_SCENE := "Town"

## `load_game()` 成功時寫入，呼叫端讀取後自行決定何時呼叫 `SceneRouter.go_to(loaded_scene, "")`。
## 見檔頭「resume 交握方式」。`load_game()` 失敗時不保證這個值的內容（呼叫端不應該在失敗時讀它）。
var loaded_scene: String = ""

## 這一局正在使用的存檔槽（0 = 還沒有：新遊戲後、或這次啟動還沒存過／讀過任何檔）。
## 自動存檔寫這一槽；為 0 時 `save_game()` 會配一個新槽（見 `_resolve_slot()`）。
var current_slot: int = 0


func _ready() -> void:
	_migrate_legacy_save()


## 存檔（寫進 `current_slot`；為 0 時自動配新槽）。回傳實際寫入的槽號，寫入失敗回傳 0。
## `scene_name`/`x`/`y` 省略時的 fallback 規則見檔頭「介面設計」一節。
## **呼叫端傳入的 x/y 應該已經是校正過的存檔座標**（室內時是門口外座標）——SaveManager 不做這個校正。
func save_game(scene_name: String = "", x: float = NO_COORD, y: float = NO_COORD) -> int:
	return save_to_slot(_resolve_slot(), scene_name, x, y)


## 存到指定槽（選單「存檔」用）。`slot <= 0` 一律當成「配一個新槽」。寫入成功會把 `current_slot`
## 指到該槽——之後的自動存檔就接著寫這一槽。回傳實際寫入的槽號，失敗回傳 0。
func save_to_slot(slot: int, scene_name: String = "", x: float = NO_COORD, y: float = NO_COORD) -> int:
	var target := slot if slot > 0 else next_free_slot()
	# scene/x/y 的沿用來源：優先目標槽的舊內容；目標是空的新槽（選單「新增存檔」）時退而讀這一局
	# 正在用的槽，否則零參數存進新槽會把場景/座標寫成哨兵值、讀檔時退回 Town。
	var prev: Variant = _read_raw(target)
	if prev == null and target != current_slot:
		prev = _read_raw(current_slot)

	var final_scene := scene_name
	if final_scene == "" and prev != null:
		final_scene = String(prev.get("scene", ""))

	var final_x := x
	if final_x == NO_COORD and prev != null:
		final_x = float(prev.get("x", NO_COORD))

	var final_y := y
	if final_y == NO_COORD and prev != null:
		final_y = float(prev.get("y", NO_COORD))

	var data := {
		"v": SAVE_VERSION,
		"scene": final_scene,
		"x": final_x,
		"y": final_y,
		"flags": GameState.flags,
		"party": GameState.party,
		"eqInv": GameState.eq_inv,
		"itemInv": GameState.item_inv,
		"gold": GameState.gold,
		"chests": GameState.chests,
		"auto": 1 if GameState.auto_battle else 0,
		# 存檔時間（Unix 秒）。純粹給存檔清單排序／顯示用，讀檔不使用。
		"at": int(Time.get_unix_time_from_system()),
	}

	var path := slot_path(target)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: 無法開啟 %s 寫入（FileAccess.get_open_error()=%s）" % [path, FileAccess.get_open_error()])
		return 0
	f.store_string(JSON.stringify(data))
	f.close()
	current_slot = target
	return target


## 讀檔。還原 GameState 的持久化欄位＋設定 resume 交握用的 result/return_x/return_y（見檔頭）。
## **不**呼叫 SceneRouter.go_to()。`slot <= 0` 代表「最近存的那一槽」（標題「繼續冒險」用）。
## 檔案不存在或 JSON 壞掉（root 不是 Dictionary、parse 失敗）回傳 false，此時不動 GameState 任何欄位。
func load_game(slot: int = 0) -> bool:
	var target := slot if slot > 0 else latest_slot()
	var data: Variant = _read_raw(target)
	if data == null:
		return false

	GameState.flags = _load_flags(data.get("flags", {}))
	GameState.party = _as_array(data.get("party", []))
	GameState.eq_inv = _as_string_array(data.get("eqInv", []))
	GameState.item_inv = _as_int_dict(data.get("itemInv", {}))
	GameState.gold = int(data.get("gold", 0))
	GameState.chests = _as_string_array(data.get("chests", []))
	GameState.auto_battle = int(data.get("auto", 0)) != 0

	var scene_name := String(data.get("scene", ""))
	if not VALID_RESUME_SCENES.has(scene_name):
		scene_name = DEFAULT_RESUME_SCENE
	loaded_scene = scene_name

	# resume 交握（照抄 scene_router.gd 檔頭「resume（讀檔）流程」建議寫法，對應 loadSave() L3387-3393）：
	# 呼叫端稍後自己呼叫 SceneRouter.go_to(loaded_scene, "")；go_to() 只覆寫 spawn，不動這兩個欄位。
	GameState.result = "resume"
	GameState.return_x = float(data.get("x", NO_COORD))
	GameState.return_y = float(data.get("y", NO_COORD))

	current_slot = target
	return true


## 有沒有任何存檔（標題「繼續冒險」是否可按）。
func has_save() -> bool:
	return not list_slots().is_empty()


func slot_path(slot: int) -> String:
	return "user://%s%d%s" % [SLOT_PREFIX, slot, SLOT_SUFFIX]


## 目前存在的槽號，由小到大。掃 `user://` 目錄檔名解析，不維護索引檔（沒有索引就不會有索引跟實際
## 檔案不同步的問題）。
func list_slots() -> Array[int]:
	var out: Array[int] = []
	var dir := DirAccess.open("user://")
	if dir == null:
		return out
	for name in dir.get_files():
		if not name.begins_with(SLOT_PREFIX) or not name.ends_with(SLOT_SUFFIX):
			continue
		var num := name.substr(SLOT_PREFIX.length(), name.length() - SLOT_PREFIX.length() - SLOT_SUFFIX.length())
		if num.is_valid_int() and int(num) > 0:
			out.append(int(num))
	out.sort()
	return out


## 存檔清單（選單存/讀/刪檔頁用）。每筆：slot / scene / at / gold / lv（隊長等級）/ names（隊員名）。
## 壞掉讀不出來的檔案直接跳過，不讓選單掛掉。
func list_saves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in list_slots():
		var data: Variant = _read_raw(slot)
		if data == null:
			continue
		var party := _as_array(data.get("party", []))
		var names := PackedStringArray()
		for m in party:
			names.append(String(m.get("name", m.get("id", "？"))))
		out.append({
			"slot": slot,
			"scene": String(data.get("scene", "")),
			"at": int(data.get("at", 0)),
			"gold": int(data.get("gold", 0)),
			"lv": int(party[0].get("lv", 1)) if not party.is_empty() else 0,
			"names": names,
		})
	return out


## 最近存檔的槽（比 `at`，相同時取槽號大的）。沒有任何存檔回傳 0。
func latest_slot() -> int:
	var best := 0
	var best_at := -1
	for s in list_saves():
		var at := int(s["at"])
		if at > best_at or (at == best_at and int(s["slot"]) > best):
			best_at = at
			best = int(s["slot"])
	return best


## 下一個沒被占用的槽號（填補中間被刪掉的空號，所以刪掉槽 2 之後新存檔會回到 2）。
func next_free_slot() -> int:
	var used := list_slots()
	var n := 1
	while used.has(n):
		n += 1
	return n


## 刪掉指定槽（`slot <= 0` 視為 `current_slot`）。刪到目前這局在用的槽時把 `current_slot` 歸零，
## 下次自動存檔會配新槽、不會把資料寫回已被刪除的槽號。
func delete_save(slot: int = 0) -> void:
	var target := slot if slot > 0 else current_slot
	if target <= 0:
		return
	var file_name := "%s%d%s" % [SLOT_PREFIX, target, SLOT_SUFFIX]
	if not FileAccess.file_exists("user://" + file_name):
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("SaveManager: 無法開啟 user:// 目錄以刪除存檔（DirAccess.get_open_error()=%s）" % DirAccess.get_open_error())
		return
	var err := dir.remove(file_name)
	if err != OK:
		push_error("SaveManager: 刪除 %s 失敗 err=%s" % [file_name, err])
		return
	if current_slot == target:
		current_slot = 0


## 清掉所有存檔槽（測試的乾淨起點用；遊戲流程沒有「全部刪除」的入口）。
func delete_all_saves() -> void:
	for slot in list_slots():
		delete_save(slot)
	current_slot = 0


## 目前這局要寫哪一槽：已經有 `current_slot` 就用它，否則配一個新槽（新遊戲的第一次自動存檔）。
func _resolve_slot() -> int:
	return current_slot if current_slot > 0 else next_free_slot()


## 舊版單槽存檔 `user://cq_save.json` → 槽 1。只在槽 1 還不存在時搬，搬完刪掉舊檔；失敗只警告不擋
## 開機（大不了玩家看不到舊存檔，資料仍在原檔案）。
func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists("user://" + LEGACY_SAVE_NAME):
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		push_warning("SaveManager: 無法開啟 user:// 目錄，略過舊存檔搬移")
		return
	var target_name := "%s1%s" % [SLOT_PREFIX, SLOT_SUFFIX]
	if FileAccess.file_exists("user://" + target_name):
		return
	var err := dir.rename(LEGACY_SAVE_NAME, target_name)
	if err != OK:
		push_warning("SaveManager: 舊存檔搬移為槽 1 失敗 err=%s" % err)


## 讀某一槽的存檔檔案並 parse 成 Dictionary；檔案不存在、開檔失敗、JSON parse 失敗、或 parse 出來的
## 根不是 Dictionary（存檔理應永遠是物件，不會是陣列/純量），一律回傳 null，由呼叫端（load_game()/
## save_to_slot() 的 fallback 讀取／list_saves()）決定怎麼處理。
func _read_raw(slot: int) -> Variant:
	if slot <= 0:
		return null
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed


## flags 專用還原。flags 幾乎都是 int（flag_set 已保證），但 `eqTitle` 是刻意的 String 例外——menu_root.gd
## 直接寫 `flags["eqTitle"]=<title id>`（String）繞過 flag_set，titles_data.gd 也以 String 讀取（見
## game_state.gd flags 註解與 titles_data.gd 檔頭）。若比照 item_inv 無差別 int()，`int("t_rookie")` 會變 0，
## 佩戴的稱號讀檔後遺失、且 titles_data 的 `String(<int>)` 會直接 crash（見 tests/check_save_roundtrip.gd）。
## 故依 JSON 還原後的型別決定：字串保留字串、其餘轉 int。key 一律轉 String（防上游資料異常）。
func _load_flags(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for k in raw.keys():
		var v: Variant = raw[k]
		if typeof(v) == TYPE_STRING:
			out[String(k)] = String(v)
		else:
			out[String(k)] = int(v)
	return out


## Godot 的 JSON.parse_string() 對數字一律可能還原成 float（JSON 規格不分 int/float），背包這類
## 「value 必須是 int」的欄位（見 game_state.gd inv_add 的型別安全設計）讀檔後要重新轉型，否則後續
## `==` 整數比對可能因為 int/float 混用出錯。key 一律轉 String（JSON 物件 key 本來就只能是字串，這裡
## 是防禦性寫法，避免上游資料異常）。flags 另走 _load_flags（需保留 eqTitle 的 String 型別）。
func _as_int_dict(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for k in raw.keys():
		out[String(k)] = int(raw[k])
	return out


## eqInv/chests 皆為 `Array[String]`（見 SAVE_SCHEMA.md），讀檔後逐一轉型防禦 JSON 型別漂移。
func _as_string_array(raw: Variant) -> Array:
	var out := []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v in raw:
		out.append(String(v))
	return out


## party 是 `Array[Dictionary]`，內部欄位（lv/hp/mp/attrs...）不在本檔案的職責範圍內做型別正規化——
## 那牽涉 MOD-F `derive()` 尚未定案的資料形狀，跟 game_state.gd 檔頭「不整合 derive()」是同一個已知
## 限制。這裡只保證回傳值是 Array，過濾掉非 Dictionary 的髒元素（防禦手動改過的存檔檔案）。
func _as_array(raw: Variant) -> Array:
	var out := []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v in raw:
		if typeof(v) == TYPE_DICTIONARY:
			out.append(v)
	return out
