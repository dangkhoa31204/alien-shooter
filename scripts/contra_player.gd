extends CharacterBody2D

# contra_player.gd
# Advanced Side-scrolling player with Double Jump and Somersault animations.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")
const ROCKET_SCENE = preload("res://scripts/contra_rocket.gd") 

var SPEED: float = 240.0
const JUMP_VELOCITY: float = -500.0
const GRAVITY: float = 1400.0

var hp: int = 3
var max_hp: int = 3
var is_dead: bool = false
var ammo: int = 30
var is_reloading: bool = false
var reload_timer: float = 0.0
const MAX_AMMO: int = 30
const RELOAD_TIME: float = 5.0

var is_god_mode: bool = false
var is_infinite_ammo: bool = false

# Movement & Aiming state
var is_crouching: bool = false
var is_rolling: bool = false
var _roll_timer: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT
var jump_count: int = 0
const MAX_JUMPS: int = 2

# Anti-tank Weapon (RPG/B40)
var rpg_cooldown: float = 0.0
const RPG_MAX_COOLDOWN: float = 30.0
var _is_firing_rpg: bool = false
var _rpg_timer: float = 0.0
var _heavy_weapon_node: Node2D

# Animation timers
var _walk_time: float = 0.0
var _muzzle_flash_timer: float = 0.0
var _recoil_offset: float = 0.0
var _air_rotation: float = 0.0

@onready var sprite: Node2D = $Sprite
@onready var gun_point: Marker2D = $GunPoint
@onready var shoot_timer: Timer = $ShootTimer

# Nodes for animation
var _body_node: Node2D
var _head_node: Node2D
var _weapon_node: Node2D
var _leg_l: Node2D
var _leg_r: Node2D
var _muzzle_flash: Polygon2D

func _ready() -> void:
	add_to_group("player")
	_setup_complex_visuals()
	_sync_hp()

func _sync_hp() -> void:
	var main = _get_main_scene()
	if main:
		if main.has_method("refresh_hp"):
			main.refresh_hp(hp, max_hp)
		if main.has_method("refresh_ammo"):
			main.refresh_ammo(ammo, MAX_AMMO, is_reloading)

func _setup_complex_visuals() -> void:
	for n in sprite.get_children(): n.queue_free()
	
	_leg_l = Node2D.new()
	_leg_r = Node2D.new()
	_body_node = Node2D.new()
	_head_node = Node2D.new()
	_weapon_node = Node2D.new()
	_heavy_weapon_node = Node2D.new()
	
	sprite.add_child(_leg_l)
	sprite.add_child(_leg_r)
	sprite.add_child(_body_node)
	_body_node.add_child(_head_node)
	_body_node.add_child(_weapon_node)
	_body_node.add_child(_heavy_weapon_node)
	_heavy_weapon_node.visible = false
	
	_setup_rpg_visuals()

	# Leg Shading & Boots/Sandals
	var poly_leg = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(4, 18), Vector2(-4, 18)])
	var l_l = Polygon2D.new(); l_l.polygon = poly_leg; l_l.color = Color(0.12, 0.28, 0.1) # Dark Olive
	_leg_l.add_child(l_l); _leg_l.position = Vector2(-3, 0)
	var l_r = Polygon2D.new(); l_r.polygon = poly_leg; l_r.color = Color(0.14, 0.32, 0.12)
	_leg_r.add_child(l_r); _leg_r.position = Vector2(3, 0)
	
	# Rubber Sandals (Dép cao su)
	var sandal_l = ColorRect.new(); sandal_l.size = Vector2(10, 3); sandal_l.position = Vector2(-5, 15); sandal_l.color = Color(0.1, 0.1, 0.1)
	_leg_l.add_child(sandal_l)
	var sandal_r = ColorRect.new(); sandal_r.size = Vector2(10, 3); sandal_r.position = Vector2(-5, 15); sandal_r.color = Color(0.1, 0.1, 0.1)
	_leg_r.add_child(sandal_r)

	# --- Body (Olive Green Uniform) ---
	var body_poly = Polygon2D.new()
	body_poly.polygon = PackedVector2Array([Vector2(-9, -18), Vector2(9, -18), Vector2(11, 2), Vector2(-11, 2)])
	body_poly.color = Color(0.18, 0.38, 0.15) # Classic Bộ Đội Green
	_body_node.add_child(body_poly)
	
	# Shading/Detail on body (Vest/Straps)
	var vest = Polygon2D.new()
	vest.polygon = PackedVector2Array([Vector2(-9, -18), Vector2(9, -18), Vector2(4, -8), Vector2(-4, -8)])
	vest.color = Color(0.15, 0.3, 0.12); _body_node.add_child(vest)
	
	# Ba lô con cóc (Backpack)
	var bag = Polygon2D.new()
	bag.polygon = PackedVector2Array([Vector2(-14, -16), Vector2(-8, -16), Vector2(-8, -2), Vector2(-15, -4)])
	bag.color = Color(0.1, 0.25, 0.1); _body_node.add_child(bag)

	# --- Head & Mũ Cối ---
	var face = Polygon2D.new()
	face.polygon = PackedVector2Array([Vector2(-4, -22), Vector2(4, -22), Vector2(5.5, -16), Vector2(-5.5, -16)])
	face.color = Color(0.95, 0.78, 0.62) # Healthier skin tone
	_head_node.add_child(face)
	
	# Alert Eyes
	var eye_l = ColorRect.new(); eye_l.size = Vector2(1.5, 1.5); eye_l.position = Vector2(1, -20); eye_l.color = Color(0.1, 0.05, 0.0)
	var eye_r = ColorRect.new(); eye_r.size = Vector2(1.5, 1.5); eye_r.position = Vector2(3, -20); eye_r.color = Color(0.1, 0.05, 0.0)
	_head_node.add_child(eye_l); _head_node.add_child(eye_r)

	# Mũ Cối (Pith Helmet)
	var helmet_base = Polygon2D.new()
	helmet_base.polygon = PackedVector2Array([Vector2(-11, -23), Vector2(11, -23), Vector2(8, -20), Vector2(-8, -20)])
	helmet_base.color = Color(0.1, 0.35, 0.1)
	_head_node.add_child(helmet_base)
	
	var helmet_dome = Polygon2D.new()
	helmet_dome.polygon = PackedVector2Array([Vector2(-7, -23), Vector2(7, -23), Vector2(6, -30), Vector2(0, -32), Vector2(-6, -30)])
	helmet_dome.color = Color(0.12, 0.4, 0.12)
	_head_node.add_child(helmet_dome)
	
	# Red Star on Helmet
	var star = Polygon2D.new()
	var s_pts = []
	for i in 5:
		var a = i * TAU / 5.0 - PI/2.0
		s_pts.append(Vector2(cos(a)*1.5, sin(a)*1.5 - 26))
	star.polygon = PackedVector2Array(s_pts); star.color = Color.RED # Red star on helmet
	_head_node.add_child(star)

	# --- AK-47 Visuals ---
	var stock = Polygon2D.new()
	stock.polygon = PackedVector2Array([Vector2(-8,-2), Vector2(0,-2), Vector2(0,2), Vector2(-8,5)])
	stock.color = Color(0.4, 0.15, 0.05) # Wood
	_weapon_node.add_child(stock)
	
	var gun_body = ColorRect.new(); gun_body.size = Vector2(15, 6); gun_body.position = Vector2(0, -3); gun_body.color = Color(0.1, 0.1, 0.1)
	var barrel = ColorRect.new(); barrel.size = Vector2(14, 2); barrel.position = Vector2(15, -1); barrel.color = Color(0.2, 0.2, 0.2)
	var wooden_handguard = ColorRect.new(); wooden_handguard.size = Vector2(8, 3); wooden_handguard.position = Vector2(8, 0); wooden_handguard.color = Color(0.45, 0.2, 0.1)
	var mag = Polygon2D.new()
	# Curved AK-47 Mag
	mag.polygon = PackedVector2Array([Vector2(3, 3), Vector2(8, 3), Vector2(10, 12), Vector2(4, 12)])
	mag.color = Color(0.08, 0.08, 0.08)
	_weapon_node.add_child(gun_body); _weapon_node.add_child(barrel); _weapon_node.add_child(wooden_handguard); _weapon_node.add_child(mag)
	_weapon_node.position = Vector2(5, -6)
	
	_muzzle_flash = Polygon2D.new()
	_muzzle_flash.polygon = PackedVector2Array([Vector2(0, -5), Vector2(15, 0), Vector2(0, 5)])
	_muzzle_flash.color = Color(1.0, 0.8, 0.2, 0.0)
	_weapon_node.add_child(_muzzle_flash)
	_muzzle_flash.position = Vector2(28, 0)

func _setup_rpg_visuals() -> void:
	# RPG-7 / B40 Launcher
	var tube = ColorRect.new(); tube.size = Vector2(40, 5); tube.position = Vector2(-5, -2.5); tube.color = Color(0.15, 0.2, 0.1)
	var heat_shield = ColorRect.new(); heat_shield.size = Vector2(12, 7); heat_shield.position = Vector2(8, -3.5); heat_shield.color = Color(0.4, 0.2, 0.1)
	var sight = ColorRect.new(); sight.size = Vector2(4, 4); sight.position = Vector2(10, -6.5); sight.color = Color(0.1, 0.1, 0.1)
	_heavy_weapon_node.add_child(tube); _heavy_weapon_node.add_child(heat_shield); _heavy_weapon_node.add_child(sight)
	_heavy_weapon_node.position = Vector2(8, -8)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		jump_count = 0
		_air_rotation = 0

	# Jump and Double Jump
	if Input.is_action_just_pressed("ui_up") and jump_count < MAX_JUMPS:
		velocity.y = JUMP_VELOCITY
		jump_count += 1
		if jump_count == 2:
			_air_rotation = 0 # Reset for flip

	if is_rolling:
		_roll_timer -= delta
		velocity.x = sprite.scale.x * SPEED * 1.5
		if _roll_timer <= 0: is_rolling = false
	elif _is_firing_rpg:
		# Don't move while firing heavy weapon
		velocity.x = move_toward(velocity.x, 0, SPEED)
		_rpg_timer -= delta
		if _rpg_timer <= 0: _is_firing_rpg = false
	else:
		var dir_x := Input.get_axis("ui_left", "ui_right")
		if is_on_floor() and Input.is_action_pressed("ui_down"):
			is_crouching = true
			velocity.x = 0
			if Input.is_action_just_pressed("ui_accept"): # Shift/Action for roll
				is_rolling = true; _roll_timer = 0.4
		else:
			is_crouching = false
			if dir_x != 0:
				velocity.x = dir_x * SPEED
				sprite.scale.x = sign(dir_x)
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_update_aiming()
	_animate(delta)
	
	# Handle Cooldowns
	if rpg_cooldown > 0:
		rpg_cooldown -= delta
	
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			is_reloading = false
			ammo = MAX_AMMO
			_sync_hp()
	
	if Input.is_action_pressed("ui_accept") and shoot_timer.is_stopped() and not _is_firing_rpg and not is_reloading:
		_shoot()
		shoot_timer.start(0.12)
	elif not Input.is_action_pressed("ui_accept"):
		# Force muzzle flash off when button is released
		_muzzle_flash.color.a = 0.0
		_muzzle_flash_timer = 0.0
	
	if Input.is_key_pressed(KEY_A) and rpg_cooldown <= 0 and not is_rolling and not _is_firing_rpg:
		_fire_rpg()
	
	if is_on_floor() and abs(velocity.x) > 10 and int(_walk_time * 2.0) % 5 == 0:
		_spawn_dust()

func _fire_rpg() -> void:
	_is_firing_rpg = true
	_rpg_timer = 2.0 # Total animation time
	rpg_cooldown = RPG_MAX_COOLDOWN
	
	# Play specific firing sequence
	var tw = create_tween()
	# Switch weapon animation
	tw.tween_property(_weapon_node, "visible", false, 0.1)
	tw.parallel().tween_property(_heavy_weapon_node, "visible", true, 0.1)
	tw.parallel().tween_property(_heavy_weapon_node, "rotation", -0.4, 0.3) # Shoulder aim
	
	# Fire at 0.4s
	tw.tween_interval(0.4)
	tw.tween_callback(func():
		var target_pos = _get_rpg_target_pos()
		
		var rocket = Area2D.new() # Create instance
		rocket.set_script(ROCKET_SCENE)
		var main = _get_main_scene()
		if main: main.bullet_container.add_child(rocket)
		else: get_parent().add_child(rocket)
		
		# Set start position
		rocket.global_position = _heavy_weapon_node.global_position + Vector2(30 * sprite.scale.x, -5).rotated(_heavy_weapon_node.rotation)
		
		# Calculate effective direction (Auto-aim)
		var fire_dir = Vector2(sprite.scale.x, -0.2).normalized()
		if target_pos != Vector2.ZERO:
			fire_dir = (target_pos - rocket.global_position).normalized()
			# Update RPG visual rotation to aim at target
			_heavy_weapon_node.rotation = fire_dir.angle()
			if sprite.scale.x < 0: _heavy_weapon_node.rotation = (fire_dir * Vector2(-1, 1)).angle()
		
		rocket.direction = fire_dir
		
		# Recoil animation
		var r_tw = create_tween()
		r_tw.tween_property(_heavy_weapon_node, "position:x", _heavy_weapon_node.position.x - 15, 0.05)
		r_tw.tween_property(_heavy_weapon_node, "position:x", 8, 0.4)
	)
	
	# Put away
	tw.tween_interval(1.0)
	tw.tween_property(_heavy_weapon_node, "visible", false, 0.2)
	tw.parallel().tween_property(_weapon_node, "visible", true, 0.2)
	tw.parallel().tween_property(_heavy_weapon_node, "rotation", 0, 0)

func _get_rpg_target_pos() -> Vector2:
	var tree = get_tree()
	if not tree: return Vector2.ZERO
	
	var best_target = null
	var min_dist = 1000.0 # Effective range
	
	# Priority 1: Tanks
	for tank in tree.get_nodes_in_group("tank"):
		if not is_instance_valid(tank): continue
		var dist = global_position.distance_to(tank.global_position)
		# Check if target is in front of player
		var dir_to = (tank.global_position - global_position).normalized()
		if dist < min_dist and sign(dir_to.x) == sign(sprite.scale.x):
			min_dist = dist
			best_target = tank
	
	if best_target: return best_target.global_position
	
	# Priority 2: Other Enemies
	for enemy in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.is_in_group("tank"): continue
		var dist = global_position.distance_to(enemy.global_position)
		var dir_to = (enemy.global_position - global_position).normalized()
		if dist < min_dist and sign(dir_to.x) == sign(sprite.scale.x):
			min_dist = dist
			best_target = enemy
			
	return best_target.global_position if best_target else Vector2.ZERO

func _update_aiming() -> void:
	var dx := Input.get_axis("ui_left", "ui_right")
	var dy := 0.0
	if Input.is_action_pressed("ui_up"): dy -= 1.0
	if Input.is_action_pressed("ui_down"): dy += 1.0
	
	var facing = sprite.scale.x
	
	if dx == 0 and dy == 0: aim_direction = Vector2(facing, 0)
	elif dx != 0 and dy == 0: aim_direction = Vector2(dx, 0)
	elif dx == 0 and dy != 0: 
		aim_direction = Vector2(0, dy)
		if is_crouching and dy > 0: aim_direction = Vector2(facing, 0)
	else: aim_direction = Vector2(dx, dy).normalized()

	var weapon_target_rot = aim_direction.angle()
	if facing < 0:
		weapon_target_rot = (aim_direction * Vector2(-1, 1)).angle()
	
	# If flipping in air, don't update weapon rotation logic strictly
	if jump_count < 2:
		_weapon_node.rotation = lerp_angle(_weapon_node.rotation, weapon_target_rot, 0.3)
	
	gun_point.global_position = _muzzle_flash.global_position + aim_direction * 5

func _animate(delta: float) -> void:
	if is_rolling:
		sprite.rotation += delta * 20.0 * sprite.scale.x
		_body_node.position.y = 10
		_leg_l.rotation = 1.0; _leg_r.rotation = -1.0
	elif is_on_floor() and abs(velocity.x) > 10:
		_walk_time += delta * 12.0
		var step = sin(_walk_time)
		_leg_l.position.x = -3 + step * 8
		_leg_r.position.x = 3 - step * 8
		_body_node.position.y = abs(step) * -4
		_body_node.rotation = step * 0.05
		sprite.rotation = 0
	elif is_on_floor():
		_walk_time = 0
		_leg_l.position.x = lerp(_leg_l.position.x, -3.0, 0.2)
		_leg_r.position.x = lerp(_leg_r.position.x, 3.0, 0.2)
		_body_node.position.y = lerp(_body_node.position.y, 0.0, 0.2)
		_body_node.rotation = lerp_angle(_body_node.rotation, 0.0, 0.2)
		sprite.rotation = 0
	else:
		# Air Animation
		if is_rolling: pass # handeled above
		elif jump_count >= 2:
			# Double Jump Somersault Rotation - Much faster!
			_air_rotation += delta * 25.0 * sprite.scale.x
			sprite.rotation = _air_rotation
		else:
			# Normal jump pose
			sprite.rotation = lerp_angle(sprite.rotation, 0, 0.2)
			_body_node.rotation = velocity.y * 0.0012
			_leg_l.rotation = 0.6
			_leg_r.rotation = -0.6

	if is_reloading:
		# Weapon tilts down during reload
		_weapon_node.rotation = lerp_angle(_weapon_node.rotation, deg_to_rad(45), 0.1)
		# Weapon bobs slightly
		_weapon_node.position.y = -6 + sin(reload_timer * 10.0) * 2.0
	
	if is_crouching:
		_body_node.position.y = 8
		_leg_l.scale.y = 0.5; _leg_r.scale.y = 0.5
	else:
		_leg_l.scale.y = 1.0; _leg_r.scale.y = 1.0

	_recoil_offset = lerp(_recoil_offset, 0.0, 0.1)
	_weapon_node.position.x = 5 - _recoil_offset

func _shoot() -> void:
	if ammo <= 0 and not is_infinite_ammo:
		is_reloading = true
		reload_timer = RELOAD_TIME
		_sync_hp()
		_spawn_falling_mag() # Visual effect
		return

	if not is_infinite_ammo:
		ammo -= 1
		_sync_hp()
	
	var b = BULLET_SCENE.instantiate()
	if "direction" in b: b.direction = aim_direction
	b.is_enemy_bullet = false
	if "damage" in b: b.damage = 1
	var main = _get_main_scene()
	if main:
		main.bullet_container.add_child(b)
		if main.has_method("spawn_shell"):
			main.spawn_shell(gun_point.global_position, sprite.scale.x)
		if main.has_method("screen_shake"):
			main.screen_shake(2.0, 0.1)
	else:
		get_parent().add_child(b)
	
	b.global_position = gun_point.global_position
	b.add_to_group("player_bullet")
	_muzzle_flash.color.a = 1.0; _muzzle_flash_timer = 0.05; _recoil_offset = 6.0

func _spawn_dust() -> void:
	var main = _get_main_scene()
	if not main: return
	var d = ColorRect.new()
	d.size = Vector2(4, 4)
	d.color = Color(0.8, 0.7, 0.5, 0.6)
	d.position = global_position + Vector2(randf_range(-10, 10), 0)
	main._world.add_child(d)
	var tw = create_tween()
	tw.tween_property(d, "position:y", d.position.y - 20, 0.5)
	tw.parallel().tween_property(d, "modulate:a", 0.0, 0.5)
	tw.finished.connect(d.queue_free)

func _spawn_falling_mag() -> void:
	var mag = Polygon2D.new()
	mag.polygon = PackedVector2Array([Vector2(3, 3), Vector2(8, 3), Vector2(10, 12), Vector2(4, 12)])
	mag.color = Color(0.08, 0.08, 0.08)
	mag.global_position = _weapon_node.global_position
	
	var main = _get_main_scene()
	if main: main._world.add_child(mag)
	else: get_parent().add_child(mag)
	
	var tw = create_tween()
	var fall_dir = -sprite.scale.x
	tw.tween_property(mag, "position", mag.position + Vector2(fall_dir * 20, 100), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mag, "rotation", randf_range(-PI, PI), 1.0)
	tw.tween_property(mag, "modulate:a", 0.0, 0.5)
	tw.finished.connect(mag.queue_free)

func _get_main_scene() -> Node:
	var curr = get_parent()
	while curr != null:
		if curr.name == "ContraMain": return curr
		curr = curr.get_parent()
	return null

func take_damage(amount: int) -> void:
	if is_god_mode: return
	hp -= amount
	_sync_hp()
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color.RED, 0.1)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if hp <= 0: _die()

func _die() -> void:
	get_tree().call_deferred("reload_current_scene")
