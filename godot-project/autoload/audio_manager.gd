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
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _current_bgm := ""
var _cache: Dictionary = {}   ## 檔名 → AudioStream，避免重複 load


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "Bgm"
	_bgm_player.volume_db = linear_to_db(0.65)   # 原版 music volume 65
	add_child(_bgm_player)

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
func play_bgm(bgm_name: String) -> void:
	if bgm_name == "":
		return
	if bgm_name == _current_bgm and _bgm_player.playing:
		return
	var stream := _load(BGM_DIR + bgm_name)
	if stream == null:
		return
	# mp3/ogg 以 loop 旗標循環（本專案 BGM 皆 mp3）。
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
	_current_bgm = bgm_name
	_bgm_player.stream = stream
	_bgm_player.play()


## 播放 bgm/ 底下的一次性短曲（戰鬥勝利 fanfare 等）：停掉目前循環 BGM、播一次「不循環」。
## 播完保持靜默、不自動接回任何曲；下一次 play_bgm()（例如按繼續返回世界場景）會接手。
func play_bgm_oneshot(bgm_name: String) -> void:
	if bgm_name == "":
		return
	var stream := _load(BGM_DIR + bgm_name)
	if stream == null:
		return
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = false
	_current_bgm = ""   # 清空：讓下一個場景的 play_bgm 一定會重新起曲，不會被誤判成「同曲續播」
	_bgm_player.stream = stream
	_bgm_player.play()


func stop_bgm() -> void:
	_bgm_player.stop()
	_current_bgm = ""


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
