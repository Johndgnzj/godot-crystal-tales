extends SceneTree
## 驗證草石地面裝飾為非碰撞格總數的 1/20，且 seeded RNG 可重現。


func _initialize() -> void:
	var first := _build(24680)
	var second := _build(24680)
	var first_decor := _ground_decor(first)
	var second_decor := _ground_decor(second)
	var expected := 5 # 12×12 地圖扣掉阻擋外圈後有 100 個非碰撞格。
	if first_decor.size() != expected:
		push_error("ground decor count: expected %d, got %d" % [expected, first_decor.size()])
		quit(1)
		return
	if first_decor != second_decor:
		push_error("ground decor placement is not deterministic")
		quit(1)
		return
	if first_decor.any(func(p: Dictionary) -> bool: return p["x"] == 32 and p["y"] == 32):
		push_error("ground decor overlaps an existing floor decoration")
		quit(1)
		return
	print("GROUND DECOR PASS (%d/100)" % first_decor.size())
	quit(0)


func _build(seed_value: int) -> MapGrid:
	var mb := MapGrid.new(12, 12, MapKit.gid("grass"))
	mb.add_prop("fst_deco_fern.png", 32, 38)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	MapKit.place_ground_decor(mb, rng)
	return mb


func _ground_decor(mb: MapGrid) -> Array:
	return mb.props.filter(func(p: Dictionary) -> bool:
		return String(p["tex"]).contains("ground_decor_grass_pebble_"))
