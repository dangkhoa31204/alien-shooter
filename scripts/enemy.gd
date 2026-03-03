extends CharacterBody2D
# enemy.gd — Movement logic. AI decision được tách sang EnemyAI node.

signal died   # phát khi enemy chết, wave_manager lắng nghe

const BULLET_SCENE  = preload("res://scenes/bullet.tscn")
const POWERUP_SCENE = preload("res://scenes/powerup.tscn")
const HEART_SCENE   = preload("res://scenes/heart.tscn")

const DROP_CHANCE: float  = 0.04   # 4% rơi powerup (giảm từ 7%)
const HEART_CHANCE: float = 0.025  # 2.5% rơi tim (giảm từ 4%)
const POWERUP_COUNT: int  = 7    # các loại powerup (0–6)

var base_speed: float = 150.0
var hp: int = 3
var max_hp: int = 3
var score_value: int = 10
var time_elapsed: float = 0.0

# Di chuyển ngang qua lại
var stationary: bool = true   # giữ lại cho wave_manager set
var _move_dir: float = 1.0
var _move_speed: float = 60.0   # tốc độ ngang

# ── SHOOT ─────────────────────────────────────────────────────────────────────
var shoot_interval: float = 2.5   # giây giữa mỗi lần bắn (wave_manager set)
var _shoot_timer: float   = 0.0   # đếm ngược đến lần bắn tiếp theo

# Cooldown để enemy không spam damage khi đứng trên player
var _contact_cooldown: float = 0.0
var _is_dying: bool = false
var _is_spawning: bool = false  # khoá bắn trong lúc fly-in vào vị trí

# ── FLY-IN khi spawn ─────────────────────────────────────────────────
var _fly_in_active: bool    = false
var _fly_in_target: Vector2 = Vector2.ZERO
const FLY_IN_SPEED: float   = 420.0

# ── HIỆU ỨNG ĐẠN ─────────────────────────────────────────────────────────────
var _burn_timer: float  = 0.0   # đạn lửa: tổng thời gian còn cháy
var _burn_tick:  float  = 0.0   # đếm ngược đến lần tick thiệt hại tiếp
var _freeze_timer: float = 0.0  # đạn băng: thời gian bị đóng băng
var _saved_move_speed: float = -1.0  # tốc độ gốc trước khi đóng băng

# Di chuyển theo kiểu — gán từ wave_manager
# 0=HORIZONTAL  1=ZIGZAG  2=PENDULUM  3=STEP  4=STRAFE
var move_pattern: int = 0
var attack_tier:  int = 0  # 0..4 — kiểu bắn tăng dần theo wave
var _move_time:   float = 0.0
var _step_timer:  float = 0.0  # cho pattern STEP

# Kiểu hiển thị — gán từ wave_manager
# 0=Scout UFO  1=Fighter  2=Bomber
var enemy_type: int = 0
var _base_color: Color = Color(1.0, 0.25, 0.1)

const ENEMY_POLYGONS: Array = [
	# 0 Scout UFO — đĩa bay tròn
	[Vector2(0,-14), Vector2(10,-8),  Vector2(18,0),  Vector2(12,10),
	 Vector2(4,14),  Vector2(-4,14),  Vector2(-12,10), Vector2(-18,0), Vector2(-10,-8)],
	# 1 Fighter — góc cạnh, cánh sau rộng
	[Vector2(0,-16), Vector2(8,-6),   Vector2(16,2),  Vector2(18,10),
	 Vector2(10,16), Vector2(-10,16), Vector2(-18,10), Vector2(-16,2), Vector2(-8,-6)],
	# 2 Bomber — rộng dẹt, thân xủ xuống
	[Vector2(0,-10), Vector2(10,-8),  Vector2(20,-2), Vector2(22,8),
	 Vector2(14,14), Vector2(6,16),   Vector2(-6,16), Vector2(-14,14),
	 Vector2(-22,8), Vector2(-20,-2), Vector2(-10,-8)],
]

const ENEMY_BASE_COLORS: Array = [
	Color(1.0,  0.25, 0.1),   # 0 Scout: cam đỏ
	Color(0.2,  0.8,  1.0),   # 1 Fighter: xanh lám
	Color(0.55, 0.1,  0.9),   # 2 Bomber: tím
]

@onready var sprite: Polygon2D = $Sprite
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

func _dp_glow(radius: float, col: Color) -> void:
	var pts: Array = []
	for i in 18:
		var a := float(i) / 18.0 * TAU
		pts.append(Vector2(cos(a) * radius, sin(a) * radius))
	_dp(pts, col)

func _ready() -> void:
	add_to_group("enemy")
	_vp_size = get_viewport_rect().size
	_shoot_timer = randf_range(2.5, shoot_interval + 2.0)
	if is_instance_valid(sprite):
		var pts: Array = ENEMY_POLYGONS[enemy_type]
		var packed := PackedVector2Array()
		for p in pts: packed.append(p)
		sprite.polygon = packed
		_base_color = ENEMY_BASE_COLORS[enemy_type]
		sprite.color = _base_color
		_add_type_details()
	if has_node("EnemyAI"):
		$EnemyAI.setup(self)

# Gọi bởi wave_manager ngay sau add_child — enemy bay từ trên xuống vị trí hàng
func start_fly_in(target: Vector2) -> void:
	_fly_in_target = target
	_fly_in_active = true
	_is_spawning   = true

func _add_type_details() -> void:
	_clear_dr()
	# Soft glow aura behind body
	match enemy_type:
		0: _dp_glow(22.0, Color(1.00, 0.30, 0.10, 0.13))
		1: _dp_glow(25.0, Color(0.20, 0.80, 1.00, 0.12))
		2: _dp_glow(28.0, Color(0.65, 0.10, 1.00, 0.11))
	match enemy_type:
		0: # Scout UFO — đĩa bay cam-đỏ
			_dp([Vector2(-6,-10),Vector2(0,-22),Vector2(6,-10)],
				Color(0.4, 1.0, 0.4))              # chóp khính xanh lá
			_dp([Vector2(-4,-2),Vector2(4,-2),Vector2(4,4),Vector2(-4,4)],
				Color(1.0, 0.95, 0.1, 0.9))        # đèn trung tâm vàng
			_dp([Vector2(-3,8),Vector2(3,8),Vector2(3,14),Vector2(-3,14)],
				Color(0.0, 0.85, 1.0, 0.8))        # tia kéo xanh dương
			_dp([Vector2(-14,2),Vector2(-10,0),Vector2(-10,4)],
				Color(1.0, 0.6, 0.0, 0.7))         # đèn cánh trái
			_dp([Vector2(14,2),Vector2(10,0),Vector2(10,4)],
				Color(1.0, 0.6, 0.0, 0.7))         # đèn cánh phải
		1: # Fighter — xanh lám góc cạnh
			_dp([Vector2(-3,-10),Vector2(3,-10),Vector2(4,-4),Vector2(0,-1),Vector2(-4,-4)],
				Color(0.0, 0.25, 0.5))             # cockpit xanh đậm
			_dp([Vector2(-10,10),Vector2(-14,10),Vector2(-14,16),Vector2(-10,16)],
				Color(1.0, 0.5, 0.0, 0.9))         # động cơ trái
			_dp([Vector2(10,10),Vector2(14,10),Vector2(14,16),Vector2(10,16)],
				Color(1.0, 0.5, 0.0, 0.9))         # động cơ phải
			_dp([Vector2(-16,2),Vector2(-12,-2),Vector2(-10,0),Vector2(-12,4)],
				Color(0.5, 0.95, 1.0))             # soc cánh trái
			_dp([Vector2(16,2),Vector2(12,-2),Vector2(10,0),Vector2(12,4)],
				Color(0.5, 0.95, 1.0))             # soc cánh phải
		2: # Bomber — tím rộng
			_dp([Vector2(-3,-6),Vector2(3,-6),Vector2(3,-1),Vector2(-3,-1)],
				Color(0.9, 0.1, 1.0, 0.95))        # cockpit tím sáng
			_dp([Vector2(-6,8),Vector2(6,8),Vector2(6,16),Vector2(-6,16)],
				Color(0.2, 0.0, 0.4, 0.85))        # khoang bả
			_dp([Vector2(-20,4),Vector2(-16,4),Vector2(-16,10),Vector2(-20,10)],
				Color(0.85, 0.3, 1.0))             # động cơ trái
			_dp([Vector2(16,4),Vector2(20,4),Vector2(20,10),Vector2(16,10)],
				Color(0.85, 0.3, 1.0))             # động cơ phải
			_dp([Vector2(-2,1),Vector2(2,1),Vector2(2,7),Vector2(-2,7)],
				Color(1.0, 0.0, 0.5, 0.8))         # cẩu nối trung tâm


func _physics_process(delta: float) -> void:
	# ── Fly-in: bay từ trên vào vị trí — chưa bắn, chưa AI ──
	if _fly_in_active:
		_do_fly_in(delta)
		return
	time_elapsed += delta
	_move_time   += delta
	_contact_cooldown -= delta
	_update_effects(delta)
	if has_node("EnemyAI"):
		$EnemyAI.update(delta)
	else:
		move_by_pattern(delta)
	_update_shoot(delta)
	# Cache viewport (cheap update every 180 frames)
	_rd_frame += 1
	if _rd_frame >= 180:
		_rd_frame = 0
		_vp_size = get_viewport_rect().size
	var vp := _vp_size
	if position.y > vp.y + 80.0 or position.y < -200.0:
		_silent_die()
	# 2.5D depth perspective: objects near top (far) appear smaller
	if not _fly_in_active and is_instance_valid(sprite) and sprite.scale.y > 0.85:
		var d := clampf(position.y / maxf(1.0, vp.y), 0.05, 1.0)
		var ds := lerpf(0.68, 1.0, d * d)
		sprite.scale = Vector2(ds * _bank, ds)
	# Throttle redraw: every other frame
	if _rd_frame % 2 == 0:
		queue_redraw()

var _depth_s: float = 1.0   # 2.5D depth scale cache
var _bank:    float = 1.0   # 2.5D side-bank (set by AI when strafing)
var _aura_t:  float = 0.0
var _vp_size: Vector2 = Vector2(1152, 720)  # cached viewport
var _rd_frame: int = 0                       # redraw throttle

func _draw() -> void:
	# Pulsing aura glow — per enemy type
	_aura_t += 0.05
	var pulse := 0.52 + 0.48 * sin(_aura_t)
	match enemy_type:
		0: # Scout — orange-red
			draw_circle(Vector2.ZERO, 24.0, Color(1.00, 0.28, 0.08, 0.11 * pulse))
			draw_circle(Vector2.ZERO, 16.0, Color(1.00, 0.55, 0.10, 0.14 * pulse))
		1: # Fighter — electric blue
			draw_circle(Vector2.ZERO, 27.0, Color(0.20, 0.75, 1.00, 0.10 * pulse))
			draw_circle(Vector2.ZERO, 18.0, Color(0.40, 0.90, 1.00, 0.14 * pulse))
		2: # Bomber — purple
			draw_circle(Vector2.ZERO, 30.0, Color(0.60, 0.10, 1.00, 0.09 * pulse))
			draw_circle(Vector2.ZERO, 20.0, Color(0.80, 0.25, 1.00, 0.13 * pulse))

func _do_fly_in(delta: float) -> void:
	var diff := _fly_in_target - global_position
	if diff.length() < FLY_IN_SPEED * delta + 2.0:
		global_position  = _fly_in_target
		_fly_in_active   = false
		_is_spawning     = false
		# Landing squish: bẹp rồi nảy về
		if is_instance_valid(sprite):
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)  # khôi phục opacity
			var tw := sprite.create_tween()
			tw.tween_property(sprite, "scale", Vector2(1.18, 0.76), 0.07)
			tw.tween_property(sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC)
		return
	# Di chuyển thẳng xuống theo hướng fly_in_target
	var fly_dir := diff.normalized()
	global_position += fly_dir * FLY_IN_SPEED * delta
	# Exhaust trail nhẹ khi bay vào
	if is_instance_valid(sprite):
		sprite.modulate = Color(1.0, 1.0, 1.0,
			clampf(1.0 - diff.length() / 160.0 + 0.4, 0.35, 1.0))

# ── STATUS EFFECTS ────────────────────────────────────────────────────────────
func _update_effects(delta: float) -> void:
	# Burn (đạn lửa): tick mỗi 0.5s
	if _burn_timer > 0.0:
		_burn_timer -= delta
		_burn_tick  -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			take_damage(1)
		if is_instance_valid(sprite): sprite.color = Color(1.0, 0.45, 0.0)
	# Freeze (đạn băng)
	if _freeze_timer > 0.0:
		_freeze_timer -= delta
		if _freeze_timer <= 0.0 and _saved_move_speed >= 0.0:
			_move_speed = _saved_move_speed
			_saved_move_speed = -1.0
			if is_instance_valid(sprite): sprite.color = _base_color

func apply_burn(intensity: int = 1) -> void:
	_burn_timer = 3.0 * intensity
	_burn_tick  = 0.5 / float(intensity)   # cháy nhanh gấp đôi khi intensity=2

func apply_freeze(duration: float = 1.5) -> void:
	if _saved_move_speed < 0.0:
		_saved_move_speed = _move_speed
	_move_speed = 0.0
	_freeze_timer = duration
	if is_instance_valid(sprite): sprite.color = Color(0.3, 0.9, 1.0)

# ── DI CHUYỂN THEO PATTERN ─────────────────────────────────────────────────
# Gọi bởi _physics_process (không AI) hoặc EnemyAI ở state IDLE
func move_by_pattern(delta: float) -> void:
	if _freeze_timer > 0.0: return
	match move_pattern:
		0: _pat_horizontal(delta)
		1: _pat_zigzag(delta)
		2: _pat_pendulum(delta)
		3: _pat_step(delta)
		4: _pat_strafe(delta)

func _pat_horizontal(delta: float) -> void:
	var vp_w := get_viewport_rect().size.x
	position.x += _move_dir * _move_speed * delta
	if position.x > vp_w - 30.0: position.x = vp_w - 30.0; _move_dir = -1.0
	elif position.x < 30.0:      position.x = 30.0;         _move_dir =  1.0

# Zigzag: ngang + sóng sin dọc nhẹ
func _pat_zigzag(delta: float) -> void:
	var vp_w := get_viewport_rect().size.x
	position.x += _move_dir * _move_speed * delta
	position.y += sin(_move_time * 2.5) * 30.0 * delta
	if position.x > vp_w - 30.0: position.x = vp_w - 30.0; _move_dir = -1.0
	elif position.x < 30.0:      position.x = 30.0;         _move_dir =  1.0

# Pendulum: ngang nhanh hơn + dao động dọc cos
func _pat_pendulum(delta: float) -> void:
	var vp_w := get_viewport_rect().size.x
	position.x += _move_dir * _move_speed * 1.4 * delta
	position.y += cos(_move_time * 1.8) * 22.0 * delta
	if position.x > vp_w - 30.0: position.x = vp_w - 30.0; _move_dir = -1.0
	elif position.x < 30.0:      position.x = 30.0;         _move_dir =  1.0

# Step: ngang bình thường, bước xuống 22px mỗi 2 giây
func _pat_step(delta: float) -> void:
	var vp_w := get_viewport_rect().size.x
	position.x += _move_dir * _move_speed * delta
	_step_timer += delta
	if _step_timer >= 2.0:
		_step_timer = 0.0
		position.y += 22.0
	if position.x > vp_w - 30.0: position.x = vp_w - 30.0; _move_dir = -1.0
	elif position.x < 30.0:      position.x = 30.0;         _move_dir =  1.0

# Strafe: ngang tốc độ x2, rung dọc nhanh nhỏ
func _pat_strafe(delta: float) -> void:
	var vp_w := get_viewport_rect().size.x
	position.x += _move_dir * _move_speed * 2.0 * delta
	position.y += sin(_move_time * 4.0) * 18.0 * delta
	if position.x > vp_w - 30.0: position.x = vp_w - 30.0; _move_dir = -1.0
	elif position.x < 30.0:      position.x = 30.0;         _move_dir =  1.0

# ── SHOOT ─────────────────────────────────────────────────────────────────────
func _update_shoot(delta: float) -> void:
	if _is_spawning: return   # chưa spawn xong thì không bắn
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = shoot_interval * randf_range(0.8, 1.3)
		_try_shoot()

func _try_shoot() -> void:
	match attack_tier:
		0: _shoot_straight()           # tier 0: thẳng xuống
		1: _shoot_straight_or_aimed()  # tier 1: thẳng ↔ ngắm xen kẽ
		2: _shoot_spread()             # tier 2: 3 đạn tỏa
		3: _shoot_aimed_spread()       # tier 3: ngắm + 2 lệch
		4: _shoot_burst()              # tier 4: ngắm + thẳng đồng thời

func _shoot_straight() -> void:
	_spawn_bullet(Vector2.DOWN)

func _shoot_straight_or_aimed() -> void:
	if int(time_elapsed) % 2 == 0:
		_spawn_bullet(Vector2.DOWN)
	else:
		var d := _get_player_dir()
		_spawn_bullet(d if d != Vector2.ZERO else Vector2.DOWN)

func _shoot_spread() -> void:
	for offset in [-0.25, 0.0, 0.25]:
		_spawn_bullet(Vector2(offset, 1.0).normalized())

func _shoot_aimed_spread() -> void:
	var d := _get_player_dir()
	if d == Vector2.ZERO: d = Vector2.DOWN
	for offset_deg in [-18.0, 0.0, 18.0]:
		_spawn_bullet(d.rotated(deg_to_rad(offset_deg)))

func _shoot_burst() -> void:
	var d := _get_player_dir()
	if d == Vector2.ZERO: d = Vector2.DOWN
	_spawn_bullet(d)
	_spawn_bullet(Vector2.DOWN)

func _get_player_dir() -> Vector2:
	var p := get_tree().current_scene.get_node_or_null("Player")
	if p == null or not is_instance_valid(p): return Vector2.ZERO
	return (p.global_position - global_position).normalized()

func _spawn_bullet(dir: Vector2) -> void:
	var bullet = BULLET_SCENE.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.speed = 260.0
	bullet.is_enemy_bullet = true
	var container := get_tree().current_scene.get_node_or_null("BulletContainer")
	if container:
		container.add_child(bullet)

# ── CONTACT DAMAGE (enemy body chạm player body) ──────────────────────────────
func _check_player_contact() -> void:
	if _contact_cooldown > 0.0:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var body := col.get_collider()
		if body and body.is_in_group("player"):
			body.take_damage(1)
			_contact_cooldown = 1.0
			break

# ── MOVEMENT METHODS (gọi bởi EnemyAI) ───────────────────────────────────────
func move_zigzag(delta: float, _speed_mul: float = 1.0) -> void:
	move_by_pattern(delta)  # dùng pattern được gán từ wave_manager

func move_toward_player_x(player_pos: Vector2, delta: float) -> void:
	if _freeze_timer > 0.0: return
	var vp_w := get_viewport_rect().size.x
	var dir_x: float = sign(player_pos.x - position.x)
	position.x += dir_x * _move_speed * 1.6 * delta
	position.x = clamp(position.x, 30.0, vp_w - 30.0)
	# Drift nhẹ về phía player theo Y nếu còn xa
	if abs(player_pos.y - position.y) > 80.0:
		position.y += sign(player_pos.y - position.y) * 30.0 * delta

func move_escape(delta: float) -> void:
	if _freeze_timer > 0.0: return
	position.y -= base_speed * 1.5 * delta  # bay ngược lên nhanh

# Kamikaze: lao thẳng về phía player ở tốc độ cao, gây damage khi chạm rồi chết
func set_kamikaze_color() -> void:
	# Đổi màu đỏ sáng để cảnh báo người chơi
	if is_instance_valid(sprite):
		sprite.color = Color(1.0, 0.15, 0.15)

func move_kamikaze(delta: float) -> void:
	var p := get_tree().current_scene.get_node_or_null("Player")
	if p == null or not is_instance_valid(p):
		_silent_die()
		return
	var player_pos := (p as Node2D).global_position
	# Kiểm tra va chạm bằng khoảng cách — đáng tin cậy với position trực tiếp
	var dist := global_position.distance_to(player_pos)
	if dist < 26.0:
		(p as CharacterBody2D).take_damage(2)
		_kamikaze_explode()
		return
	var dir: Vector2 = (player_pos - global_position).normalized()
	position += dir * base_speed * 3.8 * delta
	# Nếu bay ra ngoài màn hình thì chết lặng
	var vp := get_viewport_rect().size
	if position.x < -60.0 or position.x > vp.x + 60.0 \
		or position.y < -60.0 or position.y > vp.y + 60.0:
		_silent_die()

func _kamikaze_explode() -> void:
	if _is_dying: return
	_is_dying = true
	# Vẽ các vòng nổ tại vị trí hiện tại
	_spawn_explosion_rings(global_position)
	# Screen shake mạnh khi kamikaze nổ
	var main_ks := get_tree().current_scene
	if main_ks and main_ks.has_method("screen_shake"):
		main_ks.screen_shake(12.0, 0.30)
	# Flash sprite thật nhanh rồi biến mất
	if is_instance_valid(sprite):
		sprite.color = Color(1.0, 1.0, 0.6)
		var tw := sprite.create_tween()
		tw.set_parallel(true)
		tw.tween_property(sprite, "scale", Vector2(2.2, 2.2), 0.08).set_trans(Tween.TRANS_EXPO)
		tw.tween_property(sprite, "modulate", Color(1,1,1,0), 0.12).set_trans(Tween.TRANS_EXPO)
	# Thưởng xét và kết thúc
	var main := get_tree().current_scene
	if main and main.has_method("add_score"): main.add_score(score_value)
	var roll := randf()
	if roll < HEART_CHANCE:
		_drop_heart()
	elif roll < HEART_CHANCE + DROP_CHANCE:
		_drop_powerup()
	emit_signal("died")
	if main and main.has_method("screen_shake"):
		main.screen_shake(10.0, 0.22)
	# Chờ một frame rồi free để ring animation kịp spawn
	await get_tree().process_frame
	queue_free()

func _spawn_explosion_rings(pos: Vector2) -> void:
	var container := get_tree().current_scene.get_node_or_null("BulletContainer")
	if container == null: return
	# Tạo 3 vòng ring với độ trễ khác nhau
	var ring_defs: Array = [
		{"radius": 18.0, "color": Color(1.0, 0.85, 0.2, 0.95), "delay": 0.0,  "dur": 0.28},
		{"radius": 28.0, "color": Color(1.0, 0.45, 0.05, 0.75),"delay": 0.05, "dur": 0.35},
		{"radius": 42.0, "color": Color(1.0, 0.2,  0.0, 0.45), "delay": 0.10, "dur": 0.45},
	]
	for rd in ring_defs:
		var ring := Polygon2D.new()
		# Xấp xỉ hình tròn bằng 12 điểm
		var pts := PackedVector2Array()
		var r: float = rd["radius"]
		for i in 12:
			var a := i * TAU / 12.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		ring.polygon      = pts
		ring.color        = rd["color"]
		ring.global_position = pos
		ring.scale        = Vector2(0.15, 0.15)
		ring.z_index   = 10
		container.add_child(ring)
		# Tween: mở rộng + mờ dần
		var tw := ring.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ring, "scale",
			Vector2(1.0, 1.0), rd["dur"]).set_delay(rd["delay"]).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(ring, "color:a",
			0.0, rd["dur"]).set_delay(rd["delay"]).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Xóa sau khi xong
		var dur_total: float = rd["delay"] + rd["dur"]
		tw.tween_callback(ring.queue_free).set_delay(dur_total)

# ── PERCEPTION HELPER ─────────────────────────────────────────────────────────
func get_nearby_bullets() -> Array: return []

# ── HEALTH ─────────────────────────────────────────────────────────────────────
func take_damage(dmg: int = 1) -> void:
	if _is_dying:
		return
	hp -= dmg
	if hp <= 0:
		_die()
		return
	if is_instance_valid(sprite):
		sprite.color = Color.WHITE
		var main_dmg := get_tree().current_scene
		if main_dmg and main_dmg.has_method("screen_shake"):
			main_dmg.screen_shake(2.5, 0.07)
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(self) and is_instance_valid(sprite):
			sprite.color = _base_color

func _die() -> void:
	if _is_dying:
		return
	_is_dying = true
	var main := get_tree().current_scene
	if main and main.has_method("add_score"):
		main.add_score(score_value)
	if main and main.has_method("screen_shake"):
		main.screen_shake(4.5, 0.14)
	var roll := randf()
	if roll < HEART_CHANCE:
		_drop_heart()
	elif roll < HEART_CHANCE + DROP_CHANCE:
		_drop_powerup()
	_spawn_explosion_rings(global_position)
	# Ẩn sprite ngay, chờ một frame để explosion rings kịp spawn
	if is_instance_valid(sprite):
		sprite.visible = false
	emit_signal("died")
	var main2 := get_tree().current_scene
	if main2 and main2.has_method("screen_shake"):
		main2.screen_shake(5.0, 0.14)
	await get_tree().process_frame
	queue_free()

func _drop_heart() -> void:
	var heart = HEART_SCENE.instantiate()
	heart.global_position = global_position
	var container := get_tree().current_scene.get_node_or_null("BulletContainer")
	if container:
		container.add_child(heart)

# Chết lặng (ra off-screen): không điểm, không drop, nhưng vẫn báo wave_manager
func _silent_die() -> void:
	if _is_dying:
		return
	_is_dying = true
	emit_signal("died")
	queue_free()

func _drop_powerup() -> void:
	var powerup = POWERUP_SCENE.instantiate()
	powerup.global_position = global_position
	# Weighted: +STREAM 30%, UPGRADE 30%, các loại vũ khí 40%
	var roll := randf()
	if roll < 0.30:
		powerup.powerup_type = 0   # EXTRA_STREAM
	elif roll < 0.60:
		powerup.powerup_type = 6   # UPGRADE
	else:
		powerup.powerup_type = 1 + randi() % 5  # ELECTRIC..RICOCHET
	var container := get_tree().current_scene.get_node_or_null("BulletContainer")
	if container:
		container.add_child(powerup)
