extends Node2D
class_name PaintedScreen
## 手繪畫面地圖控制器（試作）：一張背景圖（Sprite2D）＋一層可刷的碰撞層（CollisionPaint，
## TileMapLayer physics layer，設計員在編輯器用筆刷刷牆/障礙）＋玩家＋出入口。
## 移動走現有 player_controller.gd；碰撞來自 CollisionPaint 刷過的格子（不再靠 tile 圖或烘出的矩形）。
## 這是評估「整張手繪圖＋另刷碰撞」路線用的原型，見對話紀錄。

@export var scene_id: String = ""
@export var spawns: Dictionary = {}          ## spawn_id -> Vector2（玩家落點）
@export var default_spawn: String = "start"
@export_range(0.3, 3.0, 0.05) var camera_zoom: float = 1.0


func _ready() -> void:
	var col := get_node_or_null("CollisionPaint")
	if col != null:
		col.visible = false   # 執行期隱藏紅色刷格；physics 不受 visible 影響，碰撞仍在

	var player := get_node_or_null("YSort/Player")
	if player == null:
		return
	var sid: String = GameState.spawn if GameState.spawn != "" else default_spawn
	if spawns.has(sid):
		player.global_position = spawns[sid]
	GameState.spawn = ""

	var cam := player.get_node_or_null("Camera2D")
	var bg := get_node_or_null("Background") as Sprite2D
	if cam != null and bg != null and bg.texture != null:
		var sz: Vector2 = bg.texture.get_size()
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(sz.x)
		cam.limit_bottom = int(sz.y)
		cam.zoom = Vector2(camera_zoom, camera_zoom)
