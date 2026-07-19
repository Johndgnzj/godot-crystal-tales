extends SceneTree

## headless 驗證：GameFlow.new_game() 是否產生合法的初始局面（對應 build_cq2 newGame）。
##   /Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/check_new_game.gd --path .

var _fail := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame   # 等 autoload（ContentDB 等）掛上
	print("=== check_new_game ===")
	# -s 腳本編譯期看不到 autoload 全域名，改從 /root 取（遊戲本體的正常腳本可直接用 GameState）。
	var gs: Node = root.get_node("/root/GameState")
	# 執行期 load（此時 autoload 已掛上，等同遊戲內正常載入 game_flow.gd 的情境）。
	var gf: GDScript = load("res://scripts/game_flow.gd")
	if gf == null:
		print("  [FAIL] game_flow.gd 載入失敗")
		print("=== NEW_GAME FAIL ==="); quit(1); return
	gf.new_game()

	_expect(gs.party.size() == 2, "隊伍 2 人（得到 %d）" % gs.party.size())
	_expect(gs.gold == 30, "金錢 30（得到 %d）" % gs.gold)
	_expect(int(gs.inv_get("potion")) == 4, "藥水 4（得到 %d）" % gs.inv_get("potion"))
	_expect(gs.eq_inv.has("swift_boots"), "裝備袋含 swift_boots")
	_expect(gs.flag_get("ch1") == 0 and gs.flags.has("ch1_step"), "起始 flags 設好")
	_expect(gs.spawn == "home", "spawn=home")

	if gs.party.size() > 0:
		var m: Dictionary = gs.party[0]
		_expect(m.get("id") == "ludo", "隊長是 ludo（得到 %s）" % m.get("id"))
		_expect(float(m.get("maxhp", 0)) > 0.0, "隊長 maxhp>0（derive 有跑，得到 %s）" % m.get("maxhp"))
		_expect(m.get("hp") == m.get("maxhp"), "隊長滿血 hp==maxhp")
		_expect(float(m.get("patk", 0)) > 0.0 or float(m.get("matk", 0)) > 0.0, "隊長有攻擊力（derive 衍生欄位）")
		print("  ludo: lv=%s hp=%s/%s mp=%s/%s patk=%s matk=%s spd=%s" % [
			m.get("lv"), m.get("hp"), m.get("maxhp"), m.get("mp"), m.get("maxmp"),
			m.get("patk"), m.get("matk"), m.get("spd")])

	print("=== %s ===" % ("NEW_GAME OK" if _fail == 0 else "NEW_GAME FAIL（%d）" % _fail))
	quit(0 if _fail == 0 else 1)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  [OK]   " + msg)
	else:
		_fail += 1
		print("  [FAIL] " + msg)
