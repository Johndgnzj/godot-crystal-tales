class_name ContentDatabase
extends Resource

## 聚合所有內容資料的單一入口資源（存成 res://resources/content/content_db.tres）。
##
## 為什麼需要它：Godot 匯出成 .pck 後，`DirAccess` 無法列舉 res:// 目錄，所以不能靠「掃資料夾」
## 載入散落的 .tres。改用這個聚合資源用 typed @export 陣列**明確引用**每個個別 .tres（存檔時會寫成
## ExtResource 連結）。ContentDB autoload 只要 load() 這一個檔，就拿到全部——匯出安全、型別安全。
##
## 資料真相源＝各個 .tres（設計員在 Godot 編輯器 Inspector 直接編輯個別實體）。
## 這個聚合檔由 scripts/content/build_tres.gd 從 content.json 產生（一次性匯入），之後新增/刪除實體時
## 要把對應 .tres 加進/移出下面的陣列（或重跑 build_tres.gd 重建）。

@export var party: Array[PartyMemberDef] = []
@export var equipment: Array[EquipmentDef] = []
@export var skills: Array[SkillDef] = []
@export var items: Array[ItemDef] = []
@export var enemies: Array[EnemyDef] = []
@export var encounters: Array[EncounterDef] = []
@export var shops: Array[ShopDef] = []
@export var chests: Array[ChestDef] = []
@export var derived: DerivedParams
@export var pacing: PacingParams
