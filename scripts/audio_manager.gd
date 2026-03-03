extends Node
# audio_manager.gd
# Hệ thống âm thanh sinh procedurally - không cần file .wav/.mp3 bên ngoài.
# Autoloaded as "Audio" trong project.godot

const SAMPLE_RATE := 22050
const POOL_SIZE   := 4   # số AudioStreamPlayer đồng thời mỗi loại sound

# Pool SFX: name -> Array[AudioStreamPlayer]
var _sfx: Dictionary = {}

# ── MUSIC ─────────────────────────────────────────────────────────────────────
var _music_player:  AudioStreamPlayer = null
var _music_pb:      AudioStreamGeneratorPlayback = null
var _music_t:       float = 0.0
var _chord_beat:    float = 0.0
var _arp_beat:      float = 0.0
var _chord_idx:     int   = 0
var _arp_idx:       int   = 0

const MUSIC_RATE := 22050.0
const MUSIC_VOL_DB := -10.0

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
	_build_sfx_library()
	_setup_music()

# ── PUBLIC API ───────────────────────────────────────────────────────────────
func play(name: String, vol_db: float = 0.0) -> void:
	if not PlayerData.sound_enabled: return
	var arr: Array = _sfx.get(name, [])
	if arr.is_empty(): return
	for p: AudioStreamPlayer in arr:
		if not p.playing:
			p.volume_db = vol_db
			p.play()
			return
	# Tất cả busy → dùng đầu tiên
	(arr[0] as AudioStreamPlayer).stop()
	(arr[0] as AudioStreamPlayer).volume_db = vol_db
	(arr[0] as AudioStreamPlayer).play()

## Gọi sau khi toggle sound trong settings để cập nhật trạng thái nhạc
func refresh_music() -> void:
	if _music_player == null: return
	if PlayerData.sound_enabled:
		if not _music_player.playing:
			_music_player.play()
			_music_pb = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback
	else:
		_music_player.stop()
		_music_pb = null

# ── MUSIC PROCESS ─────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if _music_pb == null or not PlayerData.sound_enabled: return
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
		["shoot",          1300.0,  900.0,  0.07,  "sine",  0.28],
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
	]
	for d in defs:
		var stream := _make_wav(float(d[1]), float(d[2]), float(d[3]), String(d[4]), float(d[5]))
		var arr: Array = []
		for _i in range(POOL_SIZE):
			var p := AudioStreamPlayer.new()
			p.stream = stream
			p.bus = "Master"
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

# ── MUSIC SETUP ───────────────────────────────────────────────────────────────
func _setup_music() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate      = MUSIC_RATE
	gen.buffer_length = 0.15
	_music_player = AudioStreamPlayer.new()
	_music_player.stream    = gen
	_music_player.volume_db = MUSIC_VOL_DB
	_music_player.bus       = "Master"
	add_child(_music_player)
	if PlayerData.sound_enabled:
		_music_player.play()
		_music_pb = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback
