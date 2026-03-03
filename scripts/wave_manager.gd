extends Node
# wave_manager.gd — Formation spawning. Wave 5, 10, 15... = Boss.
# Wave % 3 == 0 (không phải boss) = ASTEROID SHOWER.
# Khi hết toàn bộ enemy → emit wave_cleared → main.gd tự động qua wave mới.

signal wave_cleared

const ENEMY_SCENE        = preload("res://scenes/enemy.tscn")
const BOSS_SCENE         = preload("res://scenes/boss.tscn")
const ASTEROID_SCENE     = preload("res://scenes/asteroid.tscn")
const SPECIAL_PICKUP_SCENE = preload("res://scenes/special_pickup.tscn")

const SPEED_SCALE: float = 0.12   # tốc độ tăng mỗi wave

var current_wave: int    = 0
var enemies_alive: int   = 0
var wave_in_progress: bool = false
var _boss_encounter: int = 0   # đếm số lần boss xuất hiện

# Cache sibling node references (đường dẫn tương đối — không phụ thuộc tên scene)
var _spawner: Node2D = null
var _bullet_container: Node2D = null
var _asteroid_container: Node2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_spawner           = get_parent().get_node_or_null("EnemySpawner")
	_bullet_container  = get_parent().get_node_or_null("BulletContainer")
	var _ac := get_parent().get_node_or_null("AsteroidContainer")
	_asteroid_container = _ac if _ac != null else _bullet_container

# ── PUBLIC API ────────────────────────────────────────────────────────────────
func start_wave(wave_number: int) -> void:
	current_wave = wave_number
	enemies_alive = 0
	wave_in_progress = true
	await get_tree().create_timer(0.5).timeout
	if current_wave % 5 == 0:
		_spawn_boss()
	elif current_wave % 3 == 0:
		_spawn_asteroid_wave()
	else:
		_spawn_formation()

# ── ENEMY DEATH CALLBACK ──────────────────────────────────────────────────────
func _on_enemy_died() -> void:
	enemies_alive -= 1
	if enemies_alive <= 0 and wave_in_progress:
		wave_in_progress = false
		emit_signal("wave_cleared")

# ── BOSS SPAWN ────────────────────────────────────────────────────────────────
func _spawn_boss() -> void:
	_boss_encounter += 1
	# Rơi vũ khí đặc biệt trước boss (trîn sân chơi để player nhặt)
	_drop_special_pickups()
	var vp := get_viewport().get_visible_rect().size
	var boss_tier: int   = current_wave / 5
	var base_hp:   int   = 200 + boss_tier * 100
	var base_spd:  float = 120.0 + float(boss_tier) * 15.0
	var btype: int = (_boss_encounter - 1) % 5
	enemies_alive = 0
	if current_wave >= 20:
		# Từ wave 20 trở đi: xuất hiện 2 boss cùng lúc, loại luân phiên
		_make_boss(btype,             base_hp, base_spd, vp.x * 0.30)
		_make_boss((btype + 1) % 5,   base_hp, base_spd, vp.x * 0.70)
	else:
		_make_boss(btype, base_hp, base_spd, vp.x * 0.5)
	# Hiển thị thanh máu boss
	var main = get_parent()
	if main and main.has_method("show_boss_hp"):
		main.show_boss_hp(base_hp, base_hp)

func _make_boss(btype: int, bhp: int, bspd: float, x_pos: float) -> void:
	var boss = BOSS_SCENE.instantiate()
	if not _spawner: return
	boss.boss_type = btype
	boss.max_hp    = bhp
	boss.hp        = bhp
	boss.speed     = bspd
	enemies_alive += 1
	boss.died.connect(_on_enemy_died)
	_spawner.add_child(boss)
	boss.global_position = Vector2(x_pos, 100.0)

# Rơi 2 vũ khí đặc biệt ngẫu nhiên trước mỗi boss wave
func _drop_special_pickups() -> void:
	if _bullet_container == null: return
	var vp := get_viewport().get_visible_rect().size
	for i in range(2):
		var pickup = SPECIAL_PICKUP_SCENE.instantiate()
		pickup.weapon_type = randi() % 3
		pickup.global_position = Vector2(
			lerp(vp.x * 0.25, vp.x * 0.75, float(i)),
			-30.0
		)
		_bullet_container.add_child(pickup)

# ── FORMATION SPAWN ───────────────────────────────────────────────────────────
func _spawn_formation() -> void:
	var vp := get_viewport().get_visible_rect().size

	# Lưới tăng dần: bắt đầu 6x4, mỗi 4 wave bình thường thêm 1 cột (tối đa 9 cột)
	var tier: int = (current_wave - 1) / 4   # tăng mỗi 4 wave
	var cols: int = mini(6 + tier, 9)
	var rows: int = 4

	var spacing_x: float = vp.x / float(cols + 1)
	var spacing_y: float = 65.0
	var start_y:   float = 50.0

	var positions: Array = []
	for row in range(rows):
		for col in range(cols):
			positions.append(Vector2(spacing_x * float(col + 1), start_y + float(row) * spacing_y))

	var spawner = _spawner
	if not spawner:
		return
	enemies_alive = positions.size()

	var shoot_interval: float = max(5.0 - float(current_wave) * 0.18, 1.2)
	# attack_tier 0–4: tăng mỗi 4 wave — quyết định kiểu bắn
	var attack_tier: int = clampi((current_wave - 1) / 4, 0, 4)
	# số move pattern có thể dùng tăng dần theo tier
	var patterns_avail: int = mini(attack_tier + 1, 5)
	# tốc độ ngang tăng nhẹ theo wave
	var spd_base: float = 45.0 + float(current_wave) * 1.5

	# Spawn theo hàng: mỗi hàng bay xuống cùng nhau, hàng sau cách 0.25s
	for row in range(rows):
		if row > 0:
			await get_tree().create_timer(0.25).timeout
		for col in range(cols):
			var idx2: int = row * cols + col
			var target_pos: Vector2 = positions[idx2]
			var enemy = ENEMY_SCENE.instantiate()
			# Xuất phát từ trên viền màn hình, lệch nhẹ theo cột
			enemy.base_speed *= 1.0 + float(current_wave - 1) * SPEED_SCALE
			enemy.max_hp = 1 + (current_wave - 1) / 2
			enemy.hp = enemy.max_hp
			enemy.score_value  = 10 * current_wave
			enemy.shoot_interval = shoot_interval
			enemy.stationary   = true
			enemy._move_dir    = 1.0 if (idx2 % 2 == 0) else -1.0
			enemy._move_speed  = spd_base + float(idx2 % 4) * 10.0
			enemy.move_pattern = idx2 % patterns_avail
			enemy.attack_tier  = attack_tier
			enemy.enemy_type   = row % 3   # mỗi hàng một kiểu
			enemy.died.connect(_on_enemy_died)
			spawner.add_child(enemy)
			# Set vị trí sau add_child để đảm bảo global transform đúng
			enemy.global_position = Vector2(target_pos.x, -40.0 - float(col) * 3.0)
			enemy.start_fly_in(target_pos)  # bay xuống vị trí hàng

# ── ASTEROID WAVE ─────────────────────────────────────────────────────────────
# Thay thế đội hình thường bằng màn mưa thiên thạch — mỗi wave thứ 3 (không boss)
func _spawn_asteroid_wave() -> void:
	var vp    := get_viewport().get_visible_rect().size
	var main  = get_parent()
	var container := _asteroid_container

	if main and main.has_method("show_alert"):
		main.show_alert("☄  ASTEROID SHOWER!")

	var shower_idx: int = current_wave / 3
	# Số lượng random tăng theo wave
	var count: int = randi_range(10 + shower_idx * 2, 16 + shower_idx * 3)
	count = mini(count, 30)

	# HP và tốc độ tăng theo wave
	var hp_bonus: int    = shower_idx / 2
	var base_speed: float = 150.0 + float(shower_idx) * 15.0

	enemies_alive = count

	for i in range(count):
		# Khoảng cách giữa các thiên thạch hoàn toàn random
		await get_tree().create_timer(randf_range(0.25, 0.75)).timeout
		if not wave_in_progress: return

		var ast = ASTEROID_SCENE.instantiate()

		# Kích thước ngẫu nhiên — tier 2 (to) hiếm hơn
		var tier_roll := randf()
		var tier: int = 0
		if   tier_roll < 0.35: tier = 0   # 35% nhỏ
		elif tier_roll < 0.75: tier = 1   # 40% vừa
		else:                  tier = 2   # 25% to

		ast.size_tier   = tier
		ast._scale_mul  = randf_range(0.8, 1.3)   # kích thước random trong tier
		ast.hp          = ast.BASE_HP[tier] + hp_bonus

		# Vị trí X hoàn toàn random, đôi khi từ bên cạnh
		var from_side := randf() < 0.15   # 15% rơi từ cạnh
		if from_side:
			var left_side := randf() < 0.5
			ast.global_position = Vector2(
				-30.0 if left_side else vp.x + 30.0,
				randf_range(50.0, vp.y * 0.5)
			)
			ast.direction = Vector2(1.0 if left_side else -1.0, randf_range(0.5, 1.2)).normalized()
		else:
			ast.global_position = Vector2(randf_range(30.0, vp.x - 30.0), -30.0)
			var angle_offset := randf_range(-0.5, 0.5)
			ast.direction = Vector2(sin(angle_offset), cos(angle_offset)).normalized()

		ast.speed      = base_speed * randf_range(0.7, 1.4)
		ast._rot_speed = randf_range(-2.8, 2.8)
		ast.died.connect(_on_enemy_died)
		if container:
			container.add_child(ast)
