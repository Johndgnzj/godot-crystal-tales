extends Sprite2D
## 地圖事件角色：依旗標顯示、循環三幀，並建立獨立置中的腳下影子。

@export var show_when: String = "always"
@export var hide_flag: String = ""
@export var frame_paths: PackedStringArray = PackedStringArray()
@export_range(0.5, 8.0, 0.5) var animation_fps: float = 2.0
@export_range(0, 96, 1) var shadow_width: int = 0
@export_range(4, 20, 1) var shadow_height: int = 8

var _frames: Array[Texture2D] = []
var _elapsed := 0.0
var _frame_index := 0


func _ready() -> void:
	var shown := FlagMatcher.matches(GameState.flags, show_when)
	if hide_flag != "" and GameState.flag_get(hide_flag) != 0:
		shown = false
	visible = shown
	for path in frame_paths:
		if ResourceLoader.exists(path):
			_frames.append(load(path))
	if not _frames.is_empty():
		texture = _frames[0]
	if shadow_width > 0:
		_add_shadow()
	set_process(visible and _frames.size() > 1)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 1.0 / animation_fps:
		return
	_elapsed = 0.0
	_frame_index = (_frame_index + 1) % _frames.size()
	texture = _frames[_frame_index]


func _add_shadow() -> void:
	var texture_width := texture.get_width() if texture != null else 64
	var image_width := maxi(maxi(64, texture_width), shadow_width + 2)
	var image_height := shadow_height + 2
	var image := Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var radius_x := float(shadow_width) / 2.0
	var center_x := float(image_width - 1) / 2.0
	var radius_y := float(shadow_height) / 2.0
	var center_y := float(image_height - 1) / 2.0
	for y in range(image_height):
		for x in range(image_width):
			var nx := (float(x) - center_x) / radius_x
			var ny := (float(y) - center_y) / radius_y
			var distance := nx * nx + ny * ny
			if distance <= 1.0:
				var alpha := 13.0 + (127.0 - 13.0) * pow(1.0 - distance, 1.35)
				image.set_pixel(x, y, Color(58.0 / 255.0, 52.0 / 255.0, 44.0 / 255.0, alpha / 255.0))
	var shadow := Sprite2D.new()
	shadow.texture = ImageTexture.create_from_image(image)
	var texture_height := texture.get_height() if texture != null else 64
	shadow.position = Vector2(0.0, float(texture_height) / 2.0 - 3.0)
	shadow.z_index = -1
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(shadow)
