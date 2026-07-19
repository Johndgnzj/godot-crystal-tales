extends SceneTree

## world_harness_test.gd — 世界場景「實例化 harness」（第一章 Phase 2 / TASKS/13）。
##
## smoke_test.gd 刻意只把世界場景載成 PackedScene（淺檢查），不實例化——因為完整實例化需要先擺好
## GameState.party/spawn。本測試補上那一關：擺最小 GameState → 實際 instantiate 每張 painted 主線場景
## 加進 tree（跑真的 _ready()）→ 驗遭遇系統有正確接上。驗證打在 production code path（讓引擎實際載入、
## 跑 world_scene._ready / _setup_encounter_tracker / _is_enc_at），不是旁路模擬（見 memory
## verify-primary-source：這專案吃過「沒驗到底」的虧）。
##
##     # 全部 painted 主線場景
##     /Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/world_harness_test.gd --path .
##     # 只驗指定場景（`--` 之後傳 scene_id，可多個）
##     /Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/world_harness_test.gd --path . -- NMA EFA
##
## exit code 0 = 全綠。**一律綁 timeout 跑**（見 memory godot-run-validate：-s 腳本若在 quit() 前爆
## runtime error 會空轉不結束）。
##
## 每張場景驗：
##   1. instantiate + 進 tree 跑 _ready 無崩潰（＝ world_scene 全套 setup 在此場景資料下能跑完）。
##   2. world_scene._setup_encounter_tracker 有建出 _tracker（＝ enc_group 有設；空字串會 early return）。
##   3. _tracker.encounter_id == 預期遭遇表（mine / forest / forest2）。
##   4. _tracker.is_on_encounter_terrain 這個 Callable 有效（world_scene 有把 _is_enc_at 接上去）。
##   5. _is_enc_at(玩家出生點) == true（enc_rows 有填、走行區判定得到遭遇地形）——
##      光設 enc_group 不填 enc_rows 的話這裡會 false（enc_rows 空→恆 false），正是要抓的坑。
##   6. _is_enc_at(界外座標) == false（邊界防呆）。

# scene_id -> {"path": .tscn, "group": 預期 enc_group}
const SCENES := {
	"NMA": {"path": "res://scenes/world/painted/nm_a.tscn", "group": "mine"},
	"NMB": {"path": "res://scenes/world/painted/nm_b.tscn", "group": "mine"},
	"NMC": {"path": "res://scenes/world/painted/nm_c.tscn", "group": "mine"},
	"NMD": {"path": "res://scenes/world/painted/nm_d.tscn", "group": "mine"},
	"NME": {"path": "res://scenes/world/painted/nm_e.tscn", "group": "mine"},
	"NMF": {"path": "res://scenes/world/painted/nm_f.tscn", "group": "mine"},
	"EFA": {"path": "res://scenes/world/painted/ef_a.tscn", "group": "forest"},
	"EFB": {"path": "res://scenes/world/painted/ef_b.tscn", "group": "forest"},
	"EFC": {"path": "res://scenes/world/painted/ef_c.tscn", "group": "forest2"},
	"EFD": {"path": "res://scenes/world/painted/ef_d.tscn", "group": "forest2"},
	"EFE": {"path": "res://scenes/world/painted/ef_e.tscn", "group": "forest"},
	"EFF": {"path": "res://scenes/world/painted/ef_f.tscn", "group": "forest"},
	"EFG": {"path": "res://scenes/world/painted/ef_g.tscn", "group": "forest2"},
	"EFH": {"path": "res://scenes/world/painted/ef_h.tscn", "group": "forest2"},
	"EFI": {"path": "res://scenes/world/painted/ef_i.tscn", "group": "forest2"},
}

var _pass := 0
var _fail := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	print("=== 世界場景 harness 測試（Phase 2）===")
	# -s 腳本的 _initialize() 跑在 autoload 掛上 /root 之前，先等一個 frame 讓 autoload 就緒（同 smoke_test）。
	await process_frame

	var targets: Array = _resolve_targets()
	for sid in targets:
		await _check_scene(sid)

	print("\n=== 彙整：%d 通過 / %d 失敗 ===" % [_pass, _fail])
	if _fail == 0:
		print("HARNESS PASS")
	else:
		print("HARNESS FAIL — 見上方 [FAIL]")
	quit(0 if _fail == 0 else 1)


## `--` 之後有傳 scene_id 就只驗那些；否則驗全部（依 SCENES 宣告順序）。
func _resolve_targets() -> Array:
	var args := OS.get_cmdline_user_args()
	var out: Array = []
	for a in args:
		var key := String(a).to_upper()
		if SCENES.has(key):
			out.append(key)
		else:
			_bad("未知場景 id（--之後）：%s" % a)
	if out.is_empty():
		out = SCENES.keys()
	return out


func _check_scene(sid: String) -> void:
	print("\n-- %s --" % sid)
	var info: Dictionary = SCENES[sid]
	var path: String = info["path"]
	var expected_group: String = info["group"]

	if not ResourceLoader.exists(path):
		_bad("%s：場景檔不存在 %s" % [sid, path])
		return
	var packed := ResourceLoader.load(path)
	if not (packed is PackedScene):
		_bad("%s：載入非 PackedScene %s" % [sid, path])
		return

	_setup_min_gamestate()

	var inst: Node = (packed as PackedScene).instantiate()
	if inst == null:
		_bad("%s：instantiate() 回 null" % sid)
		return
	# add_child 會同步觸發 _ready；再等一幀讓後續 setup/子場景 _ready 收尾。
	root.add_child(inst)
	await process_frame

	if not inst.has_method("_is_enc_at"):
		_bad("%s：根節點腳本不是 world_scene.gd（無 _is_enc_at）——尚未遷移？" % sid)
		_free(inst)
		return
	_ok("%s：instantiate + _ready 無崩潰" % sid)

	# 2. tracker 有建出來（enc_group 空會 early return→null）
	var tracker: Variant = inst.get("_tracker")
	if tracker == null:
		_bad("%s：_setup_encounter_tracker 沒建 _tracker（enc_group 未設？）" % sid)
		_free(inst)
		return
	_ok("%s：_tracker 已建立" % sid)

	# 3. encounter_id == 預期遭遇表
	var got_group := String(tracker.get("encounter_id"))
	if got_group == expected_group:
		_ok("%s：encounter_id == \"%s\"" % [sid, expected_group])
	else:
		_bad("%s：encounter_id 為 \"%s\"，預期 \"%s\"" % [sid, got_group, expected_group])

	# 4. 地形判定 Callable 有接上
	var cb: Callable = tracker.get("is_on_encounter_terrain")
	if cb.is_valid():
		_ok("%s：is_on_encounter_terrain 已接線" % sid)
	else:
		_bad("%s：is_on_encounter_terrain 無效（world_scene 沒接 _is_enc_at）" % sid)

	# 5. 玩家出生點在走行區 → _is_enc_at 回 true（enc_rows 沒填會 false）
	var player := inst.get_node_or_null("YSort/Player")
	if player == null:
		_bad("%s：找不到 YSort/Player" % sid)
	else:
		var pos: Vector2 = (player as Node2D).global_position
		if bool(inst.call("_is_enc_at", pos)):
			_ok("%s：_is_enc_at(出生點 %s) == true" % [sid, str(pos)])
		else:
			_bad("%s：_is_enc_at(出生點 %s) == false（enc_rows 未填？）" % [sid, str(pos)])

	# 6. 界外座標 → false（邊界防呆）
	if bool(inst.call("_is_enc_at", Vector2(-64, -64))):
		_bad("%s：_is_enc_at(界外) 竟為 true（邊界判定壞）" % sid)
	else:
		_ok("%s：_is_enc_at(界外) == false" % sid)

	_free(inst)


## 最小可跑 GameState：擺一個 ludo 隊員、指定出生點、清掉會影響進場定位的暫態欄位。
func _setup_min_gamestate() -> void:
	var gs := root.get_node_or_null(^"GameState")
	if gs == null:
		return
	gs.set("party", [{"id": "ludo", "sprite": "ludo", "hp": 100, "maxhp": 100, "mp": 10, "maxmp": 10}])
	gs.set("flags", {})
	gs.set("spawn", "start")
	gs.set("result", "")
	gs.set("return_x", -1.0)
	gs.set("return_y", -1.0)


func _free(inst: Node) -> void:
	root.remove_child(inst)
	inst.queue_free()


func _ok(msg: String) -> void:
	_pass += 1
	print("  [OK]   " + msg)


func _bad(msg: String) -> void:
	_fail += 1
	print("  [FAIL] " + msg)
