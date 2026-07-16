class_name MapKit
extends RefCounted
## 地圖生成演算法（無副作用的靜態工具，操作 MapGrid）。
## 由 gen_maps.py / region_gen.py 忠實移植（迷宮雕刻、開闊佈局、autotile、碰撞合併、連通性…），
## 但改用 Godot RandomNumberGenerator（不追求與 Python RNG 逐格一致——這些是新地圖）。
## 見 TASKS/12_地圖生成器.md。

const TS := 32
const ATLAS_COLS := 6
## atlas tile 順序（＝id-1），對齊 world_scene.gd 消費端與舊 tileset_*.tres。
const TILES: Array[String] = [
	"grass", "grassf", "path", "dirt", "tgrass", "water", "sand", "bridge",
	"rockfloor", "gravel", "cavefloor", "cavedark", "rail", "farm",
	"grass2", "grass3", "plaza",
	"pn", "ps", "pw", "pe", "pnw", "pne", "psw", "pse", "pc",
	"pinw", "pine", "pisw", "pise",
	"cwall", "cwtop", "fwall", "ctop"]

## 大樹貼圖位移：樹底對齊格底、水平置中（96x120 樹，同 gen_maps TPX/TPY）。
const TPX := -32
const TPY := -88
## 玩家 origin＝腳點＝左上+(32,54)（world_scene.gd 座標約定）。
const FEET_X := 32
const FEET_Y := 54

const FTREE_TEX: Array[String] = [
	"fst_tree_1.png", "fst_tree_2.png", "fst_tree_3.png",
	"fst_tree_4.png", "fst_tree_5.png", "fst_tree_6.png"]
const FDECO_TEX: Array[String] = [
	"fst_deco_fern.png", "fst_deco_mush.png", "fst_deco_flower.png", "fst_deco_pebble.png",
	"fst_deco_fern.png", "fst_deco_flower.png", "fst_deco_bush.png"]

## 地形主題：kind → (根 base tile, tileset, atlas, floor)。抽成表＝主題可換的接縫。
const THEME := {
	"mine": {"base": "cwall", "tileset": "tileset_world.tres", "atlas": "atlas.png", "floor": "rockfloor"},
	"cave": {"base": "cwall", "tileset": "tileset_world.tres", "atlas": "atlas.png", "floor": "cavefloor"},
	"forest": {"base": "grass", "tileset": "tileset_forest.tres", "atlas": "atlas_forest.png", "floor": "grass"},
	"grassland": {"base": "grass", "tileset": "tileset_world.tres", "atlas": "atlas.png", "floor": "grass"},
}
const ROOMS_BY_COMPLEXITY := {"low": 1, "medium": 3, "high": 6}
const OPENNESS_COVER := {"wide": 0.12, "medium": 0.22, "tight": 0.32}   ## 障礙覆蓋率（越低＝路越寬）

const _DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## autotile 鄰接碼(T<<3|B<<2|L<<1|R) → path 變體名。
const _AUTOTILE_MAP := {
	15: "pc", 7: "pn", 11: "ps", 13: "pw", 14: "pe",
	5: "pnw", 6: "pne", 9: "psw", 10: "pse"}

static var _GID: Dictionary = {}
static var _FAMILY: Dictionary = {}


## tile 名 → id（1 起算，同 tmj gid）。
static func gid(n: String) -> int:
	if _GID.is_empty():
		for i in TILES.size():
			_GID[TILES[i]] = i + 1
	return _GID[n]


static func choice(arr: Array, rng: RandomNumberGenerator) -> Variant:
	return arr[rng.randi_range(0, arr.size() - 1)]


static func spawn_px(tx: int, ty: int) -> Vector2i:
	## tile → spawn 左上像素（build_scene 會再加 (FEET_X,FEET_Y)，腳點落在該格中心）。
	return Vector2i(tx * TS + TS / 2 - FEET_X, ty * TS + TS / 2 - FEET_Y)


# ============================ 基本雕刻 ============================
static func open_rect(mb: MapGrid, xa: int, ya: int, xb: int, yb: int, floor: int) -> void:
	for yy in range(ya, yb + 1):
		for xx in range(xa, xb + 1):
			mb.set_tile(xx, yy, floor)
			mb.unblock_cell(xx, yy)


static func _cell_base(x0: int, y0: int, cx: int, cy: int) -> Vector2i:
	return Vector2i(x0 + 1 + cx * 3, y0 + 1 + cy * 3)


static func carve_maze(mb: MapGrid, x0: int, y0: int, x1: int, y1: int, wall: int, floor: int, rng: RandomNumberGenerator) -> void:
	## 區域填牆後挖完美迷宮（cell=3：走廊 2 + 牆 1，走廊統一 2 格寬）。
	for yy in range(y0, y1 + 1):
		for xx in range(x0, x1 + 1):
			mb.set_tile(xx, yy, wall)
	mb.block_rect(x0, y0, x1, y1)
	var cw := (x1 - x0) / 3
	var ch := (y1 - y0) / 3
	if cw <= 0 or ch <= 0:
		return
	var seen: Array = []
	for _cy in ch:
		var row: Array = []
		for _cx in cw:
			row.append(false)
		seen.append(row)
	var scx := rng.randi_range(0, cw - 1)
	var scy := rng.randi_range(0, ch - 1)
	seen[scy][scx] = true
	var stack: Array = [Vector2i(scx, scy)]
	var b0 := _cell_base(x0, y0, scx, scy)
	open_rect(mb, b0.x, b0.y, b0.x + 1, b0.y + 1, floor)
	while not stack.is_empty():
		var cur: Vector2i = stack[-1]
		var nbrs: Array = []
		for d in _DIRS:
			var nx := cur.x + d.x
			var ny := cur.y + d.y
			if nx >= 0 and nx < cw and ny >= 0 and ny < ch and not seen[ny][nx]:
				nbrs.append(Vector2i(nx, ny))
		if nbrs.is_empty():
			stack.pop_back()
			continue
		var nxt: Vector2i = choice(nbrs, rng)
		seen[nxt.y][nxt.x] = true
		var a := _cell_base(x0, y0, cur.x, cur.y)
		var b := _cell_base(x0, y0, nxt.x, nxt.y)
		open_rect(mb, mini(a.x, b.x), mini(a.y, b.y), maxi(a.x, b.x) + 1, maxi(a.y, b.y) + 1, floor)
		stack.append(nxt)


# ============================ 後處理：autotile / 牆帽 / 草地變化 ============================
static func _is_family(t: int) -> bool:
	if _FAMILY.is_empty():
		for n in ["path", "dirt", "bridge", "farm", "rail", "plaza", "pc",
				"pn", "ps", "pw", "pe", "pnw", "pne", "psw", "pse",
				"pinw", "pine", "pisw", "pise"]:
			_FAMILY[gid(n)] = true
	return _FAMILY.has(t)


static func _fam(src: PackedInt32Array, mw: int, mh: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= mw or y >= mh:
		return true
	return _is_family(src[y * mw + x])


static func autotile(mb: MapGrid) -> void:
	## 依鄰接把 path/dirt 換成正確的邊角變體（same behavior as gen_maps.autotile）。
	var src := mb.g.duplicate()
	var path := gid("path")
	var dirt := gid("dirt")
	for y in mb.mh:
		for x in mb.mw:
			var t := src[y * mb.mw + x]
			if t != path and t != dirt:
				continue
			var top := _fam(src, mb.mw, mb.mh, x, y - 1)
			var bot := _fam(src, mb.mw, mb.mh, x, y + 1)
			var lft := _fam(src, mb.mw, mb.mh, x - 1, y)
			var rgt := _fam(src, mb.mw, mb.mh, x + 1, y)
			var code := (int(top) << 3) | (int(bot) << 2) | (int(lft) << 1) | int(rgt)
			var nm: String = _AUTOTILE_MAP.get(code, "pc")
			var tile := gid(nm)
			if nm == "pc":
				if not _fam(src, mb.mw, mb.mh, x - 1, y - 1):
					tile = gid("pinw")
				elif not _fam(src, mb.mw, mb.mh, x + 1, y - 1):
					tile = gid("pine")
				elif not _fam(src, mb.mw, mb.mh, x - 1, y + 1):
					tile = gid("pisw")
				elif not _fam(src, mb.mw, mb.mh, x + 1, y + 1):
					tile = gid("pise")
			mb.g[y * mb.mw + x] = tile


static func wall_caps(mb: MapGrid) -> void:
	## 洞窟牆：下方是地板→畫牆面(cwall)，否則牆頂(ctop)。
	var cwall := gid("cwall")
	var ctop := gid("ctop")
	var src := mb.g.duplicate()
	for y in mb.mh:
		for x in mb.mw:
			var t := src[y * mb.mw + x]
			if t != cwall and t != ctop:
				continue
			var below := -1
			if y + 1 < mb.mh:
				below = src[(y + 1) * mb.mw + x]
			if below != -1 and below != cwall and below != ctop:
				mb.g[y * mb.mw + x] = cwall
			else:
				mb.g[y * mb.mw + x] = ctop


static func grass_vary(mb: MapGrid, rng: RandomNumberGenerator) -> void:
	var grass := gid("grass")
	var opts: Array = [gid("grass"), gid("grass"), gid("grass2"), gid("grass3")]
	for i in mb.g.size():
		if mb.g[i] == grass:
			mb.g[i] = choice(opts, rng)


# ============================ 碰撞矩形 / 連通性 ============================
static func merge_block_rects(mb: MapGrid) -> Array:
	## BLK 網格 → 貪婪合併矩形（tile 座標 [x0,y0,x1,y1]，含端點）。逐列取水平連續段、等寬段向下併。
	var rects: Array = []
	var active: Dictionary = {}   # Vector2i(x0,x1) -> Vector2i(y0,y1)
	for y in mb.mh:
		var runs: Array = []
		var x := 0
		while x < mb.mw:
			if mb.blocked[y][x]:
				var x0 := x
				while x < mb.mw and mb.blocked[y][x]:
					x += 1
				runs.append(Vector2i(x0, x - 1))
			else:
				x += 1
		var nxt: Dictionary = {}
		for r in runs:
			if active.has(r):
				var yr: Vector2i = active[r]
				active.erase(r)
				nxt[r] = Vector2i(yr.x, y)
			else:
				nxt[r] = Vector2i(y, y)
		for r in active.keys():
			var yr: Vector2i = active[r]
			rects.append([r.x, yr.x, r.y, yr.y])   # x0,y0,x1,y1
		active = nxt
	for r in active.keys():
		var yr: Vector2i = active[r]
		rects.append([r.x, yr.x, r.y, yr.y])
	return rects


static func reachable(mb: MapGrid, start: Vector2i) -> Dictionary:
	## 從 start 走可行格 BFS，回傳 {Vector2i: true} 的可達集。
	var seen: Dictionary = {start: true}
	var q: Array = [start]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in _DIRS:
			var n := c + d
			if n.x >= 0 and n.x < mb.mw and n.y >= 0 and n.y < mb.mh \
					and not seen.has(n) and not mb.blocked[n.y][n.x]:
				seen[n] = true
				q.append(n)
	return seen


static func farthest_cell(mb: MapGrid, start: Vector2i) -> Vector2i:
	## 離 start（BFS 距離）最遠的可走格——boss 擺這裡。
	var dist: Dictionary = {start: 0}
	var q: Array = [start]
	var head := 0
	var best := start
	var bestd := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in _DIRS:
			var n := c + d
			if n.x >= 0 and n.x < mb.mw and n.y >= 0 and n.y < mb.mh \
					and not dist.has(n) and not mb.blocked[n.y][n.x]:
				var nd: int = int(dist[c]) + 1
				dist[n] = nd
				if nd > bestd:
					bestd = nd
					best = n
				q.append(n)
	return best


static func carve_path(mb: MapGrid, a: Vector2i, b: Vector2i, tile: int) -> void:
	## a、b 間沿可走格 BFS 最短路鋪地磚（像林徑；只換地磚＋清遇敵旗標，不改 blocked）。
	var prev: Dictionary = {a: a}
	var q: Array = [a]
	var head := 0
	var found := false
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		if cur == b:
			found = true
			break
		for d in _DIRS:
			var n := cur + d
			if n.x >= 0 and n.x < mb.mw and n.y >= 0 and n.y < mb.mh \
					and not prev.has(n) and not mb.blocked[n.y][n.x]:
				prev[n] = cur
				q.append(n)
	if not found:
		return
	var node := b
	while true:
		mb.set_tile(node.x, node.y, tile)
		mb.enc[node.y][node.x] = false
		if node == a:
			break
		node = prev[node]


# ============================ 地形：open / maze ============================
static func rooms(mb: MapGrid, complexity: String, floor: int, rng: RandomNumberGenerator) -> void:
	var count: int = ROOMS_BY_COMPLEXITY.get(complexity, 3)
	for _i in count:
		var rw := rng.randi_range(2, 4)
		var rh := rng.randi_range(2, 4)
		if mb.mw - 3 - rw <= 2 or mb.mh - 3 - rh <= 2:
			continue
		var rx := rng.randi_range(2, mb.mw - 3 - rw)
		var ry := rng.randi_range(2, mb.mh - 3 - rh)
		open_rect(mb, rx, ry, rx + rw, ry + rh, floor)


static func grow_blob(mb: MapGrid, seed_cell: Vector2i, size: int, wall: int, rng: RandomNumberGenerator) -> void:
	## 從 seed 長一團有機障礙叢並標成牆。
	var cells: Dictionary = {seed_cell: true}
	var frontier: Array = [seed_cell]
	while cells.size() < size and not frontier.is_empty():
		var c: Vector2i = choice(frontier, rng)
		var opts: Array = []
		for d in _DIRS:
			var n := c + d
			if n.x >= 2 and n.x <= mb.mw - 3 and n.y >= 2 and n.y <= mb.mh - 3 and not cells.has(n):
				opts.append(n)
		if opts.is_empty():
			frontier.erase(c)
			continue
		var nn: Vector2i = choice(opts, rng)
		cells[nn] = true
		frontier.append(nn)
	for cell in cells.keys():
		mb.set_tile(cell.x, cell.y, wall)
		mb.block_cell(cell.x, cell.y)


static func largest_open_component(mb: MapGrid) -> Dictionary:
	var seen: Dictionary = {}
	var best: Dictionary = {}
	for sy in range(1, mb.mh - 1):
		for sx in range(1, mb.mw - 1):
			var s := Vector2i(sx, sy)
			if mb.blocked[sy][sx] or seen.has(s):
				continue
			var comp: Dictionary = {}
			var q: Array = [s]
			seen[s] = true
			var head := 0
			while head < q.size():
				var c: Vector2i = q[head]
				head += 1
				comp[c] = true
				for d in _DIRS:
					var n := c + d
					if n.x >= 1 and n.x < mb.mw - 1 and n.y >= 1 and n.y < mb.mh - 1 \
							and not mb.blocked[n.y][n.x] and not seen.has(n):
						seen[n] = true
						q.append(n)
			if comp.size() > best.size():
				best = comp
	return best


static func _blocked_count(mb: MapGrid) -> int:
	var n := 0
	for y in range(1, mb.mh - 1):
		for x in range(1, mb.mw - 1):
			if mb.blocked[y][x]:
				n += 1
	return n


static func place_forest_props(mb: MapGrid, rng: RandomNumberGenerator, tree_rate := 0.5, decor_rate := 0.11) -> void:
	## 樹擺在障礙叢(fwall)上、裝飾撒草地——增森林完整度。缺圖時 world_scene 會略過。
	var fwall := gid("fwall")
	var grass_like := {gid("grass"): true, gid("grassf"): true, gid("grass2"): true,
			gid("grass3"): true, gid("tgrass"): true}
	for y in range(1, mb.mh - 1):
		for x in range(1, mb.mw - 1):
			if mb.get_tile(x, y) == fwall and mb.get_tile(x, y - 1) == fwall and rng.randf() < tree_rate:
				mb.add_prop(choice(FTREE_TEX, rng), x * TS + TPX, y * TS + TPY)
	for y in range(1, mb.mh - 1):
		for x in range(1, mb.mw - 1):
			if not mb.blocked[y][x] and grass_like.has(mb.get_tile(x, y)) and rng.randf() < decor_rate:
				mb.add_prop(choice(FDECO_TEX, rng), x * TS, y * TS + 6)


static func terrain_maze(mb: MapGrid, kind: String, complexity: String, floor: int, rng: RandomNumberGenerator) -> void:
	var wall := gid("fwall") if kind in ["forest", "grassland"] else gid("cwall")
	carve_maze(mb, 1, 1, mb.mw - 2, mb.mh - 2, wall, floor, rng)
	rooms(mb, complexity, floor, rng)
	if kind == "mine":
		var gravel := gid("gravel")
		for i in mb.g.size():
			if mb.g[i] == floor and rng.randf() < 0.40:
				mb.g[i] = gravel
	elif kind == "cave":
		for y in mb.mh:
			for x in mb.mw:
				if not mb.blocked[y][x]:
					mb.enc[y][x] = true
	else:
		var tg := gid("tgrass")
		for i in mb.g.size():
			if mb.g[i] == floor and rng.randf() < 0.32:
				mb.g[i] = tg
	mb.mark_enc()
	if kind in ["mine", "cave"]:
		wall_caps(mb)
	else:
		autotile(mb)
		grass_vary(mb, rng)


static func terrain_open(mb: MapGrid, kind: String, floor: int, openness: String, rng: RandomNumberGenerator) -> void:
	## 自然開闊：滿地可走、散佈有機障礙叢、保留最大連通開放區、填掉孤立口袋。
	var wall := gid("fwall") if kind in ["forest", "grassland"] else gid("cwall")
	for y in range(1, mb.mh - 1):
		for x in range(1, mb.mw - 1):
			mb.set_tile(x, y, floor)
			mb.unblock_cell(x, y)
	var cover: float = OPENNESS_COVER.get(openness, 0.22)
	var target := int(cover * (mb.mw - 2) * (mb.mh - 2))
	var guard := 0
	while _blocked_count(mb) < target and guard < 3000:
		guard += 1
		var seed_cell := Vector2i(rng.randi_range(2, mb.mw - 3), rng.randi_range(2, mb.mh - 3))
		grow_blob(mb, seed_cell, rng.randi_range(3, 10), wall, rng)
	var comp := largest_open_component(mb)   # 只保留最大連通開放區
	for y in range(1, mb.mh - 1):
		for x in range(1, mb.mw - 1):
			if not mb.blocked[y][x] and not comp.has(Vector2i(x, y)):
				mb.set_tile(x, y, wall)
				mb.block_cell(x, y)
	if kind in ["forest", "grassland"]:
		var tg := gid("tgrass")
		for cell in comp.keys():
			if rng.randf() < 0.26:
				mb.set_tile(cell.x, cell.y, tg)
		var fwall := gid("fwall")                 # 外圈樹籬（出入口之後由 carve_opening 鑿開）
		for x in mb.mw:
			mb.set_tile(x, 0, fwall)
			mb.set_tile(x, mb.mh - 1, fwall)
		for y in mb.mh:
			mb.set_tile(0, y, fwall)
			mb.set_tile(mb.mw - 1, y, fwall)
		mb.mark_enc()
		grass_vary(mb, rng)
	else:
		for cell in comp.keys():
			mb.enc[cell.y][cell.x] = true
		wall_caps(mb)


static func carve_kind(mb: MapGrid, mdef: MapDef, rng: RandomNumberGenerator) -> Dictionary:
	## 依 kind＋layout 產地形，回傳 {tileset, atlas, floor}。
	var kind := mdef.kind
	if not THEME.has(kind):
		push_error("map '%s' 未知 kind：%s（支援 mine/cave/forest/grassland）" % [mdef.id, kind])
		return {}
	var th: Dictionary = THEME[kind]
	var floor := gid(th["floor"])
	if mdef.effective_layout() == "open":
		terrain_open(mb, kind, floor, mdef.openness, rng)
	else:
		terrain_maze(mb, kind, mdef.complexity, floor, rng)
	return {
		"tileset": "res://resources/map/" + th["tileset"],
		"atlas": "res://assets/map/" + th["atlas"],
		"floor": floor,
	}


# ============================ 邊緣開口 ============================
static func inner_edge_cells(mb: MapGrid, edge: String) -> Array:
	## 某邊「內側一排」可走的地板格（鑿開口候選）。
	var line: Array = []
	if edge == "E":
		for y in range(2, mb.mh - 2):
			line.append(Vector2i(mb.mw - 2, y))
	elif edge == "W":
		for y in range(2, mb.mh - 2):
			line.append(Vector2i(1, y))
	elif edge == "N":
		for x in range(2, mb.mw - 2):
			line.append(Vector2i(x, 1))
	else:  # S
		for x in range(2, mb.mw - 2):
			line.append(Vector2i(x, mb.mh - 2))
	var out: Array = []
	for c in line:
		if not mb.blocked[c.y][c.x]:
			out.append(c)
	return out


static func carve_opening(mb: MapGrid, edge: String, cell: Vector2i, floor: int, depth := 4) -> void:
	## 從邊緣往內鑿 2 寬×depth 深的明顯通道口（只加地板，連通性只增不減）。
	var x := cell.x
	var y := cell.y
	var cells: Array = []
	if edge == "E" or edge == "W":
		var y2 := y + 1 if y + 1 <= mb.mh - 2 else y - 1
		var xs: Array = []
		if edge == "E":
			for cx in range(mb.mw - 1, mb.mw - 1 - depth, -1):
				xs.append(cx)
		else:
			for cx in range(0, depth):
				xs.append(cx)
		for cx in xs:
			cells.append(Vector2i(cx, y))
			cells.append(Vector2i(cx, y2))
	else:
		var x2 := x + 1 if x + 1 <= mb.mw - 2 else x - 1
		var ys: Array = []
		if edge == "S":
			for cy in range(mb.mh - 1, mb.mh - 1 - depth, -1):
				ys.append(cy)
		else:
			for cy in range(0, depth):
				ys.append(cy)
		for cy in ys:
			cells.append(Vector2i(x, cy))
			cells.append(Vector2i(x2, cy))
	for c in cells:
		if c.x >= 0 and c.x < mb.mw and c.y >= 0 and c.y < mb.mh:
			mb.set_tile(c.x, c.y, floor)
			mb.unblock_cell(c.x, c.y)


static func trail_to_edge(mb: MapGrid, edge: String, anchor: Vector2i, floor: int, width := 2) -> Vector2i:
	## 從 anchor 鑿一條 width 寬直線到指定邊（該邊無現成開口時的保底），回傳邊上內側 feature 格。
	var ax := anchor.x
	var ay := anchor.y
	var cells: Array = []
	var feat: Vector2i
	if edge == "E" or edge == "W":
		var span: Array = []
		if edge == "E":
			for cx in range(ax, mb.mw):
				span.append(cx)
		else:
			for cx in range(ax, -1, -1):
				span.append(cx)
		for cx in span:
			for w in range(width):
				cells.append(Vector2i(cx, mini(ay + w, mb.mh - 2)))
		feat = Vector2i(mb.mw - 2, ay) if edge == "E" else Vector2i(1, ay)
	else:
		var span: Array = []
		if edge == "S":
			for cy in range(ay, mb.mh):
				span.append(cy)
		else:
			for cy in range(ay, -1, -1):
				span.append(cy)
		for cy in span:
			for w in range(width):
				cells.append(Vector2i(mini(ax + w, mb.mw - 2), cy))
		feat = Vector2i(ax, mb.mh - 2) if edge == "S" else Vector2i(ax, 1)
	for c in cells:
		if c.x >= 0 and c.x < mb.mw and c.y >= 0 and c.y < mb.mh:
			mb.set_tile(c.x, c.y, floor)
			mb.unblock_cell(c.x, c.y)
	return feat
