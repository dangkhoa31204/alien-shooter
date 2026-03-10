extends Node2D

# contra_main.gd - v2.0 (Modularized Stages)
# Premium Side-scrolling controller with Bombers and Progress Tracking.

const PLAYER_SCENE = preload("res://scenes/contra_player.tscn")
const ENEMY_SCENE  = preload("res://scenes/contra_enemy.tscn")
const BOMBER_SCENE = preload("res://scenes/contra_bomber.tscn")
const TURRET_SCENE = preload("res://scenes/contra_turret.tscn")
const TANK_SCENE   = preload("res://scripts/contra_tank.gd")

const STAGE_SCRIPTS = {
	1: preload("res://scripts/stages/contra_jungle.gd"),
	2: preload("res://scripts/stages/contra_tunnels.gd"),
	3: preload("res://scripts/stages/contra_highlands.gd"),
	4: preload("res://scripts/stages/contra_base.gd"),
	5: preload("res://scripts/stages/contra_final.gd")
}

var STAGE_LENGTH: float = 12000.0 # Increased for longer gameplay
const RPG_MAX_COOLDOWN: float = 10.0

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
var last_checkpoint_x: float = 100.0
var _checkpoint_positions: Array[float] = []
var _rpg_cooldown_timer: float = 0.0 # Added for RPG cooldown tracking
var _perf_frame: int = 0

func _get_ground_y(x: float) -> float:
	if current_stage in [1, 2, 3] and not _stage_terrain.is_empty():
		var size = _stage_terrain.size()
		# Fast Binary Search for large terrain sets
		var low = 0
		var high = size - 2
		var index = -1
		
		while low <= high:
			var mid = (low + high) / 2
			if x >= _stage_terrain[mid].x and x <= _stage_terrain[mid+1].x:
				index = mid
				break
			elif x < _stage_terrain[mid].x:
				high = mid - 1
			else:
				low = mid + 1
				
		if index != -1:
			var p1 = _stage_terrain[index]
			var p2 = _stage_terrain[index+1]
			if p1.x == p2.x: return p1.y
			var t = (x - p1.x) / (p2.x - p1.x)
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
	
	if _rpg_cooldown_timer > 0:
		_rpg_cooldown_timer -= delta
		if _rpg_cooldown_timer < 0:
			_rpg_cooldown_timer = 0
		refresh_heavy_weapon(_rpg_cooldown_timer, RPG_MAX_COOLDOWN)
	
	if is_instance_valid(player):
		var target_x = player.position.x
		camera.position.x = lerp(camera.position.x, target_x, 8.0 * delta)
		# FIX: always clamp min to 576 (half screen) so left edge never shows negative world x
		camera.position.x = clamp(camera.position.x, 576.0, STAGE_LENGTH - 500)
		
		# Sync B40 HUD from actual player cooldown
		if player.get("rpg_cooldown") != null:
			refresh_heavy_weapon(player.rpg_cooldown, RPG_MAX_COOLDOWN)
		
		# Vertical Camera Follow (Follow player into tunnels)
		var target_y = 360.0
		if player.position.y > 650:
			target_y = 550.0 # Shift down to see the tunnel path clearly
		camera.position.y = lerp(camera.position.y, target_y, 4.0 * delta)
		
		_parallax_bg.position.x = camera.position.x * 0.4
		
		# Update Progress Bar
		progress_bar.value = player.position.x
		
		if player.position.x > STAGE_LENGTH - 100: on_stage_complete()
		
		# Staggered background army processing (update subset of units per frame)
		_perf_frame += 1
		_process_background_army(delta)
		
		# Army spawn: soldiers enter from the LEFT edge, march right alongside player
		_army_spawn_timer -= delta
		if _army_spawn_timer <= 0:
			var army_cap = 20 if current_stage == 5 else 14
			var current_army_count = tree.get_nodes_in_group("ally_army").size()
			if current_army_count < army_cap:
				var spawn_count = randi_range(2, 4)
				for _si in spawn_count:
					# Spawn just past the left edge of screen so they walk in immediately
					var sx = camera.position.x - 576 - randf_range(10, 80)
					var use_tunnel = (current_stage == 2 and randf() < 0.35)
					var sy = 650.0 if use_tunnel else _get_ground_y(sx)
					_add_individual_background_soldier(sx, sy, use_tunnel)
			# Always reset timer
			_army_spawn_timer = 1.5 if tree.get_nodes_in_group("ally_army").size() < 5 else 3.0
		
		# Dynamic Enemy Spawning (To keep the action going)
		_enemy_spawn_timer -= delta
		if _enemy_spawn_timer <= 0:
			var enemies = tree.get_nodes_in_group("enemy").size()
			var base_max = 8
			if current_stage == 2: base_max = 12
			elif current_stage == 3: base_max = 8 # Less crowded for Map 3
			elif current_stage == 5: base_max = 4
			
			if enemies < base_max:
				var spawn_x = camera.position.x + 900 + randf_range(100, 400)
				if spawn_x < STAGE_LENGTH - 400:
					var ey = _get_ground_y(spawn_x) - 20
					if current_stage == 2: ey = 550
					_spawn_enemy(spawn_x, ey, randf() < 0.25)
			
			var st_timer = randf_range(1.5, 3.5) if current_stage == 3 else randf_range(2.0, 4.0)
			if current_stage == 2: st_timer = randf_range(1.5, 3.0)
			if current_stage == 3: st_timer = randf_range(5.0, 9.0) # Thưa ra hơn nữa
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
	var cam_x = camera.global_position.x
	for b in tree.get_nodes_in_group("enemy_bullet"):
		if not is_instance_valid(b): continue
		
		# Offscreen Cleanup for ALL bullets to save performance
		if b.global_position.x < cam_x - 800 or b.global_position.x > cam_x + 1200:
			b.queue_free()
			continue

		if not b.has_meta("is_bomb") and not b.has_meta("is_tank_shell"): continue
		
		var ground_y = _get_ground_y(b.global_position.x)
		if b.global_position.y >= ground_y - 20:
			# Raycast only when close to ground
			var query = PhysicsRayQueryParameters2D.create(b.global_position, b.global_position + Vector2(0, 25))
			var result = space_state.intersect_ray(query)
			
			if result or b.global_position.y >= ground_y - 5:
				_explode_bomb(b.global_position)
				b.queue_free()
			elif b.global_position.y > 900: 
				b.queue_free()

func _explode_bomb(pos: Vector2) -> void:
	screen_shake(3.5, 0.25) # Reduced from 8.0, 0.4 for better visibility
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
	# Small horizontal bounce (opposite to firing direction), short arc
	var jump_x = randf_range(8, 25) * -dir
	var jump_y = -randf_range(15, 30)
	# Land near player's feet
	var ground_y = pos.y + randf_range(20, 40)
	tw.tween_property(shell, "position", pos + Vector2(jump_x, jump_y), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(shell, "rotation", randf_range(-PI, PI), 0.15)
	tw.tween_property(shell, "position:y", ground_y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(shell, "modulate:a", 0.0, 1.0)
	tw.finished.connect(shell.queue_free)

func _setup_background_sky(sky_color: Color = Color(0.1, 0.3, 0.6)) -> void:
	var sky = ColorRect.new(); sky.name = "BackgroundSky"; sky.size = Vector2(40000, 1000); sky.position = Vector2(-10000, -200); sky.z_index = -120
	sky.color = sky_color 
	_world.add_child(sky)
	
	var glow = Polygon2D.new(); _world.add_child(glow); glow.z_index = -95
	var g_pts = []
	for i in 16:
		var a = i * TAU / 16.0
		g_pts.append(Vector2(cos(a) * 400 + 4000, sin(a) * 150 + 100))
	glow.polygon = PackedVector2Array(g_pts); glow.color = Color(1.0, 0.8, 0.4, 0.15)
	
	for i in range(12):
		var mt = Polygon2D.new(); _parallax_bg.add_child(mt); mt.z_index = -110
		var mx = i * 800 - 2000; var h = randf_range(200, 450)
		mt.polygon = PackedVector2Array([Vector2(0, 720), Vector2(400, 720 - h), Vector2(800, 720)])
		mt.color = Color(0.12, 0.22, 0.4, 0.5)

func _start_stage(stage_num: int, is_respawn: bool = false) -> void:
	current_stage = stage_num
	STAGE_LENGTH = 12000.0 # Reset to default
	if not is_respawn: last_checkpoint_x = 100.0
	if progress_bar: progress_bar.max_value = STAGE_LENGTH
	is_game_over = false # FIX: must be false before cleanup so _process works from frame 1
	_cleanup_level()
	_load_stage_data(stage_num)
	_spawn_player()
	
	# FIX: spawn army AFTER _spawn_player so camera is correctly positioned
	for i in 6:
		var sx = camera.position.x + 100 + i * 140
		_add_individual_background_soldier(sx, _get_ground_y(sx))
		
	_show_stage_intro(stage_num)

func _spawn_player() -> void:
	if is_instance_valid(player): player.queue_free()
	player = PLAYER_SCENE.instantiate()
	_world.add_child(player)
	
	# FIX: spawn at minimum x=576 (= half screen) so player is never behind camera left edge
	var spawn_x = max(last_checkpoint_x, 576.0)
	player.position = Vector2(spawn_x, 500)
	# Snap to ground
	player.position.y = _get_ground_y(player.position.x) - 40
	# Sync camera immediately
	camera.position.x = player.position.x
	camera.position.y = 360.0

func _show_stage_intro(num: int) -> void:
	if stage_label:
		var titles = ["RỪNG GIÀ TÂY NGUYÊN", "ĐỊA ĐẠO CỦ CHI", "ĐƯỜNG MÒN HỒ CHÍ MINH", "CĂN CỨ ĐỊCH", "TIẾN VỀ SÀI GÒN"]
		stage_label.text = "CHIẾN DỊCH %d: %s" % [num, titles[num-1] if num <= titles.size() else "TIẾP TỤC"]
		stage_label.modulate.a = 1.0
		var tw = create_tween()
		tw.tween_interval(3.0)
		tw.tween_property(stage_label, "modulate:a", 0.0, 1.0)

func _cleanup_level() -> void:
	for n in _world.get_children():
		if n.name in ["Parallax", "BackgroundSky"]: continue
		if n is ColorRect and n.z_index == -10: continue
		if n is Polygon2D and n.z_index == -9: continue
		n.queue_free()
	
	var tree = get_tree()
	if tree:
		for n in tree.get_nodes_in_group("enemy"): n.queue_free()
		for n in tree.get_nodes_in_group("ally_army"): n.queue_free()  # FIX: was leaking old soldiers
		for n in tree.get_nodes_in_group("player_bullet"): n.queue_free()  # FIX: clear stale bullets
		for n in tree.get_nodes_in_group("enemy_bullet"): n.queue_free()
	_stage_terrain.clear()
	# Reset all timers
	_bomber_timer = 5.0
	_enemy_spawn_timer = 2.0
	_army_spawn_timer = 1.0  # FIX: was never reset, causing spawn delay bug on respawn
	_checkpoint_positions.clear()
	# Remove old checkpoint markers
	if progress_bar:
		for c in progress_bar.get_children(): c.queue_free()
	_rpg_cooldown_timer = 0.0

func _load_stage_data(num: int) -> void:
	if STAGE_SCRIPTS.has(num):
		var stage_script = STAGE_SCRIPTS[num]
		var stage_instance = stage_script.new(self)
		stage_instance.setup()
		_update_checkpoint_ui()
	else:
		# Fallback to Stage 1 script
		var stage_script = STAGE_SCRIPTS[1]
		var stage_instance = stage_script.new(self)
		stage_instance.setup()

# Stage setups moved to separate scripts in res://scripts/stages/

func _create_giant_ancient_tree(pos: Vector2) -> void:
	var tree = Node2D.new(); tree.position = pos; _world.add_child(tree)
	tree.z_index = -50 # Keep giant trunks in background
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
	var fern = Node2D.new(); fern.position = pos; _world.add_child(fern); fern.z_index = -5 # Move BEHIND characters
	for i in 8:
		var leaf = Polygon2D.new(); var a = -PI/1.2 - i * PI/6.0
		var lsize = randf_range(20, 45)
		leaf.polygon = PackedVector2Array([Vector2(0,0), Vector2(lsize, -lsize/3.0), Vector2(lsize*0.8, lsize/3.0)])
		leaf.color = Color(0.1, 0.4 + randf()*0.2, 0.05); leaf.rotation = a
		fern.add_child(leaf)

func _create_dense_shrub(pos: Vector2) -> void:
	var shrub = Node2D.new(); shrub.position = pos; _world.add_child(shrub); shrub.z_index = -5 # Move BEHIND characters
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
		_world.add_child(leaf); leaf.z_index = -5 # Less intrusive vines


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
	# Decorations are handled by stage scripts now


func _create_burning_wreckage(pos: Vector2) -> void:
	var wreckage = Node2D.new(); wreckage.position = pos; _world.add_child(wreckage); wreckage.z_index = -5
	var base = ColorRect.new(); base.size = Vector2(40, 15); base.position = Vector2(-20, -15); base.color = Color(0.1, 0.1, 0.1); wreckage.add_child(base)
	
	for i in 3: # Smoke plumes
		var s = ColorRect.new(); s.size = Vector2(10, 10); s.color = Color(0.2, 0.2, 0.2, 0.6); s.position = Vector2(randf_range(-15, 15), -20)
		wreckage.add_child(s)
		var tw = create_tween().set_loops()
		tw.tween_property(s, "position:y", s.position.y - 60, 2.0).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(s, "modulate:a", 0.0, 2.0)
		tw.tween_property(s, "position:y", -20, 0); tw.tween_property(s, "modulate:a", 0.6, 0)

func _create_aa_gun_bg(pos: Vector2) -> void:
	var aa = Node2D.new(); aa.position = pos; _world.add_child(aa); aa.z_index = -8
	var base = ColorRect.new(); base.size = Vector2(30, 10); base.position = Vector2(-15, -10); base.color = Color(0.15, 0.2, 0.12); aa.add_child(base)
	var gun = ColorRect.new(); gun.size = Vector2(4, 35); gun.position = Vector2(-2, -45); gun.color = Color(0.1, 0.1, 0.1); aa.add_child(gun); gun.rotation = -0.4
	
	# Muzzle flash timer
	var timer = Timer.new(); aa.add_child(timer); timer.wait_time = randf_range(0.8, 2.0); timer.autostart = true; timer.start()
	timer.timeout.connect(func():
		var flash = Polygon2D.new(); flash.polygon = [Vector2(-10, 0), Vector2(10, 0), Vector2(0, -30)]
		flash.color = Color(1, 0.8, 0.4, 0.9); flash.position = Vector2(0, -45).rotated(gun.rotation); aa.add_child(flash)
		var tw = create_tween(); tw.tween_property(flash, "modulate:a", 0.0, 0.15); tw.finished.connect(flash.queue_free)
		# Add a tracer line shooting up
		var tracer = ColorRect.new(); tracer.size = Vector2(2, 600); tracer.color = Color(1, 0.9, 0.2, 0.4); tracer.position = flash.position
		tracer.rotation = gun.rotation; aa.add_child(tracer); var t_tw = create_tween(); t_tw.tween_property(tracer, "position:y", -800, 0.15); t_tw.finished.connect(tracer.queue_free)
	)

func _create_wooden_log_bridge(pos: Vector2) -> void:
	var bridge = Node2D.new(); bridge.position = pos; _world.add_child(bridge); bridge.z_index = 0
	for i in 6:
		var log = ColorRect.new(); log.size = Vector2(25, 10); log.position = Vector2(i*26 - 75, -10)
		log.color = Color(0.4, 0.25, 0.15).darkened(randf()*0.2); bridge.add_child(log)
		var moss = ColorRect.new(); moss.size = Vector2(25, 3); moss.position = Vector2(i*26 - 75, -12); moss.color = Color(0.2, 0.4, 0.1); bridge.add_child(moss)

func _create_gaz_truck_bg(pos: Vector2) -> void:
	var truck = Node2D.new(); truck.position = pos; _world.add_child(truck); truck.z_index = -15
	truck.modulate = Color(0.6, 0.7, 0.6, 0.8) # Blended into background
	var body = ColorRect.new(); body.size = Vector2(60, 25); body.position = Vector2(-30, -35); body.color = Color(0.15, 0.25, 0.15)
	var cabin = ColorRect.new(); cabin.size = Vector2(25, 18); cabin.position = Vector2(5, -45); cabin.color = Color(0.12, 0.22, 0.12)
	var wheels = [ColorRect.new(), ColorRect.new()]
	wheels[0].size = Vector2(12, 12); wheels[0].position = Vector2(-20, -15); wheels[1].size = Vector2(12, 12); wheels[1].position = Vector2(15, -15)
	truck.add_child(body); truck.add_child(cabin); for w in wheels: w.color = Color.BLACK; truck.add_child(w)

func _create_bicycle_convoy_bg(pos: Vector2) -> void:
	for i in 3:
		var b = Node2D.new(); b.position = pos + Vector2(i*60, 0); _world.add_child(b); b.z_index = -15
		var frame = ColorRect.new(); frame.size = Vector2(25, 2); frame.position = Vector2(-12, -18); frame.color = Color(0.1, 0.1, 0.1); b.add_child(frame)
		var goods = ColorRect.new(); goods.size = Vector2(30, 20); goods.position = Vector2(-15, -35); goods.color = Color(0.4, 0.3, 0.2); b.add_child(goods)
		var wheels = [ColorRect.new(), ColorRect.new()]
		wheels[0].size = Vector2(10, 10); wheels[0].position = Vector2(-12, -10); wheels[1].size = Vector2(10, 10); wheels[1].position = Vector2(5, -10)
		for w in wheels: w.color = Color(0.2, 0.2, 0.2); b.add_child(w)

func _generate_hilly_terrain(soil_color: Color, grass_color: Color, has_gaps: bool = false) -> void:
	_stage_terrain.clear()
	# FIX: start terrain at -700 so camera at min x=576 (screen left=0) always has ground
	var cur_x = -700.0
	var cur_y = 560.0
	var total_len = STAGE_LENGTH + 400.0
	
	# Flat safe zone: no height change in first 800px past spawn point (x=576+200=776)
	var flat_zone_end = 900.0
	
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
				var prev_y = cur_y
				var dy_max = 200.0
				if current_stage == 1: dy_max = 110.0 # Lower hills for Map 1
				var dy = randf_range(80, dy_max) * (1 if randf() < 0.5 else -1)
				if current_stage == 2:
					dy = 0
				# FIX: no height change in the startup flat zone
				if cx < flat_zone_end:
					dy = 0
				cur_y = clamp(cur_y + dy, 320.0, 640.0)
				
				# Sloped transition for smoother mountains (Map 3 fix)
				var slope_w = randf_range(150, 300) # Increased for smoother climb
				slope_w = max(slope_w, abs(dy) * 1.8) # Ensure slope is walkable (below 45 degrees)
				if cx + slope_w < end_x and current_stage != 2:
					# Add multiple points for a curved slope
					surface_pts.append(Vector2(cx + slope_w * 0.3, lerp(prev_y, cur_y, 0.2)))
					surface_pts.append(Vector2(cx + slope_w * 0.7, lerp(prev_y, cur_y, 0.8)))
					cx += slope_w
					surface_pts.append(Vector2(cx, cur_y))
				else:
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
		ground.z_index = -25 # Ensure background units (z=-5) are above the soil
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
			cur_x = end_x + randf_range(80, 200)
			if cur_x <= total_len:
				_stage_terrain.append(Vector2(end_x + 1, 740.0))
				_stage_terrain.append(Vector2(cur_x - 1, 740.0))
		else:
			cur_x = end_x
	
	# Mist Layer (Final cleanup layer)
	for i in 15:
		var fog = ColorRect.new(); fog.size = Vector2(1500, 400); fog.position = Vector2(i * 1200, 300); fog.color = Color(1,1,1,0.05); fog.z_index = 5
		_world.add_child(fog)



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
		var ey = _get_ground_y(x) - 20.0 # Just slightly above to drop onto ground
		if current_stage == 2:
			ey = 550 # Only spawn on surface ground
		
		# Ensure they are not stacked exactly on top of other enemies (increased spacing)
		for e in get_tree().get_nodes_in_group("enemy"):
			if abs(e.position.x - x) < 200: 
				x += 300 # Push much further if too close
				ey = _get_ground_y(x) - 20.0
		
		if x > STAGE_LENGTH - 400: continue
		_spawn_enemy(x, ey, is_off)
		
		# Sniper logic restricted: only for Base/Tunnel stages where formal platforms exist
		if (current_stage == 2 or current_stage == 4) and randf() < 0.1: 
			_spawn_enemy(x + 120, ey - 200, false)
		
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
	tree.z_index = -20 # Keep behind all characters and allied units
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
		var is_tun: bool = false
		if current_stage == 2 and i % 2 == 0:
			y = 650.0  # Lower/Tunnel path (only for Stage 2)
			is_tun = true
		else:
			y = _get_ground_y(x)
			is_tun = false
		_add_individual_background_soldier(x, y, is_tun)

func _add_individual_background_soldier(x: float, y: float = 600, is_tun: bool = false) -> void:
	# Check for overlaps (loosen even more to 60px for density)
	for s in get_tree().get_nodes_in_group("ally_army"):
		if abs(s.position.x - x) < 60: return 
	var soldier = Node2D.new()
	var body_node = Node2D.new(); soldier.add_child(body_node)
	var head_node = Node2D.new(); body_node.add_child(head_node)
	
	# Leg visuals (Back & Front)
	var leg_poly = PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(4.5, 16), Vector2(-4.5, 16)])
	var l_l = Polygon2D.new(); l_l.polygon = leg_poly; l_l.color = Color(0.12, 0.28, 0.1); l_l.name = "LegL"; soldier.add_child(l_l); l_l.position = Vector2(-3, 0)
	var l_r = Polygon2D.new(); l_r.polygon = leg_poly; l_r.color = Color(0.18, 0.4, 0.15); l_r.name = "LegR"; soldier.add_child(l_r); l_r.position = Vector2(3, 0)
	
	# --- Body (Olive Green Uniform with depth) ---
	var soldier_color = Color(0.18, 0.38, 0.15)
	var torso = Polygon2D.new()
	torso.polygon = PackedVector2Array([Vector2(-9, -18), Vector2(9, -18), Vector2(10, 0), Vector2(-10, 0)])
	torso.color = soldier_color
	body_node.add_child(torso)
	
	# Shading
	var t_shade = Polygon2D.new(); t_shade.polygon = PackedVector2Array([Vector2(4, -18), Vector2(9, -18), Vector2(10, 0), Vector2(5, 0)]); t_shade.color = soldier_color.darkened(0.15); body_node.add_child(t_shade)
	
	# Ba lô con cóc (Backpack)
	var pack = Polygon2D.new(); pack.polygon = PackedVector2Array([Vector2(-14, -16), Vector2(-8, -16), Vector2(-8, -4), Vector2(-15, -6)]); pack.color = soldier_color.darkened(0.2); body_node.add_child(pack)

	# --- Head & Realistic Mũ Cối ---
	var face = ColorRect.new(); face.size = Vector2(10, 7); face.position = Vector2(-5, -23); face.color = Color(0.95, 0.8, 0.65); head_node.add_child(face)
	
	# Mũ Cối (High detail)
	var hat_base = Polygon2D.new(); hat_base.polygon = [Vector2(-11, -24), Vector2(11, -24), Vector2(9, -20), Vector2(-9, -20)]; hat_base.color = Color(0.1, 0.32, 0.1); head_node.add_child(hat_base)
	var hat_dome = Polygon2D.new(); hat_dome.polygon = [Vector2(-8, -24), Vector2(8, -24), Vector2(7, -33), Vector2(0, -35), Vector2(-7, -33)]; hat_dome.color = Color(0.15, 0.4, 0.15); head_node.add_child(hat_dome)
	
	# Star
	var star = Polygon2D.new(); var pts = []
	for j in 5:
		var a = j*TAU/5-PI/2; pts.append(Vector2(cos(a)*1.5, sin(a)*1.5 - 28))
	star.polygon = PackedVector2Array(pts); star.color = Color.YELLOW; head_node.add_child(star)
	
	# Rifle (Súng AK-47 visual)
	var gun = ColorRect.new(); gun.size = Vector2(28, 4); gun.position = Vector2(2, -12); gun.color = Color(0.08, 0.08, 0.08); body_node.add_child(gun)
	var stock = ColorRect.new(); stock.size = Vector2(6, 4); stock.position = Vector2(-4, -12); stock.color = Color(0.4, 0.15, 0.05); body_node.add_child(stock)
	
	soldier.z_index = -4
	# Snap Y immediately so soldiers don't fall from sky
	var snapped_y = 650.0 if is_tun else _get_ground_y(x)
	soldier.position = Vector2(x, snapped_y)
	soldier.add_to_group("ally_army")
	soldier.set_meta("walk_speed", randf_range(100, 180))  # Slightly faster so they keep up
	soldier.set_meta("on_tunnel", is_tun)
	soldier.set_meta("jump_time", 0.0)  # Pre-set so _process_background_army never fails
	_world.add_child(soldier)
	# Bobbing animation handled procedurally in _process_background_army (no looping tween)

	# Stage 5: occasional allied tank
	if current_stage == 5 and randf() < 0.25:
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
	tank.z_index = -3 # Just in front of allied soldiers
	
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
	var army_nodes = tree.get_nodes_in_group("ally_army")
	var cam_pos = camera.position
	
	for i in range(army_nodes.size()):
		var soldier = army_nodes[i]
		if not is_instance_valid(soldier): continue
		
		var cam_x = cam_pos.x
		var dist_to_cam = soldier.position.x - cam_x
		var leg_h = 0.0
		
		# --- Boundary checks FIRST (before any skip) ---
		# Too far behind the left edge: recycle or delete
		if dist_to_cam < -630:  # Just past left edge of screen (576px + buffer)
			if army_nodes.size() > 14:
				soldier.queue_free()
			else:
				# Recycle: place just off the left edge so they walk in again
				var nx = cam_x - 576 - randf_range(10, 60)
				soldier.position.x = nx
				soldier.position.y = _get_ground_y(nx)
				soldier.set_meta("on_tunnel", false)
			continue
		
		# Too far ahead (past right edge): send back to left edge to loop
		if dist_to_cam > 620:  # Just past right edge of screen
			soldier.position.x = cam_x - 576 - randf_range(10, 60)
			continue
		
		# Skip animation/movement for distant units (performance)
		if (i + _perf_frame) % 2 != 0: continue
		
		if not soldier.has_meta("walk_speed"): continue
		var base_speed = soldier.get_meta("walk_speed")
		soldier.position.x += base_speed * delta * 2.0
		
		# --- Procedural Animation ---
		var is_tank = soldier.has_meta("is_tank")
		if not is_tank:
			var walk_time = (Time.get_ticks_msec() / 1000.0) * 12.0 + float(soldier.get_instance_id() % 100)
			var step = sin(walk_time)
			var s_body = soldier.get_child(0) if soldier.get_child_count() > 0 else null
			if s_body:
				s_body.position.y = abs(step) * -4.0
				s_body.rotation = step * 0.04
			
			var s_leg_l = soldier.get_node_or_null("LegL"); var s_leg_r = soldier.get_node_or_null("LegR")
			if s_leg_l and s_leg_r:
				s_leg_l.position.x = -3 + step * 8.5
				s_leg_r.position.x = 3 - step * 8.5
				s_leg_l.rotation = step * 0.18
				s_leg_r.rotation = -step * 0.18
		
		# Ground snapping
		var is_tunnel_soldier = soldier.has_meta("on_tunnel") and soldier.get_meta("on_tunnel")
		if not is_tunnel_soldier:
			var tx = soldier.position.x
			leg_h = 0.0 if is_tank else 16.0
			var target_y = _get_ground_y(tx) - leg_h
			
			var jump_time = soldier.get_meta("jump_time", 0.0)
			var jump_offset = 0.0
			if jump_time > 0:
				jump_time -= delta * 3.0
				jump_offset = sin((1.0 - jump_time) * PI) * 60.0
				if jump_time <= 0: jump_time = 0
			else:
				if _get_ground_y(tx + 80.0) < target_y - 25.0:
					jump_time = 1.0
			
			soldier.set_meta("jump_time", jump_time)
			var final_target = target_y - jump_offset
			if soldier.position.y > target_y + 30:
				soldier.position.y = target_y
			else:
				var follow_speed = 12.0 if soldier.position.y < target_y else 25.0
				soldier.position.y = lerp(soldier.position.y, final_target, follow_speed * delta * 2.0)

func _spawn_heavy_enemy(x, y, type: String) -> void:
	var e = null
	if type == "tank":
		e = CharacterBody2D.new()
		e.set_script(TANK_SCENE)
		e.add_to_group("tank")
	
	if e:
		_world.add_child(e)
		e.position = Vector2(x, y)

func screen_shake(p, t) -> void:
	_shake_power = p
	_shake_time = t

func refresh_heavy_weapon(cooldown: float, max_cooldown: float) -> void:
	if not has_node("UI/HeavyWeaponBox"):
		var box = Node2D.new(); box.name = "HeavyWeaponBox"; box.position = Vector2(250, 45); $UI.add_child(box)
		var bg = ColorRect.new(); bg.size = Vector2(60, 40); bg.color = Color(0,0,0,0.5); box.add_child(bg)
		var icon = Label.new(); icon.text = "B40"; icon.position = Vector2(5, 2); icon.add_theme_font_size_override("font_size", 12); box.add_child(icon)
		var cd_lbl = Label.new(); cd_lbl.name = "CDLabel"; cd_lbl.position = Vector2(5, 18); cd_lbl.add_theme_font_size_override("font_size", 16); box.add_child(cd_lbl)
	
	var cd = $UI/HeavyWeaponBox/CDLabel
	if cooldown > 0:
		cd.text = "%.1fs" % cooldown
		cd.add_theme_color_override("font_color", Color.RED)
	else:
		cd.text = "SẴN SÀNG"
		cd.add_theme_color_override("font_color", Color.GREEN)

func on_player_die():
	_start_stage(current_stage, true) # Respawn at last checkpoint x

func on_stage_complete():
	if is_game_over: return  # FIX: prevent double-firing if player lingers at boundary
	if current_stage == 5:
		_show_victory()
	else:
		# --- EPIC STAGE VICTORY UI ---
		is_game_over = true # Stop enemy spawning/bombers
		
		var vic_title = Label.new()
		vic_title.text = "CHIẾN THẮNG!"
		vic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vic_title.add_theme_font_size_override("font_size", 60)
		vic_title.add_theme_color_override("font_color", Color.YELLOW)
		vic_title.add_theme_constant_override("outline_size", 10)
		vic_title.add_theme_color_override("font_outline_color", Color.DARK_RED)
		vic_title.size = Vector2(1152, 200); vic_title.position = Vector2(0, 200)
		$UI.add_child(vic_title)
		
		var sub = Label.new()
		sub.text = "NHIỆM VỤ HOÀN THÀNH - CHUẨN BỊ CHO CHIẾN DỊCH TIẾP THEO"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.size = Vector2(1152, 50); sub.position = Vector2(0, 320)
		sub.add_theme_font_size_override("font_size", 18); sub.add_theme_color_override("font_color", Color.WHITE)
		$UI.add_child(sub)
		
		PlayerData.unlock_next_stage()
		var tree = get_tree()
		if tree:
			await tree.create_timer(3.5).timeout
			tree.change_scene_to_file("res://scenes/level_select.tscn")


func _show_victory():
	is_game_over = true
	# Clear everything for victory
	var tree = get_tree()
	if tree:
		for n in tree.get_nodes_in_group("enemy"): n.queue_free()
	
	# Create an EPIC Victory Title (Big, Centered, Red & Gold)
	var vic_label = Label.new()
	vic_label.text = "GIẢI PHÓNG MIỀN NAM"
	vic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vic_label.add_theme_font_size_override("font_size", 54)
	vic_label.add_theme_color_override("font_color", Color.YELLOW)
	vic_label.add_theme_constant_override("outline_size", 12)
	vic_label.add_theme_color_override("font_outline_color", Color.RED)
	vic_label.size = Vector2(1152, 200); vic_label.position = Vector2(0, 120)
	$UI.add_child(vic_label)
	
	var btn = Button.new(); btn.text = "VỀ MÀN HÌNH CHÍNH"; btn.size = Vector2(250, 60); btn.position = Vector2(451, 360)
	btn.pressed.connect(_exit_to_main_menu)
	$UI.add_child(btn)

	
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
		{"id": "s4", "name": "NHẢY ĐẾN MÀN 4", "fn": func(): _start_stage(4); _toggle_cheat_menu()},
		{"id": "s5", "name": "NHẢY ĐẾN MÀN 5", "fn": func(): _start_stage(5); _toggle_cheat_menu()},
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

func _create_health_kit(pos: Vector2) -> void:
	var kit = Area2D.new(); kit.position = pos; _world.add_child(kit); kit.z_index = -1
	var col = CollisionShape2D.new(); var shp = CircleShape2D.new(); shp.radius = 30; col.shape = shp; kit.add_child(col)
	var box = ColorRect.new(); box.size = Vector2(30, 30); box.position = Vector2(-15, -15); box.color = Color.WHITE; kit.add_child(box)
	var cross1 = ColorRect.new(); cross1.size = Vector2(20, 6); cross1.position = Vector2(-10, -3); cross1.color = Color.RED; kit.add_child(cross1)
	var cross2 = ColorRect.new(); cross2.size = Vector2(6, 20); cross2.position = Vector2(-3, -10); cross2.color = Color.RED; kit.add_child(cross2)
	
	kit.body_entered.connect(func(body):
		if body.is_in_group("player"):
			if body.hp < body.max_hp:
				body.hp = min(body.hp + 1, body.max_hp)
				body._sync_hp(); kit.queue_free()
	)
	# Floating animation
	var tw = create_tween().set_loops()
	tw.tween_property(kit, "position:y", pos.y - 15, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(kit, "position:y", pos.y, 0.8).set_trans(Tween.TRANS_SINE)

func _create_checkpoint(pos: Vector2) -> void:
	var cp = Area2D.new(); cp.position = pos; _world.add_child(cp); cp.z_index = -2
	var col = CollisionShape2D.new(); var shp = RectangleShape2D.new(); shp.size = Vector2(100, 200); col.shape = shp; cp.add_child(col)
	
	# Visual: A red/blue pole that turns yellow when activated
	var pole = ColorRect.new(); pole.size = Vector2(8, 120); pole.position = Vector2(-4, -120); pole.color = Color(0.7, 0.7, 0.7); cp.add_child(pole)
	var flag = ColorRect.new(); flag.size = Vector2(40, 25); flag.position = Vector2(4, -120); flag.color = Color.BLUE; cp.add_child(flag)
	
	cp.body_entered.connect(func(body):
		if body.is_in_group("player") and last_checkpoint_x < pos.x:
			last_checkpoint_x = pos.x
			flag.color = Color.YELLOW # Activated
			ui_label.text = "ĐIỂM LƯU TẠM THỜI (CHECKPOINT)!"
	)
	_checkpoint_positions.append(pos.x)

func _update_checkpoint_ui() -> void:
	if not progress_bar: return
	# Remove old first
	for c in progress_bar.get_children(): c.queue_free()
	
	for cx in _checkpoint_positions:
		var marker = ColorRect.new()
		var ratio = cx / STAGE_LENGTH
		marker.size = Vector2(4, 14)
		marker.position = Vector2(ratio * 400 - 2, -2)
		marker.color = Color(0, 0.8, 1.0, 0.8) # Cyan marker
		progress_bar.add_child(marker)
