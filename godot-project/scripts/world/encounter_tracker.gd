extends Node
class_name EncounterTracker

## MOD-G 產出：高草/碎石地形（ENC）隨機遭遇觸發追蹤器。
##
## 對應 build_cq2.py「高草遇敵」段落（DEV_開發指南.md L55）：
##   初始值      L1390 rs.__v={..enc:0,encNext:600+Math.random()*800,grace:1.2..}
##   grace 倒數  L1505 if(st.grace>0)st.grace-=dt;                         （每幀無條件倒數，不看 lock）
##   觸發判定    L2336-2343
##     if(!lock&&st.grace<=0&&b.isMoving()&&inEnc(ft[0],ft[1])&&CFG.encGroup){
##       st.enc+=b.getSpeed()*dt;
##       if(st.enc>=st.encNext){ g_returnScene=CFG.SCENE; g_returnX/Y=p.getX()/getY();
##         g_encounter=<encGroup 解析後的字串>; replaceScene("Battle"); }
##     }
##   ENC 地形查詢 L2308-2312 inEnc(px,py) = CFG.ENC[ty].charAt(tx)==="1"（tile 字元圖）
##
## ## 用法（給 MOD-H 之後建世界場景時參考；也可用於單一測試場景先行開發，見
## ## TASKS/11_並行協作規則.md「MOD-C/MOD-G 開工時若 MOD-H 尚未完成，先用單一測試場景假資料開發」）
##
##   var tracker := EncounterTracker.new()
##   tracker.player = $Player                    # PlayerController（MOD-C），CharacterBody2D
##   tracker.world_state = state                  # WorldSceneState（MOD-C），可留 null＝視為永不鎖定
##   tracker.encounter_id = "forest"               # CFG.encGroup 解析後的字串，見下方「encounter_id 語意」
##   tracker.return_scene_id = "Forest"            # CFG.SCENE 字串，原樣轉交給 SceneRouter.start_battle()
##   tracker.is_on_encounter_terrain = <Callable>  # 見下方「ENC 地形判定介面」，MOD-H 尚未提供地圖前必填
##   add_child(tracker)
##
## ## encounter_id 語意（`CFG.encGroup` 對照，本檔案不解讀內容，只原樣轉交）
##
## GDevelop 原始碼 L2340：
##   g.get("g_encounter").setString(CFG.encGroup==="mine_step0"?(f.step===0?"tutorial":"mine"):CFG.encGroup);
##
## 大部分場景 `CFG.encGroup` 是固定字串（"forest"/"forest2"/"mine"），可以直接指派給 `encounter_id` 一次。
## 但 `mine_step0` 這個特例依賴 `flags.step`（序章 step0 用 "tutorial" 池，之後用 "mine" 池）——**這個
## 分歧判斷不是本檔案職責**（任務範圍已聲明「敵人池選擇不是 MOD-G 職責，屬於 MOD-E/CONTENT.encounters」，
## 這裡進一步延伸：連「選哪個字串代表哪個池」的判斷也留給呼叫端）。若某場景的 encGroup 是 `mine_step0`
## 這類需要依旗標動態決定的情況，呼叫端（世界場景根節點腳本）應該自行在 `GameState.flags` 變動時（或
## 每次呼叫前）重新算好最終字串再指派給 `tracker.encounter_id`，本檔案只負責把當下的 `encounter_id`
## 原樣傳給 `SceneRouter.start_battle()`。
##
## `encounter_id == ""` 比照 `CFG.encGroup` 為 falsy／未設定的場景（例如 Town 沒有高草地形遭遇）：
## 完全跳過距離累積與觸發判定。
##
## ## ENC 地形判定介面（給 MOD-H 對照）
##
## `scenes/world/**` 目前只有 `.gitkeep`（MOD-H 尚未開工），拿不到真實地圖資料，因此「哪些位置算 ENC
## 地形」設計成參數化的 `Callable(Vector2) -> bool`：輸入玩家目前 `global_position`（比照
## `boss_mark.gd`/`exit_zone.gd` 既有慣例，直接用 `global_position` 近似 GDevelop 的 `feet(p)`
## 腳底取樣點——見 `exit_zone.gd`「這裡直接加在玩家目前的 global_position 上做近似，兩者在絕大多數
## 情況下等價」的既有註解，本檔案沿用同一個近似；連 GDevelop 原始碼觸發當下寫入 `g_returnX/Y` 的也是
## `p.getX()/getY()`〈物件原始座標〉而不是 `ft[0]/ft[1]`〈腳底取樣點〉，兩者本來就分開用，這裡簡化成
## 全部用 `global_position`），回傳「這個位置是否踩在高草/碎石（ENC）地形上」。
##
## 保持預設值（空 `Callable`，`is_valid()==false`）＝視為「這個場景永遠不會踩到 ENC 地形」，且第一次
## 因此被跳過時會 `push_warning()` 一次（不洗版）提醒忘了接線——**刻意不寫死回傳 true 或 false 的假
## 版本**，因為那樣會讓「地形資料還沒接上」這件事在測試時被無聲蓋過去，回頭 debug 會找不到原因。
##
## MOD-H 決定實際地圖資料格式後，兩種常見接法都能直接符合這個簽名，不需要改本檔案任何一行：
##
##   (a) TileMapLayer 的 custom data layer（推薦，Godot 4.3 標準做法）：
##       tracker.is_on_encounter_terrain = func(pos: Vector2) -> bool:
##           var cell: Vector2i = enc_layer.local_to_map(enc_layer.to_local(pos))
##           var td: TileData = enc_layer.get_cell_tile_data(cell)
##           return td != null and bool(td.get_custom_data("enc"))
##
##   (b) 純資料查表（比照 GDevelop `CFG.ENC` 字串陣列逐字元判斷，tile-index 直接對照）：
##       tracker.is_on_encounter_terrain = func(pos: Vector2) -> bool:
##           var tx: int = int(pos.x / TILE_SIZE)
##           var ty: int = int(pos.y / TILE_SIZE)
##           return ty >= 0 and ty < ENC_MAP.size() and tx >= 0 and tx < ENC_MAP[ty].length() \
##               and ENC_MAP[ty][tx] == "1"
##
## ## 為什麼用 `_physics_process` 而非 `_process`
##
## `PlayerController`（MOD-C）的移動與 `velocity`/`global_position` 更新都發生在 `_physics_process`
## （`CharacterBody2D.move_and_slide()`），本檔案的距離累積讀的正是這兩個欄位，跟著用
## `_physics_process` 可以確保每次讀到的都是同一個 physics tick 內的最新值，避免 `_process`（可能每幀
## 執行多次或被跳幀插值）讀到暫時不一致的中間狀態。GDevelop 原始碼是「每幀重跑」的單一事件（沒有
## physics/render 分離），這裡選 `_physics_process` 是配合 Godot 既有的移動系統慣例，不是逐行翻譯。

signal encounter_triggered(encounter_id: String, trigger_position: Vector2)

## px，對應 `600+Math.random()*800` 的下界。
@export var enc_min: float = 600.0
## px，對應 `600+Math.random()*800` 的隨機範圍（上界 = enc_min + enc_span = 1400）。
@export var enc_span: float = 800.0
## 秒，對應 build_cq2.py L1390 `grace:1.2`（場景初始化/戰鬥結束返回世界後的短暫寬限期，不觸發遭遇）。
@export var initial_grace: float = 1.2

## PlayerController（MOD-C，`scripts/world/player_controller.gd`）。需要 `global_position`
## （CharacterBody2D 內建）與 `velocity`（CharacterBody2D 內建，MOD-C 每個 physics frame 更新）。
## 由掛載本節點的世界場景根節點在 `_ready()` 賦值；保持 null 時本節點完全不累積、不觸發（不會報錯）。
var player: PlayerController = null

## WorldSceneState（MOD-C，`scripts/world/world_scene_state.gd`）。可留 null＝視為永不鎖定（比照
## `player_controller.gd` 自己的 `world_state` 欄位同一套「允許 null，方便單場景/無地圖測試」慣例）。
var world_state: WorldSceneState = null

## `CFG.encGroup` 解析後的字串，原樣轉交給 `SceneRouter.start_battle()`；空字串＝本場景不觸發遭遇。
## 見上方「encounter_id 語意」。
var encounter_id: String = ""

## `CFG.SCENE` 字串（例如 "Forest"），觸發時原樣轉交給 `SceneRouter.start_battle()` 的 `return_scene`
## 參數，讓戰鬥結算後知道要送玩家回哪個世界場景。
var return_scene_id: String = ""

## `Callable(Vector2) -> bool`，見上方「ENC 地形判定介面」。預設空 `Callable`＝一律視為非 ENC 地形。
var is_on_encounter_terrain: Callable = Callable()

## 已累積移動距離（px），對應 `st.enc`。
var enc: float = 0.0
## 下次觸發門檻（px），對應 `st.encNext`。
var enc_next: float = 0.0
## 寬限倒數（秒），對應 `st.grace`。>0 時完全不觸發，且無條件每幀倒數（比照原始碼 L1505 不看 lock）。
var grace: float = 0.0

var _warned_no_terrain_cb: bool = false


func _ready() -> void:
	reset()


## 重置成「剛進場景」的初始狀態：`enc=0`、重抽 `enc_next`、`grace=initial_grace`。
## `_ready()` 會自動呼叫一次（比照 GDevelop 每次世界場景重新載入 `rs.__v` 都會重新初始化，換場景/
## 戰鬥結束返回世界在 Godot 這邊是 `change_scene_to_file()`，整個場景樹被釋放重建，本節點也會跟著
## 重新 `_ready()`，天然對應同一套語意，不需要外部手動呼叫）。額外曝露成 public 方法是給觸發後的
## 內部重置用（見 `_trigger()`），以及萬一未來有需求要在不重建節點的情況下手動重置時使用。
func reset() -> void:
	enc = 0.0
	enc_next = enc_min + randf() * enc_span
	grace = initial_grace


func _physics_process(delta: float) -> void:
	if grace > 0.0:
		grace = maxf(0.0, grace - delta)

	if player == null or encounter_id == "":
		return
	if world_state != null and world_state.lock:
		return
	if grace > 0.0:
		return
	if not player.is_moving:
		return

	if not is_on_encounter_terrain.is_valid():
		if not _warned_no_terrain_cb:
			push_warning(
				"EncounterTracker: is_on_encounter_terrain 未設定（Callable 無效），遭遇累積停用——"
				+ "等 MOD-H 提供地形資料後接上，見 encounter_tracker.gd 檔頭「ENC 地形判定介面」"
			)
			_warned_no_terrain_cb = true
		return

	var pos: Vector2 = player.global_position
	if not is_on_encounter_terrain.call(pos):
		return

	enc += player.velocity.length() * delta
	if enc >= enc_next:
		_trigger(pos)


func _trigger(pos: Vector2) -> void:
	encounter_triggered.emit(encounter_id, pos)
	SceneRouter.start_battle(encounter_id, return_scene_id, pos.x, pos.y)
	reset()
