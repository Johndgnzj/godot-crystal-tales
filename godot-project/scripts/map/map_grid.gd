class_name MapGrid
extends RefCounted
## 生成期的地圖格子（對應舊 scripts/map/gen_maps.py 的 MapB，但改成無副作用的 GDScript 資料結構）。
## 只持有資料與格子操作；地形演算法在 MapKit（靜態函式）。見 TASKS/12_地圖生成器.md。

var mw: int
var mh: int
var g: PackedInt32Array                 ## row-major 地磚 id（1 起算，同 world_scene.gd 契約）
var blocked: Array = []                 ## Array[Array[bool]]，blocked[y][x]
var enc: Array = []                     ## Array[Array[bool]]，遇敵地形
var props: Array = []                   ## [{tex,x,y,w,h}]，對應 world_scene.gd prop_list


func _init(width: int, height: int, base_tile: int) -> void:
	mw = width
	mh = height
	g = PackedInt32Array()
	g.resize(mw * mh)
	g.fill(base_tile)
	for y in mh:
		var brow: Array = []
		var erow: Array = []
		for x in mw:
			brow.append(false)
			erow.append(false)
		blocked.append(brow)
		enc.append(erow)
	# 外圍一圈預設阻擋（同 MapB.__init__）
	for y in mh:
		blocked[y][0] = true
		blocked[y][mw - 1] = true
	for x in mw:
		blocked[0][x] = true
		blocked[mh - 1][x] = true


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < mw and y >= 0 and y < mh


func set_tile(x: int, y: int, t: int) -> void:
	if in_bounds(x, y):
		g[y * mw + x] = t


func get_tile(x: int, y: int) -> int:
	return g[y * mw + x]


func is_blocked(x: int, y: int) -> bool:
	return blocked[y][x]


func fill_rect(x1: int, y1: int, x2: int, y2: int, t: int) -> void:
	for yy in range(y1, y2 + 1):
		for xx in range(x1, x2 + 1):
			set_tile(xx, yy, t)


func block_cell(x: int, y: int) -> void:
	if in_bounds(x, y):
		blocked[y][x] = true


func block_rect(x1: int, y1: int, x2: int, y2: int) -> void:
	for yy in range(y1, y2 + 1):
		for xx in range(x1, x2 + 1):
			block_cell(xx, yy)


func unblock_cell(x: int, y: int) -> void:
	if in_bounds(x, y):
		blocked[y][x] = false


func mark_enc() -> void:
	## 高草(tgrass)/碎石(gravel) 地形標成遇敵格（同 MapB.mark_enc）。
	var tg := MapKit.gid("tgrass")
	var gv := MapKit.gid("gravel")
	for yy in mh:
		for xx in mw:
			var t := g[yy * mw + xx]
			if t == tg or t == gv:
				enc[yy][xx] = true


func blk_rows() -> PackedStringArray:
	var out := PackedStringArray()
	for y in mh:
		var s := ""
		for x in mw:
			s += "1" if blocked[y][x] else "0"
		out.append(s)
	return out


func enc_rows() -> PackedStringArray:
	var out := PackedStringArray()
	for y in mh:
		var s := ""
		for x in mw:
			s += "1" if enc[y][x] else "0"
		out.append(s)
	return out


## 加一個 prop（tex_file 為 assets/props/ 下的檔名；px/py 左上像素；w/h=0 用原生尺寸）。
func add_prop(tex_file: String, px: int, py: int, w: int = 0, h: int = 0) -> void:
	props.append({"tex": "res://assets/props/" + tex_file, "x": px, "y": py, "w": w, "h": h})
