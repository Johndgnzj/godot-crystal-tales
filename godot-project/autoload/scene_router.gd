extends Node
## SceneRouter — autoload（註冊名稱 "SceneRouter"，見 ../project.godot [autoload]）。
##
## CORE-5 正式實作，取代協調者先前放的暫時性 stub（只發 signal，沒有真的切場景）。
##
## 取代 GDevelop 的 `replaceScene()` + `g_result`/`g_returnScene`/`g_returnX/Y`/`g_spawn`/
## `g_encounter` 機制（build_cq2.py 對照行號見下方各常數/函式註解）。
##
## 三個既有簽名（MOD-A 的 dialogue_system.gd、MOD-B 的 boss_mark.gd／exit_zone.gd 已經在呼叫，
## **本次實作刻意保持不變**，只把函式內容從「只發 signal」升級成真的切場景）：
##   go_to(scene_path: String, spawn_id: String) -> void
##   start_battle(encounter_id: String, return_scene: String,
##                 return_x: float, return_y: float) -> void
##   battle_result(result: String) -> void
##
## ---------------------------------------------------------------------------
## 「scene_path / to_scene / return_scene」参数語意定案（原本 exit_zone.gd／boss_mark.gd 的註解都
## 留著「待 CORE-5/MOD-H 定案」）：
##
## 沿用 GDevelop `CFG.SCENE` 的邏輯場景名稱字串（"Town"／"Forest"／"Forest2"／"Mine"／"Cave"／
## "Battle"／"Title"），**不是** Godot 的 res:// 路徑。理由：dialogue.json 的 CUTS `transfer` 欄位
## 資料本來就已經在用這組字串（例如 demon_post 的 `transfer:["Town","home"]`，見
## specs/DIALOGUE_SPEC.md D-3），MOD-A 的 dialogue_system.gd 直接把這個字串透過
## `scene_transfer_requested` signal 轉發給世界場景、再由世界場景呼叫 `SceneRouter.go_to()`；
## 如果 SceneRouter 改吃 res:// 路徑，資料層與 MOD-A 都要跟著改，範圍會超出 CORE-5。
##
## SceneRouter 內部用 `SCENE_PATHS` 對照表把邏輯名稱轉成實際場景檔路徑。**呼叫端不需要知道實際檔案
## 路徑**，MOD-H 之後建立/搬動世界場景檔時，只需要回來更新 `SCENE_PATHS` 這張表，不用改任何呼叫端
## 程式碼。若傳入字串已經是 `"res://"` 開頭，視為呼叫端直接指定路徑（略過對照表），保留彈性給還沒有
## 邏輯名稱對應的臨時測試場景使用。
##
## 目前 `scenes/world/**`、`scenes/battle/**` 底下實際場景檔還沒建立（MOD-H/MOD-E 尚未開工，只有
## `.gitkeep`），所以 `_change_scene()` 對不存在的場景檔採「寫入 GameState 欄位＋警告，不硬切場景」
## 的容錯處理，等場景檔就位後不需要回來改本檔案，會自動生效（見 `_change_scene()` 註解）。
## ---------------------------------------------------------------------------
signal battle_requested(encounter_id: String)
signal scene_change_requested(scene_path: String, spawn_id: String)

const SCENE_PATHS := {
	"Title": "res://scenes/title/title.tscn",
	"Town": "res://scenes/world/town.tscn",
	"Forest": "res://scenes/world/forest.tscn",
	"Forest2": "res://scenes/world/forest2.tscn",
	"Mine": "res://scenes/world/mine.tscn",
	"Cave": "res://scenes/world/cave.tscn",
	"Battle": "res://scenes/battle/battle.tscn",
}

## `back()` 的 fallback（build_cq2.py L2820：`g.get("g_returnScene").getAsString()||"Town"`）：
## `battle_result()` 呼叫時若 `GameState.return_scene` 是空字串，回退去 Town。
const DEFAULT_RETURN_SCENE := "Town"

## 全滅（lose）固定重生點，照抄 build_cq2.py L2814（戰鬥結算畫面點 BtnCont 時，`b.state==="lose"`
## 分支寫死的規則：`g_returnScene="Town"; g_spawn="shrine"`，蓋掉觸發戰鬥當下記錄的 returnScene）。
## 這不是各別戰鬥各自的資料，是整個遊戲唯一的「死亡復活點」規則，收斂在 `battle_result()` 這裡處理，
## 讓 MOD-E（戰鬥結算，尚未開工）呼叫 `battle_result("lose")` 時不用自己重複這段特例判斷。
const LOSE_RESPAWN_SCENE := "Town"
const LOSE_RESPAWN_SPAWN_ID := "shrine"

## 世界場景 `_ready()`／存檔載入流程判定出生點要用的規則，照抄 build_cq2.py L1425-1432：
##
##   res = GameState.result
##   若 res 屬於這個集合 且 GameState.return_x >= 0（-1 是 clrTransient() 寫入的哨兵值）：
##       用 GameState.return_x / return_y 定位玩家
##   否則：
##       用 GameState.spawn 字串查場景自己的出生點表（例如 CFG.spawns[spawn_id]）定位玩家
##
## `"lose"` 刻意不在這個集合內——全滅是特例，`battle_result()` 已經把 return_scene/spawn 強制改成
## Town/shrine（見上），所以戰敗一律走「查 spawn 表」這條路徑，不是 returnX/Y。
const RESULT_USE_RETURN_POS := ["win", "flee", "story", "resume"]


## 一般場景轉場（世界內出口 exit_zone.gd、CUTS `transfer` 欄位）。
## 對應 build_cq2.py L2313-2315（`CFG.exits`）與 L1703-1705（CUTS `transfer`）：
##   g_spawn = spawn_id; replaceScene(to_scene)
##
## 不主動清空 `GameState.result`／`return_x`／`return_y`（跟原始碼一致，`g_result` 只在世界場景
## init 時被動清空，見 `battle_result()` 的「場景端交握約定」註解第 2 點）。這代表：呼叫端若在
## `GameState.result` 還沒被上一個場景清空前就呼叫 `go_to()`，新場景可能誤讀到舊的 return 資料——
## 只要每個世界場景照約定在 `_ready()` 結尾清空這兩個欄位，就不會發生。CORE-3 的 SaveManager
## 若要實作讀檔「resume」流程，建議寫法是：先設定 `GameState.result="resume"` 與
## `GameState.return_x/return_y`，再呼叫 `go_to(存檔場景, "")`——`go_to()` 只會覆寫 `spawn`，
## 不會動 `result`/`return_x/y`，兩者可以合成使用（對應 build_cq2.py L3387-3393 `loadSave()`）。
func go_to(scene_path: String, spawn_id: String = "") -> void:
	GameState.spawn = spawn_id
	scene_change_requested.emit(scene_path, spawn_id)
	_change_scene(scene_path)


## 進入戰鬥（boss_mark.gd／CUTS `battle` 欄位／MOD-G 隨機遭遇）。
## 對應 build_cq2.py L1580-1583（一般遭遇）／L2339-2343（隨機遭遇）／L2352-2356（ch1_boss）／
## L2366-2370（ch2_bear）／L1698-1701（CUTS battle）——四處都是同一套寫法：
##   g_returnScene = 目前場景; g_returnX/Y = 玩家目前座標; g_encounter = encounter_id;
##   replaceScene("Battle")
func start_battle(
	encounter_id: String, return_scene: String, return_x: float, return_y: float
) -> void:
	GameState.encounter = encounter_id
	GameState.return_scene = return_scene
	GameState.return_x = return_x
	GameState.return_y = return_y
	battle_requested.emit(encounter_id)
	_change_scene("Battle")


## 戰鬥結算後返回世界場景，取代 build_cq2.py 的 `back()`（L2818-2821）＋呼叫端在 `back()` 之前
## 依 `b.state` 做的收尾（L2812-2815）。
##
## 場景端交握約定（MOD-C/MOD-H 的世界場景腳本 `_ready()` 要照這個約定寫，對應 build_cq2.py
## L1425-1440 的世界場景 init 出生點分支）：
##   1. 讀 `GameState.result`。若 `SceneRouter.should_use_return_position()` 為 true，
##      用 `GameState.return_x` / `GameState.return_y` 定位玩家；否則用 `GameState.spawn`
##      字串查自己的出生點表（比照 GDevelop `CFG.spawns[spawn]`）。
##   2. 定位完成後，場景要自行把 `GameState.spawn = ""` 與 `GameState.result = ""` 清空
##      （對應原始碼 L1434/L1440 的 `g_spawn=""`/`g_result=""`），避免暫態值被下一次進場誤用。
##      SceneRouter 不做這件事——「什麼時候算讀取完成」是場景生命週期的一部分，切場景當下
##      （`change_scene_to_file()` 是非同步的）沒辦法代為判斷。
##   3. `result == "win"` 且回到 Cave／`result == "win"` 且回到 Mine 時的戰後劇情推進
##      （`demon_post`/`mine_after` cutscene）不屬於 SceneRouter 職責，是世界場景自己讀
##      `GameState.result` 之後呼叫 `DialogueSystem.play_cutscene()` 的邏輯（見 D-3）。
func battle_result(result: String) -> void:
	GameState.result = result
	if result == "lose":
		GameState.return_scene = LOSE_RESPAWN_SCENE
		GameState.spawn = LOSE_RESPAWN_SPAWN_ID

	var target: String = GameState.return_scene
	if target == "":
		target = DEFAULT_RETURN_SCENE

	scene_change_requested.emit(target, GameState.spawn)
	_change_scene(target)


## 供世界場景（MOD-C/MOD-H）與存檔載入流程（CORE-3 SaveManager 的 "resume" 分支，見
## specs/SAVE_SCHEMA.md「讀檔」段落）共用的判斷式，避免各自重抄 `RESULT_USE_RETURN_POS` +
## `return_x` 哨兵值（-1）的雙重檢查（照抄 build_cq2.py L1427
## `g.get("g_returnX").getAsNumber()>=0&&p0`）。
func should_use_return_position() -> bool:
	return RESULT_USE_RETURN_POS.has(GameState.result) and GameState.return_x >= 0.0


## 邏輯場景名稱／`res://` 路徑 → 實際 res:// 路徑。回傳空字串代表無法解析（未知名稱）。
func _resolve_path(scene_id: String) -> String:
	if scene_id.begins_with("res://"):
		return scene_id
	if SCENE_PATHS.has(scene_id):
		return SCENE_PATHS[scene_id]
	push_warning("SceneRouter: 未知場景 id=%s（不在 SCENE_PATHS 對照表，也不是 res:// 路徑）" % scene_id)
	return ""


## 實際呼叫 `get_tree().change_scene_to_file()`。對尚未建立的場景檔（MOD-H/MOD-E 進度未到）採
## 容錯處理：只記警告、不丟例外，GameState 的相關欄位仍然照常寫入——一旦場景檔就位，下一次呼叫
## 同一段程式碼就會自動成功，不需要回來改本檔案任何一行。
func _change_scene(scene_id: String) -> void:
	var path := _resolve_path(scene_id)
	if path == "":
		return
	if not ResourceLoader.exists(path):
		push_warning(
			"SceneRouter: 場景檔尚未建立 path=%s（scene_id=%s），暫不切場景；GameState 欄位已寫入，等場景檔就位後會自動生效"
			% [path, scene_id]
		)
		return
	var tree := get_tree()
	if tree == null:
		push_warning("SceneRouter: get_tree() 目前為 null（SceneRouter 尚未進入場景樹？），無法切場景 path=%s" % path)
		return
	var err := tree.change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: change_scene_to_file 失敗 path=%s err=%s" % [path, err])
