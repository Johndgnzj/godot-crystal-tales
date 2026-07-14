extends SceneTree

## headless 驗證：存讀檔 roundtrip（SaveManager.save_game()/load_game()）。
##   /Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/check_save_roundtrip.gd --path .
##
## 覆蓋：
## - 一般欄位 roundtrip（gold/flags/item_inv/eq_inv/chests/auto/party）＋顯式 scene/x/y → resume 交握。
## - eqTitle（String 型 flag，flags 容器的刻意例外，見 game_state.gd flags 註解／titles_data.gd）讀檔保型。
## - 零參數 save_game() 沿用舊 scene/x/y、只更新資料欄位。
## - 非法場景名讀檔退回 Town（VALID_RESUME_SCENES 白名單）。

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

	sm.delete_save()   # 乾淨起點

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
	sm.save_game("Forest", 123.0, 456.0)

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
	_expect(sm.loaded_scene == "Forest", "loaded_scene=Forest（得到 %s）" % sm.loaded_scene)
	_expect(gs.result == "resume", "resume 交握 result=resume（得到 %s）" % gs.result)
	_expect(is_equal_approx(gs.return_x, 123.0), "return_x=123（得到 %s）" % gs.return_x)
	_expect(is_equal_approx(gs.return_y, 456.0), "return_y=456（得到 %s）" % gs.return_y)

	# --- 零參數 save_game()：沿用舊 scene/x/y、只更新資料欄位 ---
	gs.gold = 888
	sm.save_game()
	var raw: Variant = _read_save()
	if typeof(raw) == TYPE_DICTIONARY:
		_expect(String(raw.get("scene", "")) == "Forest", "零參 save 沿用舊 scene=Forest（得到 %s）" % raw.get("scene"))
		_expect(is_equal_approx(float(raw.get("x", -1.0)), 123.0), "零參 save 沿用舊 x=123（得到 %s）" % raw.get("x"))
		_expect(int(raw.get("gold", 0)) == 888, "零參 save 更新 gold=888（得到 %s）" % raw.get("gold"))
	else:
		_expect(false, "零參 save 後存檔可讀回 Dictionary")

	# --- 非法場景名讀檔退回 Town ---
	sm.save_game("NotAScene", 1.0, 2.0)
	_expect(sm.load_game(), "非法場景存檔仍可讀")
	_expect(sm.loaded_scene == "Town", "非法場景讀檔退回 Town（得到 %s）" % sm.loaded_scene)

	sm.delete_save()   # 收尾清乾淨

	print("=== %s ===" % ("SAVE_ROUNDTRIP OK" if _fail == 0 else "SAVE_ROUNDTRIP FAIL（%d）" % _fail))
	quit(0 if _fail == 0 else 1)


func _read_save() -> Variant:
	var path := "user://cq_save.json"
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
