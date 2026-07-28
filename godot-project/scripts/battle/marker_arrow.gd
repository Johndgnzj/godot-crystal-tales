extends Control
## 戰鬥用「向下等腰三角」標記：行動者指示與選取目標游標共用同一造型。
## 深灰藍圓角外框 ＋ 灰藍色填滿。以本節點原點為水平中心、頂邊 y=0、尖端朝下（+y）。
## 純繪製、不吃輸入；定位由呼叫端每幀設 position。

const W: float = 34.0            # 三角頂邊寬
const HH: float = 26.0           # 三角高（尖端朝下）
const FILL := Color(0.44, 0.55, 0.70)      # 灰藍填滿
const OUTLINE := Color(0.12, 0.16, 0.24)   # 深灰藍外框
const OUTLINE_W: float = 3.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var a := Vector2(-W * 0.5, 0.0)   # 左上
	var b := Vector2(W * 0.5, 0.0)    # 右上
	var c := Vector2(0.0, HH)         # 下尖
	draw_colored_polygon(PackedVector2Array([a, b, c]), FILL)
	draw_polyline(PackedVector2Array([a, b, c, a]), OUTLINE, OUTLINE_W, true)
	# 圓角：三頂點各補一顆小圓，讓外框轉角圓潤
	for v in [a, b, c]:
		draw_circle(v, OUTLINE_W * 0.5, OUTLINE)
