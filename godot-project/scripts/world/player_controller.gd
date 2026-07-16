extends CharacterBody2D
class_name PlayerController

## MOD-C 產出：頂視角八方向移動控制器。
##
## 對應 GDevelop `TopDownMovementBehavior::TopDownMovementBehavior`（見
## reference/gdevelop/build_cq2.py:1018-1023）：
##   allowDiagonals=true, acceleration=1200, deceleration=1500, maxSpeed=190,
##   angularMaxSpeed=360, rotateObject=false, viewpoint="TopDown"
## 這是 GDevelop 引擎內建行為（不是 build_cq2.py 自訂的 JS 邏輯），沒有文件化的逐幀積分公式可抄，
## 只有上面這幾個 export 參數是明確數字。本檔案用最直觀的「線性加速度/減速度趨近目標速度向量」模型
## 重建（`velocity.move_toward(target_velocity, rate * delta)`），是 Godot 端重新設計、非逐行翻譯
## ——`rotateObject`/`angularMaxSpeed`/`customIsometryAngle` 等旋轉相關參數在這裡不需要，因為視覺
## 呈現走的是「切換 Walk/Idle+方向 動畫幀」而不是旋轉 Sprite（同 GDevelop 版用 setAnimationName 而非
## setAngle 表現朝向，見 build_cq2.py:2265-2269）。
##
## **未經實機/視覺驗證**：`max_speed`/`acceleration`/`deceleration` 三個數字是照抄 GDevelop behavior
## 的 export 參數，但沒有 Godot 編輯器可以實際跑起來、也沒有 GDevelop 版錄影可比對手感（跟 CORE-1
## 選 stretch mode 時遇到的環境限制一樣，見 ../CLAUDE.md「Godot 版本與技術選型」段落）。之後拿到可用
## 的 Godot 編輯器時，務必實機比對 GDevelop 版錄影，重新調校這三個數字與加速度模型本身（例如是否要
## 改用非線性曲線），不用死摳這裡的預設值。
##
## 規格來源：TASKS/03_移動碰撞.md；DEV_開發指南.md L55。
## 前置依賴：CORE-6 `autoload/input_bridge.gd`（讀 `is_action_held()`，不直接呼叫 `Input.*`）。

## px/s。GDevelop 原值 190，實測偏慢（2026-07-15 John 回饋），上調到 250；此為 @export，
## 可在 Player 節點的 Inspector 即時微調到手感對的數字，不必改程式。
@export var max_speed: float = 250.0

## px/s²，加速率（放開/切換方向時速度趨近目標值）。隨 max_speed 一併上調讓起步更跟手。
@export var acceleration: float = 1600.0

## px/s²，對應 GDevelop deceleration=1500（沒有輸入時，速度趨近 0 的減速率）。
@export var deceleration: float = 1500.0

## 世界場景控制器（`world_scene_state.gd`，同任務產出）注入的狀態容器，**不是 autoload**——由掛載
## 本節點的世界場景根節點在 `_ready()` 賦值（例如 `player.world_state = state`）。刻意允許維持 null：
## 沒有世界場景控制器時（單一測試場景/MOD-H 尚未產出真正地圖），移動永遠不鎖，方便獨立開發與測試
## （見 TASKS/11_並行協作規則.md「MOD-C/MOD-G 開工時若 MOD-H 尚未完成，先用單一測試場景假資料開發」）。
var world_state: WorldSceneState = null

## 目前面向："Down"/"Left"/"Up"/"Right"，對應 build_cq2.py:2265-2267 的角度分區。供之後掛上美術資源
## 的節點（Sprite2D/AnimatedSprite2D，非本模組職責）讀取決定播放哪個 Walk/Idle 動畫；本檔案不假設
## 任何子節點存在，只暴露這個欄位。
var facing: String = "Down"

## 目前是否在移動（供動畫/隊伍跟隨判斷用，對應 GDevelop `b.isMoving()`）。
var is_moving: bool = false


func _physics_process(delta: float) -> void:
	var locked: bool = world_state != null and world_state.lock
	var input_dir: Vector2 = Vector2.ZERO
	if not locked:
		input_dir = _read_input_direction()

	var target_velocity: Vector2 = input_dir * max_speed
	var rate: float = acceleration if input_dir != Vector2.ZERO else deceleration
	velocity = velocity.move_toward(target_velocity, rate * delta)

	move_and_slide()

	is_moving = velocity.length() > 1.0
	if input_dir != Vector2.ZERO:
		facing = _direction_to_facing(input_dir)


## 讀 CORE-6 InputBridge 的 `is_action_held()`（持續按著，對應 GDevelop `hit`），八方向正規化避免
## 對角線移動比正向移動快（對應 GDevelop `allowDiagonals=true` 底下引擎內建的速度正規化）。
func _read_input_direction() -> Vector2:
	var dir := Vector2.ZERO
	if InputBridge.is_action_held("move_up"):
		dir.y -= 1.0
	if InputBridge.is_action_held("move_down"):
		dir.y += 1.0
	if InputBridge.is_action_held("move_left"):
		dir.x -= 1.0
	if InputBridge.is_action_held("move_right"):
		dir.x += 1.0
	if dir != Vector2.ZERO:
		dir = dir.normalized()
	return dir


## 對應 build_cq2.py:2265-2267 的四象限角度分區：
##   45°<=ang<135° -> Down, 135°<=ang<225° -> Left, 225°<=ang<315° -> Up, 其餘 -> Right
## Godot `Vector2.angle()` 用 `atan2(y, x)`，跟 GDevelop 物件角度同樣是 Y 軸向下為正的螢幕座標系
## （下 = 90°），兩者角度定義一致，分區條件可以直接沿用，不需要額外轉換。
func _direction_to_facing(dir: Vector2) -> String:
	var deg: float = fposmod(rad_to_deg(dir.angle()), 360.0)
	if deg >= 45.0 and deg < 135.0:
		return "Down"
	elif deg >= 135.0 and deg < 225.0:
		return "Left"
	elif deg >= 225.0 and deg < 315.0:
		return "Up"
	else:
		return "Right"
