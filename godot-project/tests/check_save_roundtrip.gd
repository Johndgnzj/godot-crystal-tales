extends SceneTree

## headless 驗證：存讀檔 roundtrip（SaveManager.save_game()/load_game()）。
##   /Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/check_save_roundtrip.gd --path .
##
## 覆蓋：
## - 一般欄位 roundtrip（gold/flags/item_inv/eq_inv/chests/auto/party）＋顯式 scene/x/y → resume 交握。
## - eqTitle（String 型 flag，flags 容器的刻意例外，見 game_state.gd flags 註解／titles_data.gd）讀檔保型。
## - 零參數 save_game() 沿用舊 scene/x/y、只更新資料欄位。
## - 非法場景名讀檔退回 Town（VALID_RESUME_SCENES 白名單）。
## - 多存檔槽（無上限）：新增槽、槽間互不覆蓋、指定槽讀檔、latest_slot()、刪除單槽後空號回收。

var _fail := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame   # 等 autoload（GameState/SaveManager/ContentDB…）掛上
	print("=== check_save_roundtrip ===")
	var gs: Node = root.get_node("/root/GameState")
	var sm: Node = root.get_node("/root/SaveManager")
	var gf: GDScript = load("res://scripts/game_flow.gd")
	if gf == null:
		print("  [FAIL] game_flow.gd 載入失敗")
		print("=== SAVE_ROUNDTRIP FAIL ==="); quit(1); return

	sm.delete_all_saves()   # 乾淨起點（清掉所有槽）

	# --- 建立已知局面 ---
	gf.new_game()                      # 合法初始隊伍（2 人）＋起始數值
	var party_n: int = gs.party.size()
	gs.gold = 777
	gs.flag_set("reg", 1)              # 一般 int flag
	gs.flags["eqTitle"] = "t_rookie"   # String 型 flag（刻意例外，測讀檔保型）
	gs.inv_add("potion", 5)            # item_inv
	gs.eq_inv.append("iron_sword")     # eq_inv
	gs.chest_mark_opened("mi_c1")      # chests
	gs.auto_battle = true
	var gold_saved: int = gs.gold
	var potion_saved: int = gs.inv_get("potion")

	# --- 存檔（顯式場景/座標）---
	sm.save_game("NMA", 123.0, 456.0)   # painted 主線場景（Forest 已退白名單，見 save_manager VALID_RESUME_SCENES）

	# --- 打亂記憶體狀態，證明讀檔真的還原 ---
	gs.gold = 0
	gs.flags = {}
	gs.item_inv = {}
	gs.eq_inv = []
	gs.chests = []
	gs.party = []
	gs.auto_battle = false
	gs.result = ""
	gs.return_x = -999.0
	gs.return_y = -999.0

	# --- 讀檔 ---
	_expect(sm.load_game(), "load_game() 回傳 true")
	_expect(gs.gold == gold_saved, "gold 還原（%d，期望 %d）" % [gs.gold, gold_saved])
	_expect(gs.flag_get("reg") == 1, "int flag reg 還原（得到 %d）" % gs.flag_get("reg"))
	var eq_title_v: Variant = gs.flags.get("eqTitle")
	_expect(typeof(eq_title_v) == TYPE_STRING and eq_title_v == "t_rookie",
		"eqTitle 保型還原為 String \"t_rookie\"（得到 %s，型別代碼 %d）" % [str(eq_title_v), typeof(eq_title_v)])
	_expect(gs.inv_get("potion") == potion_saved, "potion 還原（%d，期望 %d）" % [gs.inv_get("potion"), potion_saved])
	_expect(gs.eq_inv.has("iron_sword"), "eq_inv 含 iron_sword")
	_expect(gs.chest_is_opened("mi_c1"), "chests 含 mi_c1")
	_expect(gs.auto_battle == true, "auto_battle 還原為 true")
	_expect(gs.party.size() == party_n, "party 人數還原（%d，期望 %d）" % [gs.party.size(), party_n])
	_expect(sm.loaded_scene == "NMA", "loaded_scene=NMA（得到 %s）" % sm.loaded_scene)
	_expect(gs.result == "resume", "resume 交握 result=resume（得到 %s）" % gs.result)
	_expect(is_equal_approx(gs.return_x, 123.0), "return_x=123（得到 %s）" % gs.return_x)
	_expect(is_equal_approx(gs.return_y, 456.0), "return_y=456（得到 %s）" % gs.return_y)

	# --- 零參數 save_game()：沿用舊 scene/x/y、只更新資料欄位 ---
	gs.gold = 888
	sm.save_game()
	var raw: Variant = _read_save(sm, sm.current_slot)
	if typeof(raw) == TYPE_DICTIONARY:
		_expect(String(raw.get("scene", "")) == "NMA", "零參 save 沿用舊 scene=NMA（得到 %s）" % raw.get("scene"))
		_expect(is_equal_approx(float(raw.get("x", -1.0)), 123.0), "零參 save 沿用舊 x=123（得到 %s）" % raw.get("x"))
		_expect(int(raw.get("gold", 0)) == 888, "零參 save 更新 gold=888（得到 %s）" % raw.get("gold"))
	else:
		_expect(false, "零參 save 後存檔可讀回 Dictionary")

	# --- 非法場景名讀檔退回 Town ---
	sm.save_game("NotAScene", 1.0, 2.0)
	_expect(sm.load_game(), "非法場景存檔仍可讀")
	_expect(sm.loaded_scene == "Town", "非法場景讀檔退回 Town（得到 %s）" % sm.loaded_scene)

	# --- 多存檔槽（無上限）---
	sm.delete_all_saves()
	gs.gold = 100
	var s1: int = sm.save_to_slot(0, "Town", 10.0, 20.0)     # 新槽 → 1
	_expect(s1 == 1, "第一次存檔配到槽 1（得到 %d）" % s1)
	gs.gold = 200
	var s2: int = sm.save_to_slot(0, "NMA", 30.0, 40.0)      # 再一個新槽 → 2
	_expect(s2 == 2, "「新增存檔」配到槽 2（得到 %d）" % s2)
	_expect(sm.current_slot == 2, "存檔後 current_slot 指到新槽（得到 %d）" % sm.current_slot)
	_expect(sm.list_slots().size() == 2, "共 2 槽（得到 %d）" % sm.list_slots().size())
	_expect(sm.latest_slot() == 2, "latest_slot()=2（得到 %d）" % sm.latest_slot())

	gs.gold = 0
	_expect(sm.load_game(1), "指定槽 1 讀檔成功")
	_expect(gs.gold == 100, "槽 1 沒被槽 2 覆蓋（gold=%d，期望 100）" % gs.gold)
	_expect(sm.current_slot == 1, "讀檔後 current_slot=1（得到 %d）" % sm.current_slot)
	_expect(sm.loaded_scene == "Town", "槽 1 場景=Town（得到 %s）" % sm.loaded_scene)
	_expect(sm.load_game(2) and gs.gold == 200, "指定槽 2 讀回 gold=200（得到 %d）" % gs.gold)

	sm.delete_save(1)
	var left: Array = sm.list_slots()
	_expect(left.size() == 1 and left[0] == 2, "刪掉槽 1 後只剩槽 2（得到 %s）" % str(left))
	_expect(sm.next_free_slot() == 1, "空號回收：下一個新槽是 1（得到 %d）" % sm.next_free_slot())
	_expect(sm.has_save(), "還有存檔時 has_save()=true")

	sm.delete_all_saves()   # 收尾清乾淨
	_expect(not sm.has_save(), "全部刪除後 has_save()=false")
	_expect(sm.current_slot == 0, "全部刪除後 current_slot 歸零（得到 %d）" % sm.current_slot)

	print("=== %s ===" % ("SAVE_ROUNDTRIP OK" if _fail == 0 else "SAVE_ROUNDTRIP FAIL（%d）" % _fail))
	quit(0 if _fail == 0 else 1)


func _read_save(sm: Node, slot: int) -> Variant:
	var path: String = sm.slot_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	return JSON.parse_string(text)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK]   " + msg)
	else:
		_fail += 1
		print("  [FAIL] " + msg)
