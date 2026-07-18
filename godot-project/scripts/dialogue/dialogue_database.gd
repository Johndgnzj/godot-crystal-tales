class_name DialogueDatabase
extends Resource
## 對話資料的單一聚合入口（存成 resources/content/dialogue/dialogue_db.tres），比照 ContentDatabase。
##
## 為什麼需要它：Godot 匯出成 .pck 後 DirAccess 無法列舉 res:// 目錄，不能靠「掃資料夾」載入散落的
## .tres。改用這個聚合資源用 typed @export 陣列**明確引用**每個個別 .tres（存檔時寫成 ExtResource
## 連結）。DialogueSystem autoload 只 load() 這一個檔即拿到全部——匯出安全、型別安全。
##
## 資料真相源＝各個 .tres（設計員在 Godot 編輯器 Inspector 直接編輯個別 NPC／過場）。
## 這個聚合檔由 scripts/dialogue/build_dialogue_tres.gd 從 dialogue.json 種子產生；之後新增／刪除
## 對話時，把對應 .tres 加進／移出下面陣列（或重跑該腳本重建）。

@export var npcs: Array[NpcDialogue] = []
@export var cutscenes: Array[CutsceneEntry] = []
