extends Node
# audio_manager.gd
# Hệ thống âm thanh sinh procedurally - không cần file .wav/.mp3 bên ngoài.
# Autoloaded as "Audio" trong project.godot

const SAMPLE_RATE := 22050
const POOL_SIZE   := 4   # số AudioStreamPlayer đồng thời mỗi loại sound

# Pool SFX: name -> Array[AudioStreamPlayer]
var _sfx: Dictionary = {}

# ── MENU MUSIC (MP3) ──────────────────────────────────────────────────────────
var _menu_music_player: AudioStreamPlayer = null
const MENU_MUSIC_PATH := "res://assets/audio/lac_troi.mp3"

# MP3 SFX: tên → đường dẫn
const MP3_SFX_DEFS: Dictionary = {
	"gun_fire":       "res://assets/audio/gun_fire.mp3",
	"punch":          "res://assets/audio/punch_sound.mp3",
	"ak47_fire":  		"res://assets/audio/ak47_fire.mp3",
	"m4_fire": "res://assets/audio/m4_fire.wav",
	"collected_item": "res://assets/audio/collected_item.mp3",
	"b40":               "res://assets/audio/b40.mp3",
	"aa_sound":           "res://assets/audio/aa_sound.mp3",
	"bomber_drop_sound":  "res://assets/audio/bomber_drop_sound.mp3",
	"bomber_explode":     "res://assets/audio/bomber_explode.mp3",
	"reload_ak47":       "res://assets/audio/reload_ak47.mp3",
	"footstep_grass_1": "res://assets/audio/walk-on-grass-1.mp3",
	"footstep_grass_2": "res://assets/audio/walk-on-grass-2.mp3",
	"footstep_grass_3": "res://assets/audio/walk-on-grass-3.mp3",
	"footstep_road_1": "res://assets/audio/step-1.mp3",
	"footstep_road_2": "res://assets/audio/step-2.mp3",
	"footstep_road_3": "res://assets/audio/step-3.mp3",
}
var _mp3_sfx_loaded := false

# ── MUSIC ─────────────────────────────────────────────────────────────────────
var _music_player:  AudioStreamPlayer = null
const INGAME_MUSIC_PATH  := "" # Đã xóa nhạc nền các màn chơi
const DIED_MUSIC_PATH    := "res://assets/audio/died_music.mp3"
const STAGE5_MUSIC_PATH  := "res://assets/audio/victory _music.mp3"
const VICTORY_MUSIC_PATH := "res://assets/audio/victory _music.mp3"
var _music_pb:      AudioStreamGeneratorPlayback = null
var _music_t:       float = 0.0
var _chord_beat:    float = 0.0
var _arp_beat:      float = 0.0
var _chord_idx:     int   = 0
var _arp_idx:       int   = 0

const MUSIC_RATE := 22050.0
const MUSIC_VOL_DB := 0.0

# Hợp âm không gian: Am → F → C → G, 2s/hợp âm
const _CHORDS: Array = [
	[110.0, 130.8, 164.8],   # Am
	[87.3,  110.0, 138.6],   # F
	[130.8, 164.8, 196.0],   # C
	[98.0,  123.5, 146.8],   # G
]

# ────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Load saved settings early so music_enabled/sfx_enabled are correct
	PlayerData.load_data()
	_build_sfx_library()
	_setup_music()
	_setup_menu_music()
	# Load MP3 SFX sau 2 frame để resource cache kịp đăng ký
	call_deferred("_deferred_build_mp3_sfx")

func _deferred_build_mp3_sfx() -> void:
	await get_tree().process_frame
	_build_mp3_sfx_library()
	_mp3_sfx_loaded = true

# ── PUBLIC API ───────────────────────────────────────────────────────────────
func play(sound_name: String, vol_db: float = 0.0) -> void:
	# Only play SFX when global sound and SFX are enabled
	if not PlayerData.sfx_enabled: return
	# Lần đầu gọi sau khi scene chính load xong — thử nạp MP3 nếu chưa có
	if not _mp3_sfx_loaded and sound_name in MP3_SFX_DEFS:
		_build_mp3_sfx_library()
		_mp3_sfx_loaded = true
	var arr: Array = _sfx.get(sound_name, [])
	if arr.is_empty(): return
	for p: AudioStreamPlayer in arr:
		if not p.playing:
			# Combine caller volume_db with SFX master volume
			var sfx_db := linear_to_db(maxf(0.0001, PlayerData.sfx_volume))
			p.volume_db = vol_db + sfx_db
			p.play()
			return
	# Tất cả busy → dùng đầu tiên
	(arr[0] as AudioStreamPlayer).stop()
	var sfx_db := linear_to_db(maxf(0.0001, PlayerData.sfx_volume))
	(arr[0] as AudioStreamPlayer).volume_db = vol_db + sfx_db
	(arr[0] as AudioStreamPlayer).play()

## Play a random footstep SFX for a given surface (default: "grass").
## Chooses one of the configured footstep files, applies a small random pitch
## variation and plays it using the existing SFX pools. Respects PlayerData.sfx_enabled.
func play_footstep(surface: String = "grass", vol_db: float = 0.0) -> void:
	if not PlayerData.sfx_enabled: return
	var variants := {
		"grass": ["footstep_grass_1", "footstep_grass_2", "footstep_grass_3"],
		"road": ["footstep_road_1", "footstep_road_2", "footstep_road_3"],
	}
	var list: Array = variants.get(surface, variants["grass"])
	if list.size() == 0: return
	var name: String = list[randi() % list.size()]
	# ensure MP3 SFX loaded
	if not _mp3_sfx_loaded and name in MP3_SFX_DEFS:
		_build_mp3_sfx_library()
		_mp3_sfx_loaded = true
	var arr: Array = _sfx.get(name, [])
	if arr.is_empty(): return
	var pitch := 0.95 + randf() * 0.1 # 0.95..1.05
	for p in arr:
		if not p.playing:
			p.pitch_scale = pitch
			var sfx_db := linear_to_db(maxf(0.0001, PlayerData.sfx_volume))
			p.volume_db = vol_db + sfx_db
			p.play()
			return
	# all busy -> reuse first
	(arr[0] as AudioStreamPlayer).stop()
	(arr[0] as AudioStreamPlayer).pitch_scale = pitch
	var sfx_db2 := linear_to_db(maxf(0.0001, PlayerData.sfx_volume))
	(arr[0] as AudioStreamPlayer).volume_db = vol_db + sfx_db2
	(arr[0] as AudioStreamPlayer).play()

## Gọi sau khi toggle sound trong settings để cập nhật trạng thái nhạc
func refresh_music() -> void:
	if _music_player == null: return
	if PlayerData.music_enabled:
		# Do not start in-game procedural music if menu MP3 is playing
		if _menu_music_player != null and _menu_music_player.playing:
			return
		if not _music_player.playing:
			_music_player.play()
			_music_pb = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback
	else:
		_music_player.stop()
		_music_pb = null

func play_ingame_music() -> void:
	# Không phát nhạc nền màn chơi
	if _music_player == null: return
	_music_player.stop()

func play_stage5_music() -> void:
	# Phát nhạc chiến thắng màn 5
	if _music_player == null: return
	if not PlayerData.music_enabled: return
	if _menu_music_player != null and _menu_music_player.playing:
		_menu_music_player.stop()
	if _set_music_stream_from_path(STAGE5_MUSIC_PATH, false):
		_music_player.stop()
		_music_player.play()
		_music_pb = null

func play_victory_music() -> void:
	# Phát nhạc chiến thắng
	if _music_player == null: return
	if not PlayerData.music_enabled: return
	if _menu_music_player != null and _menu_music_player.playing:
		_menu_music_player.stop()
	if _set_music_stream_from_path(VICTORY_MUSIC_PATH, false):
		_music_player.stop()
		_music_player.play()
		_music_pb = null

func play_died_music() -> void:
	# Phát nhạc thất bại
	if _music_player == null: return
	if not PlayerData.music_enabled: return
	if _menu_music_player != null and _menu_music_player.playing:
		_menu_music_player.stop()
	if _set_music_stream_from_path(DIED_MUSIC_PATH, false):
		_music_player.stop()
		_music_player.play()
		_music_pb = null

## Phát nhạc nền menu từ file MP3 (lac_troi.mp3)
## Tắt nhạc procedural chỉ khi MP3 load thành công
func play_menu_music() -> void:
	if _menu_music_player == null: return
	if _menu_music_player.playing: return  # Tránh restart khi quay lại menu
	# Thử load MP3 — không cần ResourceLoader.exists() vì có thể trả về false khi import chưa valid
	if PlayerData.music_enabled:
		var stream: AudioStreamMP3 = null
		if ResourceLoader.exists(MENU_MUSIC_PATH):
			stream = load(MENU_MUSIC_PATH) as AudioStreamMP3
		if stream != null:
			stream.loop = true
			if _music_player != null:
				_music_player.stop()
				_music_pb = null
			_menu_music_player.stream = stream
			_menu_music_player.play()
			return
	# Fallback: MP3 chưa có hoặc load lỗi → giữ nhạc procedural đang chạy
	# Nếu procedural bị tắt vì lý do nào đó, khởi động lại
	if PlayerData.music_enabled and _music_player != null and not _music_player.playing:
		_music_player.play()
		call_deferred("_grab_music_playback")

## Dừng nhạc menu (gọi khi vào màn chơi)
func stop_menu_music() -> void:
	if _menu_music_player != null:
		_menu_music_player.stop()
	play_ingame_music()

## Dừng toàn bộ nhạc (cả nhạc game lẫn nhạc menu)
func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()
	_music_pb = null
	if _menu_music_player != null:
		_menu_music_player.stop()

## Gọi sau khi toggle sound để cập nhật nhạc menu đang phát
func refresh_menu_music() -> void:
	if _menu_music_player == null: return
	if PlayerData.music_enabled:
		if not _menu_music_player.playing:
			# Load stream if not yet loaded
			if _menu_music_player.stream == null:
				if ResourceLoader.exists(MENU_MUSIC_PATH):
					var stream = load(MENU_MUSIC_PATH) as AudioStreamMP3
					if stream != null:
						stream.loop = true
						_menu_music_player.stream = stream
			if _menu_music_player.stream != null:
				# Ensure in-game music is stopped before playing menu MP3
				if _music_player != null and _music_player.playing:
					_music_player.stop()
					_music_pb = null
				_menu_music_player.play()
	else:
		_menu_music_player.stop()

# ── MUSIC PROCESS ─────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if not PlayerData.music_enabled: return
	# Thử lấy lại playback nếu chưa có (recovery)
	if _music_pb == null and _music_player != null and _music_player.playing:
		_music_pb = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _music_pb == null: return
	var frames := _music_pb.get_frames_available()
	if frames <= 0: return
	var dt := 1.0 / MUSIC_RATE
	for _i in range(frames):
		_music_t    += dt
		_chord_beat += dt
		_arp_beat   += dt
		if _chord_beat >= 2.0:
			_chord_beat = fmod(_chord_beat, 2.0)
			_chord_idx  = (_chord_idx + 1) % _CHORDS.size()
		var chord: Array = _CHORDS[_chord_idx]
		if _arp_beat >= 0.10:
			_arp_beat = fmod(_arp_beat, 0.10)
			_arp_idx  = (_arp_idx + 1) % chord.size()
		var s := _gen_music_sample(chord)
		_music_pb.push_frame(Vector2(s, s))

func _gen_music_sample(chord: Array) -> float:
	var val := 0.0
	# Pad: các nốt hợp âm rung nhẹ tạo cảm giác không gian
	var swell := 0.55 + 0.45 * sin(TAU * 0.12 * _music_t)
	for note: float in chord:
		val += sin(TAU * note * _music_t) * 0.048 * swell

	# Bass pulse theo nhịp (0.5s/nhịp)
	var beat_frac := fmod(_music_t * 2.0, 1.0)
	var bass_env  := maxf(0.0, 1.0 - beat_frac * 5.0)
	val += sin(TAU * (float(chord[0]) * 0.5) * _music_t) * bass_env * 0.22

	# Sparkle: nốt cao theo arpeggio
	var arp_note := float(chord[_arp_idx]) * 2.0
	var arp_env  := maxf(0.0, 1.0 - (_arp_beat / 0.10) * 7.0)
	val += sin(TAU * arp_note * _music_t) * arp_env * 0.07

	# Shimmer: nhiễu rất nhẹ để tạo texture
	val += randf_range(-0.004, 0.004)

	return clamp(val, -1.0, 1.0)

# ── SFX LIBRARY ───────────────────────────────────────────────────────────────
func _build_sfx_library() -> void:
	# [name, freq_start, freq_end, duration, wave, volume]
	# freq_end != 0 → sweep từ freq_start → freq_end
	var defs: Array = [
		["shoot",          1300.0,  900.0,  0.07,  "sine",  0.07],
		["gun_fire",        900.0,  400.0,  0.18,  "noise", 0.72],   # fallback nếu MP3 chưa load
		["collected_item", 1200.0, 1800.0,  0.25,  "sine",  0.60],   # fallback
		["enemy_shoot",    550.0,   350.0,  0.06,  "sine",  0.18],
		["hit",            350.0,   180.0,  0.09,  "noise", 0.45],
		["explosion",      80.0,    30.0,   0.55,  "noise", 0.85],
		["player_hurt",    300.0,   120.0,  0.28,  "sine",  0.72],
		["coin",           1400.0, 1900.0,  0.14,  "sine",  0.50],
		["powerup",        380.0,  1000.0,  0.38,  "sine",  0.58],
		["level_complete", 660.0,  1100.0,  0.65,  "sine",  0.68],
		["game_over",      440.0,   180.0,  0.90,  "sine",  0.65],
		["buy",            700.0,  1050.0,  0.18,  "sine",  0.52],
		["boss_appear",    75.0,    45.0,   0.80,  "noise", 0.88],
		["button_click",   850.0,   700.0,  0.05,  "sine",  0.28],
		["skill_use",      700.0,  1600.0,  0.22,  "sine",  0.58],
		["dodge",         1100.0,  1600.0,  0.10,  "sine",  0.30],
		["boss_shoot",    180.0,    80.0,   0.12,  "noise", 0.70],
		["asteroid_hit",  250.0,   100.0,   0.10,  "noise", 0.55],
		["special_collect",900.0, 1800.0,   0.25,  "sine",  0.65],
		["b40",            85.0,    40.0,   0.60,  "noise", 0.88], # Procedural fallback for B40
	]
	for d in defs:
		var stream := _make_wav(float(d[1]), float(d[2]), float(d[3]), String(d[4]), float(d[5]))
		var arr: Array = []
		for _i in range(POOL_SIZE):
			var p := AudioStreamPlayer.new()
			p.stream = stream
			p.bus = "SFX"
			add_child(p)
			arr.append(p)
		_sfx[String(d[0])] = arr

func _make_wav(freq_start: float, freq_end: float, duration: float,
			   wave: String, vol: float) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var data    := PackedByteArray()
	data.resize(samples * 2)
	var sweep    := freq_end != 0.0 and not is_equal_approx(freq_start, freq_end)
	var phase    := 0.0             # dùng phase accumulator để tránh click artifacts
	var attack   := minf(0.01, duration * 0.08)
	var release  := duration * 0.40

	for i in range(samples):
		var t    := float(i) / float(SAMPLE_RATE)
		var frac := float(i) / float(maxf(1.0, float(samples - 1)))
		var freq := freq_start + (freq_end - freq_start) * frac if sweep else freq_start
		phase += TAU * freq / float(SAMPLE_RATE)
		var v := 0.0
		match wave:
			"sine":
				v = sin(phase)
			"noise":
				v = randf_range(-1.0, 1.0) * (1.0 - frac * 0.55)
				v += sin(phase) * 0.30   # tone dưới noise để không chói
		# Envelope
		var env := 1.0
		if t < attack:
			env = t / attack
		elif t > duration - release:
			env = (duration - t) / maxf(0.001, release)
		env = maxf(0.0, env)
		v = clamp(v * env * vol, -1.0, 1.0)
		var s := int(v * 32767.0)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format   = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo   = false
	stream.mix_rate = SAMPLE_RATE
	stream.data     = data
	return stream

# ── MP3 SFX LIBRARY ──────────────────────────────────────────────────────────
func _build_mp3_sfx_library() -> void:
	for sfx_name: String in MP3_SFX_DEFS:
		var path: String = MP3_SFX_DEFS[sfx_name]
		# Robust check: try with and without the 's' in assets
		if not ResourceLoader.exists(path):
			var alt_path = path.replace("res://assets/", "res://asset/")
			if ResourceLoader.exists(alt_path):
				path = alt_path
		
		var stream := load(path) as AudioStream
		if stream == null: 
			push_warning("Audio: Failed to load SFX at path: " + path)
			continue
		
		# If it's a new sound (not procedural), create a new pool
		# If it already exists (procedural), replace existing stream in pool
		if not _sfx.has(sfx_name):
			var arr: Array = []
			for _i in range(POOL_SIZE):
				var p := AudioStreamPlayer.new()
				p.stream = stream
				p.bus = "SFX"
				add_child(p)
				arr.append(p)
			_sfx[sfx_name] = arr
		else:
			# Replace procedural dummy with real audio asset if loaded
			for p: AudioStreamPlayer in _sfx[sfx_name]:
				p.stream = stream

# ── MENU MUSIC SETUP ─────────────────────────────────────────────────────────
func _setup_menu_music() -> void:
	_menu_music_player = AudioStreamPlayer.new()
	var music_bus_idx := AudioServer.get_bus_index("Music")
	if music_bus_idx >= 0:
		_menu_music_player.bus = "Music"
	else:
		_menu_music_player.bus = "Master"
	_menu_music_player.volume_db = 3.0
	add_child(_menu_music_player)

# ── MUSIC SETUP ───────────────────────────────────────────────────────────────
func _setup_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = MUSIC_VOL_DB
	var music_bus_idx := AudioServer.get_bus_index("Music")
	if music_bus_idx >= 0:
		_music_player.bus = "Music"
	else:
		_music_player.bus = "Master"
	
	if not _set_music_stream_from_path(INGAME_MUSIC_PATH, true):
		_music_player.stream = null # Không tạo procedural music nữa

	add_child(_music_player)
	if PlayerData.music_enabled:
		_music_player.play()
		call_deferred("_grab_music_playback")

func _grab_music_playback() -> void:
	if _music_player != null and _music_player.playing:
		_music_pb = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _set_music_stream_from_path(path: String, looped: bool) -> bool:
	if _music_player == null: return false
	if not ResourceLoader.exists(path): return false
	var stream := load(path) as AudioStreamMP3
	if stream == null: return false
	stream.loop = looped
	_music_player.stream = stream
	return true
