extends Node
## AudioManager — autoload（註冊名稱 "AudioManager"，見 ../project.godot [autoload]）。
##
## 取代 GDevelop 端的兩個音訊介面（build_cq2.py）：
##   - `sfx(n)`（L1297）：一次性音效，不循環、音量 100 → 這裡 sfx()，用 player 池支援同時多聲部
##     （原版戰鬥常一次 `sfx("atk.wav");sfx("hurt.wav")` 疊播，見 L3148）。
##   - channel-1 音樂（L1546-1547 等）：循環、音量 65 → 這裡 play_bgm()，單一 player。
##
## 音量換算：GDevelop 的 volume 是 0~100 線性百分比，Godot 的 volume_db 是分貝，用 linear_to_db 轉。
## BGM 語意調整：原版每次進場景 stopSoundsOnStartup 後重播（會重頭），這裡改成「同一首續播、換首才切」
## ——避免 Forest→Forest2 同為 bgm_forest 時被打斷，比原版更順（見 play_bgm 註解）。

const SFX_DIR := "res://assets/sfx/"
const BGM_DIR := "res://assets/bgm/"
const SFX_POOL_SIZE := 8

var _bgm_player: AudioStreamPlayer
var _bgm_overlay: AudioStreamPlayer   # 與 _bgm_player 同時播放的一次性疊加層（戰鬥開場）
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _current_bgm := ""
var _scene_bgm := ""       # 最後一首「場景」循環曲（不含戰鬥等 transient 覆蓋）；被打斷後用來接回
var _oneshot_active := false   # 目前播的是一次性短曲（勝利 fanfare）→ 播完自動接回 _scene_bgm
var _cache: Dictionary = {}   ## 檔名 → AudioStream，避免重複 load


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "Bgm"
	_bgm_player.volume_db = linear_to_db(0.65)   # 原版 music volume 65
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)

	_bgm_overlay = AudioStreamPlayer.new()
	_bgm_overlay.name = "BgmOverlay"
	_bgm_overlay.volume_db = linear_to_db(0.65)
	add_child(_bgm_overlay)

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		_sfx_players.append(p)


## 一次性音效。sfx_name 為檔名（含副檔名，例 "atk.wav"），對應原版 sfx(n)。
func sfx(sfx_name: String) -> void:
	if sfx_name == "":
		return
	var stream := _load(SFX_DIR + sfx_name)
	if stream == null:
		return
	var player := _free_sfx_player()
	player.stream = stream
	player.play()


## 回傳音效檔長度（秒）；查不到檔回 0。供戰鬥「音效先完、再扣血」計時用。
func sfx_length(sfx_name: String) -> float:
	if sfx_name == "":
		return 0.0
	var stream := _load(SFX_DIR + sfx_name)
	return stream.get_length() if stream != null else 0.0


## 循環背景音樂。bgm_name 為檔名（例 "bgm_town.mp3"）；空字串＝維持現況不動（部分場景資料留空）。
## 已在播同一首則不重頭（對應原版 `if(!mu||!mu.playing())` 的「別重播」語意，但更嚴謹地比對曲目）。
##
## `transient=true`＝這首只是暫時覆蓋（戰鬥 BGM），**不更新「場景循環曲」記憶**，離開後才能自動接回。
##
## 空字串的語意（2026-07-28 補強）：原本是「維持現況不動」，但 `bgm` 留空的場景（EF/STR/NFR 等靠上一個
## 場景續播）在戰鬥後會變全靜音——戰鬥 BGM 與勝利短曲把循環曲停掉了，沒人再起曲。改成：沒在播就接回
## 最後一首場景循環曲。（勝利短曲還在播的情況由 _on_bgm_finished() 接手。）
func play_bgm(bgm_name: String, transient: bool = false) -> void:
	var name_ := bgm_name
	if name_ == "":
		if _bgm_player.playing or _scene_bgm == "":
			return
		name_ = _scene_bgm
	if not transient:
		_scene_bgm = name_
	if name_ == _current_bgm and _bgm_player.playing:
		return
	_oneshot_active = false
	var stream := _load(BGM_DIR + name_)
	if stream == null:
		return
	# mp3/ogg 以 loop 旗標循環（本專案 BGM 皆 mp3）。
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
	_bgm_overlay.stop()   # 切換主 BGM＝停掉戰鬥開場疊加層（離開戰鬥時清乾淨）
	_current_bgm = name_
	_bgm_player.stream = stream
	_bgm_player.play()


## 播放 bgm/ 底下的一次性短曲（戰鬥勝利 fanfare 等）：停掉目前循環 BGM、播一次「不循環」。
## 播完自動接回最後一首場景循環曲（見 _on_bgm_finished）；中途若有 play_bgm() 進來則由它接手。
func play_bgm_oneshot(bgm_name: String) -> void:
	if bgm_name == "":
		return
	var stream := _load(BGM_DIR + bgm_name)
	if stream == null:
		return
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = false
	_bgm_overlay.stop()   # 停掉戰鬥開場疊加層（快速戰鬥時開場層可能還沒播完）
	_current_bgm = ""   # 清空：讓下一個場景的 play_bgm 一定會重新起曲，不會被誤判成「同曲續播」
	_oneshot_active = true
	_bgm_player.stream = stream
	_bgm_player.play()


## 疊加播放一次性 BGM 層（不循環），與 play_bgm 的循環曲「同時」發聲（獨立 player）。
## 用於戰鬥開場：bgm_battle 循環 ＋ bgm_battle_opening 一次性疊播。切換或停止主 BGM 時一併停止本層。
func play_bgm_overlay(bgm_name: String) -> void:
	if bgm_name == "":
		return
	var stream := _load(BGM_DIR + bgm_name)
	if stream == null:
		return
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = false
	_bgm_overlay.stream = stream
	_bgm_overlay.play()


func stop_bgm() -> void:
	_bgm_player.stop()
	_bgm_overlay.stop()
	_current_bgm = ""
	_scene_bgm = ""        # 明確要求靜音＝不要再自動接回
	_oneshot_active = false


## 一次性短曲（勝利 fanfare）播完 → 接回被它打斷的場景循環曲。
## 這是「戰鬥後場景音樂自動續播」的關鍵：`bgm` 留空的場景不會自己起曲，靠這裡接。
func _on_bgm_finished() -> void:
	if not _oneshot_active:
		return
	_oneshot_active = false
	if _scene_bgm != "":
		play_bgm(_scene_bgm)


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: 找不到音訊檔 %s" % path)
		return null
	var stream := load(path) as AudioStream
	_cache[path] = stream
	return stream


## 取一個沒在播的 player；全忙則輪替最舊的（round-robin），支援同時多聲部疊播。
func _free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	var pick := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	return pick
