extends SceneTree
## invert_paths.gd — 塊 B 收尾：把設計員刷的 PathPaint（可走區）反轉成 CollisionPaint 碰撞。
##
## 規則（見 docs/pipeline/地圖製作流程.md §7）：
##   PathPaint32 有的 32 格＝「整格可走」；只有 PathPaint16 刷到的 32 格＝「部分可走」（子格層級）。
##   一個 32 格：整格可走 → 無牆；部分可走 → 未刷的 16 子格放 16 牆（CollisionDetail）；
##   整格都沒刷 → 一顆 32 牆（CollisionPaint）。
##
## 自動保底（設計員不必刷到像素級精準）：
##   1. 出生點所在 32 格強制整格可走。
##   2. 每個出口：從出口格朝 start 落點補一小段橋（L 形），接到最近可走區，該橋整格可走。
##   3. 反轉後從 start flood-fill（整格＋部分格都算可走）驗證所有出生點/出口走得到，走不到印警告。
##
## 執行：Godot --headless -s res://scripts/map/invert_paths.gd --path <proj> -- <scene名...>
##   不給場景名＝處理全部 30 張。給名字（如 nm_a）＝只做那幾張。

const N32 := 40
const OUT_DIR := "res://scenes/world/painted/"
const COL_SRC := 0
const COL_ATLAS := Vector2i(0, 0)
const ALL := ["ef_a","ef_b","ef_c","ef_d","ef_e","ef_f","ef_g","ef_h","ef_i",
	"efd_a","efd_b","efd_c","efd_d","efd_e","efd_f","efd_g","efd_h","efd_i","efd_j","efd_k","efd_l","efd_m","efd_n","efd_m2",
	"nm_a","nm_b","nm_c","nm_d","nm_e","nm_f"]


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var targets: Array = args if args.size() > 0 else ALL
	for t in targets:
		_invert(OUT_DIR + str(t) + ".tscn")
	quit(0)


func _invert(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("找不到場景：" + path)
		return
	var root := (load(path) as PackedScene).instantiate()   # 不入樹＝不觸發 _ready
	var p32 := _used(root.get_node_or_null("PathPaint32"))
	var p16 := _used(root.get_node_or_null("PathPaint16"))
	var col32 := root.get_node_or_null("CollisionPaint") as TileMapLayer
	var col16 := root.get_node_or_null("CollisionDetail") as TileMapLayer
	if col32 == null or col16 == null:
		push_error("%s 缺 CollisionPaint/CollisionDetail 層" % path)
		root.free()
		return
	if p32.is_empty() and p16.is_empty():
		push_warning("%s 的 PathPaint 全空（還沒刷？）——跳過，不動碰撞" % path.get_file())
		root.free()
		return

	# 整格可走（PathPaint32）／部分可走（只有 PathPaint16 的 32 格）
	var full := {}
	for c: Vector2i in p32:
		full[c] = true
	var partial := {}
	for s: Vector2i in p16:
		var pc := Vector2i(s.x / 2, s.y / 2)
		if not full.has(pc):
			partial[pc] = true
	var walkbase := full.duplicate()          # 橋/連通用：整格或部分皆算可走
	for c in partial:
		walkbase[c] = true

	var spawns := _spawns(root)
	var start_cell: Vector2i = spawns.get("start", Vector2i(N32 / 2, N32 / 2))

	# 保底：出生點格 + 每個出口朝 start 補橋（補到碰可走區為止），皆設整格可走
	var force := {}
	for k in spawns:
		force[spawns[k]] = true
	var bridged := 0
	for ex_cell in _exit_cells(root):
		for b in _bridge(ex_cell, start_cell, walkbase):
			if not force.has(b) and not walkbase.has(b):
				bridged += 1
			force[b] = true
	for f in force:
		full[f] = true
		partial.erase(f)

	# 反轉建牆
	col32.clear()
	col16.clear()
	var n32 := 0
	var n16 := 0
	for cy in N32:
		for cx in N32:
			var c := Vector2i(cx, cy)
			if full.has(c):
				continue                       # 整格可走→無牆
			if partial.has(c):
				for s in _subs(c):             # 部分可走→未刷的 16 子格當牆
					if not p16.has(s):
						col16.set_cell(s, COL_SRC, COL_ATLAS)
						n16 += 1
			else:
				col32.set_cell(c, COL_SRC, COL_ATLAS)   # 整格牆
				n32 += 1

	# 連通驗證：從 start flood（整格＋部分格都算可走）
	var walk_all := full.duplicate()
	for c in partial:
		walk_all[c] = true
	var reach := _flood(start_cell, walk_all)
	var warns: Array = []
	for k in spawns:
		if not reach.has(spawns[k]):
			warns.append("落點 '%s' %s 走不到" % [k, spawns[k]])
	for ec in _exit_cells(root):
		if not reach.has(ec):
			warns.append("出口 %s 走不到" % ec)

	var packed := PackedScene.new()
	if packed.pack(root) == OK:
		ResourceSaver.save(packed, path)
	print("\n=== %s ===" % path.get_file())
	print("PathPaint 32格=%d 16格=%d → 牆 32格=%d 16格=%d；補橋=%d格；可走總數=%d/%d" %
		[p32.size(), p16.size(), n32, n16, bridged, walk_all.size(), N32 * N32])
	if warns.is_empty():
		print("連通驗證：✅ 所有出生點/出口皆可從 start 走到")
	else:
		for w in warns:
			print("連通驗證：❌ ", w)
	print(_ascii(full, partial))
	root.free()


func _used(layer: Node) -> Dictionary:
	var d := {}
	if layer is TileMapLayer:
		for c in (layer as TileMapLayer).get_used_cells():
			d[c] = true
	return d


func _spawns(root: Node) -> Dictionary:
	var out := {}
	var sp = root.get("spawns")
	if sp is Dictionary:
		for k in sp:
			if sp[k] is Vector2:
				out[k] = _cell(sp[k])
	return out


func _exit_cells(root: Node) -> Array:
	var out: Array = []
	var zones := root.get_node_or_null("Zones")
	if zones != null:
		for z in zones.get_children():
			if z.get("to_scene") != null and str(z.get("to_scene")) != "" and z is Node2D:
				out.append(_cell((z as Node2D).position))
	return out


## 從出口格朝 to_cell 走 L 形，回傳「碰到可走區前」經過的牆格（要補成可走的橋）。
func _bridge(from_cell: Vector2i, to_cell: Vector2i, walk: Dictionary) -> Array:
	var cells: Array = []
	var cur := from_cell
	var guard := 0
	while guard < 200:
		guard += 1
		if walk.has(cur):
			break
		cells.append(cur)
		if cur == to_cell:
			break
		var d := to_cell - cur
		if absi(d.x) >= absi(d.y) and d.x != 0:
			cur += Vector2i(signi(d.x), 0)
		elif d.y != 0:
			cur += Vector2i(0, signi(d.y))
		else:
			cur += Vector2i(signi(d.x), 0)
	return cells


func _flood(start: Vector2i, walk: Dictionary) -> Dictionary:
	var seen := {}
	if not walk.has(start):
		return seen
	var q: Array = [start]
	seen[start] = true
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if walk.has(n) and not seen.has(n):
				seen[n] = true
				q.append(n)
	return seen


func _subs(c: Vector2i) -> Array:
	return [Vector2i(c.x * 2, c.y * 2), Vector2i(c.x * 2 + 1, c.y * 2),
		Vector2i(c.x * 2, c.y * 2 + 1), Vector2i(c.x * 2 + 1, c.y * 2 + 1)]


func _cell(v: Vector2) -> Vector2i:
	return Vector2i(clampi(int(v.x) / 32, 0, N32 - 1), clampi(int(v.y) / 32, 0, N32 - 1))


func _ascii(full: Dictionary, partial: Dictionary) -> String:
	var s := "整格可走(.) / 部分16(+) / 牆(#)　預覽（40×40）：\n"
	for cy in N32:
		for cx in N32:
			var c := Vector2i(cx, cy)
			if full.has(c):
				s += "."
			elif partial.has(c):
				s += "+"
			else:
				s += "#"
		s += "\n"
	return s
