extends Node2D
# hit_effect.gd — Hiệu ứng va chạm đạn với enemy
# Tự huỷ sau khi animation xong. Không cần scene riêng, spawn inline từ bullet.gd.

# 1=ELECTRIC  2=FIRE  3=ICE  4=EXPLOSIVE
var effect_type: int = 0
var _t: float = 0.0          # 0→1 tiến trình animation
var _duration: float = 0.45  # giây

func _ready() -> void:
	z_index = 10

func _process(delta: float) -> void:
	_t += delta / _duration
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var p := 1.0 - _t   # ease-out: 1→0
	match effect_type:
		1: _draw_electric(p)
		2: _draw_fire(p)
		3: _draw_ice(p)
		4: _draw_explosive(p)

# ── ELECTRIC — tia sét ziczac tỏa ra ─────────────────────────────────────────
func _draw_electric(p: float) -> void:
	var col := Color(0.4, 0.6, 1.0, p)
	var col2 := Color(1.0, 1.0, 0.3, p * 0.7)
	var ray_count := 6
	for i in range(ray_count):
		var base_ang: float = TAU * float(i) / float(ray_count)
		var ray_len: float = (28.0 + float(i % 3) * 10.0) * (1.0 - _t * 0.4)
		var pts: PackedVector2Array = PackedVector2Array()
		pts.append(Vector2.ZERO)
		var seg := 4
		for s in range(1, seg + 1):
			var frac := float(s) / float(seg)
			var jitter: float = sin(float(s) * 7.3 + float(i) * 2.1 + _t * 30.0) * 7.0 * (1.0 - frac)
			var ang: float = base_ang + jitter * 0.08
			pts.append(Vector2(cos(ang), sin(ang)) * ray_len * frac + Vector2(sin(float(s) * 3.1 + float(i)), cos(float(s) * 2.7)) * jitter)
		draw_polyline(pts, col2 if i % 2 == 0 else col, 2.0)
	# glow trung tâm
	draw_circle(Vector2.ZERO, 6.0 * p, Color(0.7, 0.8, 1.0, p * 0.6))

# ── FIRE — đốm lửa bay lên rơi xuống ─────────────────────────────────────────
func _draw_fire(p: float) -> void:
	var spark_count := 10
	for i in range(spark_count):
		var seed_f: float = float(i) * 1.618
		var ang: float = fmod(seed_f * 2.399, TAU)
		var spd: float = 20.0 + fmod(seed_f * 13.0, 28.0)
		var px: float = cos(ang) * spd * _t
		var py: float = sin(ang) * spd * _t - 18.0 * _t * _t   # vọt lên rồi rơi
		var r: float = (2.5 + fmod(seed_f, 2.0)) * p
		var heat: float = 1.0 - float(i % 3) * 0.22
		var col := Color(1.0, heat * 0.55, 0.0, p)
		draw_circle(Vector2(px, py), r, col)
	# lõi sáng
	draw_circle(Vector2.ZERO, 9.0 * p, Color(1.0, 0.9, 0.2, p * 0.8))

# ── ICE — mảnh pha lê lấp lánh tỏa ra ───────────────────────────────────────
func _draw_ice(p: float) -> void:
	var shard_count := 8
	for i in range(shard_count):
		var ang: float = TAU * float(i) / float(shard_count)
		var dist: float = 26.0 * _t
		var cx: float = cos(ang) * dist
		var cy: float = sin(ang) * dist
		# hình thoi nhỏ (4 điểm)
		var sz: float = (5.0 - _t * 3.5) * p
		var perp: float = ang + PI * 0.5
		var pts := PackedVector2Array([
			Vector2(cx + cos(ang) * sz * 2.0,   cy + sin(ang) * sz * 2.0),
			Vector2(cx + cos(perp) * sz,         cy + sin(perp) * sz),
			Vector2(cx - cos(ang) * sz,          cy - sin(ang) * sz),
			Vector2(cx - cos(perp) * sz,         cy - sin(perp) * sz),
		])
		var bright: float = 0.7 + float(i % 3) * 0.1
		draw_colored_polygon(pts, Color(bright, 0.96, 1.0, p))
	# sparkle trung tâm
	draw_circle(Vector2.ZERO, 8.0 * p, Color(0.85, 0.97, 1.0, p * 0.9))
	# ring thêm
	draw_arc(Vector2.ZERO, 14.0 * (0.5 + _t * 0.5), 0.0, TAU, 20, Color(0.5, 0.95, 1.0, p * 0.5), 1.5)

# ── EXPLOSIVE — vòng xung kích mở rộng + mảnh văng ──────────────────────────
func _draw_explosive(p: float) -> void:
	# Vòng xung kích nở rộng rất nhanh
	var ring_r: float = 55.0 * _t
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 32, Color(1.0, 0.65, 0.1, p * 0.85), 3.5)
	draw_arc(Vector2.ZERO, ring_r * 0.7, 0.0, TAU, 24, Color(1.0, 0.9, 0.3, p * 0.5), 2.0)
	# Mảnh vụn văng ra
	var frag_count := 10
	for i in range(frag_count):
		var ang: float = TAU * float(i) / float(frag_count) + _t * 0.5
		var d: float = 42.0 * _t
		var fx: float = cos(ang) * d
		var fy: float = sin(ang) * d
		var fs: float = (3.5 - _t * 2.5) * p
		draw_circle(Vector2(fx, fy), maxf(fs, 0.5), Color(1.0, 0.4, 0.0, p))
	# lõi sáng trắng
	draw_circle(Vector2.ZERO, 12.0 * p * (1.0 - _t * 0.8), Color(1.0, 1.0, 0.8, p))
