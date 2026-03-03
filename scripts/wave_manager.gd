extends Node
# wave_manager.gd — Formation spawning với đa dạng hình thái.
# Hỗ trợ level config từ PlayerData.current_level:
#   max_waves, hp_mult, boss_hp_mult, asteroid_rate, theme (boss_rush, v.v.)
# Khi hết toàn bộ enemy → emit wave_cleared → main.gd tự động qua wave mới.

signal wave_cleared
signal level_completed   # phát khi đã qua hết max_waves

const ENEMY_SCENE          = preload("res://scenes/enemy.tscn")
const BOSS_SCENE           = preload("res://scenes/boss.tscn")
const ASTEROID_SCENE       = preload("res://scenes/asteroid.tscn")
const SPECIAL_PICKUP_SCENE = preload("res://scenes/special_pickup.tscn")

const SPEED_SCALE: float = 0.12   # tốc độ tăng mỗi wave

var current_wave:    int  = 0
var enemies_alive:   int  = 0
var wave_in_progress: bool = false
var _boss_encounter: int  = 0

# Tham số từ level hiện tại
var _max_waves:      int   = 999
var _hp_mult:        float = 1.0
var _boss_hp_mult:   float = 1.0
var _asteroid_rate:  float = 0.25   # xác suất wave asteroid (0–1)
var _boss_rush:      bool  = false  # Boss Rush: mọi wave đều là boss
var _boss_waves:     Array = []     # Danh sách wave xuất hiện boss (tính sẵn)

# Cache node con cùng cấp
var _spawner: Node2D              = null
var _bullet_container: Node2D    = null
var _asteroid_container: Node2D  = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE   # dừng khi game pause
	_spawner           = get_parent().get_node_or_null("EnemySpawner")
	_bullet_container  = get_parent().get_node_or_null("BulletContainer")
	var _ac := get_parent().get_node_or_null("AsteroidContainer")
	_asteroid_container = _ac if _ac != null else _bullet_container
	# Đọc config level
	var lv: Dictionary = PlayerData.current_level
	_max_waves     = lv.get("max_waves",      999)
	_hp_mult       = lv.get("hp_mult",        1.0)
	_boss_hp_mult  = lv.get("boss_hp_mult",   1.0)
	_asteroid_rate = lv.get("asteroid_rate",  0.25)
	_boss_rush     = (lv.get("theme", -1) == 2)  # theme index 2 = Boss Rush
	_boss_waves    = _calc_boss_waves()

# Chia đều boss vào các wave theo số wave thực tế của màn
#   ≤ 7  wave  → 2 boss   (vd: 5→[3,5]  6→[3,6]  7→[4,7])
#   8–17 wave  → 3 boss   (vd: 9→[3,6,9]  14→[5,9,14]  15→[5,10,15])
#   ≥ 18 wave  → 4 boss   (vd: 18→[5,9,14,18]  30→[8,15,23,30])
func _calc_boss_waves() -> Array:
	if _boss_rush: return []   # Boss Rush tự xử lý
	var boss_count: int
	if _max_waves <= 7:
		boss_count = 2
	elif _max_waves <= 17:
		boss_count = 3
	else:
		boss_count = 4
	var result: Array = []
	for k in range(boss_count):
		var w: int = roundi(float(_max_waves) * float(k + 1) / float(boss_count))
		result.append(w)
	return result

# ── PUBLIC API ────────────────────────────────────────────────────────────────
func start_wave(wave_number: int) -> void:
	current_wave = wave_number
	enemies_alive = 0
	wave_in_progress = true
	await get_tree().create_timer(0.5).timeout

	# Boss Rush: gần như mọi wave đều là boss
	if _boss_rush:
		_spawn_boss()
		return

	# Boss xuất hiện theo danh sách đã chia đều
	if current_wave in _boss_waves:
		_spawn_boss()
	# Asteroid: tỉ lệ theo config level (wave thứ 3 mặc định + random thêm)
	elif (current_wave % 3 == 0) or (randf() < _asteroid_rate * 0.5):
		_spawn_asteroid_wave()
	else:
		_spawn_formation()

# ── ENEMY DEATH CALLBACK ─────────────────────────────────────────────────────
func _on_enemy_died() -> void:
	enemies_alive -= 1
	if enemies_alive <= 0 and wave_in_progress:
		wave_in_progress = false
		# Kiểm tra đã qua hết màn chưa
		if current_wave >= _max_waves:
			emit_signal("level_completed")
		else:
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
	# Hiển thị thanh máu boss — dùng scaled_hp để bar max khớp HP thực của boss
	var bar_hp: int = int(float(base_hp) * _boss_hp_mult)
	var main = get_parent()
	if main and main.has_method("show_boss_hp"):
		main.show_boss_hp(bar_hp, bar_hp)

func _make_boss(btype: int, bhp: int, bspd: float, x_pos: float) -> void:
	var boss = BOSS_SCENE.instantiate()
	if not _spawner: return
	boss.boss_type = btype
	var scaled_hp: int = int(float(bhp) * _boss_hp_mult)
	boss.max_hp    = scaled_hp
	boss.hp        = scaled_hp
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

# ── FORMATION SPAWN — 10 hình thái khác nhau ──────────────────────────────
func _spawn_formation() -> void:
	var vp := get_viewport().get_visible_rect().size

	# Chọn hình thái ngẫu nhiên theo wave, đảm bảo đa dạng
	var formation_types := 10
	var form_type: int  = randi() % formation_types

	var positions: Array = _build_positions(form_type, vp)
	if positions.is_empty():
		positions = _grid_positions(6, 4, vp)  # fallback

	var spawner := _spawner
	if not spawner: return
	enemies_alive = positions.size()

	var shoot_interval: float = max(5.0 - float(current_wave) * 0.18, 1.2)
	var attack_tier: int      = clampi((current_wave - 1) / 4, 0, 4)
	var patterns_avail: int   = mini(attack_tier + 1, 5)
	var spd_base: float       = 45.0 + float(current_wave) * 1.5

	# Hiển thị alert tên hình thái
	var shape_names := [
		"GRID", "DIAMOND", "STAR", "V-FORMATION",
		"PINCER", "RING", "CROSS", "STAIRS",
		"ARROWHEAD", "SPIRAL"
	]
	var main = get_parent()
	if main and main.has_method("show_alert"):
		main.show_alert("[ %s ]" % shape_names[form_type])

	# Spawn từng enemy theo vị trí
	for idx in range(positions.size()):
		if idx > 0 and idx % 6 == 0:
			await get_tree().create_timer(0.22).timeout
		var target_pos: Vector2 = positions[idx]
		var enemy = ENEMY_SCENE.instantiate()
		var scaled_hp: int = max(1, int(float(1 + (current_wave - 1) / 2) * _hp_mult))
		enemy.base_speed     *= 1.0 + float(current_wave - 1) * SPEED_SCALE
		enemy.max_hp          = scaled_hp
		enemy.hp              = scaled_hp
		enemy.score_value     = 10 * current_wave
		enemy.shoot_interval  = shoot_interval
		enemy.stationary      = true
		enemy._move_dir       = 1.0 if (idx % 2 == 0) else -1.0
		enemy._move_speed     = spd_base + float(idx % 4) * 10.0
		enemy.move_pattern    = idx % patterns_avail
		enemy.attack_tier     = attack_tier
		enemy.enemy_type      = idx % 3
		enemy.died.connect(_on_enemy_died)
		spawner.add_child(enemy)
		enemy.global_position = Vector2(target_pos.x, -40.0 - float(idx % 5) * 4.0)
		enemy.start_fly_in(target_pos)

# ── HÌNH THÁI SPAWN ─────────────────────────────────────────────────────────
func _build_positions(form_type: int, vp: Vector2) -> Array:
	match form_type:
		0: return _grid_positions(6, 4, vp)
		1: return _diamond_positions(vp)
		2: return _star_positions(vp)
		3: return _v_formation_positions(vp)
		4: return _pincer_positions(vp)
		5: return _ring_positions(vp)
		6: return _cross_positions(vp)
		7: return _stairs_positions(vp)
		8: return _arrowhead_positions(vp)
		9: return _spiral_positions(vp)
	return []

# 0: Lưới tiêu chuẩn — đôi khi tăng kích thước
func _grid_positions(cols: int, rows: int, vp: Vector2) -> Array:
	var tier: int  = (current_wave - 1) / 4
	var c: int     = mini(cols + tier, 9)
	var r: int     = mini(rows + tier / 3, 6)
	var sx := vp.x / float(c + 1)
	var sy := 62.0
	var pts: Array = []
	for row in range(r):
		for col in range(c):
			pts.append(Vector2(sx * float(col + 1), 55.0 + float(row) * sy))
	return pts

# 1: Hình thoi
func _diamond_positions(vp: Vector2) -> Array:
	var cx := vp.x * 0.5
	var pts: Array = []
	# 5 hàng: 1-3-5-3-1
	var counts := [1, 3, 5, 3, 1]
	for row in range(counts.size()):
		var n: int = counts[row]
		for col in range(n):
			var dx := (float(col) - float(n - 1) * 0.5) * 72.0
			pts.append(Vector2(cx + dx, 45.0 + float(row) * 60.0))
	return pts

# 2: Hình ngôi sao 5 cánh (24 điểm)
func _star_positions(vp: Vector2) -> Array:
	var cx := vp.x * 0.5
	var cy := 155.0
	var pts: Array = []
	var r_outer := 130.0
	var r_inner := 60.0
	for i in range(10):
		var angle := TAU * float(i) / 10.0 - PI * 0.5
		var r := r_outer if (i % 2 == 0) else r_inner
		pts.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))
	# Thêm vòng trong thứ 2 (14 điểm)
	for i in range(14):
		var angle := TAU * float(i) / 14.0
		pts.append(Vector2(cx + cos(angle) * 35.0, cy + sin(angle) * 35.0))
	return pts

# 3: Chữ V
func _v_formation_positions(vp: Vector2) -> Array:
	var cx := vp.x * 0.5
	var pts: Array = []
	var arms := 5
	for side in [-1, 1]:
		for i in range(arms):
			pts.append(Vector2(cx + side * float(i + 1) * 55.0, 48.0 + float(i) * 55.0))
	pts.append(Vector2(cx, 48.0))  # đỉnh V
	return pts

# 4: Gọng kìm (2 cánh cung)
func _pincer_positions(vp: Vector2) -> Array:
	var cx := vp.x * 0.5
	var pts: Array = []
	for side in [-1.0, 1.0]:
		for i in range(6):
			var angle := deg_to_rad(float(i) * 14.0 - 35.0)
			pts.append(Vector2(cx + side * (85.0 + cos(angle) * 90.0),
								85.0 + sin(angle) * 80.0))
	return pts

# 5: Vòng tròn (18 địch)
func _ring_positions(vp: Vector2) -> Array:
	var cx := vp.x * 0.5
	var cy := 140.0
	var pts: Array = []
	var n := 18
	for i in range(n):
		var angle := TAU * float(i) / float(n)
		pts.append(Vector2(cx + cos(angle) * 115.0, cy + sin(angle) * 90.0))
	# Thêm 6 ở vòng trong
	for i in range(6):
		var angle := TAU * float(i) / 6.0
		pts.append(Vector2(cx + cos(angle) * 50.0, cy + sin(angle) * 50.0))
	return pts

# 6: Hình thập tự (+)
func _cross_positions(vp: Vector2) -> Array:
	var cx := vp.x * 0.5
	var cy := 140.0
	var pts: Array = []
	# ngang
	for i in range(-3, 4):
		pts.append(Vector2(cx + float(i) * 60.0, cy))
	# dọc (bỏ tâm)
	for i in [-2, -1, 1, 2]:
		pts.append(Vector2(cx, cy + float(i) * 55.0))
	return pts

# 7: Cầu thang lệch (2 hàng dọc lệch nhau)
func _stairs_positions(vp: Vector2) -> Array:
	var pts: Array = []
	var cols := 8
	var sx := vp.x / float(cols + 1)
	for col in range(cols):
		pts.append(Vector2(sx * float(col + 1), 50.0 + float(col) * 25.0))
		pts.append(Vector2(sx * float(col + 1), 90.0 + float(col) * 25.0))
	return pts

# 8: Mũi tên (Arrowhead — chỉ lên trên)
func _arrowhead_positions(vp: Vector2) -> Array:
	var cx := vp.x * 0.5
	var pts: Array = []
	var layers := 5
	for row in range(layers):
		var n := 2 * row + 1
		for col in range(n):
			var dx := (float(col) - float(n - 1) * 0.5) * 60.0
			pts.append(Vector2(cx + dx, 50.0 + float(row) * 55.0))
	return pts

# 9: Xoắn ốc (20 điểm)
func _spiral_positions(vp: Vector2) -> Array:
	var cx := vp.x * 0.5
	var cy := 155.0
	var pts: Array = []
	var n := 20
	for i in range(n):
		var angle := float(i) * 0.55
		var radius := 20.0 + float(i) * 6.5
		pts.append(Vector2(cx + cos(angle) * radius, cy + sin(angle) * radius * 0.7))
	return pts

# ── ASTEROID WAVE ──────────────────────────────────────────────────────────
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
