extends CharacterBody2D
# special_boss.gd — Boss cuối cùng của màn đặc biệt (wave 30)
#
# Aerial Warfare:
#   Phase 1 — Trụ sở không quân (HQ): bất động, liên tục tạo máy bay &
#             bắn tên lửa phòng không homing.  Kết thúc khi mất 40% HP.
#   Phase 2 — Máy bay khổng lồ: bay lượn, bắn nhiều đạn, máu trâu.
#
# Mọi pack khác:
#   Pháo đài Dreadfort: di chuyển chậm, bắn quạt đạn dày đặc, tạo quân,
#                       đôi khi ném thiên thạch hướng về phía người chơi.

signal died

const BULLET_SCENE   = preload("res://scenes/bullet.tscn")
const ENEMY_SCENE    = preload("res://scenes/enemy.tscn")
const ASTEROID_SCENE = preload("res://scenes/asteroid.tscn")
const HEART_SCENE    = preload("res://scenes/heart.tscn")

# ── Thuộc tính chính (gán bởi wave_manager) ──────────────────────────────────
var max_hp:          int   = 3500
var hp:              int   = 3500
var score_value:     int   = 80000
var force_aerial:    bool  = false   # gán bởi wave_manager cho boss challenge
var use_force_aerial: bool = false   # nếu true: bỏ qua dò ThemePack

# ── Trạng thái nội bộ ─────────────────────────────────────────────────────────
var _is_aerial:          bool  = false
var _phase2_triggered:   bool  = false   # đã chuyển sang Bomber chưa
var _is_dying:           bool  = false
var _is_boss_challenge:  bool  = false   # đơn thể boss challenge (1 wave)
var _time:               float = 0.0
var _move_dir:           float = 1.0
var _shoot_pattern_idx:  int   = 0

var _player:          Node = null
var _spawner:         Node = null
var _bullet_cont:     Node = null
var _asteroid_cont:   Node = null

# ── Visual nodes ──────────────────────────────────────────────────────────────
var _dr:           Node2D    = null
var _engine_nodes: Array     = []
var _weapon_nodes: Array     = []
var _body_poly:    Polygon2D = null

@onready var shoot_timer:    Timer    = $ShootTimer
@onready var spawn_timer:    Timer    = $SpawnTimer
@onready var asteroid_timer: Timer    = $AsteroidTimer
@onready var sprite:         Polygon2D = $Sprite

# ── SETUP ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	_is_boss_challenge = PlayerData.current_level.get("is_boss_challenge", false)
	if use_force_aerial:
		_is_aerial = force_aerial
	else:
		_is_aerial = (ThemePack.get_pack().get("shape_mode","") == "aerial_warfare")
	_player       = get_tree().get_first_node_in_group("player")
	var sc        = get_tree().current_scene
	_spawner      = sc.get_node_or_null("EnemySpawner")
	_bullet_cont  = sc.get_node_or_null("BulletContainer")
	_asteroid_cont = _bullet_cont

	hp = max_hp

	if _is_aerial:
		_build_hq_visuals()
		shoot_timer.wait_time  = 2.5
		spawn_timer.wait_time  = 4.0
		asteroid_timer.stop()
	else:
		_build_fortress_visuals()
		shoot_timer.wait_time  = 1.4
		spawn_timer.wait_time  = 8.0
		asteroid_timer.wait_time = 14.0
		asteroid_timer.start()

	shoot_timer.timeout.connect(_on_shoot)
	spawn_timer.timeout.connect(_on_spawn)
	asteroid_timer.timeout.connect(_on_asteroid_fire)
	shoot_timer.start()
	spawn_timer.start()

	# ── Căn vị trí + scale sau 1 frame ───────────────────────────────────────
	await get_tree().process_frame
	if not is_instance_valid(self): return
	var vp := get_viewport_rect().size
	if _is_boss_challenge:
		if _is_aerial:
			var sx := vp.x * 0.46 / 92.0
			if is_instance_valid(_dr):
				_dr.scale = Vector2(sx, sx * 0.52)
			global_position = Vector2(vp.x * 0.5, vp.y * 0.17)
		else:
			var s := vp.x * 0.43 / 195.0
			if is_instance_valid(_dr):
				_dr.scale = Vector2(s, s)
			global_position = Vector2(vp.x * 0.5, vp.y * 0.07)
	else:
		global_position = Vector2(vp.x * 0.5, vp.y * 0.125)

	Audio.play("boss_appear")

# ═══════════════════════════════════════════════════════════════════════════════
# PHYSICS / MOVEMENT
# ═══════════════════════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	if _is_dying: return
	_time += delta
	_animate_visuals(delta)

	var vp := get_viewport_rect().size

	if _is_aerial:
		if not _phase2_triggered:
			# ── Phase 1 HQ: bất động ────────────────────────────────────────
			velocity = Vector2.ZERO
			if _is_boss_challenge:
				global_position = Vector2(vp.x * 0.5, vp.y * 0.17)
		else:
			# ── Phase 2 Bomber: bay ngang + lắc ─────────────────────────────
			var spd := 70.0
			velocity.x = _move_dir * spd + sin(_time * 0.6) * 18.0
			velocity.y = sin(_time * 0.4) * 22.0
			if global_position.x > vp.x - 90.0 or global_position.x < 90.0:
				_move_dir = -_move_dir
	else:
		# ── Fortress: bất động, ghim cứng ───────────────────────────────────
		velocity = Vector2.ZERO
		var pin_y := vp.y * (0.07 if _is_boss_challenge else 0.125)
		global_position = Vector2(vp.x * 0.5, pin_y)
	move_and_slide()

# ═══════════════════════════════════════════════════════════════════════════════
# SHOOT PATTERN
# ═══════════════════════════════════════════════════════════════════════════════
func _on_shoot() -> void:
	if _is_dying or not is_instance_valid(_bullet_cont): return

	if _is_aerial and not _phase2_triggered:
		_fire_aa_missiles(3)
	elif _is_aerial and _phase2_triggered:
		_fire_bomber_cannons()
	else:
		_fire_fortress_burst()

# Pháo đài bắn quạt 5 đến 9 đạn
func _fire_fortress_burst() -> void:
	var hpf: float = float(hp) / float(max_hp)
	var count: int = 5 if hpf > 0.66 else (7 if hpf > 0.33 else 9)
	var spread: float = PI * 0.75
	var center_angle := PI * 0.5    # bắn xuống
	if is_instance_valid(_player):
		var to_pl := (_player as Node2D).global_position - global_position
		center_angle = to_pl.angle()

	for i in range(count):
		var a := center_angle - spread * 0.5 + spread * (float(i) / float(count - 1))
		_fire_bullet(a, 340.0, 0)

	# Pha 3: thêm 2 cánh bắn ngang
	if hpf <= 0.33:
		for side in [-1, 1]:
			for k in range(3):
				var a2 := PI * 0.5 + float(side) * (float(k + 1) * 0.28)
				_fire_bullet(a2, 380.0, 2)

# Máy bay khổng lồ bắn từ nhiều pháo
func _fire_bomber_cannons() -> void:
	var angles := [PI * 0.35, PI * 0.5, PI * 0.65,
				   PI * 0.35 + 0.1, PI * 0.5 + 0.05, PI * 0.65 - 0.1]
	for a in angles:
		_fire_bullet(a, 360.0, 1)

# Bắn tên lửa AA homing (dùng asteroid scene)
func _fire_aa_missiles(count: int) -> void:
	if not is_instance_valid(_asteroid_cont): return
	var vp := get_viewport_rect().size
	for i in range(count):
		var ast = ASTEROID_SCENE.instantiate()
		ast.size_tier   = 0
		ast._scale_mul  = 0.6
		ast.hp          = 2
		ast.speed       = 230.0
		# Bắn từ vị trí pháo phân tán
		var offset_x := float(i - count / 2) * 40.0
		ast.global_position = global_position + Vector2(offset_x, 30.0)
		var to_pl: Vector2
		if is_instance_valid(_player):
			to_pl = ((_player as Node2D).global_position - ast.global_position).normalized()
		else:
			to_pl = Vector2(0.0, 1.0)
		ast.direction  = to_pl
		ast.rotation   = to_pl.angle() + PI * 0.5
		ast.died.connect(_on_missile_expired)
		_asteroid_cont.add_child(ast)

func _on_missile_expired() -> void:
	pass   # tên lửa diệt → không tính kill cho wave_manager

func _fire_bullet(angle: float, speed: float, btype: int) -> void:
	var b = BULLET_SCENE.instantiate()
	b.global_position = global_position
	b.direction       = Vector2(cos(angle), sin(angle))
	b.speed           = speed
	b.bullet_type     = btype
	b.damage          = 1
	b.is_enemy_bullet = true
	if is_instance_valid(_bullet_cont):
		_bullet_cont.add_child(b)

# ═══════════════════════════════════════════════════════════════════════════════
# SPAWN ENEMIES
# ═══════════════════════════════════════════════════════════════════════════════
func _on_spawn() -> void:
	if _is_dying: return
	if _is_aerial and not _phase2_triggered:
		_spawn_fighter_jets()
	else:
		_spawn_rush_enemies()

# Sinh máy bay chiến đấu từ hai bên
func _spawn_fighter_jets() -> void:
	if not is_instance_valid(_spawner): return
	var vp := get_viewport_rect().size
	for side in [-1, 1]:
		for k in range(2):
			var jet = ENEMY_SCENE.instantiate()
			jet.max_hp         = 3
			jet.hp             = 3
			jet.score_value    = 80
			jet.shoot_interval = 3.5
			jet.stationary     = false
			jet._move_dir      = float(side)
			jet._move_speed    = 220.0
			jet.attack_tier    = 2
			jet.enemy_type     = k % 3
			jet.died.connect(func(): pass)   # không tính cho wave_manager
			_spawner.add_child(jet)
			jet.global_position = Vector2(
				vp.x * 0.5 + float(side) * (vp.x * 0.6),
				60.0 + float(k) * 70.0
			)
			var target_x := vp.x * (0.3 + randf() * 0.4)
			var target_y := vp.y * (0.3 + randf() * 0.3)
			jet.start_fly_in(Vector2(target_x, target_y))

# Sinh địch lao thẳng vào người chơi
func _spawn_rush_enemies() -> void:
	if not is_instance_valid(_spawner): return
	var vp    := get_viewport_rect().size
	var count := 3 + randi() % 3
	for i in range(count):
		var e = ENEMY_SCENE.instantiate()
		var hpf: float = float(hp) / float(max_hp)
		e.max_hp         = 2 + int((1.0 - hpf) * 3.0)
		e.hp             = e.max_hp
		e.score_value    = 60
		e.shoot_interval = 4.0
		e.stationary     = false
		e._move_dir      = 1.0 if (i % 2 == 0) else -1.0
		e._move_speed    = 260.0 + float(i) * 20.0
		e.attack_tier    = 1
		e.enemy_type     = i % 3
		e.died.connect(func(): pass)          # không tính kill cho wave_manager
		_spawner.add_child(e)
		e.global_position = Vector2(
			randf_range(60.0, vp.x - 60.0),
			-40.0 - float(i) * 22.0
		)
		var pl_pos := vp * 0.5
		if is_instance_valid(_player):
			pl_pos = (_player as Node2D).global_position
		e.start_fly_in(pl_pos + Vector2(randf_range(-40.0, 40.0), 0.0))

# ═══════════════════════════════════════════════════════════════════════════════
# ASTEROID VOLLEY (Fortress only)
# ═══════════════════════════════════════════════════════════════════════════════
func _on_asteroid_fire() -> void:
	if _is_dying or _is_aerial: return
	_fire_asteroid_volley()
	# Pha cuối: bắn nhanh hơn
	var hpf: float = float(hp) / float(max_hp)
	asteroid_timer.wait_time = 10.0 if hpf <= 0.33 else 14.0

func _fire_asteroid_volley() -> void:
	if not is_instance_valid(_asteroid_cont): return
	var count := 3 + randi() % 2
	for i in range(count):
		var ast = ASTEROID_SCENE.instantiate()
		ast.size_tier  = randi() % 2
		ast._scale_mul = randf_range(0.7, 1.1)
		ast.hp         = ast.BASE_HP[ast.size_tier]
		ast.speed      = 190.0 + float(i) * 20.0
		ast.global_position = global_position + Vector2(
			float(i - count / 2) * 55.0, 20.0
		)
		var pl_pos := Vector2(get_viewport_rect().size.x * 0.5, 400.0)
		if is_instance_valid(_player):
			pl_pos = (_player as Node2D).global_position
		ast.direction  = (pl_pos - ast.global_position).normalized()
		ast._rot_speed = randf_range(-2.0, 2.0)
		ast.died.connect(func(): pass)
		_asteroid_cont.add_child(ast)

# ═══════════════════════════════════════════════════════════════════════════════
# NHẬN SÁT THƯƠNG
# ═══════════════════════════════════════════════════════════════════════════════
func take_damage(amount: int) -> void:
	if _is_dying: return
	hp -= amount
	# Flash visual
	for n in _weapon_nodes + _engine_nodes:
		if is_instance_valid(n):
			(n as Polygon2D).modulate = Color(2.0, 2.0, 2.0)
	await get_tree().create_timer(0.08).timeout
	for n in _weapon_nodes + _engine_nodes:
		if is_instance_valid(n):
			(n as Polygon2D).modulate = Color.WHITE
	if is_instance_valid(_body_poly):
		_body_poly.modulate = Color(1.8, 0.5, 0.5)
		await get_tree().create_timer(0.10).timeout
		if is_instance_valid(_body_poly):
			_body_poly.modulate = Color.WHITE

	# Cập nhật HP bar
	var main = get_tree().current_scene
	if main and main.has_method("update_boss_hp"):
		main.update_boss_hp(hp)

	# Kiểm tra chuyển phase (Aerial)
	if _is_aerial and not _phase2_triggered:
		var hq_threshold: int = int(float(max_hp) * 0.60)   # 40% HP đầu = HQ
		if hp <= hq_threshold:
			_phase2_triggered = true
			_start_bomber_phase()
			return

	# Kiểm tra chết
	if hp <= 0:
		_die()

# ═══════════════════════════════════════════════════════════════════════════════
# CHUYỂN SANG BOMBER (Aerial phase 2)
# ═══════════════════════════════════════════════════════════════════════════════
func _start_bomber_phase() -> void:
	shoot_timer.stop()
	spawn_timer.stop()
	# Hiệu ứng nổ HQ
	var main = get_tree().current_scene
	if main and main.has_method("show_alert"):
		main.show_alert("☠  HQ DESTROYED — BOMBER INBOUND!")
	if main and main.has_method("screen_shake"):
		main.screen_shake(14.0, 0.8)
	# Rebuild visuals cho Bomber
	_build_bomber_visuals()
	# Điều chỉnh tốc độ bắn Bomber
	shoot_timer.wait_time = 1.1
	spawn_timer.wait_time = 10.0
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(self):
		shoot_timer.start()
		spawn_timer.start()

# ═══════════════════════════════════════════════════════════════════════════════
# CHẾT
# ═══════════════════════════════════════════════════════════════════════════════
func _die() -> void:
	if _is_dying: return
	_is_dying = true
	set_physics_process(false)
	shoot_timer.stop()
	spawn_timer.stop()
	asteroid_timer.stop()
	if sprite: sprite.visible = false

	var main = get_tree().current_scene
	if main and main.has_method("screen_shake"):
		main.screen_shake(18.0, 1.5)
	if main and main.has_method("hide_boss_hp"):
		main.hide_boss_hp()

	# Chuỗi nổ lớn
	for burst in range(8):
		await get_tree().create_timer(0.18).timeout
		if not is_instance_valid(self): return
		_spawn_death_burst(randf_range(12.0, 40.0), randf_range(-55.0, 55.0))

	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self): return
	# Thả heart
	var heart = HEART_SCENE.instantiate()
	heart.global_position = global_position
	var hcont: Node = main.get_node_or_null("BulletContainer") if main else null
	if hcont: hcont.add_child(heart)

	# Thưởng điểm
	if main and main.has_method("add_score"):
		main.add_score(score_value)

	emit_signal("died")
	queue_free()

func _spawn_death_burst(radius: float, offset_x: float) -> void:
	var ring := Node2D.new()
	ring.global_position = global_position + Vector2(offset_x, 0.0)
	var main = get_tree().current_scene
	var cont: Node = main.get_node_or_null("BulletContainer") if main else null
	if not cont: return
	cont.add_child(ring)
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	var n := 16
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * radius, sin(a) * radius))
	p.polygon = pts
	p.color = Color(1.0, 0.55, 0.1, 0.85)
	ring.add_child(p)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(2.8, 2.8), 0.45)
	tw.parallel().tween_property(p, "color:a", 0.0, 0.45)
	tw.tween_callback(ring.queue_free)

# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATION VISUALS
# ═══════════════════════════════════════════════════════════════════════════════
func _animate_visuals(delta: float) -> void:
	for n in _engine_nodes:
		if is_instance_valid(n):
			var pulse := 0.75 + sin(_time * 4.0 + (n as Polygon2D).position.x * 0.1) * 0.25
			(n as Polygon2D).modulate = Color(pulse, pulse, pulse)

# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS ─ Xây dựng hình vẽ
# ═══════════════════════════════════════════════════════════════════════════════
func _clear_dr() -> void:
	_engine_nodes.clear()
	_weapon_nodes.clear()
	_body_poly = null
	if is_instance_valid(_dr): _dr.queue_free()
	_dr = Node2D.new()
	_dr.z_index = 1
	sprite.add_child(_dr)

func _mk(pts: Array, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var pv := PackedVector2Array()
	for v in pts: pv.append(v)
	p.polygon = pv
	p.color   = col
	return p

func _dp(pts: Array, col: Color) -> void:
	_dr.add_child(_mk(pts, col))

func _dp_e(pts: Array, col: Color) -> void:
	var p := _mk(pts, col); _dr.add_child(p); _engine_nodes.append(p)

func _dp_w(pts: Array, col: Color) -> void:
	var p := _mk(pts, col); _dr.add_child(p); _weapon_nodes.append(p)

func _dp_b(pts: Array, col: Color) -> void:   # primary body — flash on hit
	var p := _mk(pts, col); _dr.add_child(p); _body_poly = p

# ── FORTRESS ─────────────────────────────────────────────────────────────────
# Chiếm ~1/4 màn hình phía trên: trải rộng ngang ±220, cao ~180px
func _build_fortress_visuals() -> void:
	sprite.color = Color(0.0, 0.0, 0.0, 0.0)
	_clear_dr()

	# ── Thân trung tâm — khối chữ nhật dày ──────────────────────────────────
	_dp_b([
		Vector2(-180, -70), Vector2(180, -70),
		Vector2(195,  -50), Vector2(195,   50),
		Vector2(180,   70), Vector2(-180,  70),
		Vector2(-195,  50), Vector2(-195, -50)
	], Color(0.35, 0.30, 0.25))

	# ── Lớp giáp phía trên ───────────────────────────────────────────────────
	_dp([
		Vector2(-175, -70), Vector2(175, -70),
		Vector2(165,  -90), Vector2(-165, -90)
	], Color(0.28, 0.24, 0.20))

	# ── Đỉnh pháo đài — răng cưa 5 tháp ─────────────────────────────────────
	for i in range(5):
		var tx := float(i - 2) * 72.0
		_dp([
			Vector2(tx - 22, -90), Vector2(tx + 22, -90),
			Vector2(tx + 18, -118), Vector2(tx - 18, -118)
		], Color(0.32, 0.28, 0.22))
		# Lỗ châu mai
		_dp([
			Vector2(tx - 8, -110), Vector2(tx + 8, -110),
			Vector2(tx + 6, -118), Vector2(tx - 6, -118)
		], Color(0.10, 0.08, 0.06))

	# ── Lõi năng lượng trung tâm (phát sáng) ─────────────────────────────────
	_dp_e([
		Vector2(-30, -24), Vector2(30, -24),
		Vector2(34,   0),  Vector2(30,  24),
		Vector2(-30,  24), Vector2(-34,  0)
	], Color(1.0, 0.50, 0.08))
	_dp_e([
		Vector2(-15, -12), Vector2(15, -12),
		Vector2(15,   12), Vector2(-15,  12)
	], Color(1.0, 0.80, 0.30))

	# ── Pháo chính phía dưới — 5 nòng ────────────────────────────────────────
	for sx in [-144.0, -72.0, 0.0, 72.0, 144.0]:
		_dp_w([
			Vector2(sx - 8, 50), Vector2(sx + 8, 50),
			Vector2(sx + 6, 90), Vector2(sx - 6, 90)
		], Color(0.65, 0.15, 0.10))
		# Đầu nòng
		_dp([Vector2(sx - 5, 84), Vector2(sx + 5, 84),
			 Vector2(sx + 4, 98), Vector2(sx - 4, 98)],
			Color(0.85, 0.22, 0.08))

	# ── Pháo cánh (bên hông, hướng ra ngoài xuống dưới) ─────────────────────
	for side in [-1, 1]:
		var sx2 := float(side) * 196.0
		_dp_w([
			Vector2(sx2 - float(side) * 8, -10),
			Vector2(sx2 + float(side) * 8, -10),
			Vector2(sx2 + float(side) * 8,  28),
			Vector2(sx2 - float(side) * 8,  28)
		], Color(0.60, 0.20, 0.15))

	# ── Tường cạnh trái/phải dày ─────────────────────────────────────────────
	for side in [-1, 1]:
		_dp([
			Vector2(float(side) * 155, -70),
			Vector2(float(side) * 195, -50),
			Vector2(float(side) * 195,  50),
			Vector2(float(side) * 155,  70)
		], Color(0.40, 0.34, 0.26))

	# ── Chi tiết trang trí: cửa sổ / lỗ thông gió ────────────────────────────
	for i in range(4):
		var wx := float(i - 1.5) * 80.0
		_dp([Vector2(wx - 14, -48), Vector2(wx + 14, -48),
			 Vector2(wx + 12, -30), Vector2(wx - 12, -30)],
			Color(0.15, 0.18, 0.22))

	# ── Băng chuyền / đường ray phía trên ────────────────────────────────────
	_dp([Vector2(-185, -72), Vector2(185, -72),
		 Vector2(183,  -80), Vector2(-183, -80)], Color(0.50, 0.45, 0.35))

# ── AERIAL HQ ────────────────────────────────────────────────────────────────
func _build_hq_visuals() -> void:
	sprite.color = Color(0.0, 0.0, 0.0, 0.0)
	_clear_dr()

	# Nền căn cứ — hình chữ nhật rộng
	_dp_b([
		Vector2(-85, -32), Vector2(85, -32),
		Vector2(92,  -16), Vector2(92,  26),
		Vector2(85,   42), Vector2(-85,  42),
		Vector2(-92,  26), Vector2(-92, -16)
	], Color(0.38, 0.42, 0.28))

	# Mái nhà hangar (3 khoang)
	for i in range(3):
		var hx := float(i - 1) * 58.0
		_dp([
			Vector2(hx - 24, -32), Vector2(hx + 24, -32),
			Vector2(hx + 18, -56), Vector2(hx - 18, -56)
		], Color(0.45, 0.48, 0.30))
		# Cửa hangar
		_dp([
			Vector2(hx - 16, 20), Vector2(hx + 16, 20),
			Vector2(hx + 15, 41), Vector2(hx - 15, 41)
		], Color(0.18, 0.22, 0.14))

	# Pháo phòng không (4 vị trí)
	for sx in [-72.0, -36.0, 36.0, 72.0]:
		_dp_w([
			Vector2(sx - 5, -26), Vector2(sx + 5, -26),
			Vector2(sx + 4, -56), Vector2(sx - 4, -56)
		], Color(0.6, 0.55, 0.2))
		_dp([Vector2(sx - 8, -26), Vector2(sx + 8, -26),
			 Vector2(sx + 6, -34), Vector2(sx - 6, -34)],
			Color(0.75, 0.70, 0.28))

	# Radar tháp giữa
	_dp([Vector2(-8, -56), Vector2(8, -56),
		 Vector2(6, -78),  Vector2(-6, -78)], Color(0.55, 0.60, 0.55))
	_dp([Vector2(-20, -82), Vector2(20, -82),
		 Vector2(14,   -90), Vector2(-14, -90)], Color(0.80, 0.85, 0.80))
	_dp_e([Vector2(-3, -80), Vector2(3, -80),
		   Vector2(2, -92),  Vector2(-2, -92)], Color(0.2, 1.0, 0.4))

	# Đèn hiệu ở hai đầu căn cứ
	for sx in [-88.0, 88.0]:
		_dp_e([Vector2(sx - 4, -20), Vector2(sx + 4, -20),
			   Vector2(sx + 4, -8),  Vector2(sx - 4, -8)],
			Color(1.0, 0.2, 0.1))

	# Đường băng / phần trang trí mặt đất
	_dp([Vector2(-80, 30), Vector2(80, 30),
		 Vector2(78, 42),  Vector2(-78, 42)], Color(0.32, 0.36, 0.22))

# ── BOMBER (Aerial Phase 2) ───────────────────────────────────────────────────
func _build_bomber_visuals() -> void:
	sprite.color = Color(0.0, 0.0, 0.0, 0.0)
	_clear_dr()

	# Thân máy bay khổng lồ — cánh delta rộng
	_dp_b([
		Vector2(0,   -42), Vector2(22,  -30), Vector2(58,  -18),
		Vector2(110, -6),  Vector2(115,  8),  Vector2(90,   22),
		Vector2(50,   28), Vector2(20,   32), Vector2(0,    36),
		Vector2(-20,  32), Vector2(-50,  28), Vector2(-90,  22),
		Vector2(-115, 8),  Vector2(-110, -6), Vector2(-58, -18),
		Vector2(-22, -30)
	], Color(0.30, 0.30, 0.35))

	# Buồng lái
	_dp([Vector2(-14, -44), Vector2(14, -44),
		 Vector2(12,  -30), Vector2(-12, -30)], Color(0.15, 0.45, 0.75))

	# Động cơ (4 cái)
	for sx in [-80.0, -42.0, 42.0, 80.0]:
		_dp_e([
			Vector2(sx - 8,  12), Vector2(sx + 8,  12),
			Vector2(sx + 6,  32), Vector2(sx - 6,  32)
		], Color(1.0, 0.55, 0.1))
		# Luồng lửa
		_dp_e([
			Vector2(sx - 5, 32), Vector2(sx + 5, 32),
			Vector2(sx + 2, 46), Vector2(sx - 2, 46)
		], Color(1.0, 0.85, 0.3))

	# Ống bom phía dưới
	_dp([Vector2(-32, 20), Vector2(32, 20),
		 Vector2(28,  36), Vector2(-28, 36)], Color(0.20, 0.20, 0.22))
	_dp([Vector2(-26, 22), Vector2(26, 22),
		 Vector2(22,  34), Vector2(-22, 34)], Color(0.12, 0.12, 0.14))

	# Pháo hai cánh
	for sx in [-100.0, 100.0]:
		_dp_w([Vector2(sx - 4, 6), Vector2(sx + 4, 6),
			   Vector2(sx + 3, 30), Vector2(sx - 3, 30)],
			Color(0.65, 0.55, 0.15))
