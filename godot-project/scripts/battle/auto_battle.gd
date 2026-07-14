class_name AutoBattle
extends RefCounted
## 自動戰鬥（`GameState.auto_battle` 對應邏輯，build_cq2.py L2702-2706、L2824-2832）。
##
## GDevelop 版把「自動戰鬥」拆成兩處：a 鍵/`BtnAuto` 切換 `g_autoBattle`（L2702-2706，若切換當下
## 剛好停在 `menu` 狀態，立即代打一次）；`openCmd(h)` 開場檢查 `g_autoBattle`，是的話直接
## `autoAttack(h)` 代打，不開指令選單（L2830-2832）。本檔案收斂這兩處共用的「自動戰鬥要做什麼」邏輯
## （選第一個存活敵人當目標），實際的狀態切換（`state="target"`→`applyOne()`）留在
## `battle_state_machine.gd`，因為那牽涉戰鬥狀態機的內部欄位，不適合讓一個獨立的純函式檔案直接改。


## 目前是否開著自動戰鬥。薄包裝，收斂呼叫入口（跟 `InputBridge` 對 `Input` 的包裝同一個理由）。
static func is_enabled() -> bool:
	return GameState.auto_battle


## 切換開關，回傳切換後的新狀態。對應 L2703 `g_autoBattle` 的 0/1 toggle。
static func toggle() -> bool:
	GameState.auto_battle = not GameState.auto_battle
	return GameState.auto_battle


## 自動戰鬥要打誰：陣列中第一個存活敵人（對應 `autoAttack()` L2825 `af[0]`）。沒有存活敵人回傳
## `null`（呼叫端應該視為「這次自動出招失敗，退回正常指令選單」，見 `autoAttack()` 的
## `if(!af.length)return false;`）。
static func pick_target(foes: Array) -> Variant:
	for f in foes:
		var foe: Dictionary = f
		if bool(foe.get("alive", false)):
			return foe
	return null
