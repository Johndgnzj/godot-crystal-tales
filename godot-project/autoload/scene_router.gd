extends Node

## ⚠️ 暫時性 STUB — 這不是 CORE-5 任務的正式產出。
##
## 目的同 game_state.gd 檔頭說明：MOD-A/MOD-B 需要一個可呼叫的場景轉場介面才能寫出結構完整的程式碼，
## 協調者先放最小版本，簽名照抄 ../TASKS/00_核心任務.md CORE-5 段落。CORE-5 任務認領時要正式檢視/擴充
## （例如 Signal 化、跟 GameState 轉場暫態欄位的整合、實際 change_scene_to_file 呼叫的時機與淡入淡出）。

signal battle_requested(encounter_id: String)
signal scene_change_requested(scene_path: String, spawn_id: String)


func go_to(scene_path: String, spawn_id: String = "") -> void:
	GameState.spawn = spawn_id
	scene_change_requested.emit(scene_path, spawn_id)
	# TODO(CORE-5): 實際呼叫 get_tree().change_scene_to_file()，目前只發 signal 供測試/上層邏輯掛勾。


func start_battle(encounter_id: String, return_scene: String, return_x: float, return_y: float) -> void:
	GameState.encounter = encounter_id
	GameState.return_scene = return_scene
	GameState.return_x = return_x
	GameState.return_y = return_y
	battle_requested.emit(encounter_id)
	# TODO(CORE-5): 實際 replaceScene 等價行為（change_scene_to_file 到 Battle 場景）。


func battle_result(result: String) -> void:
	GameState.result = result
