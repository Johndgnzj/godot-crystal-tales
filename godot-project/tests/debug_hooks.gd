extends Node

## DebugHooks — autoload（註冊名稱 "DebugHooks"，見 ../project.godot [autoload]）。
##
## ⚠️ 骨架，尚未實機驗證 ⚠️
## 這個環境沒有 Godot 4.3+ 執行檔（六種下載管道全被網路政策擋下，見 ../TASKS/00_核心任務.md CORE-1
## 段落），所以這支腳本從未被 Godot 引擎載入/執行過，只做過 Python 括號成對＋API 名稱人工核對。等有
## Godot 環境時，先 `godot --headless --check-only` 確認語法，再由 tests/smoke_test.gd 與未來的自動打法
## 腳本實際呼叫，才算驗收。
##
## ## 用途：GDevelop `window.__W` / `window.__B` / `window.__forceEnc` 的 Godot 等價物
##
## GDevelop 版的 puppeteer E2E（見 reference/gdevelop/DEV_開發指南.md L73-79）
## 靠瀏覽器全域變數讀遊戲內部狀態、強制觸發遭遇：
##   window.__W       世界：scene / 座標 / 旗標 / 選單狀態 / 隊伍摘要
##   window.__B       戰鬥：state / foes / heroes / sel
##   window.__forceEnc="ch1_boss"   直接開該遭遇戰（測戰鬥不用跑圖）
## Godot 沒有瀏覽器全域物件，改用這個 autoload 當「單一除錯查詢點」。自動化測試（headless 腳本 / GUT）
## 拿到 SceneTree 後，透過固定路徑 `/root/DebugHooks` 呼叫下列方法讀狀態、驅動遭遇，語意逐一對齊上面三個
## 瀏覽器掛勾。
##
## ## 設計原則
##
## 1. **唯讀快照為主**：dump_world()/dump_battle() 回傳純 Dictionary 快照（可被測試直接斷言、可被
##    JSON.stringify 印出比對），不回傳實際 Node 參照，避免測試不小心改到遊戲狀態。
## 2. **防禦式 introspection**：世界/戰鬥場景節點（WorldScene / battle_state_machine.gd 的 Battle）由
##    MOD-H / MOD-E 擁有，欄位可能演進。這裡一律用 `Object.get("field")`（找不到回 null，不報錯）＋
##    型別檢查取值，任何一個場景改欄位名都只會讓對應快照欄位變 null，不會讓整個 hook 崩掉。
## 3. **debug build 才啟用**：預設只在 `OS.is_debug_build()` 或環境變數 `CQ_DEBUG_HOOKS=1` 時掛上；
##    release 匯出不暴露內部狀態。CI/headless 測試預設就是 debug build，符合需求。
##
## 擁有檔案：CORE-7（tests/**）。project.godot [autoload] 只新增本檔案一行登記（比照 CORE-2/MOD-A/
## CORE-6 先例），不動其他區塊。

var enabled: bool = false

## 除錯用「不會遇敵」開關：true 時 EncounterTracker 完全跳過隨機遭遇觸發，方便測地區移動。
## 僅測試便利用，不寫進存檔（SaveManager 不理它），每次啟動遊戲重設為 false。由 HUD 除錯選單切換。
var no_encounter: bool = false


func _ready() -> void:
	enabled = OS.is_debug_build() or OS.get_environment("CQ_DEBUG_HOOKS") == "1"
	if enabled:
		# 對應 GDevelop 在 window 上掛全域變數的時機（遊戲一啟動就可讀）。
		print("[DebugHooks] enabled — 測試可透過 /root/DebugHooks 讀取 GameState/戰鬥狀態、force_encounter()。")


# ---------------------------------------------------------------------------
# __W 等價：世界狀態快照（GameState 全域 + 目前場景摘要）
# ---------------------------------------------------------------------------
## 對應 window.__W。回傳跨場景全域狀態（GameState，永遠可讀）＋目前 current_scene 的世界摘要
## （scene_id / 玩家座標 / 是否鎖定 / 是否在室內；只有 current_scene 是 WorldScene 時才有值）。
func dump_world() -> Dictionary:
	var out := {
		"flags": GameState.flags.duplicate(true),
		"gold": GameState.gold,
		"party": _party_summary(),
		"item_inv": GameState.inv_all().duplicate(true),
		"eq_inv": GameState.eq_inv.duplicate(true),
		"auto_battle": GameState.auto_battle,
		# 場景轉場暫態（對應 g_return*/g_spawn/g_result）——測試核對交握用。
		"return_scene": GameState.return_scene,
		"return_x": GameState.return_x,
		"return_y": GameState.return_y,
		"spawn": GameState.spawn,
		"result": GameState.result,
		"encounter": GameState.encounter,
	}
	var scene := _current_scene()
	if scene != null and scene.get("scene_id") != null:
		# WorldScene（MOD-H）：scene_id / enc_group / world_state。
		out["scene"] = scene.get("scene_id")
		out["enc_group"] = scene.get("enc_group")
		var ws = scene.get("world_state")
		if ws != null:
			out["lock"] = ws.get("lock")
			out["inside"] = ws.get("inside")
		out["player_pos"] = _find_player_pos(scene)
	else:
		out["scene"] = _scene_name_fallback(scene)
	return out


# ---------------------------------------------------------------------------
# __B 等價：戰鬥狀態快照
# ---------------------------------------------------------------------------
## 對應 window.__B。只有 current_scene 是戰鬥場景（battle_state_machine.gd，節點名 "Battle"，有 `state`
## 欄位）時才有內容；否則回傳 {"in_battle": false}。自動打法腳本靠這個判斷 state 機（menu/target/...）。
func dump_battle() -> Dictionary:
	var scene := _current_scene()
	if scene == null or scene.get("state") == null:
		return {"in_battle": false}
	return {
		"in_battle": true,
		"state": scene.get("state"),       # run/menu/target/skill/item/target_ally/anim/win/lose/end
		"sel": scene.get("sel"),
		"s_sel": scene.get("s_sel"),
		"i_sel": scene.get("i_sel"),
		"t_sel": scene.get("t_sel"),
		"msg": scene.get("msg"),
		"enc": scene.get("enc"),
		"end_state": scene.get("end_state"),
		"heroes": _unit_summaries(scene.get("heroes")),
		"foes": _unit_summaries(scene.get("foes")),
	}


# ---------------------------------------------------------------------------
# __forceEnc 等價：強制開遭遇戰
# ---------------------------------------------------------------------------
## 對應 window.__forceEnc="ch1_boss"。從任一世界場景直接開該遭遇戰，測戰鬥不用跑圖。內部走正規
## SceneRouter.start_battle()（不是繞過），所以返回座標/return_scene 的交握跟真實遭遇一致。
## return_scene / return_x/y 若沒帶（-1），沿用目前世界場景的 scene_id 與玩家座標。
func force_encounter(encounter_id: String, return_scene: String = "", return_x: float = -1.0, return_y: float = -1.0) -> void:
	var scene := _current_scene()
	if return_scene == "" and scene != null and scene.get("scene_id") != null:
		return_scene = scene.get("scene_id")
	if return_scene == "":
		return_scene = "Town"
	if return_x < 0.0 or return_y < 0.0:
		var pos: Variant = _find_player_pos(scene)
		if pos is Vector2:
			return_x = pos.x
			return_y = pos.y
	print("[DebugHooks] force_encounter(%s) return_scene=%s pos=(%.0f,%.0f)" % [encounter_id, return_scene, return_x, return_y])
	SceneRouter.start_battle(encounter_id, return_scene, return_x, return_y)


# ---------------------------------------------------------------------------
# 測試輔助：直接改 GameState（給 setup fixture 用，對應 puppeteer 在 evaluate 裡塞旗標）
# ---------------------------------------------------------------------------
## 批次設旗標，方便測試把遊戲擺到某個劇情節點（例如 ch2==1）再驗證分支，對應 puppeteer 直接寫
## window 全域再觸發互動。只在 enabled 時生效。
func set_flags(flags: Dictionary) -> void:
	if not enabled:
		return
	for k in flags:
		GameState.flag_set(String(k), int(flags[k]))


func set_gold(amount: int) -> void:
	if enabled:
		GameState.gold = amount


# ---------------------------------------------------------------------------
# 內部工具
# ---------------------------------------------------------------------------
func _current_scene() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene


func _scene_name_fallback(scene: Node) -> String:
	if scene == null:
		return ""
	return scene.name


func _party_summary() -> Array:
	var out: Array = []
	for m in GameState.party:
		if m is Dictionary:
			out.append({
				"id": m.get("id", ""),
				"hp": m.get("hp", 0),
				"mp": m.get("mp", 0),
				"lv": m.get("lv", 0),
			})
	return out


## 戰鬥單位（heroes/foes 是 Array[Dictionary]）摘要，取自動打法/斷言常用的欄位，容錯缺欄。
func _unit_summaries(units: Variant) -> Array:
	var out: Array = []
	if units is Array:
		for u in units:
			if u is Dictionary:
				out.append({
					"id": u.get("id", ""),
					"name": u.get("name", ""),
					"hp": u.get("hp", 0),
					"maxhp": u.get("maxhp", 0),
					"alive": int(u.get("hp", 0)) > 0,
				})
	return out


## 世界場景玩家座標。WorldScene 的玩家節點是私有欄位（_player），改走節點樹用群組/名稱找，找不到回 null。
func _find_player_pos(scene: Node) -> Variant:
	if scene == null:
		return null
	var p := scene.get_node_or_null("Player")
	if p == null:
		# 玩家可能在 "player" 群組（MOD-C/MOD-H 若有加）。
		var nodes := get_tree().get_nodes_in_group("player")
		if nodes.size() > 0:
			p = nodes[0]
	if p != null and p is Node2D:
		return (p as Node2D).global_position
	return null
