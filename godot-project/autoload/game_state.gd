extends Node

## ⚠️ 暫時性 STUB — 這不是 CORE-4 任務的正式產出。
##
## 目的：MOD-A（對話/劇情）與 MOD-B（撿取/觸發）依規格依賴 GameState，但 CORE-4 尚未排入執行。
## 為了不讓兩個平行的模組任務各自發明一份、也不讓它們卡住，協調者先放這個最小可用版本，
## 欄位與方法簽名照抄 ../specs/SAVE_SCHEMA.md 與 ../TASKS/00_核心任務.md CORE-4 段落。
##
## CORE-4 任務認領時：這個檔案要被正式檢視/擴充（例如補上驗證、型別安全、跟 SaveManager 的整合），
## 不是「已經做完可以跳過」。任何 MOD 任務都不應該大幅改寫這個檔案的結構——只能透過下面已提供的方法讀寫。

# ---- 持久化欄位（見 SAVE_SCHEMA.md）----
var party: Array = []            # Array[Dictionary]，隊伍成員
var flags: Dictionary = {}       # 劇情旗標，未定義 key 視為 0
var eq_inv: Array = []           # 裝備袋（裝備 id 陣列）
var item_inv: Dictionary = {}    # 背包 {item_id: count}
var gold: int = 0
var chests: Dictionary = {}      # 已開啟寶箱清單（待 CORE-3/4 確認精確型別，見 SAVE_SCHEMA.md 待確認事項）
var auto_battle: bool = false

# ---- 場景轉場暫態值（不持久化，CORE-5 的 SceneRouter 應該接手管理，這裡先提供欄位）----
var encounter: String = ""
var return_scene: String = ""
var return_x: float = 0.0
var return_y: float = 0.0
var result: String = ""          # win/lose/flee/story/resume
var spawn: String = ""


func flag_get(key: String) -> int:
	return int(flags.get(key, 0))


func flag_set(key: String, value: int) -> void:
	flags[key] = value


func flag_inc(key: String, delta: int = 1) -> void:
	flags[key] = flag_get(key) + delta


# ---- 背包操作（照搬 build_cq2.py invAll/invGet/invAdd/invUse 的介面收斂意圖）----
func inv_all() -> Dictionary:
	return item_inv


func inv_get(id: String) -> int:
	return int(item_inv.get(id, 0))


func inv_add(id: String, n: int) -> void:
	var v: int = inv_get(id) + n
	if v < 0:
		v = 0
	item_inv[id] = v


func inv_use(id: String) -> void:
	inv_add(id, -1)
