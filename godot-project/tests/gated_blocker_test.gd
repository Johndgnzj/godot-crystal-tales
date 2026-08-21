extends SceneTree
## gated_blocker_test.gd — 驗 `scripts/world/gated_blocker.gd`：旗標決定「擋不擋」。
##
## 為什麼要有這支：gated 物件是「路原本就通、任務前先擋住」的唯一機制（M4 boss 廣場往 M7 的路障、
## 第二章檢查哨柵欄）。它一旦失效，玩家會直接穿過本該擋住的路障，或打倒 boss 後路還是不通。
##
## 執行：/Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tests/gated_blocker_test.gd --path <proj>
## 用 load() 而非 class_name 建節點——主腳本在引擎啟動早期編譯，避開 class cache 依賴。

const GB := "res://scripts/world/gated_blocker.gd"

var _pass := 0
var _fail := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	# -s 腳本的 _initialize() 跑在 autoload 掛上 /root 之前，先等一幀（同 smoke_test.gd）。
	await process_frame
	var gs := root.get_node("/root/GameState")
	gs.flags.erase("efd_boss")

	var blocker := _make("efd_boss==0", "")
	root.add_child(blocker)
	var shape: CollisionShape2D = blocker.get_child(0)

	# 旗標未設（＝0）→ 路障在，擋人
	_check("旗標未設時顯示", blocker.visible, true)
	_check("旗標未設時碰撞開啟", shape.disabled, false)

	# 打倒 boss（旗標=1）→ 下一幀自己消失、碰撞關掉
	gs.flags["efd_boss"] = 1
	blocker._process(0.016)
	_check("旗標成立後隱藏", blocker.visible, false)
	_check("旗標成立後碰撞關閉", shape.disabled, true)

	# 旗標再被清掉（例：讀取舊存檔）→ 回來擋住
	gs.flags["efd_boss"] = 0
	blocker._process(0.016)
	_check("旗標回復後又擋住", blocker.visible, true)
	_check("旗標回復後碰撞開啟", shape.disabled, false)

	# hide_flag：另一條「強制消失」的路，與 show_when 互相獨立
	var forced := _make("always", "efd_gate_open")
	root.add_child(forced)
	var forced_shape: CollisionShape2D = forced.get_child(0)
	_check("hide_flag 未設時擋住", forced.visible, true)
	gs.flags["efd_gate_open"] = 1
	forced._process(0.016)
	_check("hide_flag 設立後消失", forced.visible, false)
	_check("hide_flag 設立後碰撞關閉", forced_shape.disabled, true)

	# 碰撞層要跟 collision_tileset_32（physics_layer_0/collision_layer = 1）一致，否則擋不住玩家
	_check("碰撞層＝1", blocker.collision_layer, 1)

	gs.flags.erase("efd_boss")
	gs.flags.erase("efd_gate_open")
	print("\n=== 彙整：%d 通過 / %d 失敗 ===" % [_pass, _fail])
	print("GATED BLOCKER PASS" if _fail == 0 else "GATED BLOCKER FAIL")
	quit(0 if _fail == 0 else 1)


func _make(show_when: String, hide_flag: String) -> StaticBody2D:
	var node := StaticBody2D.new()
	node.set_script(load(GB))
	node.set("show_when", show_when)
	node.set("hide_flag", hide_flag)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 64)
	shape.shape = rect
	node.add_child(shape)
	return node


func _check(what: String, got: Variant, want: Variant) -> void:
	if got == want:
		_pass += 1
		print("  [OK]   %s" % what)
	else:
		_fail += 1
		print("  [FAIL] %s（得到 %s，預期 %s）" % [what, str(got), str(want)])
