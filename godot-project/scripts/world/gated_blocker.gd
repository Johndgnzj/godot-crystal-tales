class_name GatedBlocker
extends StaticBody2D
## 依旗標決定「在不在」的擋路物件——路障、關著的柵欄門、崩落的巨木。
##
## 為什麼需要獨立節點：一般 map-def prop 的碰撞由 `blueprint_to_paths.gd` **烘進 CollisionPaint**
## （tilemap 靜態資料），旗標一變也不會消失。所以 prop 帶 `gate` 欄時，`build_scenes.gd` 改生成
## 本節點——碰撞掛在自己身上，可以開關；`blueprint_to_paths.gd` 則跳過這筆、不烘進 tilemap。
##
## show_when：FlagMatcher 語法（""/"always"、"flag==n"、"flag>=n"），成立才擋（也才看得見）。
## hide_flag：非空且該旗標 !=0 時強制移除（例：打倒 boss → 路障沒了）。
##
## 每幀重算而不是只在 _ready：旗標常在戰鬥結算或對話結束後才變，而那些流程不會重載世界場景
## （同 `boss_mark.gd` 的理由）。只在狀態真的翻轉時才動節點。
##
## 碰撞層維持 StaticBody2D 預設的 layer 1——與 `collision_tileset_32.tres`（`physics_layer_0/
## collision_layer = 1`）一致，玩家才擋得住。

@export var show_when: String = "always"
@export var hide_flag: String = ""

var _shown := true


func _ready() -> void:
	_apply(_want_shown())


func _process(_delta: float) -> void:
	var want := _want_shown()
	if want != _shown:
		_apply(want)


func _want_shown() -> bool:
	if hide_flag != "" and GameState.flag_get(hide_flag) != 0:
		return false
	return FlagMatcher.matches(GameState.flags, show_when)


func _apply(shown: bool) -> void:
	_shown = shown
	visible = shown
	for c in get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).disabled = not shown
