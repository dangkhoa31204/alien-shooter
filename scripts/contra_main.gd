extends Node2D

# contra_main.gd
# Premium Side-scrolling controller with Bombers and Progress Tracking.

const PLAYER_SCENE = preload("res://scenes/contra_player.tscn")
const ENEMY_SCENE  = preload("res://scenes/contra_enemy.tscn")
const BOMBER_SCENE = preload("res://scenes/contra_bomber.tscn")
const TURRET_SCENE = preload("res://scenes/contra_turret.tscn")
const TANK_SCENE   = preload("res://scripts/contra_tank.gd")

var STAGE_LENGTH: float = 12000.0 # Increased for longer gameplay

var current_stage: int = 1
var score: int = 0
var is_game_over: bool = false

@onready var ui_label: Label = $UI/Label
@onready var stage_label: Label = $UI/StageLabel
@onready var camera: Camera2D = $Camera2D
@onready var bullet_container: Node2D = $BulletContainer

var progress_bar: ProgressBar
var hp_bar: ProgressBar
var player: CharacterBody2D = null
var _world: Node2D = null
var _parallax_bg: Node2D = null
var _cheat_menu: Control = null
var _is_cheat_visible: bool = false
var _pause_menu: Control = null
var _is_paused: bool = false

# Screen shake state
var _shake_power: float = 0.0
var _shake_time: float = 0.0
var _bomber_timer: float = 5.0
var _army_spawn_timer: float = 1.0 
var _enemy_spawn_timer: float = 2.0 # Dynamic enemy spawn
var _stage_terrain: PackedVector2Array = PackedVector2Array()

func _get_ground_y(x: float) -> float:
	if current_stage in [1, 2, 3] and not _stage_terrain.is_empty():
		for i in range(_stage_terrain.size() - 1):
			var p1 = _stage_terrain[i]
			var p2 = _stage_terrain[i+1]
			if x >= p1.x and x <= p2.x:
				var t = (x - p1.x) / max(0.01, p2.x - p1.x)
				return lerp(p1.y, p2.y, t)
	return 600.0

func _ready() -> void:
	_world = Node2D.new(); _world.name = "World"; add_child(_world)
	move_child(_world, 0)
	
	_parallax_bg = Node2D.new(); _parallax_bg.name = "Parallax"; _world.add_child(_parallax_bg)
	
	_setup_background_sky()
	_setup_progress_ui()
	
	if not has_node("Camera2D"):
		camera = Camera2D.new()
		add_child(camera)
		camera.make_current()
	
	_setup_cheat_menu()
	_setup_pause_menu()
	_start_stage(PlayerData.current_selected_stage)
	
	# Đảm bảo các đối tượng con của root (world, objects) sẽ pause khi tree paused
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	if camera: camera.process_mode = Node.PROCESS_MODE_PAUSABLE
	if bullet_container: bullet_container.process_mode = Node.PROCESS_MODE_PAUSABLE
	$UI.process_mode = Node.PROCESS_MODE_PAUSABLE

func _setup_progress_ui() -> void:
	# Add Progress Bar
	progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.size = Vector2(400, 10)
	progress_bar.position = Vector2(376, 30) # Top middle
	progress_bar.max_value = STAGE_LENGTH
	progress_bar.show_percentage = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0,0,0,0.5)
	style.border_width_left = 1; style.border_width_right = 1; style.border_width_top = 1; style.border_width_bottom = 1
	style.border_color = Color(1, 1, 0.4, 0.5)
	progress_bar.add_theme_stylebox_override("background", style)
	
	var fg_style = StyleBoxFlat.new()
	fg_style.bg_color = Color(1, 0.9, 0.2) # Gold
	progress_bar.add_theme_stylebox_override("fill", fg_style)
	
	$UI.add_child(progress_bar)
	
	var prog_lbl = Label.new()
	prog_lbl.text = "TIẾN TRÌNH CHIẾN DỊCH"
	prog_lbl.add_theme_font_size_override("font_size", 12)
	prog_lbl.position = Vector2(376, 10)
	$UI.add_child(prog_lbl)

	# Add HP Bar
	hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.size = Vector2(180, 16)
	hp_bar.position = Vector2(20, 60)
	hp_bar.max_value = 3
	hp_bar.value = 3
	hp_bar.show_percentage = false
	
	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.2, 0.05, 0.05, 0.7)
	hp_bg.border_width_left = 1; hp_bg.border_width_right = 1; hp_bg.border_width_top = 1; hp_bg.border_width_bottom = 1
	hp_bg.border_color = Color(0.8, 0.2, 0.2, 0.6)
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	
	var hp_fg = StyleBoxFlat.new()
	hp_fg.bg_color = Color(0.9, 0.1, 0.1) # Bright Red
	hp_bar.add_theme_stylebox_override("fill", hp_fg)
	
	$UI.add_child(hp_bar)
	
	var hp_lbl = Label.new()
	hp_lbl.text = "SINH LỰC"
	hp_lbl.add_theme_font_size_override("font_size", 14)
	hp_lbl.position = Vector2(20, 42)
	$UI.add_child(hp_lbl)

func refresh_hp(val: int, max_val: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_val
		hp_bar.value = val

func refresh_ammo(val: int, max_val: int, is_rel: bool) -> void:
	if not has_node("UI/AmmoLabel"):
		var lbl = Label.new()
		lbl.name = "AmmoLabel"
		lbl.position = Vector2(20, 85)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color.YELLOW)
		$UI.add_child(lbl)
	
	var al = $UI/AmmoLabel
	if is_rel:
		al.text = "ĐANG NẠP ĐẠN..."
		al.add_theme_color_override("font_color", Color.RED)
	else:
		al.text = "ĐẠN: %d / %d" % [val, max_val]
		al.add_theme_color_override("font_color", Color.YELLOW)

func _process(delta: float) -> void:
	if is_game_over: return
	var tree = get_tree()
	if not tree: return
	if tree.paused: return
	
	if is_instance_valid(player):
		var target_x = player.position.x
		camera.position.x = lerp(camera.position.x, target_x, 8.0 * delta)
		camera.position.x = clamp(camera.position.x, 576, STAGE_LENGTH - 500)
		
		# Vertical Camera Follow (Follow player into tunnels)
		var target_y = 360.0
		if player.position.y > 650:
			target_y = 550.0 # Shift down to see the tunnel path clearly
		camera.position.y = lerp(camera.position.y, target_y, 4.0 * delta)
		
		_parallax_bg.position.x = camera.position.x * 0.4
		
		# Update Progress Bar
		progress_bar.value = player.position.x
		
		if player.position.x > STAGE_LENGTH - 100: on_stage_complete()
		
		# Update Background Army positions to follow player
		_process_background_army(delta)
		
		# Continuous Spawning: 4-5 soldiers every ~3s on BOTH paths
		_army_spawn_timer -= delta
		if _army_spawn_timer <= 0:
			# Spawn 5-6 soldiers per wave, spread out widely (Fewer on Stage 5)
			var spawn_count = randi_range(2, 3) if current_stage == 5 else randi_range(5, 6)
			for _si in spawn_count:
				var sx = camera.position.x + 800 + randf_range(0, 1500)
				var sy: float
				# Randomly pick upper (terrain) or lower (tunnel) path
				var use_tunnel = false
				if current_stage == 2 or current_stage == 3:
					use_tunnel = randf() < 0.5
				if use_tunnel:
					sy = 650.0 # Tunnel lower path — just above tunnel_y=660
				else:
					sy = _get_ground_y(sx)
				_add_individual_background_soldier(sx, sy)
			_army_spawn_timer = randf_range(12.0, 16.0) if current_stage == 5 else randf_range(7.0, 9.0)
		
		# Dynamic Enemy Spawning (To keep the action going)
		_enemy_spawn_timer -= delta
		if _enemy_spawn_timer <= 0:
			var enemies = tree.get_nodes_in_group("enemy").size()
			var max_enemies = 12 if current_stage == 2 else (6 if current_stage == 3 else (4 if current_stage == 5 else 8))
			if enemies < max_enemies:
				var spawn_x = camera.position.x + 900 + randf_range(100, 400) # Spaced further away
				if spawn_x < STAGE_LENGTH - 400:
					var ey = _get_ground_y(spawn_x) - 100
					if current_stage == 2: ey = 550
					_spawn_enemy(spawn_x, ey, randf() < 0.25)
			
			var st_timer = randf_range(2.0, 4.0)
			if current_stage == 2: st_timer = randf_range(1.5, 3.0)
			if current_stage == 3: st_timer = randf_range(3.5, 6.0) # Thưa ra
			if current_stage == 5: st_timer = randf_range(4.5, 8.0) # Rất thưa
			_enemy_spawn_timer = st_timer

		# Random Bomber Spawns (Scales with difficulty/stage)
		_bomber_timer -= delta
		if _bomber_timer <= 0:
			_spawn_bomber()
			var base_timer = lerp(12.0, 4.0, float(current_stage - 1) / 4.0)
			# Stage 3 Special: Much higher bomber frequency
			if current_stage == 3: base_timer *= 0.4 
			_bomber_timer = randf_range(base_timer * 0.7, base_timer * 1.3)

		# Check for bombs hitting the ground
		_process_bombs(delta)

	if _shake_time > 0:
		_shake_time -= delta
		camera.offset = Vector2(randf_range(-_shake_power, _shake_power), randf_range(-_shake_power, _shake_power))
	else:
		camera.offset = Vector2.ZERO

func _process_bombs(delta: float) -> void:
	var tree = get_tree()
	if not tree: return
	var space_state = get_world_2d().direct_space_state
	for b in tree.get_nodes_in_group("enemy_bullet"):
		if not is_instance_valid(b) or not b.has_meta("is_bomb"): continue
		
		# Check for collision with ground/platforms
		var ground_y = _get_ground_y(b.global_position.x)
		if b.global_position.y >= ground_y - 15:
			var query = PhysicsRayQueryParameters2D.create(b.global_position, b.global_position + Vector2(0, 20))
			var result = space_state.intersect_ray(query)
			
			if result or b.global_position.y >= ground_y - 5:
				_explode_bomb(b.global_position)
				b.queue_free()
			elif b.global_position.y > 1000: # Final cleanup if it misses everything
				b.queue_free()
		
		elif b.has_meta("is_tank_shell"):
			# Tank shells also explode on floor
			var query = PhysicsRayQueryParameters2D.create(b.global_position, b.global_position + Vector2(0, 15))
			var result = space_state.intersect_ray(query)
			if result or b.global_position.y >= ground_y - 5:
				_explode_bomb(b.global_position)
				b.queue_free()

func _explode_bomb(pos: Vector2) -> void:
	screen_shake(8.0, 0.4)
	Audio.play("explosion")
	
	# Create a visual crater (a dark pit in the ground)
	_create_crater(pos)
	
	# Damage player if nearby
	if is_instance_valid(player) and player.global_position.distance_to(pos) < 80.0:
		player.take_damage(2)

func _create_crater(pos: Vector2) -> void:
	var crater = Polygon2D.new()
	var pts = []
	var res = 12
	var radius = randf_range(30, 50)
	for i in res:
		var a = i * TAU / res
		var r = radius * (0.8 + randf() * 0.4)
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.4))
	crater.polygon = PackedVector2Array(pts)
	crater.color = Color(0.1, 0.05, 0.0, 0.8) # Burnt soil
	crater.position = Vector2(pos.x, _get_ground_y(pos.x)) # Stick to floor
	_world.add_child(crater)
	
	# Add some smoke particles (simple version)
	for i in 5:
		var smoke = ColorRect.new()
		smoke.size = Vector2(8, 8)
		smoke.color = Color(0.4, 0.4, 0.4, 0.6)
		smoke.position = pos + Vector2(randf_range(-20, 20), randf_range(-10, 0))
		_world.add_child(smoke)
		var tw = create_tween()
		tw.tween_property(smoke, "position:y", smoke.position.y - 40, 1.0)
		tw.tween_property(smoke, "modulate:a", 0.0, 1.0)
		tw.finished.connect(smoke.queue_free)

func _spawn_bomber() -> void:
	var b = BOMBER_SCENE.instantiate()
	# Spawn ahead of camera
	var spawn_x = camera.position.x + 800
	var spawn_y = randf_range(50, 150)
	b.position = Vector2(spawn_x, spawn_y)
	b.direction = -1
	# Ensure they are added to world so they scroll correctly
	_world.add_child(b)

func spawn_shell(pos: Vector2, dir: float) -> void:
	var shell = ColorRect.new()
	shell.size = Vector2(4, 2)
	shell.color = Color(1, 0.8, 0.2) # Brass
	shell.position = pos
	_world.add_child(shell)
	
	var tw = create_tween()
	var jump_x = randf_range(30, 60) * -dir
	var jump_y = -randf_range(40, 80)
	tw.tween_property(shell, "position", pos + Vector2(jump_x, jump_y), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(shell, "rotation", randf_range(-PI, PI), 0.2)
	tw.tween_property(shell, "position:y", 600, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(shell, "modulate:a", 0.0, 2.0)
	tw.finished.connect(shell.queue_free)

func _setup_background_sky(sky_color: Color = Color(0.1, 0.3, 0.6)) -> void:
	var sky = ColorRect.new(); sky.name = "BackgroundSky"; sky.size = Vector2(40000, 1000); sky.position = Vector2(-10000, -200); sky.z_index = -100
	sky.color = sky_color 
	_world.add_child(sky)
	
	var glow = Polygon2D.new(); _world.add_child(glow); glow.z_index = -95
	var g_pts = []
	for i in 16:
		var a = i * TAU / 16.0
		g_pts.append(Vector2(cos(a) * 400 + 4000, sin(a) * 150 + 100))
	glow.polygon = PackedVector2Array(g_pts); glow.color = Color(1.0, 0.8, 0.4, 0.15)
	
	for i in range(12):
		var mt = Polygon2D.new(); _parallax_bg.add_child(mt); mt.z_index = -90
		var mx = i * 800 - 2000; var h = randf_range(200, 450)
		mt.polygon = PackedVector2Array([Vector2(0, 720), Vector2(400, 720 - h), Vector2(800, 720)])
		mt.color = Color(0.12, 0.22, 0.4, 0.5)

func _start_stage(stage_num: int) -> void:
	current_stage = stage_num
	STAGE_LENGTH = 12000.0 # Reset to default
	if progress_bar: progress_bar.max_value = STAGE_LENGTH
	_cleanup_level()
	_load_stage_data(stage_num)
	_spawn_player()
	_show_stage_intro(stage_num)

func _cleanup_level() -> void:
	for n in _world.get_children():
		if n.name in ["Parallax", "BackgroundSky"]: continue
		if n is ColorRect and n.z_index == -10: continue
		if n is Polygon2D and n.z_index == -9: continue
		n.queue_free()
	
	var tree = get_tree()
	if tree:
		for n in tree.get_nodes_in_group("enemy"): n.queue_free()
		for n in tree.get_nodes_in_group("bullet"): n.queue_free()
		for n in tree.get_nodes_in_group("player_bullet"): n.queue_free()
		for n in tree.get_nodes_in_group("enemy_bullet"): n.queue_free()
	if is_instance_valid(player): player.queue_free()

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	_world.add_child(player) # Add to world for scrolling
	player.position = Vector2(100, 500)

func _load_stage_data(num: int) -> void:
	match num:
		1: _setup_jungle()
		2: _setup_tunnels()
		3: _setup_highlands()
		4: _setup_base()
		5: _setup_final_push()

func _setup_jungle() -> void:
	# Stage 1: Ancient Jungle - Lush & Magnificent
	_setup_background_sky(Color(0.5, 0.8, 0.9)) # Bright, hazy tropical sky
	
	# Distant Karst Mountains (Ha Long Bay style lime-stone peaks)
	for i in 10:
		var mt = Polygon2D.new()
		var mx = i * 1200 + randf_range(-200, 200)
		var mw = randf_range(300, 500); var mh = randf_range(400, 600)
		mt.polygon = PackedVector2Array([
			Vector2(-mw, 600), Vector2(-mw*0.6, 600-mh*0.8), 
			Vector2(0, 600-mh), Vector2(mw*0.5, 600-mh*0.7), Vector2(mw, 600)
		])
		mt.color = Color(0.4, 0.6, 0.6, 0.6) # Hazy blue-green
		mt.position.x = mx; mt.z_index = -9
		_parallax_bg.add_child(mt)

	# Mid-ground: Dense Bamboo/Thin trees layer
	for i in 40:
		var bx = i * 200 + randf_range(-50, 50)
		var bamboo = ColorRect.new()
		bamboo.size = Vector2(8, 600); bamboo.position = Vector2(bx, 0)
		bamboo.color = Color(0.15, 0.4, 0.1, 0.4); bamboo.z_index = -8
		_parallax_bg.add_child(bamboo)

	# Giant Hero Trees (Ancient Gnarled Trees from reference)
	for i in range(12):
		var tx = i * 800 + randf_range(-100, 100)
		_create_giant_ancient_tree(Vector2(tx, 600))

	_generate_hilly_terrain(Color(0.15, 0.1, 0.05), Color(0.08, 0.22, 0.05), false)

	# Hanging Vines with leaves
	for i in 30:
		var vx = randf_range(0, STAGE_LENGTH)
		_create_hanging_vine_detailed(vx)

	_spawn_background_soldiers(8) 
	_spawn_enemy_wave(12, 0.1) # Pre-spawn some initial enemies
	# Extra enemies right at the start to ensure visibility
	_spawn_enemy(400, 500); _spawn_enemy(700, 500)

func _create_giant_ancient_tree(pos: Vector2) -> void:
	var tree = Node2D.new(); tree.position = pos; _world.add_child(tree)
	# Thick, curved trunk with roots
	var trunk = Polygon2D.new()
	var tw = randf_range(60, 90)
	trunk.polygon = PackedVector2Array([
		Vector2(-tw*1.2, 0), Vector2(-tw, -80), Vector2(-tw*0.6, -300), 
		Vector2(tw*0.4, -300), Vector2(tw*0.8, -80), Vector2(tw*1.2, 0)
	])
	trunk.color = Color(0.22, 0.15, 0.08); tree.add_child(trunk)
	
	# Wrapping Vines on trunk
	for v in 4:
		var vine = Polygon2D.new()
		var vy = -v * 70
		vine.polygon = PackedVector2Array([Vector2(-tw*0.8, vy), Vector2(tw*0.8, vy-20), Vector2(tw*0.8, vy-10), Vector2(-tw*0.8, vy+10)])
		vine.color = Color(0.1, 0.3, 0.05); tree.add_child(vine)

	# Massive Canopy Layers
	for layer in 3:
		var layer_y = -300 - layer * 80
		for leaf in 12:
			var l = Polygon2D.new(); var a = leaf * PI / 6.0
			var size = randf_range(80, 150)
			l.polygon = PackedVector2Array([Vector2(0,0), Vector2(size, -40), Vector2(size*0.8, 40)])
			l.color = Color(0.05, 0.2 + layer*0.1, 0.02).lightened(randf()*0.2)
			l.rotation = a; l.position = Vector2(0, layer_y)
			tree.add_child(l)

func _create_jungle_fern(pos: Vector2) -> void:
	var fern = Node2D.new(); fern.position = pos; _world.add_child(fern); fern.z_index = 1
	for i in 8:
		var leaf = Polygon2D.new(); var a = -PI/1.2 - i * PI/6.0
		var lsize = randf_range(20, 45)
		leaf.polygon = PackedVector2Array([Vector2(0,0), Vector2(lsize, -lsize/3.0), Vector2(lsize*0.8, lsize/3.0)])
		leaf.color = Color(0.1, 0.4 + randf()*0.2, 0.05); leaf.rotation = a
		fern.add_child(leaf)

func _create_dense_shrub(pos: Vector2) -> void:
	var shrub = Node2D.new(); shrub.position = pos; _world.add_child(shrub); shrub.z_index = 1
	for i in 10:
		var leaf = Polygon2D.new()
		var s = randf_range(15, 30)
		leaf.polygon = PackedVector2Array([Vector2(-s, 0), Vector2(0, -s*1.5), Vector2(s, 0)])
		leaf.color = Color(0.05, 0.3, 0.02).lightened(randf()*0.3)
		leaf.position = Vector2(randf_range(-20, 20), 0)
		shrub.add_child(leaf)

func _create_hanging_vine_detailed(x: float) -> void:
	var v_len = randf_range(300, 500)
	var vine = Line2D.new(); _world.add_child(vine)
	vine.width = 2.0; vine.default_color = Color(0.1, 0.3, 0.05)
	var pts = []
	for i in 10: pts.append(Vector2(x + sin(i)*10, i * v_len/10 - 100))
	vine.points = PackedVector2Array(pts)
	
	# Add small leaves along the vine
	for i in 6:
		var lp = pts[i+2]
		var leaf = ColorRect.new(); leaf.size = Vector2(6, 4); leaf.position = lp; leaf.color = Color(0.2, 0.5, 0.1); leaf.rotation = randf()
		_world.add_child(leaf)

func _setup_tunnels() -> void:
	# Stage 2: Củ Chi Tunnels (Dual-path System with Vertical Depth)
	_setup_background_sky(Color(0.4, 0.7, 0.9))
	
	# Background Mountains
	for i in 6:
		var mt = Polygon2D.new(); var mx = i * 2000; var mw = 2500
		mt.polygon = PackedVector2Array([Vector2(0, 600), Vector2(mw/2, 100), Vector2(mw, 600)])
		mt.color = Color(0.1, 0.25, 0.35, 0.4); mt.position = Vector2(mx, 100); mt.z_index = -90
		_world.add_child(mt)
	
	# Mid-ground decorative hills
	for i in 25:
		var hill = Polygon2D.new()
		var hx = i * 500 + randf_range(-100, 100)
		var hw = randf_range(200, 400); var hh = randf_range(50, 120)
		hill.polygon = PackedVector2Array([Vector2(-hw/2, 600), Vector2(0, 600-hh), Vector2(hw/2, 600)])
		hill.color = Color(0.08, 0.2, 0.05); hill.position.x = hx; hill.z_index = -40
		_world.add_child(hill)

	# ──── KEY LAYOUT PARAMETERS ────
	var surface_y  = 490.0  # Upper path ground
	var tunnel_y   = 660.0  # Lower tunnel floor (much closer now)
	var soil_top_y = 555.0  # Top of the earth divider (tunnel ceiling)
	# ───────────────────────────────

	# Deep soil background below surface
	var soil_bg = ColorRect.new()
	soil_bg.size = Vector2(STAGE_LENGTH + 400, 800)
	soil_bg.position = Vector2(-200, soil_top_y)
	soil_bg.color = Color(0.11, 0.065, 0.038)
	soil_bg.z_index = -22
	_world.add_child(soil_bg)

	# Earth-layer divider between upper and lower path
	var divider = ColorRect.new()
	divider.size = Vector2(STAGE_LENGTH + 400, soil_top_y - surface_y - 8)
	divider.position = Vector2(-200, surface_y + 8)
	divider.color = Color(0.165, 0.092, 0.052)
	divider.z_index = -17
	_world.add_child(divider)

	# Upper path: segmented ground with PHYSICS GAPS for tunnel entry
	# Hole positions every 1000px (player can drop/climb through)
	var hole_width  = 100.0
	var hole_gap    = 1000.0
	var seg_start   = -200.0
	while seg_start < STAGE_LENGTH + 200:
		var hole_x = seg_start + hole_gap
		var seg_end = min(hole_x, STAGE_LENGTH + 200.0)
		var seg_w = seg_end - seg_start
		if seg_w > 10:
			# Physics segment
			var seg_body = StaticBody2D.new()
			var seg_col  = CollisionShape2D.new()
			var seg_shp  = RectangleShape2D.new()
			seg_shp.size = Vector2(seg_w, 40)
			seg_col.shape = seg_shp
			seg_body.position = Vector2(seg_start + seg_w * 0.5, surface_y + 20)
			seg_body.add_child(seg_col)
			_world.add_child(seg_body)
			
			# Grass visual for this segment
			var gv = ColorRect.new()
			gv.size = Vector2(seg_w, 14)
			gv.position = Vector2(seg_start, surface_y - 7)
			gv.color = Color(0.16, 0.44, 0.11)
			gv.z_index = -10
			_world.add_child(gv)
			
			# Dirt under grass
			var dv = ColorRect.new()
			dv.size = Vector2(seg_w, soil_top_y - surface_y)
			dv.position = Vector2(seg_start, surface_y)
			dv.color = Color(0.19, 0.11, 0.055)
			dv.z_index = -14
			_world.add_child(dv)
			
			# Grass tufts along this segment
			for ti in range(int(seg_w / 50)):
				var gx = seg_start + ti * 50 + randf_range(-10, 10)
				var tuft = Polygon2D.new()
				tuft.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(0, -randf_range(8, 16)), Vector2(4, 0)])
				tuft.color = Color(0.11, 0.40, 0.08)
				tuft.position = Vector2(gx, surface_y - 7)
				tuft.z_index = -9
				_world.add_child(tuft)
			
			# Dark arrow hints pointing down into hole (before hole_x)
			if seg_end < STAGE_LENGTH + 100:
				for ar in 3:
					var arrow = Polygon2D.new()
					arrow.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(0, 13)])
					arrow.color = Color(0.95, 0.8, 0.15, 0.8)
					arrow.position = Vector2(hole_x + hole_width * 0.5, surface_y - 30 + ar * 16)
					arrow.z_index = 2
					_world.add_child(arrow)
				# Hole dark pit visual
				var hole_v = ColorRect.new()
				hole_v.size = Vector2(hole_width, soil_top_y - surface_y + 10)
				hole_v.position = Vector2(hole_x, surface_y)
				hole_v.color = Color(0.04, 0.02, 0.01)
				hole_v.z_index = -13
				_world.add_child(hole_v)

		seg_start = hole_x + hole_width  # Skip over hole width

	# Dense surface vegetation — rậm rạp jungle feel
	for i in range(int(STAGE_LENGTH / 110)):
		var tx2 = 100 + i * 110 + randf_range(-40, 40)
		var dice = randf()
		if dice < 0.25:
			_create_palm_tree(Vector2(tx2, surface_y))
		elif dice < 0.45:
			_create_giant_ancient_tree(Vector2(tx2, surface_y))
		elif dice < 0.65:
			_create_dense_shrub(Vector2(tx2, surface_y))
		elif dice < 0.80:
			_create_jungle_fern(Vector2(tx2, surface_y))
		else:
			_create_rock(Vector2(tx2, surface_y))
		# Bamboo cluster (20% chance)
		if randf() < 0.20:
			for b in 3:
				var bamboo = ColorRect.new()
				bamboo.size = Vector2(4, randf_range(80, 180))
				bamboo.position = Vector2(tx2 + b * 8, surface_y - bamboo.size.y)
				bamboo.color = Color(0.1, 0.35, 0.05)
				bamboo.z_index = 1
				_world.add_child(bamboo)

	# ── Stepped platforms on surface (parkour variety) ──
	var step_h_arr = [75, 55, 95, 65, 85, 50, 105]
	var step_w_arr = [210, 165, 245, 185, 225, 155, 265]
	var plat_x = 700.0
	for si in range(24):
		var idx = si % step_h_arr.size()
		var sh = step_h_arr[idx]
		var sw = float(step_w_arr[idx])
		var py = surface_y - sh

		# Platform physics
		var plat = StaticBody2D.new()
		var pcol = CollisionShape2D.new()
		var pshp = RectangleShape2D.new()
		pshp.size = Vector2(sw, 14)
		pcol.shape = pshp
		pcol.one_way_collision = true
		plat.add_child(pcol)
		plat.position = Vector2(plat_x + sw * 0.5, py)
		_world.add_child(plat)

		# Wood-log visual
		var pv = ColorRect.new()
		pv.size = Vector2(sw, 14); pv.position = Vector2(-sw * 0.5, -7)
		pv.color = Color(0.3, 0.18, 0.09)
		plat.add_child(pv)
		var pm = ColorRect.new() # moss top
		pm.size = Vector2(sw, 4); pm.position = Vector2(-sw * 0.5, -9)
		pm.color = Color(0.20, 0.50, 0.13)
		plat.add_child(pm)

		# Support pillar
		var pillar = ColorRect.new()
		pillar.size = Vector2(10, sh)
		pillar.position = Vector2(plat_x + sw * 0.5 - 5, py)
		pillar.color = Color(0.22, 0.13, 0.07)
		pillar.z_index = -8
		_world.add_child(pillar)

		# Hanging vines
		for v in 2:
			var vine = ColorRect.new()
			vine.size = Vector2(2, randf_range(18, 45))
			vine.position = Vector2(plat_x + 25 + v * 55, py + 7)
			vine.color = Color(0.12, 0.34, 0.09)
			vine.z_index = -7
			_world.add_child(vine)

		plat_x += sw + randf_range(160, 320)
		if plat_x > STAGE_LENGTH - 500:
			break

	# ── Tunnel floor ──
	var lower_floor = StaticBody2D.new()
	var tfcol = CollisionShape2D.new()
	var tfshape = WorldBoundaryShape2D.new()
	tfshape.normal = Vector2.UP
	tfcol.shape = tfshape
	lower_floor.position.y = tunnel_y
	lower_floor.add_child(tfcol)
	_world.add_child(lower_floor)

	# Tunnel floor strip visual
	var tfloor_v = ColorRect.new()
	tfloor_v.size = Vector2(STAGE_LENGTH + 400, 8)
	tfloor_v.position = Vector2(-200, tunnel_y - 4)
	tfloor_v.color = Color(0.19, 0.11, 0.06)
	tfloor_v.z_index = -11
	_world.add_child(tfloor_v)

	# ── Tunnel corridor visuals ──
	var corr_h = tunnel_y - soil_top_y
	for i in range(int(STAGE_LENGTH / 250)):
		var tx = i * 250

		var corridor = ColorRect.new()
		corridor.size = Vector2(255, corr_h + 5)
		corridor.position = Vector2(tx, soil_top_y)
		corridor.color = Color(0.085, 0.05, 0.028)
		corridor.z_index = -12
		_world.add_child(corridor)

		if randf() < 0.5: # Root tendrils from ceiling
			var root = Line2D.new(); root.width = randf_range(1.5, 3.0); root.default_color = Color(0.16, 0.10, 0.05)
			var cur_p = Vector2(tx + randf() * 200, soil_top_y)
			for j in 5:
				root.add_point(cur_p - Vector2(tx, 0))
				cur_p += Vector2(randf_range(-10, 10), randf_range(12, 26))
			_world.add_child(root); root.position.x = tx

		if i % 3 == 0: # Wooden beams
			var pole = ColorRect.new(); pole.size = Vector2(10, corr_h)
			pole.position = Vector2(tx, soil_top_y)
			pole.color = Color(0.26, 0.16, 0.09); pole.z_index = -11; _world.add_child(pole)
			var beam = ColorRect.new(); beam.size = Vector2(260, 10)
			beam.position = Vector2(tx, soil_top_y)
			beam.color = Color(0.21, 0.11, 0.055); beam.z_index = -11; _world.add_child(beam)

		for j in 3: # Soil texture dots
			var dot = ColorRect.new(); dot.size = Vector2(randf() * 4, randf() * 4)
			dot.position = Vector2(tx + randf() * 250, soil_top_y + 10 + randf() * 80)
			dot.color = Color(0.21, 0.11, 0.055).darkened(0.2)
			_world.add_child(dot)

		if i % 4 == 0: # Oil lamp
			var lamp = ColorRect.new(); lamp.size = Vector2(8, 12)
			lamp.position = Vector2(tx + 120, soil_top_y + 12); lamp.color = Color.YELLOW; _world.add_child(lamp)
			var glow = Polygon2D.new()
			glow.polygon = PackedVector2Array([Vector2(-110, corr_h - 15), Vector2(110, corr_h - 15), Vector2(0, 0)])
			glow.color = Color(1, 0.8, 0.2, 0.11)
			glow.position = Vector2(tx + 124, soil_top_y + 15); _world.add_child(glow)

	# (Holes are already placed per-segment above as physics gaps)

	# ── Surface detail decorations (make ground feel lively) ──
	# Sandbag barricades along the surface at intervals
	for i in range(int(STAGE_LENGTH / 600)):
		var sbx = 300 + i * 600 + randf_range(-100, 100)
		# Skip holes
		var in_hole = fmod(sbx, 1100.0) > 1000.0
		if in_hole: continue
		for s in 3:
			var bag = ColorRect.new()
			bag.size = Vector2(randf_range(18, 26), randf_range(12, 16))
			bag.position = Vector2(sbx + s * 22, surface_y - bag.size.y)
			bag.color = Color(0.45, 0.35, 0.2)
			bag.rotation = randf_range(-0.15, 0.15)
			bag.z_index = 1
			_world.add_child(bag)

	# Wildflowers and grass tufts scattered on surface
	for i in range(int(STAGE_LENGTH / 80)):
		var fx = 80 + i * 80 + randf_range(-25, 25)
		if randf() < 0.35:
			_create_flower(Vector2(fx, surface_y))
		elif randf() < 0.25:
			_create_rock(Vector2(fx, surface_y))

	# Small pebbles/debris on tunnel floor
	for i in range(int(STAGE_LENGTH / 120)):
		var px2 = i * 120 + randf_range(-40, 40)
		var peb = ColorRect.new()
		peb.size = Vector2(randf_range(4, 8), randf_range(3, 6))
		peb.position = Vector2(px2, tunnel_y - peb.size.y - 2)
		peb.color = Color(0.25, 0.18, 0.12)
		peb.z_index = -10
		_world.add_child(peb)

	# Flat terrain lookup for ground-y queries
	_stage_terrain.clear()
	_stage_terrain.append(Vector2(-200, surface_y))
	_stage_terrain.append(Vector2(STAGE_LENGTH + 400, surface_y))

	_spawn_background_soldiers(4)
	_spawn_enemy_wave(15, 0.25)
	_spawn_enemy(400, surface_y - 50)
	_bomber_timer = 4.0

func _create_ground_segment(x1, x2, y) -> void:
	if x2 <= x1: return
	var w = x2 - x1
	var body = StaticBody2D.new()
	var col = CollisionShape2D.new(); var shape = RectangleShape2D.new(); shape.size = Vector2(w, 400); col.shape = shape
	body.add_child(col); body.position = Vector2(x1 + w/2, y + 200); _world.add_child(body)
	
	var dirt = ColorRect.new(); dirt.size = Vector2(w, 400); dirt.position = Vector2(-w/2, -200); dirt.color = Color(0.25, 0.12, 0.05)
	body.add_child(dirt)
	var grass = ColorRect.new(); grass.size = Vector2(w, 10); grass.position = Vector2(-w/2, -200); grass.color = Color(0.3, 0.15, 0.05)
	body.add_child(grass)

	# Foreground Pillars
	for i in 12:
		var px = i * 650; var p = ColorRect.new()
		p.size = Vector2(40, 800); p.position = Vector2(px, -100); p.color = Color(0.05, 0.02, 0.01, 0.85); p.z_index = 10
		_world.add_child(p)
	_spawn_decoration_density(0.5, 0.2)
	_spawn_background_soldiers(6)
	_spawn_enemy_wave(30, 1.0)
	_bomber_timer = 2.0

func _setup_highlands() -> void:
	# Stage 3: Đường mòn Hồ Chí Minh (Ho Chi Minh Trail - Redesigned)
	_setup_background_sky(Color(0.2, 0.4, 0.25)) # Deep forest green hazy sky
	
	# Dense Background Karst Peaks (Limestone mountains)
	for i in 12:
		var mt = Polygon2D.new(); var mx = i * 1400; var mw = 1000
		mt.polygon = PackedVector2Array([Vector2(0, 720), Vector2(mw/2, 200), Vector2(mw, 720)])
		mt.color = Color(0.1, 0.2, 0.15); mt.position = Vector2(mx, 0); mt.z_index = -11
		_world.add_child(mt)


	# Light atmospheric mist (fewer layers, lighter, BEHIND player)
	for i in 3:
		var mist = ColorRect.new(); mist.size = Vector2(5000, 600)
		mist.color = Color(0.3, 0.45, 0.32, 0.08); mist.position = Vector2(i*4000, 50); mist.z_index = -5
		_world.add_child(mist)
		var mtw = create_tween().set_loops()
		mtw.tween_property(mist, "position:x", mist.position.x + 1200, 30.0)
		mtw.tween_property(mist, "position:x", mist.position.x, 30.0)

	# Bottom dirt floor fill
	var dirt = ColorRect.new(); dirt.color = Color(0.15, 0.1, 0.06); dirt.size = Vector2(STAGE_LENGTH+1000, 200); dirt.position = Vector2(-200, 700)
	dirt.z_index = -20; _world.add_child(dirt)

	# Lower tunnel floor for path switching
	var floor_node = StaticBody2D.new()
	var col = CollisionShape2D.new(); var shape = WorldBoundaryShape2D.new(); shape.normal = Vector2.UP; col.shape = shape
	floor_node.add_child(col); floor_node.position.y = 750; _world.add_child(floor_node)

	# Map 3: continuous stepped hilly terrain (NO gaps needed - tunnel below)
	_generate_hilly_terrain(Color(0.18, 0.1, 0.05), Color(0.12, 0.28, 0.08), false)

func _generate_hilly_terrain(soil_color: Color, grass_color: Color, has_gaps: bool = false) -> void:
	_stage_terrain.clear()
	var cur_x = -200.0
	var cur_y = 550.0
	var total_len = STAGE_LENGTH + 400.0
	
	while cur_x < total_len:
		var chunk_len = min(2000.0, total_len - cur_x)
		if has_gaps:
			chunk_len = randf_range(800, 1500)
			
		var end_x = cur_x + chunk_len
		if end_x > total_len: end_x = total_len
		
		var surface_pts = PackedVector2Array()
		var cx = cur_x
		surface_pts.append(Vector2(cx, cur_y))
		while cx < end_x:
			var step_x = randf_range(200, 500)
			if cx + step_x >= end_x: step_x = end_x - cx
			
			cx += step_x
			surface_pts.append(Vector2(cx, cur_y))
			
			if cx < end_x:
				# Decide new height for next step
				var dy = randf_range(60, 150) * (1 if randf() < 0.5 else -1)
				if current_stage == 2:
					dy = 0 # Map 2 strictly flat and straight as requested
				cur_y = clamp(cur_y + dy, 300.0, 650.0)
				if has_gaps:
					cur_y = clamp(cur_y, 450.0, 580.0)
				
				# Small slope transition
				var slope_w = 20.0
				if cx + slope_w < end_x and current_stage != 2:
					cx += slope_w
					surface_pts.append(Vector2(cx, cur_y))
				
		var poly_pts = PackedVector2Array()
		for p in surface_pts: poly_pts.append(p)
		
		if has_gaps:
			for i in range(surface_pts.size()-1, -1, -1):
				poly_pts.append(Vector2(surface_pts[i].x, surface_pts[i].y + randf_range(100, 150)))
		else:
			poly_pts.append(Vector2(end_x, 1200)) # Bottom right
			poly_pts.append(Vector2(cur_x, 1200)) # Bottom left
			
		var ground = StaticBody2D.new()
		var coll = CollisionPolygon2D.new()
		coll.polygon = poly_pts
		if has_gaps: coll.one_way_collision = true
		ground.add_child(coll)
		_world.add_child(ground)
		
		var soil = Polygon2D.new()
		soil.polygon = poly_pts
		soil.color = soil_color
		ground.add_child(soil)
		
		var grass_pts = PackedVector2Array()
		var th = 18.0
		for i in range(surface_pts.size()):
			grass_pts.append(surface_pts[i])
		for i in range(surface_pts.size()-1, -1, -1):
			grass_pts.append(surface_pts[i] + Vector2(0, th))
			
		var grass = Polygon2D.new()
		grass.polygon = grass_pts
		grass.color = grass_color
		ground.add_child(grass)
		
		for p in surface_pts:
			if p.x <= total_len: _stage_terrain.append(p)
			
		# Decoration
		for i in range(surface_pts.size()-1):
			var p1 = surface_pts[i]
			var p2 = surface_pts[i+1]
			var count = int((p2.x - p1.x) / 50.0)
			for j in count:
				var t = randf()
				var vx = lerp(p1.x, p2.x, t)
				var vy = lerp(p1.y, p2.y, t)
				
				if randf() < 0.4: _create_jungle_fern(Vector2(vx, vy))
				elif randf() < 0.4: _create_dense_shrub(Vector2(vx, vy))
				
				if randf() < 0.2: _create_palm_tree(Vector2(vx, vy))
				if randf() < 0.15: _create_giant_ancient_tree(Vector2(vx, vy))
				if randf() < 0.25: _create_rock(Vector2(vx, vy))
				
				if randf() < 0.15:
					for b in 3:
						var bamboo = ColorRect.new()
						bamboo.size = Vector2(4, randf_range(100, 200))
						bamboo.position = Vector2(vx + b*8, vy - bamboo.size.y)
						bamboo.color = Color(0.1, 0.35, 0.05); _world.add_child(bamboo)
				
				if randf() < 0.05:
					var wreck = ColorRect.new()
					wreck.size = Vector2(80, 40)
					wreck.color = Color(0.2, 0.1, 0.05) if current_stage == 3 else Color(0.2, 0.25, 0.1)
					wreck.position = Vector2(vx, vy - 40)
					wreck.rotation = atan2(p2.y - p1.y, p2.x - p1.x)
					_world.add_child(wreck)
		
		# Gaps logic
		if has_gaps:
			var prev_y = cur_y
			cur_x = end_x + randf_range(80, 200)
			if cur_x <= total_len:
				_stage_terrain.append(Vector2(end_x + 1, 740.0))
				_stage_terrain.append(Vector2(cur_x - 1, 740.0))
		else:
			cur_x = end_x

	if current_stage == 3:
		_spawn_background_soldiers(12)
		_spawn_enemy_wave(25, 0.25) # Reduced from 50, less crowded
		# Spawn Tanks ONLY in Stage 3 — fewer, more spread out
		for i in 5:
			var tx = 2000 + i * 2200 + randf_range(-300, 300)
			var ty = _get_ground_y(tx)
			_spawn_heavy_enemy(tx, ty, "tank")
		_bomber_timer = 3.0
	else:
		# Stage 2 or others: already handled by _setup_tunnels, skip heavy spawns here
		pass
	
	# Mist Layer (Final cleanup layer)
	for i in 15:
		var fog = ColorRect.new(); fog.size = Vector2(1500, 400); fog.position = Vector2(i * 1200, 300); fog.color = Color(1,1,1,0.05); fog.z_index = 5
		_world.add_child(fog)

func _setup_base() -> void:
	# Stage 4: US Military Base (Căn cứ địch kiên cố)
	_setup_background_sky(Color(0.05, 0.05, 0.08)) # Dark night
	
	# Moon
	var moon = Polygon2D.new()
	var mpts = PackedVector2Array()
	for i in 20: mpts.append(Vector2(cos(i*TAU/20)*40, sin(i*TAU/20)*40))
	moon.polygon = mpts; moon.color = Color(0.9, 0.9, 0.9, 0.8)
	moon.position = Vector2(800, 150); moon.z_index = -110
	_world.add_child(moon)

	# Base Floor (Concrete)
	var floor_node = StaticBody2D.new()
	var col = CollisionShape2D.new(); var shape = WorldBoundaryShape2D.new(); shape.normal = Vector2.UP; col.shape = shape
	floor_node.add_child(col); floor_node.position.y = 600; _world.add_child(floor_node)
	
	var dirt = ColorRect.new(); dirt.color = Color(0.15, 0.15, 0.18); dirt.size = Vector2(STAGE_LENGTH+800, 400); dirt.position = Vector2(-200, 0); floor_node.add_child(dirt)
	var highlight = ColorRect.new(); highlight.color = Color(0.28, 0.28, 0.32); highlight.size = Vector2(STAGE_LENGTH+800, 14); highlight.position = Vector2(-200, -5); floor_node.add_child(highlight)

	_stage_terrain.clear()
	_stage_terrain.append(Vector2(-200, 600))
	_stage_terrain.append(Vector2(STAGE_LENGTH + 800, 600))

	# Background Fences
	for i in range(int(STAGE_LENGTH/300)):
		var fx = i * 300
		var fw = ColorRect.new(); fw.size = Vector2(6, 140); fw.position = Vector2(fx, 460); fw.color = Color(0.25, 0.25, 0.25); fw.z_index = -30; _world.add_child(fw)
		for j in 6:
			var w = Line2D.new(); w.width = 2.0; w.default_color = Color(0.4, 0.4, 0.4); w.add_point(Vector2(fx, 465 + j*25)); w.add_point(Vector2(fx+300, 465 + j*25)); w.z_index = -30; _world.add_child(w)

	# Watchtowers & Bunkers
	for i in range(int(STAGE_LENGTH/700)):
		var tx = 500 + i * 700 + randf_range(-50, 50)
		if randf() < 0.5:
			# Watchtower
			var tower = ColorRect.new(); tower.size = Vector2(16, 250); tower.position = Vector2(tx-8, 350); tower.color = Color(0.18, 0.18, 0.2); tower.z_index = -15; _world.add_child(tower)
			var plat = StaticBody2D.new(); var pcol = CollisionShape2D.new(); var pshape = RectangleShape2D.new(); pshape.size = Vector2(120, 14); pcol.shape = pshape; pcol.one_way_collision = true
			plat.add_child(pcol); plat.position = Vector2(tx, 350); _world.add_child(plat)
			var pv = ColorRect.new(); pv.size = Vector2(120, 14); pv.position = Vector2(-60, -7); pv.color = Color(0.3, 0.3, 0.35); plat.add_child(pv)
			_spawn_turret(tx, 340)
			# Searchlight beam
			var light = Polygon2D.new(); light.polygon = PackedVector2Array([Vector2.ZERO, Vector2(350, 800), Vector2(-350, 800)])
			light.color = Color(1, 1, 0.7, 0.15); light.position = Vector2(tx, 355); light.z_index = 5; _world.add_child(light)
			var tw = create_tween().set_loops()
			tw.tween_property(light, "rotation", deg_to_rad(35), 4.0).set_trans(Tween.TRANS_SINE)
			tw.tween_property(light, "rotation", deg_to_rad(-35), 4.0).set_trans(Tween.TRANS_SINE)
		else:
			# Concrete Bunker
			var bunker = ColorRect.new(); bunker.size = Vector2(160, 90); bunker.position = Vector2(tx-80, 510); bunker.color = Color(0.3, 0.35, 0.35); _world.add_child(bunker)
			var slit = ColorRect.new(); slit.size = Vector2(90, 12); slit.position = Vector2(tx-45, 540); slit.color = Color(0.05, 0.05, 0.05); _world.add_child(slit)
			_spawn_turret(tx, 505)
	
	# Parkour Crates / Covers
	for i in 25:
		var cx = randf_range(400, STAGE_LENGTH - 400)
		var cy = 600 - randf_range(40, 100)
		var cw = randf_range(50, 90)
		var crate = StaticBody2D.new()
		var ccol = CollisionShape2D.new(); var cshaped = RectangleShape2D.new(); cshaped.size = Vector2(cw, 600-cy); ccol.shape = cshaped; crate.add_child(ccol)
		crate.position = Vector2(cx, cy + (600-cy)/2.0); _world.add_child(crate)
		var cv = ColorRect.new(); cv.size = Vector2(cw, 600-cy); cv.position = Vector2(-cw/2.0, -(600-cy)/2.0); cv.color = Color(0.42, 0.32, 0.22); crate.add_child(cv)
		# Crate bands
		var ct = ColorRect.new(); ct.size = Vector2(cw, 6); ct.position = Vector2(-cw/2.0, -(600-cy)/2.0 + 5); ct.color = Color(0.3, 0.2, 0.1); crate.add_child(ct)
		var cb = ColorRect.new(); cb.size = Vector2(cw, 6); cb.position = Vector2(-cw/2.0, (600-cy)/2.0 - 11); cb.color = Color(0.3, 0.2, 0.1); crate.add_child(cb)

	# Warning Lights (Pulsing Red)
	for i in 20:
		var lx = i * 450 + 200; var r_light = ColorRect.new(); r_light.size = Vector2(12, 12); r_light.position = Vector2(lx, 45); r_light.color = Color.RED; _world.add_child(r_light)
		var tw = create_tween().set_loops()
		tw.tween_property(r_light, "modulate:a", 0.1, 0.5); tw.tween_property(r_light, "modulate:a", 1.0, 0.5)

	# Reduced initial static enemies to 15 to prevent CPU lag (Slow-motion effect). 
	# The dynamic spawner in _process() will keep the action alive as player progresses.
	_spawn_enemy_wave(15, 0.5) 
	for i in 3:
		var t_tx = 1800 + i * 3000 + randf_range(-100, 100)
		_spawn_heavy_enemy(t_tx, 595, "tank")
	_bomber_timer = 2.0
	_spawn_background_soldiers(6)

func _setup_final_push() -> void:
	STAGE_LENGTH = 16000.0 # Make Phase 5 notably longer
	if progress_bar: progress_bar.max_value = STAGE_LENGTH
	
	# Stage 5: Giải phóng miền Nam - Tiến vào Sài Gòn (10:30 AM)
	_setup_background_sky(Color(0.35, 0.65, 0.9)) # Clear blue sky
	
	var sun = Polygon2D.new(); var spts = PackedVector2Array()
	for i in 24: spts.append(Vector2(cos(i*TAU/24)*180, sin(i*TAU/24)*180))
	sun.polygon = spts; sun.color = Color(1.0, 0.95, 0.4, 0.9); sun.position = Vector2(800, 150); sun.z_index = -110; _world.add_child(sun)

	# City Skyline (Sài Gòn 1975 - Colonial Style / Thấp hơn, màu vàng/trắng cũ)
	for i in 60:
		var bw = randf_range(160, 280)
		var bh = randf_range(80, 220) # Colonial buildings
		var bx = i * 250 + randf_range(-50, 50)
		var b = ColorRect.new()
		b.size = Vector2(bw, bh); b.position = Vector2(bx, 600 - bh)
		
		# Colonial colors: Pale yellow, off-white, faded green/brown
		b.color = [Color(0.85, 0.8, 0.6), Color(0.8, 0.8, 0.75), Color(0.65, 0.7, 0.6), Color(0.7, 0.6, 0.5)].pick_random()
		b.color = b.color.darkened(randf_range(0.1, 0.15))
		b.z_index = -80; _world.add_child(b)
		
		# Slanted Roofs (Mái ngói)
		if randf() < 0.7:
			var roof = Polygon2D.new(); roof.polygon = PackedVector2Array([Vector2(-15, 0), Vector2(bw/2, -40), Vector2(bw+15, 0)])
			roof.color = Color(0.65, 0.35, 0.25).darkened(randf_range(0.0, 0.2)); roof.position = Vector2(bx, 600 - bh); roof.z_index = -80
			_world.add_child(roof)
		
		# Windows & Balconies
		for r in int(bh/40):
			for c in int(bw/45):
				if randf() > 0.1:
					var wx = c*45 + 15
					var wy = r*40 + 15
					var win = ColorRect.new(); win.size = Vector2(18, 25); win.position = Vector2(wx, wy)
					win.color = Color(0.3, 0.4, 0.3, 0.7); b.add_child(win)
					# Add colonial balcony for some windows
					if randf() < 0.4 and r > 0:
						var balc = ColorRect.new(); balc.size = Vector2(26, 8); balc.position = Vector2(wx-4, wy+22)
						balc.color = Color(0.3, 0.3, 0.3); b.add_child(balc)
						var railing = ColorRect.new(); railing.size = Vector2(26, 12); railing.position = Vector2(wx-4, wy+10)
						railing.color = Color(0.1, 0.1, 0.1, 0.5); b.add_child(railing)

	# Smoke pillars rising from the city
	for i in 12:
		var sx = i * 1500 + 500
		var smoke = Polygon2D.new()
		smoke.polygon = PackedVector2Array([Vector2(-40, 600), Vector2(-150, -200), Vector2(150, -200), Vector2(40, 600)])
		smoke.color = Color(0.2, 0.2, 0.2, 0.3); smoke.position = Vector2(sx, 0); smoke.z_index = -75; _world.add_child(smoke)

	# Multi-layer Urban Road / Bridge (Chiều sâu tầng địa hình)
	var floor_node = StaticBody2D.new()
	var col = CollisionShape2D.new(); var shape = WorldBoundaryShape2D.new(); shape.normal = Vector2.UP; col.shape = shape
	floor_node.add_child(col); floor_node.position.y = 600
	floor_node.z_index = -25 # FIX: Push road far back so background army (z_index=-5) spawns on TOP of it
	_world.add_child(floor_node)
	
	# Background Lane
	var bg_road = ColorRect.new(); bg_road.color = Color(0.3, 0.3, 0.32); bg_road.size = Vector2(STAGE_LENGTH+800, 80); bg_road.position = Vector2(-200, -80); floor_node.add_child(bg_road)
	
	# Median (Dải phân cách lớn)
	var median = ColorRect.new(); median.color = Color(0.4, 0.4, 0.35); median.size = Vector2(STAGE_LENGTH+800, 25); median.position = Vector2(-200, -35); floor_node.add_child(median)
	var median_grass = ColorRect.new(); median_grass.color = Color(0.2, 0.35, 0.15); median_grass.size = Vector2(STAGE_LENGTH+800, 15); median_grass.position = Vector2(-200, -30); floor_node.add_child(median_grass)
	
	# Foreground Lane (Playable asphalt)
	var fg_road = ColorRect.new(); fg_road.color = Color(0.2, 0.2, 0.22); fg_road.size = Vector2(STAGE_LENGTH+800, 400); fg_road.position = Vector2(-200, 0); floor_node.add_child(fg_road)
	var road_line = ColorRect.new(); road_line.color = Color(0.8, 0.7, 0.2, 0.8); road_line.size = Vector2(STAGE_LENGTH+800, 6); road_line.position = Vector2(-200, -2); floor_node.add_child(road_line)

	_stage_terrain.clear()
	_stage_terrain.append(Vector2(-200, 600))
	_stage_terrain.append(Vector2(STAGE_LENGTH + 800, 600))

	# Streetlights, Palm Trees and Celebration Flags across the street
	for i in range(int(STAGE_LENGTH/400)):
		var px = i * 400 + randf_range(-20, 20)
		
		# Streetlight
		var pole = ColorRect.new(); pole.size = Vector2(6, 280); pole.position = Vector2(px, 300); pole.color = Color(0.3, 0.3, 0.3); pole.z_index = -30; _world.add_child(pole)
		var light = ColorRect.new(); light.size = Vector2(35, 8); light.position = Vector2(px-15, 300); light.color = Color(0.25, 0.25, 0.25); pole.z_index = -30; _world.add_child(light)
		
		# Palm Trees lining the avenue
		if randf() < 0.6:
			_create_palm_tree(Vector2(px + 100, 600))
			# Push palm trees back visually
			var last_tree = _world.get_child(_world.get_child_count()-1)
			last_tree.z_index = -28
			last_tree.scale = Vector2(0.8, 0.8)
			
		# Liberation Flags hanging across street
		if i % 3 == 0:
			var wire = Line2D.new(); wire.width = 1.0; wire.default_color = Color(0.1, 0.1, 0.1, 0.6); wire.z_index = -29
			wire.add_point(Vector2(px, 350)); wire.add_point(Vector2(px+400, 370)); _world.add_child(wire)
			
			for f in 3:
				var flag_x = px + 80 + f * 100
				var flag_y = 350 + (flag_x - px) * 0.05
				var flag = Polygon2D.new()
				flag.polygon = PackedVector2Array([Vector2(0,0), Vector2(30,0), Vector2(30,40), Vector2(0,40)])
				flag.position = Vector2(flag_x, flag_y); flag.z_index = -28
				_world.add_child(flag)
				
				# Cờ nửa đỏ nửa xanh (Mặt trận Dân tộc Giải phóng miền Nam)
				var red = ColorRect.new(); red.size = Vector2(30, 20); red.color = Color(0.8, 0.1, 0.1); flag.add_child(red)
				var blue = ColorRect.new(); blue.size = Vector2(30, 20); blue.position = Vector2(0, 20); blue.color = Color(0.1, 0.4, 0.8); flag.add_child(blue)
				var star = Polygon2D.new(); var pts = []
				for j in 10:
					var r = 6 if j%2==0 else 2.5
					pts.append(Vector2(cos(j*TAU/10-PI/2)*r, sin(j*TAU/10-PI/2)*r))
				star.polygon = PackedVector2Array(pts); star.color = Color.YELLOW; star.position = Vector2(15, 20); flag.add_child(star)

	# Realistic Parkour Obstacles: Vintage Vespas, Jeeps and Sandbags
	for i in 25:
		var cx = randf_range(300, STAGE_LENGTH - 1000)
		var r = randf()
		if r < 0.3:
			_create_truck_husk(Vector2(cx, 600))
		elif r < 0.6:
			_create_sandbag_fort(Vector2(cx, 600), randf_range(40, 80))
		else:
			# Vintage Vespa Scooter (Abandoned)
			var vespa = StaticBody2D.new(); vespa.position = Vector2(cx, 600); vespa.z_index = -24; _world.add_child(vespa)
			var vbody = Polygon2D.new(); vbody.polygon = PackedVector2Array([Vector2(-20,-10), Vector2(25,-10), Vector2(35,10), Vector2(-30,10)])
			vbody.color = [Color(0.4, 0.7, 0.8), Color(0.8, 0.9, 0.8), Color(0.9, 0.3, 0.3)].pick_random() # Retro colors
			vbody.position = Vector2(0, -20); vespa.add_child(vbody)
			var seat = ColorRect.new(); seat.size=Vector2(25,6); seat.position=Vector2(-10,-36); seat.color=Color(0.1,0.1,0.1); vespa.add_child(seat)
			var handle = Line2D.new(); handle.width=3.0; handle.default_color=Color(0.8,0.8,0.8); handle.add_point(Vector2(25,-30)); handle.add_point(Vector2(20,-50)); vespa.add_child(handle)
			var w1 = ColorRect.new(); w1.size=Vector2(14,14); w1.position=Vector2(-25,-14); w1.color=Color(0.05,0.05,0.05); vespa.add_child(w1)
			var w2 = ColorRect.new(); w2.size=Vector2(14,14); w2.position=Vector2(20,-14); w2.color=Color(0.05,0.05,0.05); vespa.add_child(w2)
			
	# Giảm địch cho thưa thớt
	_spawn_enemy_wave(12, 0.2) 
	for i in 2:
		var t_tx = 3000 + i * 5000 + randf_range(-100, 100) # Tanks spread out heavily
		_spawn_heavy_enemy(t_tx, 595, "tank")
	
	_bomber_timer = 5.0 
	_spawn_background_soldiers(4) # Heavy allied presence marching in
	
	# Boss Fortress at the end (Dinh Độc Lập Gates)
	var bx = STAGE_LENGTH - 400
	var by = 600
	_spawn_boss(bx, by)

func _spawn_turret(x, y) -> void:
	var t = TURRET_SCENE.instantiate()
	_world.add_child(t)
	t.position = Vector2(x, y)

func _spawn_boss(x, y) -> void:
	# Cổng Dinh Độc Lập / Independence Palace Gates
	
	# Palace Yard (Green grass behind the gate)
	var yard = ColorRect.new(); yard.size = Vector2(800, 150); yard.position = Vector2(x, y-150); yard.color = Color(0.15, 0.4, 0.15); yard.z_index = -35; _world.add_child(yard)
	var palace_bg = ColorRect.new(); palace_bg.size = Vector2(800, 300); palace_bg.position = Vector2(x, y-450); palace_bg.color = Color(0.85, 0.85, 0.8); palace_bg.z_index = -36; _world.add_child(palace_bg)
	
	# Tropical Palm Trees in the palace yard
	for i in 4:
		_create_palm_tree(Vector2(x + 100 + i*150, y))
		var last_tree = _world.get_child(_world.get_child_count()-1)
		last_tree.z_index = -34
	
	# Iron fences (Broken in the middle)
	for i in 22:
		# Create a gap in the middle where the tank crashed
		if i > 7 and i < 15: continue 
		var bar = ColorRect.new(); bar.size = Vector2(8, 450); bar.position = Vector2(x-80 + i*35, y-450); bar.color = Color(0.2, 0.2, 0.2); bar.z_index = -15; _world.add_child(bar)
		var spike = Polygon2D.new(); spike.polygon = PackedVector2Array([Vector2(0,0), Vector2(4, -15), Vector2(8, 0)]); spike.color = Color(0.8, 0.7, 0.2); spike.position = Vector2(x-80 + i*35, y-450); spike.z_index = -15; _world.add_child(spike)

	# Concrete Pillars
	for i in 4:
		var px = x -100 + i * 260
		# Destroyed central pillars
		var pillar_h = 500 if (i == 0 or i == 3) else randf_range(100, 200)
		var pillar = ColorRect.new(); pillar.size = Vector2(60, pillar_h); pillar.position = Vector2(px, y-pillar_h); pillar.color = Color(0.8, 0.8, 0.75); pillar.z_index = -10; _world.add_child(pillar)
		var base = ColorRect.new(); base.size = Vector2(80, 40); base.position = Vector2(px-10, y-40); base.color = Color(0.6, 0.6, 0.55); pillar.add_child(base)

	# Banner above the gate
	var banner = ColorRect.new(); banner.size = Vector2(500, 60); banner.position = Vector2(x-100, y-550); banner.color = Color(0.8, 0.1, 0.1); banner.z_index = -9; _world.add_child(banner)
	
	# Iconic T-54 Tank husk that rammed the center gate
	var tank_husk = StaticBody2D.new(); tank_husk.position = Vector2(x + 100, y); _world.add_child(tank_husk)
	var tcol = CollisionShape2D.new(); var tshp = RectangleShape2D.new(); tshp.size = Vector2(250, 100); tcol.shape = tshp; tcol.position = Vector2(0, -50); tcol.one_way_collision = true; tank_husk.add_child(tcol)
	var tbody = Polygon2D.new(); tbody.polygon = PackedVector2Array([Vector2(-125, 0), Vector2(-100, -80), Vector2(100, -100), Vector2(125, 0)])
	tbody.color = Color(0.1, 0.35, 0.1) # Viet Cong Green
	tank_husk.add_child(tbody)
	var star = Polygon2D.new(); var pts = []
	for j in 10:
		var r = 20 if j % 2 == 0 else 8
		pts.append(Vector2(cos(j*TAU/10 - PI/2)*r, sin(j*TAU/10 - PI/2)*r))
	star.polygon = PackedVector2Array(pts); star.color = Color.YELLOW; star.position = Vector2(-20, -50); tank_husk.add_child(star)

	# Note: No win_check timer needed. Winning is triggered by walking over STAGE_LENGTH - 100

func _create_truck_husk(pos: Vector2) -> void:
	var husk = StaticBody2D.new(); husk.position = pos; _world.add_child(husk)
	var col = CollisionShape2D.new(); var shp = RectangleShape2D.new(); shp.size = Vector2(160, 80); col.shape = shp; col.position = Vector2(0, -40); col.one_way_collision = true; husk.add_child(col)
	var body = Polygon2D.new(); body.polygon = PackedVector2Array([Vector2(-80, 0), Vector2(-80, -60), Vector2(-40, -80), Vector2(80, -80), Vector2(80, 0)])
	body.color = Color(0.25, 0.28, 0.22); husk.add_child(body)
	var w1 = ColorRect.new(); w1.size = Vector2(24, 24); w1.position = Vector2(-60, -12); w1.color = Color(0.1, 0.1, 0.1); husk.add_child(w1)
	var w2 = ColorRect.new(); w2.size = Vector2(24, 24); w2.position = Vector2(40, -12); w2.color = Color(0.1, 0.1, 0.1); husk.add_child(w2)
	if randf() < 0.5:
		var fire = ColorRect.new(); fire.size = Vector2(12, 18); fire.position = Vector2(-20, -98); fire.color = Color(1.0, 0.4, 0.0); husk.add_child(fire)
		var tw = create_tween().set_loops(); tw.tween_property(fire, "scale:y", 1.5, 0.15); tw.tween_property(fire, "scale:y", 1.0, 0.15)

func _create_sandbag_fort(pos: Vector2, h: float) -> void:
	var fort = StaticBody2D.new(); fort.position = pos; _world.add_child(fort)
	var col = CollisionShape2D.new(); var shp = RectangleShape2D.new(); shp.size = Vector2(100, h); col.shape = shp; col.position = Vector2(0, -h/2); col.one_way_collision = true; fort.add_child(col)
	for r in int(h/15):
		for c in 4:
			var bag = ColorRect.new(); bag.size = Vector2(24, 14); bag.position = Vector2(-50 + c*25 + (r%2)*10, -15 - r*15); bag.color = Color(0.5, 0.45, 0.35).darkened(randf_range(0.0, 0.2)); fort.add_child(bag)

# Helper to spawn enemies and decorations based on stage
func _spawn_enemy_wave(count: int, officer_p: float) -> void:
	for i in range(count):
		# Distribute across stage
		var x = 800 + i * (STAGE_LENGTH / count) + randf_range(-100, 100)
		if x > STAGE_LENGTH - 400: continue
		
		var is_off = randf() < officer_p
		var ey = _get_ground_y(x) - 100
		if current_stage == 2:
			ey = 550 # Only spawn on surface ground
		
		# Ensure they are not stacked exactly on top of other enemies
		for e in get_tree().get_nodes_in_group("enemy"):
			if abs(e.position.x - x) < 60:
				x += 100
				break

		_spawn_enemy(x, ey, is_off)
		
		# Occasional extra sniper on high platforms
		if randf() < 0.15: _spawn_enemy(x + 120, ey - 200, false)
		
		# (Removed the sneaky random tank spawn here. Tanks are only spawned directly by stage logic now)
	
	# Initial delay for first bomber: scales with stage
	var base_delay = lerp(8.0, 3.0, float(current_stage - 1) / 4.0)
	_bomber_timer = base_delay

func _spawn_decoration_density(tree_p: float, rock_p: float) -> void:
	for i in range(100):
		var x = randf_range(0, STAGE_LENGTH)
		var y = _get_ground_y(x)
		if randf() < tree_p: _create_palm_tree(Vector2(x, y))
		if randf() < rock_p: _create_rock(Vector2(x, y))
		if randf() < 0.3: _create_flower(Vector2(x, y))

func _setup_clouds(count: int) -> void:
	for i in range(count):
		_create_cloud_premium(Vector2(i * (STAGE_LENGTH/count) + randf_range(-100, 100), randf_range(40, 180)))

func _create_platform_complex(count: int, low: bool = false) -> void:
	for i in range(count):
		var y = randf_range(350, 480) if not low else randf_range(450, 520)
		var x = 400 + i * (STAGE_LENGTH/count) + randf_range(-50, 50)
		_create_platform_detailed(Vector2(x, y), randf_range(150, 350))

func _create_floor_detailed(start_x, end_x, y, grass_color = Color(0.08, 0.22, 0.05)) -> void:
	var floor_node = StaticBody2D.new()
	var col = CollisionShape2D.new()
	var shape = WorldBoundaryShape2D.new()
	shape.normal = Vector2.UP
	col.shape = shape
	floor_node.add_child(col)
	floor_node.position.y = y
	_world.add_child(floor_node)
	
	var dirt = ColorRect.new()
	dirt.color = Color(0.2, 0.12, 0.05)
	dirt.size = Vector2(end_x - start_x, 400)
	dirt.position = Vector2(start_x, 0)
	floor_node.add_child(dirt)
	
	var grass = ColorRect.new()
	grass.color = grass_color
	grass.size = Vector2(end_x - start_x, 20)
	grass.position = Vector2(start_x, -5)
	floor_node.add_child(grass)
	
	for i in range(600):
		var leaf = Polygon2D.new()
		var lx = randf_range(start_x, end_x)
		leaf.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(0, -12), Vector2(3, 0)])
		leaf.color = grass_color.lightened(0.2)
		leaf.position = Vector2(lx, 0)
		floor_node.add_child(leaf)

func _create_palm_tree(pos: Vector2) -> void:
	var tree = Node2D.new(); tree.position = pos; _world.add_child(tree)
	# Thicker, textured trunk
	var trunk = Polygon2D.new()
	trunk.polygon = PackedVector2Array([Vector2(-5,0), Vector2(5,0), Vector2(3, -120), Vector2(-3, -120)])
	trunk.color = Color(0.28, 0.18, 0.08)
	tree.add_child(trunk)
	
	# Foreground Leaves (Multiple layers)
	for i in 12:
		var frond = Polygon2D.new(); var a = i * PI / 6.0
		var flen = randf_range(40, 70)
		frond.polygon = PackedVector2Array([Vector2(0,0), Vector2(flen, -15), Vector2(flen-10, 15)])
		frond.color = Color(0.08, 0.35, 0.05, 0.9)
		frond.rotation = a; frond.position = Vector2(0, -120)
		tree.add_child(frond)
	
	# Small details/Shadows on trunk
	var shad = ColorRect.new(); shad.size = Vector2(2, 100); shad.position = Vector2(1, -100); shad.color = Color(0,0,0,0.2)
	tree.add_child(shad)

func _create_jungle_shrub(pos: Vector2) -> void:
	var shrub = Polygon2D.new(); shrub.position = pos; _world.add_child(shrub)
	shrub.polygon = PackedVector2Array([Vector2(-25, 0), Vector2(-15, -40), Vector2(0, -55), Vector2(15, -40), Vector2(25, 0)])
	shrub.color = Color(0.1, 0.28, 0.08, 0.9)

func _create_cloud_premium(pos: Vector2) -> void:
	var cloud = Node2D.new()
	cloud.position = pos
	cloud.modulate.a = 0.55
	_world.add_child(cloud)
	for i in 4:
		var puffy = Polygon2D.new()
		var pts = []
		var rd = 40 + randf() * 20
		for j in 12:
			var a = j * TAU / 12
			pts.append(Vector2(cos(a) * rd, sin(a) * rd / 1.8))
		puffy.polygon = PackedVector2Array(pts)
		puffy.color = Color.WHITE
		puffy.position = Vector2(i * 40 - 60, randf() * 10)
		cloud.add_child(puffy)

func _create_rock(pos: Vector2) -> void:
	var r = Polygon2D.new()
	r.position = pos
	_world.add_child(r)
	r.polygon = PackedVector2Array([
		Vector2(-10, 0), Vector2(-8, -8), Vector2(0, -12), 
		Vector2(8, -6), Vector2(10, 0)
	])
	r.color = Color(0.4, 0.4, 0.45)

func _create_flower(pos: Vector2) -> void:
	var fl = Polygon2D.new()
	fl.position = pos
	_world.add_child(fl)
	fl.polygon = PackedVector2Array([
		Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)
	])
	fl.color = [Color.RED, Color.YELLOW, Color.MAGENTA, Color.ORANGE, Color.CYAN].pick_random()

func _create_platform_detailed(pos: Vector2, width: float) -> void:
	var hill = Polygon2D.new()
	var hill_h = 600 - pos.y
	hill.polygon = PackedVector2Array([
		Vector2(-width/2 - 20, hill_h), 
		Vector2(-width/2 + 10, 0), 
		Vector2(width/2 - 10, 0), 
		Vector2(width/2 + 20, hill_h)
	])
	hill.color = Color(0.25, 0.15, 0.08)
	hill.position = pos
	_world.add_child(hill)
	
	var plat = StaticBody2D.new()
	var col = CollisionShape2D.new()
	col.one_way_collision = true
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, 16)
	col.shape = shape
	plat.add_child(col)
	plat.position = pos
	_world.add_child(plat)
	
	var log_v = ColorRect.new()
	log_v.size = Vector2(width, 16)
	log_v.position = Vector2(-width/2, -8)
	log_v.color = Color(0.28, 0.18, 0.08)
	plat.add_child(log_v)
	
	var moss = ColorRect.new()
	moss.size = Vector2(width, 4)
	moss.position = Vector2(-width/2, -10)
	moss.color = Color(0.2, 0.5, 0.1)
	plat.add_child(moss)
	
	for i in range(int(width/30)):
		var vine = ColorRect.new()
		vine.size = Vector2(2, randf_range(30, 80))
		vine.position = Vector2(-width/2 + i * 30 + 10, 8)
		vine.color = Color(0.12, 0.35, 0.1)
		plat.add_child(vine)

func _spawn_enemy(x, y, is_off: bool = false) -> void:
	var e = ENEMY_SCENE.instantiate()
	e.is_officer = is_off
	_world.add_child(e) # Add to _world for proper scrolling & cleanup
	e.position = Vector2(x, y)

func _spawn_background_soldiers(count: int) -> void:
	for i in range(count):
		var x = 400 + i * (STAGE_LENGTH / count) + randf_range(-400, 400)
		var y: float
		if (current_stage == 2 or current_stage == 3) and i % 2 == 0:
			y = 650.0  # Lower/Tunnel path (tunnel_y=660, stand just above it)
		else:
			y = _get_ground_y(x)  # Upper terrain path
		_add_individual_background_soldier(x, y)

func _add_individual_background_soldier(x: float, y: float = 600) -> void:
	# Check for overlaps to avoid bunching (increased to 150 to keep them spread out)
	for s in get_tree().get_nodes_in_group("ally_army"):
		if abs(s.position.x - x) < 150: return # Too close, skip this one
	var soldier = Node2D.new()
	
	# Visuals: Brighter Green for visibility
	var soldier_color = Color(0.18, 0.35, 0.18)
	
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(7, -26), Vector2(-7, -26)])
	body.color = soldier_color
	soldier.add_child(body)
	
	var head = Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(-4, -26), Vector2(4, -26), Vector2(4, -34), Vector2(-4, -34)])
	head.color = soldier_color
	soldier.add_child(head)
	
	# Nón cối (Pith Helmet)
	var hat = Polygon2D.new()
	hat.polygon = PackedVector2Array([Vector2(-10, -32), Vector2(10, -32), Vector2(0, -40)])
	hat.color = Color(0.22, 0.4, 0.2) # Even brighter hat
	soldier.add_child(hat)
	
	# Rifle (Súng trường)
	var gun = ColorRect.new()
	gun.size = Vector2(25, 3); gun.position = Vector2(2, -21); gun.color = Color(0.05, 0.05, 0.05)
	soldier.add_child(gun)
	
	# Decoration: Backpack (Ba lô con cóc)
	var pack = ColorRect.new()
	pack.size = Vector2(8, 14); pack.position = Vector2(-12, -22); pack.color = soldier_color.darkened(0.2)
	soldier.add_child(pack)
	
	soldier.z_index = -5 
	soldier.position = Vector2(x, y)
	soldier.add_to_group("ally_army")
	
	# Variety in speed: Some overtake player, some trail behind
	soldier.set_meta("walk_speed", randf_range(120, 300)) 
	_world.add_child(soldier)
	
	# Only scale bobbing — NO position:y tween (it fights teleport and causes floating)
	var anim_speed = randf_range(0.35, 0.45)
	var stw = create_tween().set_loops()
	stw.tween_property(soldier, "scale:y", 1.06, anim_speed).set_trans(Tween.TRANS_SINE)
	stw.tween_property(soldier, "scale:y", 1.0, anim_speed).set_trans(Tween.TRANS_SINE)
	
	# --- Stage 5 feature: Spawn an occasional Allied Tank moving alongside soldiers ---
	if current_stage == 5 and randf() < 0.4: # Increased spawn rate
		_add_allied_tank(x - randf_range(100, 300), y)

func _add_allied_tank(x: float, y: float) -> void:
	var tank_count = 0
	for s in get_tree().get_nodes_in_group("ally_army"):
		if s.has_meta("is_tank"):
			tank_count += 1
			if abs(s.position.x - x) < 800: return # Keep them spread out
			
	if tank_count >= 2: return # Limit total allied tanks on screen

	var tank = Node2D.new()
	tank.position = Vector2(x, y)
	tank.z_index = -6 # Just behind allied soldiers
	
	# T-54 Tank Body
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-60, 0), Vector2(-50, -40), Vector2(50, -40), Vector2(60, 0)])
	body.color = Color(0.1, 0.35, 0.1) # Viet Cong Green
	tank.add_child(body)
	
	var turret = Polygon2D.new()
	turret.polygon = PackedVector2Array([Vector2(-30, -40), Vector2(-15, -65), Vector2(15, -65), Vector2(20, -40)])
	turret.color = Color(0.08, 0.28, 0.08)
	tank.add_child(turret)
	
	var barrel = ColorRect.new()
	barrel.size = Vector2(70, 8); barrel.position = Vector2(10, -58); barrel.color = Color(0.05, 0.15, 0.05)
	tank.add_child(barrel)
	
	# Yellow Star
	var star = Polygon2D.new(); var pts = []
	for j in 10:
		var r = 12 if j % 2 == 0 else 5
		pts.append(Vector2(cos(j*TAU/10 - PI/2)*r, sin(j*TAU/10 - PI/2)*r))
	star.polygon = PackedVector2Array(pts); star.color = Color.YELLOW; star.position = Vector2(5, -50)
	tank.add_child(star)

	tank.add_to_group("ally_army")
	tank.set_meta("walk_speed", randf_range(150, 220)) # Slower than some soldiers, faster than others
	tank.set_meta("is_tank", true) 
	
	# Slight bobbing to simulate treads
	var tw = create_tween().set_loops()
	tw.tween_property(tank, "rotation", deg_to_rad(-1.5), 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tank, "rotation", deg_to_rad(1.5), 0.25).set_trans(Tween.TRANS_SINE)

	_world.add_child(tank)

func _process_background_army(delta: float) -> void:
	var tree = get_tree()
	if not tree: return
	for soldier in tree.get_nodes_in_group("ally_army"):
		if not is_instance_valid(soldier): continue
		
		# Skip units that don't have walk_speed meta (like Cheat Tanks)
		if not soldier.has_meta("walk_speed"): continue
		
		var base_speed = soldier.get_meta("walk_speed")
		
		# Move forward at their own pace
		soldier.position.x += base_speed * delta
		
		# ── Ground tracking: keep soldier glued to terrain ──
		# Tunnel soldiers keep their fixed y; surface soldiers follow terrain
		var is_tunnel_soldier = soldier.has_meta("on_tunnel") and soldier.get_meta("on_tunnel")
		if not is_tunnel_soldier:
			var target_y = _get_ground_y(soldier.position.x)
			soldier.position.y = lerp(soldier.position.y, target_y, 12.0 * delta)
		
		# If they fall too far behind, teleport ahead
		var cam_x = camera.position.x - 600
		if soldier.position.x < cam_x - 300:
			var nx = camera.position.x + 600 + randf_range(200, 1000)
			soldier.position.x = nx
			# Randomly assign upper or lower path for stages with tunnels
			if (current_stage == 2 or current_stage == 3) and randf() < 0.5:
				soldier.position.y = 650.0
				soldier.set_meta("on_tunnel", true)
			else:
				soldier.position.y = _get_ground_y(nx)
				soldier.set_meta("on_tunnel", false)
		
		# If they get too far ahead (very fast ones), teleport behind
		if soldier.position.x > camera.position.x + 1500:
			var nx = cam_x - 200
			soldier.position.x = nx
			if (current_stage == 2 or current_stage == 3) and randf() < 0.5:
				soldier.position.y = 650.0
				soldier.set_meta("on_tunnel", true)
			else:
				soldier.position.y = _get_ground_y(nx)
				soldier.set_meta("on_tunnel", false)

func _spawn_heavy_enemy(x, y, type: String) -> void:
	var e = null
	if type == "tank":
		e = CharacterBody2D.new()
		e.set_script(TANK_SCENE)
		e.add_to_group("tank")
	
	if e:
		_world.add_child(e)
		e.position = Vector2(x, y)

func _show_stage_intro(num) -> void:
	var names = [
		"MÀN 1: RỪNG SÂU", 
		"MÀN 2: ĐỊA ĐẠO CỦ CHI", 
		"MÀN 3: ĐƯỜNG TRƯỜNG SƠN", 
		"MÀN 4: CĂN CỨ ĐỊCH", 
		"MÀN 5: CHIẾN THẮNG CUỐI CÙNG"
	]
	if num <= names.size():
		stage_label.text = names[num-1]
		stage_label.visible = true
		var tree = get_tree()
		if tree:
			await tree.create_timer(3.0).timeout
			stage_label.visible = false

func screen_shake(p, t) -> void:
	_shake_power = p
	_shake_time = t

func on_player_die():
	_start_stage(current_stage)

func on_stage_complete():
	if current_stage == 5:
		_show_victory()
	else:
		PlayerData.unlock_next_stage()
		var tree = get_tree()
		if tree:
			tree.change_scene_to_file("res://scenes/level_select.tscn")

func _show_victory():
	is_game_over = true
	# Clear everything for victory
	var tree = get_tree()
	if tree:
		for n in tree.get_nodes_in_group("enemy"): n.queue_free()
	
	stage_label.text = "CHIẾN THẮNG HUY HOÀNG!\nGIẢI PHÓNG MIỀN NAM"
	stage_label.visible = true
	
	# === LÁ CỜ MẶT TRẬN GIẢI PHÓNG KÉO LÊN ===
	if current_stage == 5:
		# Cột cờ Dinh Độc Lập
		var flag_pole = ColorRect.new()
		flag_pole.size = Vector2(12, 500)
		flag_pole.position = Vector2(STAGE_LENGTH - 150, 100)
		flag_pole.color = Color(0.7, 0.7, 0.7)
		flag_pole.z_index = -8
		_world.add_child(flag_pole)
		
		# Chân đế cột cờ
		var base = ColorRect.new(); base.size = Vector2(40, 20); base.position = Vector2(STAGE_LENGTH - 164, 600); base.color = Color(0.4, 0.4, 0.4); base.z_index = -8; _world.add_child(base)
		
		# Lá cờ nửa trên đỏ, nửa dưới xanh, sao vàng
		var giant_flag = Node2D.new()
		giant_flag.position = Vector2(STAGE_LENGTH - 144, 450) # Cờ bắt đầu kéo ở dưới
		giant_flag.z_index = -7
		_world.add_child(giant_flag)
		
		var red_half = ColorRect.new(); red_half.size = Vector2(240, 75); red_half.color = Color(0.85, 0.15, 0.15); giant_flag.add_child(red_half)
		var blue_half = ColorRect.new(); blue_half.size = Vector2(240, 75); blue_half.position = Vector2(0, 75); blue_half.color = Color(0.1, 0.4, 0.85); giant_flag.add_child(blue_half)
		
		var big_star = Polygon2D.new(); var s_pts = []
		for j in 10:
			var sr = 42 if j%2==0 else 16
			s_pts.append(Vector2(cos(j*TAU/10-PI/2)*sr, sin(j*TAU/10-PI/2)*sr))
		big_star.polygon = PackedVector2Array(s_pts); big_star.color = Color.YELLOW; big_star.position = Vector2(120, 75)
		giant_flag.add_child(big_star)
		
		# Anime kéo cờ từ từ lên đỉnh cột
		var tw_flag = create_tween()
		tw_flag.tween_property(giant_flag, "position:y", 100, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		# Hiệu ứng cờ bay phấp phới trong gió
		var wave_tw = create_tween().set_loops()
		wave_tw.tween_property(giant_flag, "scale:y", 0.95, 0.2)
		wave_tw.tween_property(giant_flag, "scale:y", 1.05, 0.2)
	
	# Victory SFX and slow mo
	Engine.time_scale = 0.5
	screen_shake(15.0, 2.0)
	
	# Spawn victory particles (fireworks)
	if tree:
		for i in 20:
			var delay = i * 0.15
			tree.create_timer(delay).timeout.connect(_spawn_firework)
	
		await tree.create_timer(6.0).timeout
		Engine.time_scale = 1.0
		tree.change_scene_to_file("res://scenes/menu.tscn")
	else:
		Engine.time_scale = 1.0

func _spawn_firework() -> void:
	var fw = ColorRect.new()
	fw.size = Vector2(6, 6)
	fw.color = [Color.RED, Color.YELLOW, Color.CYAN, Color.GREEN].pick_random()
	fw.position = camera.global_position + Vector2(randf_range(-400, 400), randf_range(-200, 100))
	add_child(fw)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(fw, "scale", Vector2(10, 10), 0.5)
	tw.tween_property(fw, "modulate:a", 0.0, 0.5)
	tw.finished.connect(fw.queue_free)

func _setup_cheat_menu() -> void:
	_cheat_menu = Control.new()
	_cheat_menu.name = "CheatMenu"
	_cheat_menu.visible = false
	_cheat_menu.z_index = 1000
	$UI.add_child(_cheat_menu)
	
	var bg = ColorRect.new()
	bg.size = Vector2(400, 500)
	bg.position = Vector2(376, 110)
	bg.color = Color(0, 0, 0, 0.85)
	_cheat_menu.add_child(bg)
	
	var title = Label.new()
	title.text = "GIAO DIỆN KIỂM THỬ (CHEAT)"
	title.position = Vector2(400, 130)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.YELLOW)
	_cheat_menu.add_child(title)
	
	var btn_v = VBoxContainer.new()
	btn_v.size = Vector2(360, 400)
	btn_v.position = Vector2(396, 170)
	btn_v.add_theme_constant_override("separation", 15)
	_cheat_menu.add_child(btn_v)
	
	var cheats = [
		{"id": "god", "name": "BẤT TỬ (GOD MODE)", "fn": _cheat_god_mode},
		{"id": "ammo", "name": "VÔ HẠN ĐẠN (INF AMMO)", "fn": _cheat_inf_ammo},
		{"id": "hp", "name": "HỒI ĐẦY MÁU", "fn": _cheat_heal},
		{"id": "s2", "name": "NHẢY ĐẾN MÀN 2", "fn": func(): _start_stage(2); _toggle_cheat_menu()},
		{"id": "s3", "name": "NHẢY ĐẾN MÀN 3", "fn": func(): _start_stage(3); _toggle_cheat_menu()},
		{"id": "tank", "name": "GỌI XE TĂNG CHIẾN ĐẤU", "fn": _cheat_spawn_tank},
		{"id": "speed", "name": "SIÊU TỐC ĐỘ", "fn": _cheat_speed},
	]
	
	for c in cheats:
		var b = Button.new()
		b.name = "Btn_" + c["id"]
		b.text = c["name"]
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(c["fn"])
		btn_v.add_child(b)
	
	# CRITICAL: Allow cheat menu to process even when the game is paused
	_cheat_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	process_mode = Node.PROCESS_MODE_ALWAYS

func _setup_pause_menu() -> void:
	_pause_menu = Control.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.visible = false
	_pause_menu.z_index = 2000 # On top of cheat menu
	_pause_menu.process_mode = PROCESS_MODE_ALWAYS
	$UI.add_child(_pause_menu)
	
	var dim_bg = ColorRect.new()
	dim_bg.size = Vector2(1152, 720) # Full screen
	dim_bg.color = Color(0, 0, 0, 0.7)
	_pause_menu.add_child(dim_bg)
	
	var panel = ColorRect.new()
	panel.size = Vector2(300, 200)
	panel.position = Vector2(426, 260)
	panel.color = Color(0.1, 0.1, 0.1, 0.9)
	_pause_menu.add_child(panel)
	
	var title = Label.new()
	title.text = "TẠM DỪNG"
	title.position = Vector2(426, 280)
	title.size = Vector2(300, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	_pause_menu.add_child(title)
	
	var btn_v = VBoxContainer.new()
	btn_v.size = Vector2(240, 100)
	btn_v.position = Vector2(456, 330)
	btn_v.add_theme_constant_override("separation", 20)
	_pause_menu.add_child(btn_v)
	
	var btn_resume = Button.new()
	btn_resume.text = "TIẾP TỤC"
	btn_resume.custom_minimum_size = Vector2(0, 45)
	btn_resume.pressed.connect(_toggle_pause_menu)
	btn_v.add_child(btn_resume)
	
	var btn_exit = Button.new()
	btn_exit.text = "THOÁT RA MENU"
	btn_exit.custom_minimum_size = Vector2(0, 45)
	btn_exit.pressed.connect(_exit_to_main_menu)
	btn_v.add_child(btn_exit)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			if not _is_paused: # Don't open cheat menu if game is paused by PauseMenu
				_toggle_cheat_menu()
		elif event.keycode == KEY_ESCAPE:
			if not _is_cheat_visible: # Don't open pause menu if cheat menu is open
				_toggle_pause_menu()

func _toggle_cheat_menu() -> void:
	_is_cheat_visible = !_is_cheat_visible
	_cheat_menu.visible = _is_cheat_visible
	_update_pause_state()

func _toggle_pause_menu() -> void:
	_is_paused = !_is_paused
	_pause_menu.visible = _is_paused
	_update_pause_state()

func _update_pause_state() -> void:
	get_tree().paused = _is_cheat_visible or _is_paused

func _exit_to_main_menu() -> void:
	get_tree().paused = false # Must resume before changing scene
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://scenes/menu.tscn")

func _cheat_god_mode() -> void:
	if is_instance_valid(player):
		player.is_god_mode = !player.is_god_mode
		var btn = _cheat_menu.find_child("Btn_god", true, false)
		if btn: btn.text = "GOD MODE: " + ("BẬT" if player.is_god_mode else "TẮT")
		ui_label.text = "GOD MODE: " + ("BẬT" if player.is_god_mode else "TẮT")

func _cheat_inf_ammo() -> void:
	if is_instance_valid(player):
		player.is_infinite_ammo = !player.is_infinite_ammo
		var btn = _cheat_menu.find_child("Btn_ammo", true, false)
		if btn: btn.text = "INF AMMO: " + ("BẬT" if player.is_infinite_ammo else "TẮT")
		ui_label.text = "INF AMMO: " + ("BẬT" if player.is_infinite_ammo else "TẮT")

func _cheat_heal() -> void:
	if is_instance_valid(player):
		player.hp = player.max_hp
		player._sync_hp()
		ui_label.text = "ĐÃ HỒI MÁU!"

func _cheat_spawn_tank() -> void:
	if is_instance_valid(player):
		var tank = TANK_SCENE.new()
		tank.is_ally = true
		tank.position = player.position - Vector2(200, 0)
		_world.add_child(tank)

func _cheat_speed() -> void:
	if is_instance_valid(player):
		var is_fast = player.SPEED > 250.0
		player.SPEED = 500.0 if not is_fast else 240.0
		var btn = _cheat_menu.find_child("Btn_speed", true, false)
		if btn: btn.text = "SIÊU TỐC ĐỘ: " + ("BẬT" if !is_fast else "TẮT")
