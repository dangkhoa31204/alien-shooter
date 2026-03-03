extends CharacterBody2D
# boss.gd — Boss với 3 phase, đổi phase theo % máu

signal died   # phát khi boss chết, wave_manager lắng nghe

const BULLET_SCENE   = preload("res://scenes/bullet.tscn")
const HEART_SCENE    = preload("res://scenes/heart.tscn")
const POWERUP_SCENE  = preload("res://scenes/powerup.tscn")
const ENEMY_SCENE    = preload("res://scenes/enemy.tscn")

# Tính cách chiến đấu mỗi boss:
# 0 Warship     — xả đạn liên tục, không lao, không gọi quân
# 1 Interceptor — lách thường xuyên, bắn ít
# 2 Dreadnought — gọi quân, bắn chậm, không lao
# 3 Carrier     — gọi quân liên tục, bắn vừa, không lao
# 4 Mothership  — tất cả: bắn + lao + gọi quân
const BOSS_CAN_CHARGE: Array = [false, true, false, false, true]

# ── CONFIG ────────────────────────────────────────────────────────────────────
var max_hp: int   = 300
var hp: int       = 300
var speed: float  = 120.0
var score_value: int = 5000
var boss_type:   int   = 0   # 0–4, gán từ wave_manager

# ── HÌNH DẠNG & MÀU 5 BOSS ───────────────────────────────────────────────────
# Polygon per boss_type (center at origin, up = negative Y)
const BOSS_POLYGONS: Array = [
	# 0 Warship — dàn rộng, cánh dày
	[Vector2(0,-35), Vector2(22,-20), Vector2(42,-8),  Vector2(30,4),
	 Vector2(18,14), Vector2(10,30),  Vector2(-10,30), Vector2(-18,14),
	 Vector2(-30,4), Vector2(-42,-8), Vector2(-22,-20)],
	# 1 Interceptor — mũi nhọn dài, thân hẹp
	[Vector2(0,-44), Vector2(10,-26), Vector2(16,-8),   Vector2(14,10),
	 Vector2(8,28),  Vector2(0,36),   Vector2(-8,28),   Vector2(-14,10),
	 Vector2(-16,-8), Vector2(-10,-26)],
	# 2 Dreadnought — siêu rộng, giáp dày
	[Vector2(0,-28), Vector2(14,-22), Vector2(30,-18),  Vector2(50,-8),
	 Vector2(54,4),  Vector2(46,16),  Vector2(28,26),   Vector2(14,32),
	 Vector2(-14,32), Vector2(-28,26), Vector2(-46,16), Vector2(-54,4),
	 Vector2(-50,-8), Vector2(-30,-18), Vector2(-14,-22)],
	# 3 Carrier — ngang dẹt, cánh cong
	[Vector2(0,-22), Vector2(12,-18), Vector2(20,-12),  Vector2(40,-6),
	 Vector2(44,4),  Vector2(34,16),  Vector2(16,24),   Vector2(-16,24),
	 Vector2(-34,16), Vector2(-44,4), Vector2(-40,-6),  Vector2(-20,-12),
	 Vector2(-12,-18)],
	# 4 Mothership — bát giác lớn đối xứng
	[Vector2(0,-46), Vector2(22,-36), Vector2(40,-18),  Vector2(46,0),
	 Vector2(40,18), Vector2(22,36),  Vector2(0,42),    Vector2(-22,36),
	 Vector2(-40,18), Vector2(-46,0), Vector2(-40,-18), Vector2(-22,-36)],
]

# Loại đạn đặc trưng cho từng boss (NORMAL=0,ELECTRIC=1,FIRE=2,ICE=3,EXPLOSIVE=4)
const BOSS_BULLET_TYPES: Array = [2, 1, 3, 4, 0]  # Warship=FIRE, Interceptor=ELECTRIC, Dreadnought=ICE, Carrier=EXPLOSIVE, Mothership=NORMAL

# Màu [phase1, phase2, phase3] cho từng boss_type
const BOSS_COLORS: Array = [
	[Color(0.8,  0.2,  0.8),  Color(1.0, 0.5,  0.0),  Color(1.0, 0.1,  0.1)],  # 0 Warship
	[Color(0.1,  0.6,  1.0),  Color(0.0, 1.0,  0.9),  Color(0.1, 1.0,  0.4)],  # 1 Interceptor
	[Color(0.55, 0.12, 0.08), Color(0.85,0.28, 0.0),  Color(1.0, 0.05, 0.05)], # 2 Dreadnought
	[Color(0.6,  0.55, 0.05), Color(0.9, 0.85, 0.0),  Color(1.0, 1.0,  0.2)],  # 3 Carrier
	[Color(0.65, 0.65, 0.8),  Color(0.9, 0.3,  0.95), Color(1.0, 0.05, 0.85)], # 4 Mothership
]

# Phase thresholds (theo % máu còn lại)
const PHASE2_HP: float = 0.66  # dưới 66% → phase 2
const PHASE3_HP: float = 0.33  # dưới 33% → phase 3

enum Phase { ONE, TWO, THREE }
var current_phase: Phase = Phase.ONE

var time_elapsed: float = 0.0
var move_dir: float = 1.0
var _is_dying: bool = false
var _special_cd: float = 5.0   # countdown đến chiêu đặc trưng

# ── CHARGE ────────────────────────────────────────────────────────────────────
var _charge_cd:        float = 8.0    # giây đến lần lao tới tiếp theo
var _charging:         bool  = false
var _charge_dir:       Vector2 = Vector2.ZERO
var _charge_remaining: float = 0.0
const CHARGE_SPEED:    float = 580.0
const CHARGE_DURATION: float = 0.65

@onready var shoot_timer: Timer = $ShootTimer
@onready var sprite: Polygon2D  = $Sprite
var _dr: Node2D = null

func _clear_dr() -> void:
	if is_instance_valid(_dr): _dr.queue_free()
	_dr = Node2D.new(); _dr.z_index = 1
	sprite.add_child(_dr)

func _dp(pts: Array, col: Color) -> void:
	var p2d := Polygon2D.new()
	var pv := PackedVector2Array()
	for v in pts: pv.append(v)
	p2d.polygon = pv; p2d.color = col
	_dr.add_child(p2d)

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	shoot_timer.timeout.connect(_on_shoot_timer)
	_apply_boss_type()
	_apply_phase()
	# Khởi tạo charge_cd theo kiểu boss
	match boss_type:
		1: _charge_cd = 3.0   # Interceptor lách ngay sau phase 1
		4: _charge_cd = 8.0
		_: _charge_cd = 999.0  # không bao giờ lao

# ── BOSS TYPE SETUP ───────────────────────────────────────────────────────────
func _apply_boss_type() -> void:
	if sprite:
		var pts: Array = BOSS_POLYGONS[boss_type]
		var packed := PackedVector2Array()
		for p in pts:
			packed.append(p)
		sprite.polygon = packed
		_add_type_details()

func _add_type_details() -> void:
	_clear_dr()
	match boss_type:
		0: # Warship — màu tím/đỏ, dàn rộng
			_dp([Vector2(-8,-30),Vector2(8,-30),Vector2(10,-18),Vector2(0,-12),Vector2(-10,-18)],
				Color(1.0, 0.65, 0.0))             # cầu chỉ huy vàng
			_dp([Vector2(-8,24),Vector2(8,24),Vector2(8,31),Vector2(-8,31)],
				Color(1.0, 0.45, 0.0, 0.9))        # động cơ sau
			_dp([Vector2(-32,0),Vector2(-26,-4),Vector2(-24,0),Vector2(-26,4)],
				Color(1.0, 0.1, 0.9, 0.9))         # khẩu đại bác trái
			_dp([Vector2(32,0),Vector2(26,-4),Vector2(24,0),Vector2(26,4)],
				Color(1.0, 0.1, 0.9, 0.9))         # khẩu đại bác phải
			_dp([Vector2(-40,-4),Vector2(-36,-8),Vector2(-34,-4),Vector2(-36,0)],
				Color(0.9, 0.1, 0.8, 0.75))        # súng cánh ngoài trái
			_dp([Vector2(40,-4),Vector2(36,-8),Vector2(34,-4),Vector2(36,0)],
				Color(0.9, 0.1, 0.8, 0.75))        # súng cánh ngoài phải
		1: # Interceptor — xanh cán, thân hẹp
			_dp([Vector2(-4,-36),Vector2(4,-36),Vector2(6,-22),Vector2(0,-16),Vector2(-6,-22)],
				Color(0.0, 0.9, 1.0))              # cockpit cyan sáng
			_dp([Vector2(-2,-10),Vector2(2,-10),Vector2(2,18),Vector2(-2,18)],
				Color(0.0, 0.8, 1.0, 0.55))        # vạch thân
			_dp([Vector2(-12,22),Vector2(-8,22),Vector2(-8,36),Vector2(-12,36)],
				Color(0.0, 1.0, 0.5, 0.95))        # động cơ trái
			_dp([Vector2(8,22),Vector2(12,22),Vector2(12,36),Vector2(8,36)],
				Color(0.0, 1.0, 0.5, 0.95))        # động cơ phải
			_dp([Vector2(-14,6),Vector2(-10,2),Vector2(-8,6),Vector2(-10,10)],
				Color(0.3, 1.0, 0.6))              # pod trái
			_dp([Vector2(10,2),Vector2(14,6),Vector2(10,10),Vector2(8,6)],
				Color(0.3, 1.0, 0.6))              # pod phải
		2: # Dreadnought — cam-đỏ, siêu rộng
			_dp([Vector2(-6,-20),Vector2(6,-20),Vector2(8,-10),Vector2(0,-6),Vector2(-8,-10)],
				Color(1.0, 0.55, 0.0))             # cầu chỉ huy
			_dp([Vector2(-10,26),Vector2(10,26),Vector2(10,33),Vector2(-10,33)],
				Color(1.0, 0.5, 0.0, 0.9))         # động cơ sau
			_dp([Vector2(-44,4),Vector2(-38,0),Vector2(-36,4),Vector2(-38,8)],
				Color(1.0, 0.35, 0.0))             # turret trái
			_dp([Vector2(44,4),Vector2(38,0),Vector2(36,4),Vector2(38,8)],
				Color(1.0, 0.35, 0.0))             # turret phải
			_dp([Vector2(-28,-6),Vector2(-20,-10),Vector2(-18,-2),Vector2(-24,2)],
				Color(0.75, 0.2, 0.05, 0.8))       # giáp cánh trái
			_dp([Vector2(28,-6),Vector2(20,-10),Vector2(18,-2),Vector2(24,2)],
				Color(0.75, 0.2, 0.05, 0.8))       # giáp cánh phải
		3: # Carrier — vàng, nằm ngang
			_dp([Vector2(-6,-16),Vector2(6,-16),Vector2(8,-8),Vector2(0,-4),Vector2(-8,-8)],
				Color(0.8, 0.75, 0.0))             # cầu chỉ huy
			_dp([Vector2(-28,10),Vector2(-20,10),Vector2(-20,20),Vector2(-28,20)],
				Color(0.0, 0.5, 0.95, 0.9))        # khoang bay trái
			_dp([Vector2(-8,12),Vector2(8,12),Vector2(8,22),Vector2(-8,22)],
				Color(0.0, 0.55, 1.0, 0.9))        # khoang bay giữa
			_dp([Vector2(20,10),Vector2(28,10),Vector2(28,20),Vector2(20,20)],
				Color(0.0, 0.5, 0.95, 0.9))        # khoang bay phải
			_dp([Vector2(-40,0),Vector2(-36,-4),Vector2(-34,0),Vector2(-36,4)],
				Color(1.0, 0.85, 0.0))             # động cơ trái
			_dp([Vector2(40,0),Vector2(36,-4),Vector2(34,0),Vector2(36,4)],
				Color(1.0, 0.85, 0.0))             # động cơ phải
		4: # Mothership — bát giác lớn
			_dp([Vector2(0,-28),Vector2(14,-22),Vector2(24,-10),Vector2(28,0),
				 Vector2(24,10),Vector2(14,22),Vector2(0,26),Vector2(-14,22),
				 Vector2(-24,10),Vector2(-28,0),Vector2(-24,-10),Vector2(-14,-22)],
				Color(0.9, 0.2, 1.0, 0.4))         # vòng nội
			_dp([Vector2(0,-10),Vector2(8,-5),Vector2(8,5),Vector2(0,10),Vector2(-8,5),Vector2(-8,-5)],
				Color(1.0, 0.0, 0.85))             # lõi trung tâm
			_dp([Vector2(-4,-40),Vector2(4,-40),Vector2(4,-32),Vector2(-4,-32)],
				Color(0.8, 0.3, 1.0))              # pod đỉnh
			_dp([Vector2(-40,-6),Vector2(-32,-6),Vector2(-32,6),Vector2(-40,6)],
				Color(0.75, 0.25, 1.0))            # pod trái
			_dp([Vector2(32,-6),Vector2(40,-6),Vector2(40,6),Vector2(32,6)],
				Color(0.75, 0.25, 1.0))            # pod phải
			_dp([Vector2(-6,36),Vector2(6,36),Vector2(6,44),Vector2(-6,44)],
				Color(0.0, 1.0, 0.9, 0.85))        # tia kéo bên dưới

func _physics_process(delta: float) -> void:
	time_elapsed += delta
	# Charge override
	if _charging:
		_charge_remaining -= delta
		velocity = _charge_dir * CHARGE_SPEED * (1.0 + float(boss_type) * 0.08)
		move_and_slide()
		# Kiểm tra chạm player
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if col.get_collider() and (col.get_collider() as Node).is_in_group("player"):
				(col.get_collider() as Node).take_damage(2)
		if _charge_remaining <= 0.0:
			_charging = false
			_charge_cd = randf_range(6.0, 10.0)
			shoot_timer.start()
			# Khôi phục màu boss sau khi lao
			if is_instance_valid(sprite):
				sprite.color = (BOSS_COLORS[boss_type] as Array)[0]
		return
	_special_cd -= delta
	if _special_cd <= 0.0:
		_special_cd = 5.5 - float(current_phase) * 1.2
		_do_special()
	_charge_cd -= delta
	if _charge_cd <= 0.0 and current_phase != Phase.ONE \
			and BOSS_CAN_CHARGE[boss_type]:
		_start_charge()
	_update_phase()
	_move(delta)

# ── PHASE MANAGEMENT ──────────────────────────────────────────────────────────
func _update_phase() -> void:
	var ratio := float(hp) / float(max_hp)
	var new_phase: Phase

	if ratio > PHASE2_HP:
		new_phase = Phase.ONE
	elif ratio > PHASE3_HP:
		new_phase = Phase.TWO
	else:
		new_phase = Phase.THREE

	if new_phase != current_phase:
		current_phase = new_phase
		_apply_phase()

func _apply_phase() -> void:
	var colors: Array = BOSS_COLORS[boss_type]
	# Shoot timer per boss_type per phase
	# Warship: nhanh | Interceptor: chậm | Dreadnought: chậm | Carrier: vừa | Mothership: vừa
	const SHOOT_TIMES: Array = [
		[0.7,  0.38, 0.22],   # 0 Warship — xả đạn rất nhanh
		[3.5,  2.4,  1.6 ],   # 1 Interceptor — hiếm khi bắn
		[2.8,  2.0,  1.3 ],   # 2 Dreadnought — chậm, gọi quân là chính
		[2.2,  1.6,  1.0 ],   # 3 Carrier — bắn vừa + gọi quân
		[1.2,  0.7,  0.45],   # 4 Mothership — all-rounder
	]
	var phase_idx: int
	match current_phase:
		Phase.ONE:   phase_idx = 0; if sprite: sprite.color = colors[0]
		Phase.TWO:   phase_idx = 1; if sprite: sprite.color = colors[1]
		Phase.THREE: phase_idx = 2; if sprite: sprite.color = colors[2]
		_:           phase_idx = 0
	shoot_timer.wait_time = (SHOOT_TIMES[boss_type] as Array)[phase_idx]
	shoot_timer.start()

# ── MOVEMENT (dispatch by boss_type) ─────────────────────────────────────────
func _move(_delta: float) -> void:
	match boss_type:
		0: _move_warship()
		1: _move_interceptor()
		2: _move_dreadnought()
		3: _move_carrier()
		4: _move_mothership()

# 0 Warship — ngang bình thường + sin Y nhẹ
func _move_warship() -> void:
	var vp_w := get_viewport_rect().size.x
	velocity.x = move_dir * speed
	velocity.y = sin(time_elapsed * 1.2) * 30.0
	move_and_slide()
	if position.x > vp_w - 60.0: move_dir = -1.0
	elif position.x < 60.0:      move_dir = 1.0

# 1 Interceptor — rất nhanh, lắc Y mạnh
func _move_interceptor() -> void:
	var vp_w := get_viewport_rect().size.x
	velocity.x = move_dir * speed * 1.7
	velocity.y = sin(time_elapsed * 2.8) * 55.0
	move_and_slide()
	if position.x > vp_w - 50.0: move_dir = -1.0
	elif position.x < 50.0:      move_dir = 1.0

# 2 Dreadnought — rất chậm, gần như không lắc Y
func _move_dreadnought() -> void:
	var vp_w := get_viewport_rect().size.x
	velocity.x = move_dir * speed * 0.4
	velocity.y = sin(time_elapsed * 0.5) * 10.0
	move_and_slide()
	if position.x > vp_w - 80.0: move_dir = -1.0
	elif position.x < 80.0:      move_dir = 1.0

# 3 Carrier — vẽ hình số 8 ngang màn hình
func _move_carrier() -> void:
	var vp := get_viewport_rect().size
	position.x = vp.x * 0.5 + sin(time_elapsed * 0.7) * (vp.x * 0.36)
	position.y = 115.0 + sin(time_elapsed * 1.4) * 38.0

# 4 Mothership — vòng tròn chậm, uy nghi
func _move_mothership() -> void:
	var vp := get_viewport_rect().size
	position.x = vp.x * 0.5 + cos(time_elapsed * 0.4) * (vp.x * 0.3)
	position.y = 130.0 + sin(time_elapsed * 0.4) * 44.0

# ── SHOOT PATTERNS ────────────────────────────────────────────────────────────
func _on_shoot_timer() -> void:
	match current_phase:
		Phase.ONE:   _phase1_attack()
		Phase.TWO:   _phase2_attack()
		Phase.THREE: _phase3_attack()

# ── PHASE 1 (> 66% HP): phụ thuộc boss_type ─────────────────────────────────
var _p1_step: int = 0
func _phase1_attack() -> void:
	if boss_type == 0:       # Warship
		match _p1_step % 3:
			0: _shoot_straight()
			1: _shoot_aimed()
			2: _shoot_cross()
	elif boss_type == 1:     # Interceptor — burst ngắm
		if _p1_step % 2 == 0: _shoot_aimed()
		else:                  _shoot_aimed_spread()
	elif boss_type == 2:     # Dreadnought — vòng tròn nặng
		match _p1_step % 3:
			0: _shoot_circle(8)
			1: _shoot_straight()
			2: _shoot_double_ring()
	elif boss_type == 3:     # Carrier — xoắn ốc + tản
		match _p1_step % 3:
			0: _shoot_aimed_spread()
			1: _shoot_straight()
			2: _shoot_spiral()
	else:                    # Mothership — full pattern
		match _p1_step % 4:
			0: _shoot_circle(10)
			1: _shoot_aimed()
			2: _shoot_spiral()
			3: _shoot_cross()
	_p1_step += 1

# ── PHASE 2 (33–66% HP): 4 kiểu ────────────────────────────────────────────────
var _p2_step: int = 0
func _phase2_attack() -> void:
	match _p2_step % 4:
		0: _shoot_circle(12)         # vòng tròn 12 đạn
		1: _shoot_double_ring()      # 2 vòng xen kẽ
		2: _shoot_aimed_spread()     # ngắm + 2 đạn lệch hai bên
		3: _shoot_spiral()           # xoắn ốc bắn từ từ
	_p2_step += 1

# ── PHASE 3 (< 33% HP): tổng hợp tất cả ─────────────────────────────────────
var _p3_step: int = 0
func _phase3_attack() -> void:
	match _p3_step % 6:
		0: _shoot_circle(16)
		1: _shoot_aimed_burst(6)     # nhóm đạn vào player
		2: _shoot_double_ring()
		3: _shoot_cross()
		4: _shoot_spiral()
		5: _shoot_aimed_spread()
	_p3_step += 1

# ── CÁC PATTERN ───────────────────────────────────────────────────────────────
func _shoot_straight() -> void:
	for i in range(-1, 2):
		_spawn_bullet(Vector2(i * 0.3, 1.0).normalized())

func _shoot_aimed() -> void:
	var p := _get_player_dir()
	if p != Vector2.ZERO:
		_spawn_bullet(p)

func _shoot_cross() -> void:
	for angle_deg in [0, 90, 180, 270]:
		var a := deg_to_rad(float(angle_deg))
		_spawn_bullet(Vector2(cos(a), sin(a)))

func _shoot_aimed_spread() -> void:
	var p := _get_player_dir()
	if p == Vector2.ZERO: p = Vector2.DOWN
	for offset in [-20.0, 0.0, 20.0]:
		_spawn_bullet(p.rotated(deg_to_rad(offset)))

func _shoot_aimed_burst(count: int) -> void:
	var p := _get_player_dir()
	if p == Vector2.ZERO: p = Vector2.DOWN
	for i in range(count):
		var spread := randf_range(-0.18, 0.18)
		_spawn_bullet(p.rotated(spread))

func _shoot_circle(count: int = 12) -> void:
	for i in range(count):
		var angle := TAU * i / count
		_spawn_bullet(Vector2(cos(angle), sin(angle)))

func _shoot_double_ring() -> void:
	var count := 10
	for i in range(count):
		var a1 := TAU * i / count
		var a2 := TAU * (i + 0.5) / count
		_spawn_bullet(Vector2(cos(a1), sin(a1)))
		_spawn_bullet(Vector2(cos(a2), sin(a2)))

func _shoot_spiral() -> void:
	# Bắn 8 đạn rải đều nhưng mỗi đạn lệch thêm một góc tăng dần
	var base_angle := float(Time.get_ticks_msec()) * 0.002
	for i in range(8):
		var a := base_angle + TAU * i / 8.0
		_spawn_bullet(Vector2(cos(a), sin(a)))

func _get_player_dir() -> Vector2:
	var p := get_tree().current_scene.get_node_or_null("Player")
	if p == null or not is_instance_valid(p):
		return Vector2.ZERO
	return (p.global_position - global_position).normalized()

func _spawn_bullet(dir: Vector2, btype: int = -1, spd: float = 280.0) -> void:
	var bullet = BULLET_SCENE.instantiate()
	bullet.global_position  = global_position
	bullet.direction        = dir
	bullet.speed            = spd
	bullet.is_enemy_bullet  = true
	bullet.is_boss_bullet   = true
	bullet.bullet_type      = BOSS_BULLET_TYPES[boss_type] if btype < 0 else btype
	var container = get_tree().current_scene.get_node_or_null("BulletContainer")
	if container:
		container.add_child(bullet)

# ── CHIÊU ĐẶC TRƯNG MỖI BOSS ─────────────────────────────────────────────────
func _do_special() -> void:
	if _is_dying or _charging: return
	match boss_type:
		0: _special_warship_barrage()        # xả đạn tạp trung
		1: _special_interceptor_dash()       # teleport rồi bắn chéo
		2: _special_dreadnought_summon()     # gọi quân + quet đạn ICE
		3: _special_carrier_summon()         # gọi quân + tản đạn
		4: _special_mothership_nova()        # nova + gọi quân

# 0 Warship: 6 đạn FIRE nhắm liên tiếp nhanh
func _special_warship_barrage() -> void:
	for i in range(6):
		if not is_instance_valid(self): return
		var d := _get_player_dir()
		if d == Vector2.ZERO: d = Vector2.DOWN
		_spawn_bullet(d.rotated(randf_range(-0.12, 0.12)), 2, 320.0)
		await get_tree().create_timer(0.09).timeout

# 1 Interceptor: teleport đến X của player, rồi bắn 4 hướng chéo ELECTRIC
func _special_interceptor_dash() -> void:
	var p := get_tree().current_scene.get_node_or_null("Player")
	if p and is_instance_valid(p):
		position.x = clamp((p as Node2D).global_position.x, 50.0, get_viewport_rect().size.x - 50.0)
	for angle_deg in [45, 135, 225, 315]:
		var a := deg_to_rad(float(angle_deg))
		_spawn_bullet(Vector2(cos(a), sin(a)), 1, 300.0)

# 2 Dreadnought: gọi 3 enemy + quét đạn ICE để cản đường player
func _special_dreadnought_summon() -> void:
	_summon_enemies(3)
	await get_tree().create_timer(0.6).timeout
	if _is_dying or not is_instance_valid(self): return
	for i in range(9):
		var frac := float(i) / 8.0
		var angle: float = lerp(-PI * 0.45, PI * 0.45, frac)
		_spawn_bullet(Vector2(sin(angle), cos(angle)), 3, 100.0)

# 3 Carrier: gọi 5 enemy, bắn tản nộ EXPLOSIVE
func _special_carrier_summon() -> void:
	_summon_enemies(5)
	await get_tree().create_timer(0.4).timeout
	if _is_dying or not is_instance_valid(self): return
	var d := _get_player_dir()
	if d == Vector2.ZERO: d = Vector2.DOWN
	for offset in [-0.55, -0.25, 0.0, 0.25, 0.55]:
		_spawn_bullet(d.rotated(offset), 4, 300.0)

# 2 Dreadnought (cũ — giữ để dùng trong phase 3 nếu muốn)
func _special_dreadnought_sweep() -> void:
	for i in range(13):
		var frac := float(i) / 12.0
		var angle: float = lerp(-PI * 0.5, PI * 0.5, frac)
		_spawn_bullet(Vector2(sin(angle), cos(angle)), 3, 110.0)

# 3 Carrier (cũ)
func _special_carrier_drones() -> void:
	var d := _get_player_dir()
	if d == Vector2.ZERO: d = Vector2.DOWN
	for offset in [-0.5, -0.18, 0.18, 0.5]:
		_spawn_bullet(d.rotated(offset), 4, 360.0)

# 4 Mothership: vòng 24 đạn + 3 đạn ngắm + gọi 2 enemy
func _special_mothership_nova() -> void:
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		_spawn_bullet(Vector2(cos(angle), sin(angle)), 0, 200.0)
	var d := _get_player_dir()
	if d != Vector2.ZERO:
		for offset in [-0.25, 0.0, 0.25]:
			_spawn_bullet(d.rotated(offset), 0, 340.0)
	_summon_enemies(2)

# ── GỌI QUÂN (Dreadnought / Carrier / Mothership) ─────────────────────────────────
func _summon_enemies(count: int) -> void:
	var spawner := get_tree().current_scene.get_node_or_null("EnemySpawner")
	var wm      := get_tree().current_scene.get_node_or_null("WaveManager")
	if spawner == null: return
	var vp := get_viewport_rect().size
	for i in range(count):
		var enemy = ENEMY_SCENE.instantiate()
		enemy.enemy_type = randi() % 3
		enemy.base_speed = 80.0 + randf() * 40.0
		enemy.hp = 2
		enemy.max_hp = 2
		enemy.score_value = 100
		var half := count / 2
		var offset_x := (float(i) - float(half)) * (vp.x * 0.18)
		enemy.global_position = Vector2(
			clamp(global_position.x + offset_x, 60.0, vp.x - 60.0),
			global_position.y + randf_range(60.0, 120.0)
		)
		if wm and wm.has_method("_on_enemy_died"):
			enemy.died.connect(wm._on_enemy_died)
			wm.enemies_alive += 1
		spawner.add_child(enemy)

# ── CHARGE (lao thẳng về phía player) ────────────────────────────────────────
func _start_charge() -> void:
	if _is_dying: return
	var p := get_tree().current_scene.get_node_or_null("Player")
	if p == null or not is_instance_valid(p): return
	_charge_dir = (p.global_position - global_position).normalized()
	_charge_remaining = CHARGE_DURATION
	_charging = true
	shoot_timer.stop()
	if is_instance_valid(sprite):
		sprite.color = Color.WHITE
	# Interceptor rạp tới lần nữa nhanh hơn
	_charge_cd = randf_range(3.0, 5.5) if boss_type == 1 else randf_range(6.0, 10.0)

# ── HEALTH ────────────────────────────────────────────────────────────────────
func take_damage(dmg: int = 1) -> void:
	if _is_dying:
		return
	hp -= dmg
	var main = get_tree().current_scene
	if main and main.has_method("update_boss_hp"):
		main.update_boss_hp(max(hp, 0))
	if hp <= 0:
		_die()

func _die() -> void:
	if _is_dying:
		return
	_is_dying = true
	var main = get_tree().current_scene
	if main and main.has_method("add_score"):
		main.add_score(score_value)
		main.hide_boss_hp()
	if main and main.has_method("screen_shake"):
		main.screen_shake(18.0, 0.65)
	_drop_boss_reward()
	emit_signal("died")
	queue_free()

func _drop_boss_reward() -> void:
	var container := get_tree().current_scene.get_node_or_null("BulletContainer")
	if container == null: return
	# Luôn rơi 2 trái tim
	for i in range(2):
		var heart = HEART_SCENE.instantiate()
		heart.global_position = global_position + Vector2(randf_range(-50.0, 50.0), randf_range(-20.0, 20.0))
		container.add_child(heart)
	# Powerup đặc trưng theo boss_type
	# 0=Warship→FIRE, 1=Interceptor→ELECTRIC, 2=Dreadnought→ICE, 3=Carrier→EXPLOSIVE, 4=Mothership→UPGRADE
	var reward_types: Array = [2, 1, 3, 4, 6]
	var powerup = POWERUP_SCENE.instantiate()
	powerup.global_position = global_position
	powerup.powerup_type = reward_types[boss_type]
	container.add_child(powerup)
	# Cũng rơi thêm 1 UPGRADE nếu phase 3
	if current_phase == Phase.THREE:
		var bonus = POWERUP_SCENE.instantiate()
		bonus.global_position = global_position + Vector2(30.0, 0.0)
		bonus.powerup_type = 6
		container.add_child(bonus)
