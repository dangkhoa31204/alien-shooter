extends CharacterBody2D

# contra_player.gd
# Advanced Side-scrolling player with Double Jump and Somersault animations.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")

# Animation name constants
const ANIM_IDLE         = &"idle"
const ANIM_RUN          = &"run"
const ANIM_RUN_SHOOT    = &"run_and_shoot"
const ANIM_JUMP         = &"jump"
const ANIM_DOUBLE_JUMP  = &"double_jump"
const ANIM_FALL         = &"fall"
const ANIM_PUNCH        = &"punch"
const ANIM_SHOOT        = &"shoot"
const ANIM_SHOOT_UP     = &"run_shoot_45_up"
const ANIM_SHOOT_DOWN   = &"shoot_45_down"
const ANIM_RELOAD       = &"reload"
const ANIM_RUN_RELOAD   = &"run_and_reload"
const ANIM_B40          = &"b40"
const ANIM_ANTI_AIR     = &"anti_air"
const ROCKET_SCENE = preload("res://scripts/contra_rocket.gd") 

# Optional: Custom scales for specific animations that have different source dimensions
const ANIM_SCALES = {
	ANIM_B40: Vector2(0.24, 0.24),        
	ANIM_RUN_SHOOT: Vector2(0.38, 0.38),  
	ANIM_SHOOT_UP: Vector2(0.38, 0.38),   
	ANIM_SHOOT_DOWN: Vector2(0.28, 0.28), 
	ANIM_ANTI_AIR: Vector2(0.28, 0.28),   
}
const DEFAULT_SCALE = Vector2(0.303, 0.289) # From .tscn

# Alignment offsets for the gun muzzle per animation
const ANIM_GUN_OFFSETS = {
	ANIM_IDLE:          Vector2(55.0, -10.0),
	ANIM_RUN:           Vector2(55.0, -10.0),
	ANIM_RUN_SHOOT:     Vector2(55.0, -10.0),
	ANIM_SHOOT:         Vector2(55.0, -10.0),
	ANIM_SHOOT_UP:      Vector2(45.0, -45.0), # run_shoot_45_up
	ANIM_SHOOT_DOWN:    Vector2(45.0, 34.0),  # shoot_45_down
	ANIM_ANTI_AIR:      Vector2(10.0, -55.0), # Standing straight up muzzle
	ANIM_B40:           Vector2(60.0, -15.0),
	ANIM_RELOAD:        Vector2(55.0, -10.0),
	ANIM_RUN_RELOAD:    Vector2(55.0, -10.0),
}

var SPEED: float = 240.0
const JUMP_VELOCITY: float = -500.0
const GRAVITY: float = 1400.0

var hp: int = 100
var max_hp: int = 100
var current_damage: int = 1
var current_fire_rate: float = 0.12
var is_dead: bool = false
var ammo: int = 30
var is_reloading: bool = false
var reload_timer: float = 0.0
const MAX_AMMO: int = 30
const RELOAD_TIME: float = 2.5

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
var rpg_max_cooldown: float = 10.0

# Anti-aircraft Missile (phím X)
var aa_cooldown: float = 0.0
var aa_max_cooldown: float = 10.0
var _aa_cool_bar = null
var _aa_cool_lbl: Label = null

# Melee attack
var melee_cooldown: float = 0.0
const MELEE_COOLDOWN_MAX: float = 0.6
const MELEE_DAMAGE: int = 2
const MELEE_RANGE: float = 60.0
var is_meleeing: bool = false
var _melee_anim_timer: float = 0.0
const MELEE_ANIM_DUR: float = 0.4
var _is_firing_rpg: bool = false
var _rpg_timer: float = 0.0
var _is_firing_aa: bool = false
var _aa_anim_timer: float = 0.0

# Animation timers
var _walk_time: float = 0.0
var _muzzle_flash_timer: float = 0.0

var _space_was_pressed: bool = false
var _shift_was_pressed: bool = false

@onready var gun_point: Marker2D = $GunPoint
@onready var shoot_timer: Timer = $ShootTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Muzzle flash (kept as a lightweight ColorRect on the AnimatedSprite)
var _muzzle_flash: ColorRect
var _facing: float = 1.0  # +1 right, -1 left

func _ready() -> void:
	add_to_group("player")
	_apply_loadout()
	_setup_sprite_visuals()
	_sync_hp()
	# Register melee input action for key F
	if not InputMap.has_action("melee"):
		var ev := InputEventKey.new()
		ev.keycode = KEY_F
		InputMap.add_action("melee")
		InputMap.action_add_event("melee", ev)

func _apply_loadout() -> void:
	max_hp = 100
	SPEED = 240.0
	current_damage = 1
	current_fire_rate = 0.12
	rpg_max_cooldown = 10.0
	aa_max_cooldown = 10.0
	
	if not PlayerData.inventory.is_empty():
		var arm_id = PlayerData.loadout.get("armor", "")
		if arm_id != "":
			var stat = ItemDatabase.get_stat(arm_id, "hp_bonus", PlayerData.inventory.get(arm_id, 1))
			max_hp += int(stat)
			
		var wpn_id = PlayerData.loadout.get("main_weapon", "")
		if wpn_id != "":
			current_damage = int(ItemDatabase.get_stat(wpn_id, "damage", PlayerData.inventory.get(wpn_id, 1)))
			var fr = ItemDatabase.get_stat(wpn_id, "fire_rate", PlayerData.inventory.get(wpn_id, 1))
			if fr > 0.0: current_fire_rate = fr
			
		var acc_id = PlayerData.loadout.get("accessory", "")
		if acc_id != "":
			var spd = ItemDatabase.get_stat(acc_id, "speed_bonus", PlayerData.inventory.get(acc_id, 1))
			SPEED += float(spd)
			
		var skl_id = PlayerData.loadout.get("skill", "")
		if skl_id != "":
			var stat = ItemDatabase.get_stat(skl_id, "cooldown", PlayerData.inventory.get(skl_id, 1))
			rpg_max_cooldown = stat
			
		var spc_id = PlayerData.loadout.get("special", "")
		if spc_id != "":
			var stat = ItemDatabase.get_stat(spc_id, "cooldown", PlayerData.inventory.get(spc_id, 1))
			aa_max_cooldown = stat
	
	hp = max_hp

func _sync_hp() -> void:
	var main = _get_main_scene()
	if main:
		if main.has_method("refresh_hp"):
			main.refresh_hp(hp, max_hp)
		if main.has_method("refresh_ammo"):
			main.refresh_ammo(ammo, MAX_AMMO, is_reloading)
		if main.has_method("refresh_heavy_weapon"):
			main.refresh_heavy_weapon(rpg_cooldown, rpg_max_cooldown)

func _setup_sprite_visuals() -> void:
	# Start with idle animation (scale is set in the .tscn scene, don't override)
	animated_sprite.position = Vector2(0, 0)
	animated_sprite.flip_h = false
	animated_sprite.play(ANIM_IDLE)
	_update_sprite_scale(ANIM_IDLE)

	# Lightweight muzzle-flash overlay attached to AnimatedSprite2D
	_muzzle_flash = ColorRect.new()
	_muzzle_flash.size    = Vector2(14, 10)
	_muzzle_flash.color   = Color(1.0, 0.9, 0.3, 0.0)
	_muzzle_flash.z_index = 3
	_muzzle_flash.position = Vector2(28, -8)  # rough gun-barrel offset (local to animated_sprite)
	animated_sprite.add_child(_muzzle_flash)

var _was_on_floor: bool = false

func _physics_process(delta: float) -> void:
	var space_pressed = Input.is_key_pressed(KEY_SPACE)
	var space_just_pressed = space_pressed and not _space_was_pressed
	_space_was_pressed = space_pressed
	
	var shift_pressed = Input.is_key_pressed(KEY_SHIFT)
	var shift_just_pressed = shift_pressed and not _shift_was_pressed
	_shift_was_pressed = shift_pressed

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		jump_count = 0

	# Jump and Double Jump
	if space_just_pressed:
		# Dropping down through one-way platforms (Down + Jump)
		if is_on_floor() and Input.is_action_pressed("ui_down"):
			position.y += 1
		elif jump_count < MAX_JUMPS:
			velocity.y = JUMP_VELOCITY
			jump_count += 1

	if is_rolling:
		_roll_timer -= delta
		velocity.x = _facing * SPEED * 1.5
		if _roll_timer <= 0: is_rolling = false
	elif _is_firing_rpg:
		# Don't move while firing heavy weapon
		velocity.x = move_toward(velocity.x, 0, SPEED)
		_rpg_timer -= delta
		if _rpg_timer <= 0: _is_firing_rpg = false
	elif _is_firing_aa:
		# Don't move while firing anti-air
		velocity.x = move_toward(velocity.x, 0, SPEED)
		_aa_anim_timer -= delta
		if _aa_anim_timer <= 0: _is_firing_aa = false
	else:
		var dir_x := Input.get_axis("ui_left", "ui_right")
		var is_down := Input.is_action_pressed("ui_down")
		
		if is_on_floor() and is_down:
			if dir_x == 0:
				is_crouching = true
				velocity.x = 0
			else:
				# Stationary diagonal aiming instead of running or crouching
				is_crouching = false
				velocity.x = 0
				# Update facing even when not moving
				_facing = sign(dir_x)
				animated_sprite.flip_h = (_facing < 0)
		else:
			is_crouching = false
			if dir_x != 0:
				velocity.x = dir_x * SPEED
				_facing = sign(dir_x)
				animated_sprite.flip_h = (_facing < 0)
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	# Landing dust: detect landing on floor this frame
	var now_on_floor := is_on_floor()
	if now_on_floor and not _was_on_floor and velocity.y > 80.0:
		var main := _get_main_scene()
		if main and main.has_method("spawn_landing_dust"):
			main.spawn_landing_dust(global_position)
	_was_on_floor = now_on_floor

	_update_aiming()
	_animate(delta)
	
	# Handle Cooldowns
	if rpg_cooldown > 0:
		rpg_cooldown -= delta
		_sync_hp()

	if aa_cooldown > 0:
		aa_cooldown -= delta
		_update_aa_hud()

	if melee_cooldown > 0:
		melee_cooldown -= delta

	if is_meleeing:
		_melee_anim_timer += delta
		if _melee_anim_timer >= MELEE_ANIM_DUR:
			is_meleeing = false
			_melee_anim_timer = 0.0
	
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			is_reloading = false
			ammo = MAX_AMMO
			_sync_hp()
	
	var s_pressed = Input.is_key_pressed(KEY_S)
	if s_pressed and shoot_timer.is_stopped() and not _is_firing_rpg and not is_reloading:
		_shoot()
		shoot_timer.start(current_fire_rate)
	elif not s_pressed:
		# Force muzzle flash off when button is released
		_muzzle_flash.color.a = 0.0
		_muzzle_flash_timer = 0.0
	
	if Input.is_key_pressed(KEY_A) and rpg_cooldown <= 0 and not is_rolling and not _is_firing_rpg:
		_fire_rpg()

	if Input.is_action_just_pressed("melee") and melee_cooldown <= 0 and not is_dead:
		_melee_attack()

	if Input.is_action_just_pressed("aa_missile") and aa_cooldown <= 0 and not is_dead:
		_fire_aa_missile()

	if is_on_floor() and abs(velocity.x) > 10 and int(_walk_time * 2.0) % 5 == 0:
		_spawn_dust()
		var _main := _get_main_scene()
		var _surface := "road" if (_main and _main.current_stage in [4, 5]) else "grass"
		Audio.play_footstep(_surface)

	# Keep gun_point aligned with the specific animation frames
	_update_gun_point(animated_sprite.animation)

func _fire_rpg() -> void:
	_is_firing_rpg = true
	_rpg_timer = 2.0 # Total animation time
	rpg_cooldown = rpg_max_cooldown
	animated_sprite.play(ANIM_B40)
	
	# Fire at 0.4s
	var tw = create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(func():
		var target_pos = _get_rpg_target_pos()
		
		var rocket = Area2D.new() # Create instance
		rocket.set_script(ROCKET_SCENE)
		var main = _get_main_scene()
		if main: main.bullet_container.add_child(rocket)
		else: get_parent().add_child(rocket)
		
		# Set start position from gun_point
		rocket.global_position = gun_point.global_position
		
		# Calculate effective direction (Auto-aim)
		var fire_dir = Vector2(_facing, -0.2).normalized()
		if target_pos != Vector2.ZERO:
			fire_dir = (target_pos - rocket.global_position).normalized()
		
		rocket.direction = fire_dir
		
		# Play launch sound (High volume as requested)
		Audio.play("b40", 15.0)
	)

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
		if dist < min_dist and sign(dir_to.x) == _facing:
			min_dist = dist
			best_target = tank
	
	if best_target: return best_target.global_position
	
	# Priority 2: Other Enemies
	for enemy in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.is_in_group("tank"): continue
		var dist = global_position.distance_to(enemy.global_position)
		var dir_to = (enemy.global_position - global_position).normalized()
		if dist < min_dist and sign(dir_to.x) == _facing:
			min_dist = dist
			best_target = enemy
			
	return best_target.global_position if best_target else Vector2.ZERO

func _update_aiming() -> void:
	var dx := Input.get_axis("ui_left", "ui_right")
	var dy := 0.0
	if Input.is_action_pressed("ui_up"): dy -= 1.0
	if Input.is_action_pressed("ui_down"): dy += 1.0
	
	if dx == 0 and dy == 0: aim_direction = Vector2(_facing, 0)
	elif dx != 0 and dy == 0: aim_direction = Vector2(dx, 0)
	elif dx == 0 and dy != 0:
		aim_direction = Vector2(0, dy)
		if is_crouching and dy > 0: aim_direction = Vector2(_facing, 0)
	else: aim_direction = Vector2(dx, dy).normalized()

	# gun_point is updated in _physics_process after movement

func _animate(_delta: float) -> void:
	# Muzzle flash fade
	_muzzle_flash_timer -= _delta
	if _muzzle_flash_timer <= 0.0:
		_muzzle_flash.color.a = 0.0

	# ── Pick the right animation based on state ──────────────────────────────
	var anim: StringName

	if is_meleeing:
		anim = ANIM_PUNCH
	elif _is_firing_rpg:
		anim = ANIM_B40
	elif _is_firing_aa:
		anim = ANIM_ANTI_AIR
	elif is_reloading:
		if is_on_floor() and abs(velocity.x) > 10:
			anim = ANIM_RUN_RELOAD
			# footstep dust
			_walk_time += _delta * 13.0
			var prev_sign: float = signf(sin(_walk_time - _delta * 13.0))
			var cur_sign: float  = signf(sin(_walk_time))
			if prev_sign != cur_sign:
				_spawn_footstep_dust()
		else:
			anim = ANIM_RELOAD
	elif not is_on_floor():
		# Airborne
		if jump_count >= 2:
			anim = ANIM_DOUBLE_JUMP
		elif velocity.y > 80.0:
			anim = ANIM_FALL
		else:
			anim = ANIM_JUMP
	elif abs(velocity.x) > 10:
		# Running
		var shooting := Input.is_key_pressed(KEY_S)
		
		if shooting:
			if aim_direction.y < -0.1: # Precise check for upward aiming
				anim = ANIM_SHOOT_UP
			else:
				anim = ANIM_RUN_SHOOT
		else:
			anim = ANIM_RUN
		# footstep dust
		_walk_time += _delta * 13.0
		var prev_sign: float = signf(sin(_walk_time - _delta * 13.0))
		var cur_sign: float  = signf(sin(_walk_time))
		if prev_sign != cur_sign:
			_spawn_footstep_dust()
	else:
		# Standing / crouching
		var shooting := Input.is_key_pressed(KEY_S)
		
		if is_crouching:
			anim = ANIM_IDLE # Fallback since no specific crawl/crouch anim listed
		elif shooting:
			if aim_direction.y < -0.9: # Straigh UP
				anim = ANIM_ANTI_AIR
			elif aim_direction.y < -0.1: # Diagonal UP
				anim = ANIM_SHOOT_UP
			elif aim_direction.y > 0.1: # Diagonal DOWN
				anim = ANIM_SHOOT_DOWN
			else:
				anim = ANIM_SHOOT
		else:
			# Non-shooting aiming
			if aim_direction.y < -0.9:
				anim = ANIM_ANTI_AIR
			elif aim_direction.y < -0.1:
				anim = ANIM_SHOOT_UP
			elif aim_direction.y > 0.1:
				anim = ANIM_SHOOT_DOWN
			else:
				anim = ANIM_IDLE

	# Only call play() when animation actually changes (avoids restart)
	if animated_sprite.animation != anim:
		animated_sprite.play(anim)
	
	# Update scale EVERY frame during _animate to ensure manual play() calls 
	# (like in _fire_rpg) don't bypass the scaling logic.
	_update_sprite_scale(anim)

func _update_gun_point(anim_name: StringName) -> void:
	var offset = ANIM_GUN_OFFSETS.get(anim_name, Vector2(55.0, -10.0))
	# Apply facing to X, keep Y as defined
	gun_point.position = Vector2(_facing * offset.x, offset.y)

func _update_sprite_scale(anim_name: StringName) -> void:
	var target_scale = ANIM_SCALES.get(anim_name, DEFAULT_SCALE)
	# Use target_scale directly; flip_h handles horizontal orientation
	animated_sprite.scale = target_scale

func _shoot() -> void:
	if ammo <= 0 and not is_infinite_ammo:
		is_reloading = true
		reload_timer = RELOAD_TIME
		_sync_hp()
		Audio.play("reload_ak47", 6.0) # Play reload sound, +6dB for clarity
		_spawn_falling_mag() # Visual effect
		return

	if not is_infinite_ammo:
		ammo -= 1
		_sync_hp()
	
	Audio.play("ak47_fire")
	var b = BULLET_SCENE.instantiate()
	if "direction" in b: b.direction = aim_direction
	b.is_enemy_bullet = false
	if "damage" in b: b.damage = current_damage
	var main = _get_main_scene()
	if main:
		main.bullet_container.add_child(b)
		if main.has_method("spawn_shell"):
			main.spawn_shell(gun_point.global_position, _facing)
		if main.has_method("screen_shake"):
			main.screen_shake(2.0, 0.1)
	else:
		get_parent().add_child(b)
	
	b.global_position = gun_point.global_position
	b.add_to_group("player_bullet")
	_muzzle_flash.color.a = 1.0
	_muzzle_flash_timer = 0.05
	_spawn_muzzle_smoke()

	# Point-blank fix: nếu enemy nằm trong vùng spawn đạn (~50px),
	# Godot sẽ không fire body_entered → gây sát thương trực tiếp.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy): continue
		var diff: Vector2 = (enemy as Node2D).global_position - gun_point.global_position
		if diff.length() <= 50.0 and sign(diff.x) == _facing:
			if enemy.has_method("take_damage"):
				enemy.take_damage(current_damage)

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
	mag.global_position = gun_point.global_position
	
	var main = _get_main_scene()
	if main: main._world.add_child(mag)
	else: get_parent().add_child(mag)
	
	var tw = create_tween()
	var fall_dir = -_facing
	tw.tween_property(mag, "position", mag.position + Vector2(fall_dir * 20, 100), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mag, "rotation", randf_range(-PI, PI), 1.0)
	tw.tween_property(mag, "modulate:a", 0.0, 0.5)
	tw.finished.connect(mag.queue_free)

# ── ANTI-AIRCRAFT MISSILE ────────────────────────────────────────────────────
func _fire_aa_missile() -> void:
	# Find nearest bomber in scene
	var target: Node2D = null
	var best_dist := 9999.0
	for b in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(b): continue
		if not ("contra_bomber" in b.get_script().resource_path.to_lower()): continue
		var d := global_position.distance_to((b as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			target = b as Node2D

	if target == null:
		# No bomber — show brief "NO TARGET" flash
		_aa_flash_no_target()
		return

	aa_cooldown = aa_max_cooldown
	_update_aa_hud()
	Audio.play("aa_sound", 8.0)
	
	_is_firing_aa = true
	_aa_anim_timer = 0.8 # Duration for the anti-air pose

	var main := _get_main_scene()

	# --- Missile node ---
	var missile := Node2D.new()
	missile.global_position = global_position + Vector2(_facing * 20.0, -30.0)
	missile.z_index = 8
	if main: main._world.add_child(missile)
	else: get_parent().add_child(missile)

	# Missile body (thin white rect)
	var body := ColorRect.new()
	body.size = Vector2(18, 5); body.position = Vector2(-9, -2)
	body.color = Color(0.9, 0.88, 0.82)
	missile.add_child(body)
	# Nose cone (orange tip)
	var nose := Polygon2D.new()
	nose.polygon = PackedVector2Array([Vector2(9, -3), Vector2(9, 3), Vector2(18, 0)])
	nose.color = Color(1.0, 0.45, 0.05)
	missile.add_child(nose)
	# Exhaust flame
	var flame := Polygon2D.new()
	flame.polygon = PackedVector2Array([Vector2(-9, -3), Vector2(-9, 3), Vector2(-22, 0)])
	flame.color = Color(1.0, 0.8, 0.2, 0.9)
	missile.add_child(flame)
	# Flame flicker
	var ftw: Tween = flame.create_tween().set_loops()
	ftw.tween_property(flame, "modulate:a", 0.4, 0.05)
	ftw.tween_property(flame, "modulate:a", 1.0, 0.05)

	# Smoke trail Line2D (grows as missile travels)
	var trail := Line2D.new()
	trail.width = 3.0
	trail.default_color = Color(0.7, 0.68, 0.65, 0.55)
	trail.z_index = 7
	if main: main._world.add_child(trail)
	else: get_parent().add_child(trail)

	# Animate missile toward target using Tween + per-frame callback
	var start_pos := missile.global_position
	var travel_time := clampf(best_dist / 900.0, 0.25, 1.2)
	var mtw: Tween = missile.create_tween()
	mtw.tween_method(
		func(t: float):
			if not is_instance_valid(missile): return
			if not is_instance_valid(target):
				# Target already dead — still travel forward
				missile.global_position = start_pos.lerp(
					start_pos + Vector2(_facing * best_dist, -60.0), t)
			else:
				var cur_target := target.global_position + Vector2(0, -20)
				# Slight arc: peak upward at mid-flight
				var arc_offset := Vector2(0, -80.0 * sin(t * PI))
				missile.global_position = start_pos.lerp(cur_target, t) + arc_offset
			# Rotate missile toward velocity direction
			if t > 0.01:
				var prev := start_pos.lerp(
					(target.global_position if is_instance_valid(target) else start_pos + Vector2(_facing * best_dist, 0)),
					maxf(t - 0.02, 0.0))
				var vel_dir := (missile.global_position - prev).normalized()
				missile.rotation = vel_dir.angle()
			# Append trail point
			if is_instance_valid(trail):
				trail.add_point(missile.global_position)
				if trail.get_point_count() > 30:
					trail.remove_point(0),
		0.0, 1.0, travel_time)

	# On arrival — explode
	mtw.tween_callback(func():
		var hit_pos := missile.global_position if is_instance_valid(missile) else start_pos
		# Damage target
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(45)
		# Explosion
		_spawn_aa_explosion(hit_pos, main)
		if main and main.has_method("screen_shake"): main.screen_shake(16.0, 0.5)
		if is_instance_valid(missile): missile.queue_free()
		# Fade trail
		if is_instance_valid(trail):
			var ttw: Tween = trail.create_tween()
			ttw.tween_property(trail, "modulate:a", 0.0, 0.6)
			ttw.finished.connect(trail.queue_free)
	)

func _spawn_aa_explosion(pos: Vector2, main: Node) -> void:
	if not main: return
	Audio.play("b40", 14.0)
	for ring in 3:
		var blast := Polygon2D.new()
		var pts: Array = []
		var rad := 50.0 + ring * 45.0
		for i in 12:
			var a := i * TAU / 12.0
			pts.append(Vector2(cos(a) * rad, sin(a) * rad))
		blast.polygon = PackedVector2Array(pts)
		blast.color = Color(1.0, 0.6 - ring * 0.12, 0.05, 0.9)
		blast.global_position = pos
		blast.z_index = 9
		main._world.add_child(blast)
		var btw: Tween = blast.create_tween().set_parallel(true)
		btw.tween_property(blast, "scale",      Vector2(3.0, 3.0), 0.5 + ring * 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		btw.tween_property(blast, "modulate:a", 0.0,               0.5 + ring * 0.1).set_delay(0.05 * ring)
		btw.finished.connect(blast.queue_free)
	# Debris sparks
	for _i in 8:
		var sp := ColorRect.new()
		sp.size = Vector2(4, 4)
		sp.color = Color(1.0, randf_range(0.3, 0.8), 0.0)
		sp.global_position = pos + Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 10.0))
		sp.z_index = 10
		main._world.add_child(sp)
		var stw: Tween = sp.create_tween().set_parallel(true)
		stw.tween_property(sp, "position", sp.global_position + Vector2(randf_range(-120.0, 120.0), randf_range(-80.0, 80.0)), 0.7).set_trans(Tween.TRANS_QUAD)
		stw.tween_property(sp, "modulate:a", 0.0, 0.5).set_delay(0.2)
		stw.finished.connect(sp.queue_free)

func _aa_flash_no_target() -> void:
	if not _aa_cool_lbl: _setup_aa_hud()
	if not _aa_cool_lbl: return
	_aa_cool_lbl.text = "KHÔNG CÓ MỤC TIÊU"
	_aa_cool_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	var tw: Tween = _aa_cool_lbl.create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func(): _update_aa_hud())

func _update_aa_hud() -> void:
	if not _aa_cool_bar: _setup_aa_hud()
	if not _aa_cool_bar: return
	_aa_cool_bar.max_value = aa_max_cooldown
	if aa_cooldown > 0.05:
		_aa_cool_bar.value = aa_max_cooldown - aa_cooldown
		if _aa_cool_lbl:
			_aa_cool_lbl.text = "%.1fs" % aa_cooldown
			_aa_cool_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	else:
		_aa_cool_bar.value = aa_max_cooldown
		if _aa_cool_lbl:
			_aa_cool_lbl.text = "SẴN SÀNG"
			_aa_cool_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

func _setup_aa_hud() -> void:
	var main := _get_main_scene()
	if not main: return
	_aa_cool_bar = main.get_node_or_null("UI/HUDPanel/AACoolBar")
	_aa_cool_lbl = main.get_node_or_null("UI/HUDPanel/AACDLabel")
	if _aa_cool_bar:
		_aa_cool_bar.max_value = aa_max_cooldown

func _get_main_scene() -> Node:
	var curr = get_parent()
	while curr != null:
		if curr.name == "ContraMain": return curr
		curr = curr.get_parent()
	return null

func _spawn_muzzle_smoke() -> void:
	var main := _get_main_scene()
	if not main: return
	var wisp := Polygon2D.new()
	var pts: Array = []
	var r := 5.0
	for i in 6:
		var a := i * TAU / 6.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	wisp.polygon = PackedVector2Array(pts)
	wisp.color = Color(0.9, 0.85, 0.75, 0.5)
	wisp.global_position = gun_point.global_position
	wisp.z_index = 4
	main._world.add_child(wisp)
	var tw: Tween = wisp.create_tween()
	var drift_x := aim_direction.x * 22.0
	tw.tween_property(wisp, "position", wisp.position + Vector2(drift_x, -28.0), 0.55)
	tw.parallel().tween_property(wisp, "scale", Vector2(2.2, 2.2), 0.55)
	tw.parallel().tween_property(wisp, "modulate:a", 0.0, 0.55)
	tw.finished.connect(wisp.queue_free)

func _spawn_footstep_dust() -> void:
	var main := _get_main_scene()
	if not main: return
	for i in 2:
		var d := ColorRect.new()
		d.size = Vector2(3, 3)
		d.color = Color(0.8, 0.72, 0.56, 0.6)
		d.global_position = global_position + Vector2(randf_range(-8.0, 8.0), 0.0)
		d.z_index = 3
		main._world.add_child(d)
		var tw: Tween = d.create_tween()
		tw.tween_property(d, "position:y", d.position.y - randf_range(8.0, 18.0), 0.35)
		tw.parallel().tween_property(d, "modulate:a", 0.0, 0.35)
		tw.finished.connect(d.queue_free)

func _melee_attack() -> void:
	melee_cooldown = MELEE_COOLDOWN_MAX
	is_meleeing       = true
	_melee_anim_timer = 0.0
	Audio.play("punch")
	var facing := _facing

	# Damage is applied at the impact frame (t ≈ 0.18)
	# Schedule it via a short timer so it aligns with the animation
	var hit_timer := get_tree().create_timer(0.18)
	hit_timer.timeout.connect(func():
		if not is_instance_valid(self): return
		var hit_any := false
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(enemy): continue
			var diff: Vector2 = enemy.global_position - global_position
			if diff.length() <= MELEE_RANGE and sign(diff.x) == facing:
				if enemy.has_method("take_damage"):
					# Lính thường: 1 hit chết; tank giữ damage thấp
					var dmg := 12 if enemy.is_in_group("tank") else 999
					enemy.take_damage(dmg)
					hit_any = true
		if hit_any:
			# Spawn spark
			var spark := ColorRect.new()
			spark.size = Vector2(10, 10)
			spark.color = Color(1.0, 0.85, 0.2)
			spark.global_position = global_position + Vector2(facing * 44.0, -22.0)
			var main2 := _get_main_scene()
			if main2 and main2.has_node("World"):
				main2.get_node("World").add_child(spark)
			else:
				get_parent().add_child(spark)
			var sp_tw := spark.create_tween()
			sp_tw.tween_property(spark, "modulate:a", 0.0, 0.28)
			sp_tw.finished.connect(spark.queue_free)
			# Screen shake via main scene
			var main3 := _get_main_scene()
			if main3 and main3.has_method("screen_shake"):
				main3.screen_shake(3.5, 0.14)
	)

func take_damage(amount: int) -> void:
	if is_god_mode: return
	if amount <= 0: return
	hp -= amount
	_sync_hp()
	var main: Node = _get_main_scene()
	if main and main.has_method("flash_damage"):
		main.flash_damage()
	var t := create_tween()
	t.tween_property(animated_sprite, "modulate", Color.RED, 0.1)
	t.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)
	if hp <= 0: _die()

func apply_bomb_knockback(explosion_pos: Vector2) -> void:
	if is_dead: return
	# Cancel low-profile states so impulse looks natural.
	is_crouching = false
	is_rolling = false
	_roll_timer = 0.0
	# Vertical knock-up (stronger than a normal jump)
	velocity.y = minf(velocity.y, JUMP_VELOCITY * 1.3)
	# Horizontal push away from explosion center
	var push_dir: float = sign(global_position.x - explosion_pos.x)
	if is_zero_approx(push_dir):
		push_dir = 1.0 if randf() > 0.5 else -1.0
	velocity.x += push_dir * 220.0

func _die() -> void:
	if is_dead: return
	is_dead = true
	var main = _get_main_scene()
	if main and main.has_method("on_player_die"):
		main.on_player_die()
	else:
		get_tree().call_deferred("reload_current_scene")

func revive() -> void:
	is_dead = false
	hp = max_hp
	animated_sprite.modulate = Color.WHITE
	_sync_hp()
