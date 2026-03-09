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
		
		# Continuous Spawning for "Balanced Army" feel (Approx 7-8 active)
		_army_spawn_timer -= delta
		if _army_spawn_timer <= 0:
			var current_army = tree.get_nodes_in_group("ally_army").size()
			if current_army < 12: 
				var sx = camera.position.x + 800 + randf_range(200, 600)
				var sy = _get_ground_y(sx)
				if current_stage == 2 and randf() < 0.5: sy = 740 # Tunnel floor
				_add_individual_background_soldier(sx, sy)
			_army_spawn_timer = randf_range(2.5, 4.5)
		
		# Dynamic Enemy Spawning (To keep the action going)
		_enemy_spawn_timer -= delta
		if _enemy_spawn_timer <= 0:
			var enemies = tree.get_nodes_in_group("enemy").size()
			var max_enemies = 8 if current_stage == 2 else 8 # Stage 2 enemies reduced
			if enemies < max_enemies:
				var spawn_x = camera.position.x + 900 + randf_range(0, 300)
				if spawn_x < STAGE_LENGTH - 400:
					var ey = _get_ground_y(spawn_x) - 100
					if current_stage == 2: ey = 550
					_spawn_enemy(spawn_x, ey, randf() < 0.25)
			_enemy_spawn_timer = randf_range(1.5, 3.0) if current_stage == 2 else randf_range(2.0, 4.0)

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
	_setup_background_sky(Color(0.4, 0.7, 0.9)) # Clear tropical sky
	
	# Background Mountains (Truong Son Range)
	for i in 6:
		var mt = Polygon2D.new(); var mx = i * 2000; var mw = 2500
		mt.polygon = PackedVector2Array([Vector2(0, 600), Vector2(mw/2, 100), Vector2(mw, 600)])
		mt.color = Color(0.1, 0.25, 0.35, 0.4); mt.position = Vector2(mx, 100); mt.z_index = -90
		_world.add_child(mt)
	
	# Mid-ground Hills for Surface Depth (Behind the surface path)
	for i in 25:
		var hill = Polygon2D.new()
		var hx = i * 500 + randf_range(-100, 100)
		var hw = randf_range(200, 400); var hh = randf_range(50, 120)
		hill.polygon = PackedVector2Array([Vector2(-hw/2, 600), Vector2(0, 600-hh), Vector2(hw/2, 600)])
		hill.color = Color(0.08, 0.2, 0.05); hill.position.x = hx; hill.z_index = -40
		_world.add_child(hill)

	# 1. Lower Tunnel Floor (Using WorldBoundary for exact alignment)
	var tunnel_y = 740.0 
	var lower_floor = StaticBody2D.new()
	var tfcol = CollisionShape2D.new()
	var tfshape = WorldBoundaryShape2D.new()
	tfshape.normal = Vector2.UP
	tfcol.shape = tfshape
	lower_floor.add_child(tfcol)
	lower_floor.position.y = tunnel_y 
	_world.add_child(lower_floor)
	
	# Visual for the deep soil block
	var soil = ColorRect.new(); soil.size = Vector2(STAGE_LENGTH, 1000); soil.position = Vector2(0, 600); soil.color = Color(0.15, 0.08, 0.05)
	soil.z_index = -20 # Needs to be above sky (-110)
	_world.add_child(soil)

	# 2. Surface Path (Segmented Hilly Terrain)
	_generate_hilly_terrain(Color(0.18, 0.1, 0.05), Color(0.12, 0.4, 0.08), true)

	# 3. Tunnel Corridor (Adjusted for raised floor)
	var corr_h = tunnel_y - 605
	for i in range(STAGE_LENGTH / 250):
		var tx = i * 250
		var corridor = ColorRect.new(); corridor.size = Vector2(255, corr_h + 5); corridor.position = Vector2(tx, 605)
		corridor.color = Color(0.1, 0.06, 0.03); corridor.z_index = -12
		_world.add_child(corridor)
		
		# Root details coming from ceiling (Authentic Củ Chi feel)
		if randf() < 0.4:
			var root = Line2D.new(); root.width = randf_range(1.5, 3.0); root.default_color = Color(0.15, 0.1, 0.05)
			var cur_p = Vector2(tx + randf()*200, 605)
			for j in 6:
				root.add_point(cur_p - Vector2(tx, 0))
				cur_p += Vector2(randf_range(-12, 12), randf_range(15, 35))
			_world.add_child(root); root.position.x = tx

		if i % 3 == 0:
			var pole = ColorRect.new(); pole.size = Vector2(10, corr_h); pole.position = Vector2(tx, 605)
			pole.color = Color(0.25, 0.15, 0.08); pole.z_index = -11; _world.add_child(pole)
			var beam = ColorRect.new(); beam.size = Vector2(260, 10); beam.position = Vector2(tx, 605)
			beam.color = Color(0.2, 0.1, 0.05); beam.z_index = -11; _world.add_child(beam)
		
		# Debris/Soil texture on tunnel walls
		for j in 3:
			var dot = ColorRect.new(); dot.size = Vector2(randf()*4, randf()*4)
			dot.position = Vector2(tx + randf()*250, 630 + randf()*100); dot.color = Color(0.2, 0.1, 0.05).darkened(0.2)
			_world.add_child(dot)
		
		if i % 4 == 0:
			var lamp = ColorRect.new(); lamp.size = Vector2(8, 12); lamp.position = Vector2(tx + 120, 620); lamp.color = Color.YELLOW; _world.add_child(lamp)
			var glow = Polygon2D.new(); glow.polygon = PackedVector2Array([Vector2(-120, 250), Vector2(120, 250), Vector2(0,0)])
			glow.color = Color(1, 0.8, 0.2, 0.15); glow.position = Vector2(tx + 124, 625); _world.add_child(glow)

	_spawn_background_soldiers(6)
	_spawn_enemy_wave(8, 0.3) 
	_spawn_enemy(400, 550) # Early enemy for visibility
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


	# Moving Mist Layers (Thick Jungle Smoke/Fog)
	for i in 8:
		var mist = ColorRect.new(); mist.size = Vector2(3000, 800)
		mist.color = Color(0.2, 0.3, 0.2, 0.2); mist.position = Vector2(i*2500, 0); mist.z_index = 5
		_world.add_child(mist)
		var mtw = create_tween().set_loops()
		mtw.tween_property(mist, "position:x", mist.position.x + 800, 25.0)
		mtw.tween_property(mist, "position:x", mist.position.x, 25.0)

	# 1. Lower Tunnel Floor for Map 3 Parkour / path switching
	var floor_node = StaticBody2D.new()
	var col = CollisionShape2D.new(); var shape = WorldBoundaryShape2D.new(); shape.normal = Vector2.UP; col.shape = shape
	floor_node.add_child(col); floor_node.position.y = 750; _world.add_child(floor_node)
	
	var dirt = ColorRect.new(); dirt.color = Color(0.1, 0.08, 0.05); dirt.size = Vector2(STAGE_LENGTH+1000, 400); dirt.position = Vector2(-200, 740)
	dirt.z_index = -20; _world.add_child(dirt)
	
	# Tunnel wall background
	var bg_dirt = ColorRect.new(); bg_dirt.color = Color(0.12, 0.15, 0.1); bg_dirt.size = Vector2(STAGE_LENGTH+1000, 800); bg_dirt.position = Vector2(-200, 600); bg_dirt.z_index = -25; _world.add_child(bg_dirt)

	# Floating Stepped Terrain (now straight steps and gaps to access tunnel for parkour)
	_generate_hilly_terrain(Color(0.18, 0.1, 0.05), Color(0.12, 0.28, 0.08), true)

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

	_spawn_background_soldiers(12)
	_spawn_enemy_wave(50, 0.3) 
	
	# Spawn Tanks in Stage 3
	for i in 10:
		var tx = 1500 + i * 1100 + randf_range(-200, 200)
		var ty = _get_ground_y(tx)
		_spawn_heavy_enemy(tx, ty, "tank")

	_bomber_timer = 2.0
	
	# Mist Layer (Final cleanup layer)
	for i in 15:
		var fog = ColorRect.new(); fog.size = Vector2(1500, 400); fog.position = Vector2(i * 1200, 300); fog.color = Color(1,1,1,0.05); fog.z_index = 5
		_world.add_child(fog)

func _setup_base() -> void:
	# Stage 4: US Military Base (Căn cứ địch kiên cố)
	_setup_background_sky(Color(0.1, 0.1, 0.15)) # Night infiltration
	_create_floor_detailed(0, STAGE_LENGTH, 600, Color(0.25, 0.25, 0.28)) # Concrete floor

	# Concrete Walls & Fortifications
	for i in range(15):
		var wx = 800 + i * 1200; var ww = randf_range(150, 400); var wh = randf_range(60, 150)
		var wall = ColorRect.new(); wall.size = Vector2(ww, wh); wall.position = Vector2(wx, 600 - wh); wall.color = Color(0.35, 0.35, 0.38)
		_world.add_child(wall)
		# Barbed wire on top
		var wire = Line2D.new(); wire.width = 2.0; wire.default_color = Color(0.5, 0.5, 0.5)
		for j in 10: wire.add_point(Vector2(j * (ww/10.0), -10 + (j%2)*8))
		wall.add_child(wire)

	# Searchlights (Dynamic light beams)
	for i in 6:
		var sx = i * 2500 + 1000
		var light = Polygon2D.new(); light.polygon = PackedVector2Array([Vector2.ZERO, Vector2(250, 1000), Vector2(-250, 1000)])
		light.color = Color(1, 1, 0.8, 0.1); light.position = Vector2(sx, 100); _world.add_child(light)
		var ltw = create_tween().set_loops()
		ltw.tween_property(light, "rotation", deg_to_rad(45), 4.0).set_trans(Tween.TRANS_SINE)
		ltw.tween_property(light, "rotation", deg_to_rad(-45), 4.0).set_trans(Tween.TRANS_SINE)

	# Warning Lights (Pulsing Red)
	for i in 25:
		var lx = i * 600; var ly = 50
		var r_light = ColorRect.new(); r_light.size = Vector2(10, 10); r_light.position = Vector2(lx, ly); r_light.color = Color.RED; _world.add_child(r_light)
		var tw = create_tween().set_loops()
		tw.tween_property(r_light, "modulate:a", 0.0, 0.6); tw.tween_property(r_light, "modulate:a", 1.0, 0.6)

	# Turrets and Defense positions
	for i in range(12):
		var tx = 1500 + i * 1000 + randf_range(-100, 100)
		_spawn_turret(tx, 600)
		if randf() < 0.4: 
			var ty = randf_range(300, 450)
			_create_platform_detailed(Vector2(tx + 200, ty), 200)
			_spawn_turret(tx + 200, ty)

	_spawn_enemy_wave(22, 0.5) # High officer count for elite base guards
	_bomber_timer = 2.5
	_spawn_background_soldiers(12) # Add background army

func _setup_final_push() -> void:
	# Stage 5: Final Battle (Sunset sky, Boss at the end)
	_setup_background_sky(Color(0.8, 0.3, 0.1))
	_create_floor_detailed(0, STAGE_LENGTH, 600, Color(0.1, 0.2, 0.1))
	_spawn_decoration_density(0.6, 0.3)
	_spawn_background_soldiers(12) # Add background army
	_spawn_enemy_wave(25, 0.4)
	
	# Boss Fortress at the end
	_spawn_boss(STAGE_LENGTH - 600, 400)

func _spawn_turret(x, y) -> void:
	var t = TURRET_SCENE.instantiate()
	_world.add_child(t)
	t.position = Vector2(x, y)

func _spawn_boss(x, y) -> void:
	# Create a giant fortress wall with multiple turrets
	var base = ColorRect.new()
	base.size = Vector2(400, 600); base.position = Vector2(x, y - 400)
	base.color = Color(0.15, 0.15, 0.2); _world.add_child(base)
	
	# Add "Boss Core" - 3 main turrets that must be destroyed
	for i in 3:
		var bt = TURRET_SCENE.instantiate()
		bt.hp = 25 # Boss turrets are tougher
		bt.shoot_cooldown = 0.8
		bt.detection_range = 800.0
		bt.scale = Vector2(1.5, 1.5)
		_world.add_child(bt)
		bt.position = Vector2(x + 20, y - 300 + i * 120)
		bt.add_to_group("boss_core")
	
	# Signal end trigger is destruction of cores
	var win_check = Timer.new()
	win_check.wait_time = 1.0; win_check.autostart = true; win_check.name = "BossCheck"
	win_check.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(win_check)
	win_check.timeout.connect(func():
		if get_tree().get_nodes_in_group("boss_core").is_empty():
			on_stage_complete()
	)

# Helper to spawn enemies and decorations based on stage
func _spawn_enemy_wave(count: int, officer_p: float) -> void:
	for i in range(count):
		# Distribute across stage
		var x = 800 + i * (STAGE_LENGTH / count) + randf_range(-200, 200)
		if x > STAGE_LENGTH - 400: continue
		
		var is_off = randf() < officer_p
		var ey = _get_ground_y(x) - 100
		if current_stage == 2:
			ey = 550 # Only spawn on surface ground
		
		_spawn_enemy(x, ey, is_off)
		
		# Occasional extra sniper on high platforms
		if randf() < 0.15: _spawn_enemy(x + 100, ey - 200, false)
		
		# Tank spawning from Stage 3 onwards (rarer standalone)
		if current_stage >= 3 and randf() < 0.1:
			var tx = x + 300
			_spawn_heavy_enemy(tx, _get_ground_y(tx) - 10, "tank")
	
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
		var y = _get_ground_y(x)
		if current_stage == 2:
			y = 740 if i % 2 == 0 else 600 # Surface or Tunnel
		_add_individual_background_soldier(x, y)

func _add_individual_background_soldier(x: float, y: float = 600) -> void:
	# Check for overlaps to avoid bunching
	for s in get_tree().get_nodes_in_group("ally_army"):
		if abs(s.position.x - x) < 80: return # Too close, skip this one
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
	
	# Bobbing animation
	var tw = create_tween().set_loops()
	var anim_speed = randf_range(0.35, 0.45)
	tw.tween_property(soldier, "position:y", y - 6, anim_speed).set_trans(Tween.TRANS_SINE)
	tw.tween_property(soldier, "position:y", y, anim_speed).set_trans(Tween.TRANS_SINE)
	
	var stw = create_tween().set_loops()
	stw.tween_property(soldier, "scale:y", 1.05, anim_speed)
	stw.tween_property(soldier, "scale:y", 1.0, anim_speed)

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
		
		# If they fall too far behind, teleport ahead
		var cam_x = camera.position.x - 600
		if soldier.position.x < cam_x - 300:
			var nx = camera.position.x + 600 + randf_range(200, 1000)
			soldier.position.x = nx
			soldier.position.y = _get_ground_y(nx)
			# Re-assign layer in Stage 2 to keep mixing
			if current_stage == 2:
				soldier.position.y = 740 if randf() < 0.5 else 600
		
		# If they get too far ahead (very fast ones), teleport behind
		if soldier.position.x > camera.position.x + 1500:
			var nx = cam_x - 200
			soldier.position.x = nx
			soldier.position.y = _get_ground_y(nx)

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
