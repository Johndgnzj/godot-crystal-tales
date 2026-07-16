class_name MenuPage
extends Control

## 選單分頁的共用基底（角色/道具/地圖/稱號/系統）。menu_root 只認這個介面，各 page override。
##
## focus-zone 模型：每頁分「選擇區(top zone)」與更深的內容區。at_top_zone()==true 時 ←→ 由 menu_root
## 拿去切頂部 5 分頁；==false 時 ←→ 交給 page 自己用（子頁/隊員/分類切換）。所有輸入走 InputBridge
## edge-trigger（見 menu_root._hit）。

var scene_id: String = ""   ## 地圖頁需要；menu_root 於 set_scene_id/建構時灌入。


## 進入本頁（切到此分頁時呼叫）：重設游標到 top zone。
func page_enter() -> void:
	pass


## 每幀（開啟且本頁為 active 時）讀輸入、改狀態，回傳底部提示字。
func page_input() -> String:
	return ""


## 依 GameState＋自身游標狀態重畫。
func page_refresh() -> void:
	pass


## Esc/返回：若焦點在深層則退一層並回 true（已消費）；若已在 top zone 回 false（→ menu_root 關選單）。
func page_back() -> bool:
	return false


## 焦點是否在最上層 zone（決定 ←→ 歸 menu_root 切分頁還是本頁自用）。
func at_top_zone() -> bool:
	return true


# --- 輸入小工具（轉呼叫 InputBridge，edge-triggered）---
func hit(action: String) -> bool:
	return InputBridge.is_action_hit(action)


## 游標移動：action 觸發且 can_move 為真才播 cursor.mp3 並回 true（對應原版每次成功移動 sfx("cursor.mp3")）。
## 用法把 `if hit("move_up") and _cursor > 0:` 改成 `if move_hit("move_up", _cursor > 0):`，
## 游標被夾在邊界（can_move=false）時不發聲，與原版一致。無邊界的切換傳 can_move 預設值 true 即可。
func move_hit(action: String, can_move: bool = true) -> bool:
	if hit(action) and can_move:
		AudioManager.sfx("cursor.mp3")
		return true
	return false
