extends Sprite2D
## 依旗標決定是否顯示的地圖裝飾 sprite（如「事件當下才出現、事件後消失」的熊）。
## 純顯示，不含互動——互動交給同位置的 TriggerZone/PickupZone。
##
## show_when：FlagMatcher 語法（""/"always"、"flag==n"、"flag>=n"），成立才顯示。
## hide_flag：非空且該旗標已設(!=0)時，強制隱藏（用來在事件完成後把它藏起來）。
##
## 只在 runtime 生效（非 @tool）：編輯器內一律顯示，方便設計員擺位。

@export var show_when: String = "always"
@export var hide_flag: String = ""


func _ready() -> void:
	var shown: bool = FlagMatcher.matches(GameState.flags, show_when)
	if hide_flag != "" and GameState.flag_get(hide_flag) != 0:
		shown = false
	visible = shown
