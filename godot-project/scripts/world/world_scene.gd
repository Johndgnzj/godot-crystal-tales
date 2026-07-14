extends Node2D
class_name WorldScene

## MOD-H 產出：世界場景通用控制器（Town/Forest/Forest2/Mine/Cave 五張室外地圖共用一支腳本，
## per-scene 差異全部走下方 @export 資料，由 scripts/map/gen_maps.py 生成 .tscn 時填入）。
##
## 對應 build_cq2.py WORLD_JS 的「場景生命週期」部分（init 出生點 L1425-1449、劇情佇列、
## 出口/觸發/撿取閘門 L2298-2392、NPC 對話/寶箱互動 L1711-1808、隊伍跟隨 L2272-2296）。
## 個別子系統的邏輯不在本檔案重複實作，而是把既有元件組起來：
##   - PlayerController／WorldSceneState／PartyTrail（MOD-C，scripts/world/）
##   - ExitZone／TriggerZone／PickupZone／BossMark（MOD-B，場景檔裡以節點實例存在，
##     生成時已把 CFG.exits/triggers/pickups 資料填進各節點的 export）
##   - EncounterTracker（MOD-G，本腳本在 _ready() 以程式建立並接線）
##   - DialogueSystem／SceneRouter／GameState／SaveManager／ContentDB／InputBridge（autoload）
##
## ## 座標約定（生成器與本腳本共用，務必一致）
##
## Godot 玩家節點 origin ＝ GDevelop 的「腳點」feet(p) = (左上x + 32, 左上y + 64*0.85 ≈ +54)
## （build_cq2.py L1386）。理由：GDevelop 版所有區域判定（exits/triggers/pickups/ENC 地形）都以
## 腳點為準，MOD-B/MOD-G 的既有腳本也都直接拿 `global_position` 判定，把 origin 定成腳點可以讓
## 兩邊語意一致。生成器把 CFG.spawns 的像素值 +(32,54) 之後才寫進 `spawns` export；戰鬥返回座標
## （return_x/y）在 Godot 端存的取的都是同一個腳點座標，內部自洽，不需要再轉換。
##
## ## 視覺資源採「執行期載入＋存在檢查」而非 .tscn ext_resource（重要設計決定）
##
## MOD-I（美術資產複製）與本任務平行進行，本 worktree 裡 `res://assets/**` 還不存在。若場景檔
## 直接 ext_resource 引用貼圖，資產就位前整個場景會載入失敗（連帶 SceneRouter 切場景失敗）。
## 因此所有貼圖（地磚 atlas、prop、NPC、玩家/跟隨者動畫幀、寶箱）一律由本腳本在 _ready() 用
## `ResourceLoader.exists()` 檢查後 `load()`：資產缺席時場景照常運作（碰撞/出入口/觸發/遭遇全部
## 有效，只是看不到圖），MOD-I 合併後不需要改任何檔案即自動顯示。TileSet .tres 同理，用路徑字串
## export＋執行期載入，不進場景的 ext_resource 清單。
##
## ## 本次範圍外（留待後續任務，見 TASKS/08_地圖管線.md「範圍外」）：
## 室內系統（INT_DRAWN 手繪大圖/門口進屋）、告示板動態文字、Town 母雞/戶外 NPC 遊走、BGM/SFX
## （尚無音訊 autoload）、觸控 UI。

const TS := 32
const ATLAS_COLS := 6
## AnimatedSprite2D 相對腳點 origin 的位移：LPC 幀 64x64、中心 (32,32)、腳點 (32,54) → (0,-22)。
const SPRITE_FEET_OFFSET := Vector2(0.0, -22.0)
## NPC 對話半徑，對應 build_cq2.py L1713 `_talkR=st.inside?134:72`（室內模式範圍外，固定用 72）。
const TALK_RADIUS := 72.0
const PROMPT_SECONDS := 3.0
const CHAR_DIR := "res://assets/char"
## 跟隨者可用的行走圖白名單，對應 WORLD_JS `FSPRITES={marin:1,aaron:1}`（L2282）。
const FOLLOWER_SPRITES := ["marin", "aaron"]
const WALK_FPS := 12.5  # GDevelop anim timeBetweenFrames=0.08s

@export var scene_id: String = ""            ## CFG.SCENE 邏輯名稱（"Town"…），交給 SceneRouter 用。
@export var map_w: int = 0
@export var map_h: int = 0
@export var ground_tiles: PackedInt32Array = PackedInt32Array()  ## row-major，值＝atlas tile id（1 起算，同 tmj）
@export var blk_rows: PackedStringArray = PackedStringArray()    ## CFG.BLK：每列 '0'/'1' 字串（阻擋格，除錯/驗證用；實際碰撞是 $Collision 烘好的矩形）
@export var enc_rows: PackedStringArray = PackedStringArray()    ## CFG.ENC：高草/碎石遭遇地形（encounter_tracker 接法 (b)）
@export var spawns: Dictionary = {}          ## spawn_id -> Vector2（已轉為腳點座標）
@export var enc_group: String = ""           ## CFG.encGroup；"" = 本場景無隨機遭遇
@export var bgm: String = ""                 ## CFG.bgm（目前無音訊系統，先保留資料）
@export var cut_on_enter: Array = []         ## CFG.cutOnEnter：[{"cut": String, "step": int?}]
@export var npc_list: Array = []             ## [{"id","sprite","x","y","face"}]（tile 座標；Town 只含戶外 NPC）
@export var prop_list: Array = []            ## [{"tex","x","y","w","h"}]（x/y=GDevelop 左上像素；w/h=0 用原生尺寸）
@export var chest_list: Array = []           ## [{"id","tx","ty"}]（loot 資料查 ContentDB.get_chest()）
@export var tileset_path: String = ""        ## res://resources/map/tileset_*.tres
@export var atlas_path: String = ""          ## res://assets/map/atlas*.png（存在檢查用）

var world_state: WorldSceneState = WorldSceneState.new()

var _player: PlayerController
var _trail := PartyTrail.new()
var _tracker: EncounterTracker = null
var _player_anim: AnimatedSprite2D = null
var _followers: Array = []      # [{node, anim}]
var _npc_nodes: Array = []      # [{id, node}]
var _chest_nodes: Array = []    # [{id, tx, ty, sprite}]
var _prompt_timer: float = 0.0
var _missing_textures: int = 0

# UI（選單/HUD）由本控制器在 _ready() 以程式建立，不進 .tscn ext_resource——這樣地圖生成器
# （gen_maps.py）重生成場景檔時不會覆蓋掉 UI 掛載，也避免與地圖資料工作搶同一個 .tscn。
var _menu: CanvasLayer = null
var _hud_full: CanvasLayer = null

# 對話推進與世界互動搶同一個 ui_accept 的協調狀態：對話結束後要求該鍵先放開，才能再次開啟新對話，
# 否則「結束對話的那一下」會在同一幀被 _update_interactions 當成開啟輸入導致無限重開。
var _was_busy: bool = false
var _accept_release_needed: bool = false


func _ready() -> void:
	_player = $YSort/Player
	_player.add_to_group("player")  # 保險；場景檔已宣告 groups=["player"]
	_player.world_state = world_state
	_fill_ground()
	_spawn_props()
	_spawn_npcs()
	_spawn_chests()
	_setup_player_visual()
	_setup_followers()
	_setup_camera_limits()
	_wire_zones()
	_setup_ui()
	_apply_entry_state()
	_trail.reset(_player.global_position)
	_setup_encounter_tracker()
	DialogueSystem.battle_requested.connect(_on_cut_battle)
	DialogueSystem.scene_transfer_requested.connect(_on_cut_transfer)
	_play_enter_cutscenes()
	if _missing_textures > 0:
		push_warning(
			"WorldScene(%s): %d 張貼圖尚未就位（MOD-I 資產複製未合併？），先以隱形方式運作"
			% [scene_id, _missing_textures]
		)


func _physics_process(delta: float) -> void:
	# lock 同步：對話/過場進行中，或選單開啟時，鎖移動與 zones（對應 WORLD_JS 的 lock 旗標）。
	var busy_now: bool = DialogueSystem.is_busy()
	if _was_busy and not busy_now:
		# 對話/過場剛結束 → 要求 ui_accept 放開後才能再開新對話（見 _update_interactions 的 release gate）。
		_accept_release_needed = true
	_was_busy = busy_now
	var menu_open: bool = _menu != null and _menu.is_open()
	world_state.set_lock(busy_now or menu_open)
	if _tracker != null:
		# mine_step0 特例每幀重解析（見 encounter_tracker.gd 檔頭「encounter_id 語意」）。
		_tracker.encounter_id = _resolve_encounter_group()
	var walking: bool = _player.is_moving and not world_state.lock
	_trail.update_leader(_player.global_position, _player.facing)
	_update_player_anim(walking)
	_update_followers(walking)
	_update_interactions(delta)


# =========================================================================
# 地磚
# =========================================================================

@warning_ignore("integer_division")
func _fill_ground() -> void:
	var layer: TileMapLayer = $Ground
	if tileset_path == "" or not ResourceLoader.exists(tileset_path) \
			or (atlas_path != "" and not ResourceLoader.exists(atlas_path)):
		_missing_textures += 1
		return
	layer.tile_set = load(tileset_path)
	if layer.tile_set == null:
		return
	for y in range(map_h):
		for x in range(map_w):
			var t: int = ground_tiles[y * map_w + x]
			if t <= 0:
				continue
			var idx: int = t - 1
			layer.set_cell(Vector2i(x, y), 0, Vector2i(idx % ATLAS_COLS, idx / ATLAS_COLS))


# =========================================================================
# 視覺物件（props / NPC / 寶箱 / 玩家 / 跟隨者）——全部執行期載入，缺圖不擋功能
# =========================================================================

## 建立「底部中心為 origin」的 sprite 節點加進 $YSort（y_sort_enabled 以 node.y 排序，等價
## GDevelop 的 baseZ = y + height，見 build_cq2.py L1387）。x/y 是 GDevelop 左上角像素。
func _add_base_sprite(tex_path: String, x: float, y: float, w: float = 0.0, h: float = 0.0) -> Node2D:
	if not ResourceLoader.exists(tex_path):
		_missing_textures += 1
		return null
	var tex: Texture2D = load(tex_path)
	if tex == null:
		_missing_textures += 1
		return null
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	var sw: float = w if w > 0.0 else tw
	var sh: float = h if h > 0.0 else th
	var node := Node2D.new()
	node.position = Vector2(x + sw / 2.0, y + sh)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.scale = Vector2(sw / tw, sh / th)
	spr.position = Vector2(0.0, -sh / 2.0)
	node.add_child(spr)
	$YSort.add_child(node)
	return node


func _spawn_props() -> void:
	for p in prop_list:
		_add_base_sprite(
			str(p["tex"]), float(p["x"]), float(p["y"]),
			float(p.get("w", 0.0)), float(p.get("h", 0.0))
		)


func _spawn_npcs() -> void:
	# GDevelop 把 NPC 放在 (x*TS, y*TS-16)（build_cq2.py L1224），64x64 幀 → 底部中心
	# (x*TS+32, y*TS+48)。互動半徑判定用這個底部中心點（≒GDevelop 用 sprite 中心，差 32px 內
	# 對 72px 半徑無實質影響）。
	for n in npc_list:
		var node := Node2D.new()
		node.position = Vector2(float(n["x"]) * TS + 32.0, float(n["y"]) * TS + 48.0)
		var tex_path := "%s/%s_%s_0.png" % [CHAR_DIR, str(n["sprite"]), str(n.get("face", "Down"))]
		if ResourceLoader.exists(tex_path):
			var spr := Sprite2D.new()
			spr.texture = load(tex_path)
			spr.position = Vector2(0.0, -32.0)
			node.add_child(spr)
		else:
			_missing_textures += 1
		$YSort.add_child(node)
		_npc_nodes.append({"id": str(n["id"]), "node": node})


func _spawn_chests() -> void:
	for c in chest_list:
		var cid := str(c["id"])
		var tx := int(c["tx"])
		var ty := int(c["ty"])
		var opened: bool = GameState.chest_is_opened(cid)
		var node := _add_base_sprite(_chest_tex(opened), float(tx * TS), float(ty * TS))
		var spr: Sprite2D = null
		if node != null and node.get_child_count() > 0:
			spr = node.get_child(0)
		_chest_nodes.append({"id": cid, "tx": tx, "ty": ty, "sprite": spr})


func _chest_tex(opened: bool) -> String:
	return "res://assets/props/chest_opened.png" if opened else "res://assets/props/chest_closed.png"


func _build_char_frames(sprite_names: Array, prefix_with_name: bool) -> SpriteFrames:
	# 動畫命名對齊 GDevelop char_anims()/follower_anims()（build_cq2.py L494-509）：
	# 玩家＝"WalkDown"/"IdleDown"…；跟隨者＝"marin_WalkDown"/"aaron_IdleDown"…。
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var any := false
	for cn in sprite_names:
		for dn in ["Down", "Left", "Right", "Up"]:
			var idle_path := "%s/%s_%s_0.png" % [CHAR_DIR, cn, dn]
			if not ResourceLoader.exists(idle_path):
				_missing_textures += 1
				continue
			any = true
			var pre := "%s_" % cn if prefix_with_name else ""
			var idle_name := "%sIdle%s" % [pre, dn]
			frames.add_animation(idle_name)
			frames.set_animation_loop(idle_name, false)
			frames.add_frame(idle_name, load(idle_path))
			var walk_name := "%sWalk%s" % [pre, dn]
			frames.add_animation(walk_name)
			frames.set_animation_speed(walk_name, WALK_FPS)
			for i in range(1, 9):
				var fp := "%s/%s_%s_%d.png" % [CHAR_DIR, cn, dn, i]
				if ResourceLoader.exists(fp):
					frames.add_frame(walk_name, load(fp))
	return frames if any else null


func _setup_player_visual() -> void:
	var frames := _build_char_frames(["ludo"], false)
	if frames == null:
		return
	_player_anim = AnimatedSprite2D.new()
	_player_anim.sprite_frames = frames
	_player_anim.position = SPRITE_FEET_OFFSET
	_player.add_child(_player_anim)
	if frames.has_animation("IdleDown"):
		_player_anim.play("IdleDown")


func _setup_followers() -> void:
	var frames := _build_char_frames(FOLLOWER_SPRITES, true)
	for _i in range(3):
		var node := Node2D.new()
		node.visible = false
		var anim: AnimatedSprite2D = null
		if frames != null:
			anim = AnimatedSprite2D.new()
			anim.sprite_frames = frames
			anim.position = SPRITE_FEET_OFFSET
			node.add_child(anim)
		$YSort.add_child(node)
		_followers.append({"node": node, "anim": anim})


func _setup_camera_limits() -> void:
	var cam: Camera2D = $YSort/Player/Camera2D
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = map_w * TS
	cam.limit_bottom = map_h * TS


func _update_player_anim(walking: bool) -> void:
	if _player_anim == null:
		return
	var anim_name := ("Walk" if walking else "Idle") + _player.facing
	if _player_anim.sprite_frames.has_animation(anim_name) and _player_anim.animation != anim_name:
		_player_anim.play(anim_name)


func _update_followers(walking: bool) -> void:
	# 對應 WORLD_JS L2280-2295：party[1..3] 中 sprite 在白名單者依 trail 取樣點排隊。
	var party: Array = GameState.party
	var fi := 0
	for i in range(1, mini(party.size(), 4)):
		if fi >= _followers.size():
			break
		var mem = party[i]
		if typeof(mem) != TYPE_DICTIONARY:
			continue
		var spr_name := str(mem.get("sprite", ""))
		if not FOLLOWER_SPRITES.has(spr_name):
			continue
		var pt = _trail.sample_follower(i)
		if pt == null:
			continue
		var f: Dictionary = _followers[fi]
		fi += 1
		var node: Node2D = f["node"]
		node.visible = true
		node.position = pt["pos"]
		var anim: AnimatedSprite2D = f["anim"]
		if anim != null:
			var anim_name := "%s_%s%s" % [spr_name, "Walk" if walking else "Idle", pt["facing"]]
			if anim.sprite_frames.has_animation(anim_name) and anim.animation != anim_name:
				anim.play(anim_name)
	for j in range(fi, _followers.size()):
		(_followers[j]["node"] as Node2D).visible = false


# =========================================================================
# Zones（MOD-B 節點）接線
# =========================================================================

func _wire_zones() -> void:
	for z in $Zones.get_children():
		if z is ExitZone:
			world_state.register_gated_zone(z)
			z.exit_denied.connect(_show_prompt)
		elif z is TriggerZone:
			world_state.register_gated_zone(z)
			z.cutscene_requested.connect(_on_trigger_cutscene)
			z.message_requested.connect(_show_prompt)
		elif z is PickupZone:
			world_state.register_gated_zone(z)
			z.picked_up.connect(_on_picked_up)
			_attach_zone_sprite(z)
		elif z is BossMark:
			_attach_zone_sprite(z)


## Pickup/BossMark 的視覺貼圖：由生成器寫在節點 metadata（tex/w/h），這裡掛成 zone 的子節點，
## 跟著 zone 腳本自己的 visible 開關一起顯示/隱藏。
func _attach_zone_sprite(z: Node2D) -> void:
	if not z.has_meta("tex"):
		return
	var tex_path := str(z.get_meta("tex"))
	if not ResourceLoader.exists(tex_path):
		_missing_textures += 1
		return
	var tex: Texture2D = load(tex_path)
	if tex == null:
		_missing_textures += 1
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	var w := float(z.get_meta("w", 0.0))
	var h := float(z.get_meta("h", 0.0))
	if w > 0.0 and h > 0.0:
		spr.scale = Vector2(w / float(tex.get_width()), h / float(tex.get_height()))
	z.add_child(spr)


func _on_trigger_cutscene(cut_id: String) -> void:
	DialogueSystem.play_cutscene(cut_id)


func _on_picked_up(msg: String, _sfx_name: String) -> void:
	if msg != "":
		_show_prompt(msg)
	# sfx：尚無音訊 autoload，暫略（見檔頭「本次範圍外」）。


# =========================================================================
# 進場交握（scene_router.gd 檔頭「場景端交握約定」）
# =========================================================================

## 掛載選單與完整 HUD（隊伍血條/金幣/目標/[M]選單提示）。以程式建立而非 .tscn ext_resource，
## 見 `_menu`/`_hud_full` 欄位註解。世界的 `$HUD/Prompt`（互動提示）是另一個節點，兩者互不影響。
func _setup_ui() -> void:
	if ResourceLoader.exists("res://scenes/ui/menu_root.tscn"):
		var menu: Node = load("res://scenes/ui/menu_root.tscn").instantiate()
		menu.name = "MenuRootRuntime"
		add_child(menu)
		if menu.has_method("set_scene_id"):
			menu.set_scene_id(scene_id)
		_menu = menu
	if ResourceLoader.exists("res://scenes/ui/hud.tscn"):
		var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
		hud.name = "HudFull"
		add_child(hud)
		if hud.has_method("set_scene_id"):
			hud.set_scene_id(scene_id)
		_hud_full = hud


func _apply_entry_state() -> void:
	var res: String = GameState.result
	if SceneRouter.should_use_return_position():
		_player.global_position = Vector2(GameState.return_x, GameState.return_y)
	else:
		var spn: String = GameState.spawn
		if spn != "" and spawns.has(spn):
			_player.global_position = spawns[spn]
	# 戰後劇情推進（對應 build_cq2.py L1435-1439；once 閘門由 play_cutscene 內建檢查）
	if res == "story" and scene_id == "Cave":
		DialogueSystem.play_cutscene("demon_post")
	if res == "win" and scene_id == "Mine" \
			and GameState.flag_get("ch2") == 2 and GameState.flag_get("c_mine_after") == 0:
		DialogueSystem.play_cutscene("mine_after")
	if res == "lose":
		_heal_all_party()
		DialogueSystem.play_defeat_narration()
	# 約定第 2 點：讀取完成後清空暫態欄位
	GameState.spawn = ""
	GameState.result = ""


func _play_enter_cutscenes() -> void:
	# CFG.cutOnEnter（build_cq2.py L1442-1448）：step 精確比對（未設 step＝不限），once 閘門由
	# DialogueSystem.play_cutscene() 統一檢查。
	for c in cut_on_enter:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var ok_step: bool = (not c.has("step")) or GameState.flag_get("step") == int(c["step"])
		if ok_step:
			DialogueSystem.play_cutscene(str(c["cut"]))


## 對應 healAll()（build_cq2.py L1375）＋ dialogue_system.gd `_heal_all()` 的同款已知限制：
## 不重算衍生屬性（MOD-F 職責），只信任既有 maxhp/maxmp 欄位。
func _heal_all_party() -> void:
	for m in GameState.party:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		if m.has("maxhp"):
			m["hp"] = m["maxhp"]
		if m.has("maxmp"):
			m["mp"] = m["maxmp"]


# =========================================================================
# 隨機遭遇（MOD-G）
# =========================================================================

func _setup_encounter_tracker() -> void:
	if enc_group == "":
		return
	_tracker = EncounterTracker.new()
	_tracker.player = _player
	_tracker.world_state = world_state
	_tracker.return_scene_id = scene_id
	_tracker.encounter_id = _resolve_encounter_group()
	_tracker.is_on_encounter_terrain = _is_enc_at
	add_child(_tracker)


## 對應 build_cq2.py L2341 `CFG.encGroup==="mine_step0"?(f.step===0?"tutorial":"mine"):CFG.encGroup`。
func _resolve_encounter_group() -> String:
	if enc_group == "mine_step0":
		return "tutorial" if GameState.flag_get("step") == 0 else "mine"
	return enc_group


## encounter_tracker.gd 檔頭「ENC 地形判定介面」接法 (b)：CFG.ENC 字串陣列逐字元查表。
func _is_enc_at(pos: Vector2) -> bool:
	var tx := int(pos.x / TS)
	var ty := int(pos.y / TS)
	if ty < 0 or ty >= enc_rows.size() or tx < 0 or tx >= enc_rows[ty].length():
		return false
	return enc_rows[ty][tx] == "1"


# =========================================================================
# 過場的 battle/transfer side-effect（DialogueSystem 發訊號，場景補上場景端資訊）
# =========================================================================

func _on_cut_battle(encounter_id: String) -> void:
	SceneRouter.start_battle(
		encounter_id, scene_id, _player.global_position.x, _player.global_position.y
	)


func _on_cut_transfer(to_scene: String, spawn_id: String) -> void:
	SceneRouter.go_to(to_scene, spawn_id)


# =========================================================================
# 互動（NPC 對話／寶箱）與提示列
# =========================================================================

func _update_interactions(delta: float) -> void:
	if _prompt_timer > 0.0:
		_prompt_timer -= delta
		if _prompt_timer <= 0.0:
			$HUD/Prompt.text = ""
	if not world_state.is_gate_open():
		if _prompt_timer <= 0.0:
			$HUD/Prompt.text = ""
		return
	# release gate：對話剛結束後，等 ui_accept 放開才解除，避免同一次按壓結束又立刻重開對話。
	if _accept_release_needed and not Input.is_action_pressed("ui_accept"):
		_accept_release_needed = false
	var near_npc := _find_near_npc()
	var near_chest := _find_near_chest()
	if not _accept_release_needed and InputBridge.is_action_hit("ui_accept"):
		if near_npc != "":
			DialogueSystem.open_npc_dialogue(near_npc)
			return
		if not near_chest.is_empty():
			_open_chest(near_chest)
			return
	if _prompt_timer <= 0.0:
		if near_npc != "":
			$HUD/Prompt.text = "空白鍵：交談"
		elif not near_chest.is_empty():
			$HUD/Prompt.text = "空白鍵：開啟寶箱"
		else:
			$HUD/Prompt.text = ""


func _find_near_npc() -> String:
	# 對應 WORLD_JS L1712-1719：逐一比距離，取第一個 < TALK_RADIUS。
	for e in _npc_nodes:
		var node: Node2D = e["node"]
		if not node.visible:
			continue
		if node.position.distance_to(_player.global_position) < TALK_RADIUS:
			return e["id"]
	return ""


func _find_near_chest() -> Dictionary:
	# 對應 WORLD_JS L1738-1744：玩家腳點 tile 與寶箱 tile 的 Chebyshev 距離 <= 1。
	var ptx := int(_player.global_position.x / TS)
	var pty := int(_player.global_position.y / TS)
	for c in _chest_nodes:
		if GameState.chest_is_opened(c["id"]):
			continue
		if absi(ptx - int(c["tx"])) <= 1 and absi(pty - int(c["ty"])) <= 1:
			return c
	return {}


## 對應 openChest()（build_cq2.py L1608-1618）＋ grantChestLoot()/chestLootDesc()（L1590-1607）。
func _open_chest(c: Dictionary) -> void:
	var cid: String = c["id"]
	if not GameState.chest_mark_opened(cid):
		return
	var chest_def: ChestDef = ContentDB.get_chest(cid)
	var parts: Array[String] = []
	if chest_def != null:
		for l in chest_def.loot:
			if typeof(l) != TYPE_DICTIONARY:
				continue
			match str(l.get("type", "")):
				"gold":
					var amount := int(l.get("amount", 0))
					GameState.gold += amount
					parts.append("%d 金幣" % amount)
				"item":
					var iid := str(l.get("id", ""))
					var n := int(l.get("count", 1))
					GameState.inv_add(iid, n)
					var item_def: ItemDef = ContentDB.get_item(iid)
					var nm := item_def.display_name if item_def != null else iid
					parts.append(nm + ("×%d" % n if n > 1 else ""))
				"eq":
					var eid := str(l.get("id", ""))
					GameState.eq_inv.append(eid)
					var eq_def: EquipmentDef = ContentDB.get_equipment(eid)
					parts.append(eq_def.display_name if eq_def != null else eid)
	if c["sprite"] != null and ResourceLoader.exists(_chest_tex(true)):
		(c["sprite"] as Sprite2D).texture = load(_chest_tex(true))
	DialogueSystem.show_message("寶箱", PackedStringArray(["打開了寶箱！獲得 %s。" % "、".join(parts)]))
	SaveManager.save_game()


func _show_prompt(msg: String) -> void:
	$HUD/Prompt.text = msg
	_prompt_timer = PROMPT_SECONDS
