extends CharacterBody2D

# contra_player.gd
# Advanced Side-scrolling player with Double Jump and Somersault animations.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")
const ROCKET_SCENE = preload("res://scripts/contra_rocket.gd") 

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
var _melee_flash: ColorRect
var _is_firing_aa: bool = false
var _is_firing_rpg: bool = false
var _rpg_timer: float = 0.0
var _heavy_weapon_node: Node2D

# Animation timers
var _walk_time: float = 0.0
var _muzzle_flash_timer: float = 0.0
var _recoil_offset: float = 0.0
var _air_rotation: float = 0.0

var _space_was_pressed: bool = false
var _shift_was_pressed: bool = false

@onready var sprite: Node2D = $Sprite
@onready var gun_point: Marker2D = $GunPoint
@onready var shoot_timer: Timer = $ShootTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	_apply_loadout()
	# Chỉnh scale cho player cao và nổi bật hơn
	animated_sprite.scale = Vector2(1.7, 1.7) # Tăng chiều cao
	animated_sprite.modulate = Color(1.0, 1.0, 0.85) # Tăng độ sáng, nổi bật
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

func _setup_rpg_visuals() -> void:
	# RPG-7 / B40 Launcher
	var tube = ColorRect.new(); tube.size = Vector2(40, 5); tube.position = Vector2(-5, -2.5); tube.color = Color(0.15, 0.2, 0.1)
	var heat_shield = ColorRect.new(); heat_shield.size = Vector2(12, 7); heat_shield.position = Vector2(8, -3.5); heat_shield.color = Color(0.4, 0.2, 0.1)
	var sight = ColorRect.new(); sight.size = Vector2(4, 4); sight.position = Vector2(10, -6.5); sight.color = Color(0.1, 0.1, 0.1)
	_heavy_weapon_node.add_child(tube); _heavy_weapon_node.add_child(heat_shield); _heavy_weapon_node.add_child(sight)
	_heavy_weapon_node.position = Vector2(8, -8)

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
			_air_rotation = 0
		# Jump and Double Jump
		if space_just_pressed:
			if is_on_floor() and Input.is_action_pressed("ui_down"):
				position.y += 1
			elif jump_count < MAX_JUMPS:
				velocity.y = JUMP_VELOCITY
				jump_count += 1
				if jump_count == 2:
					_air_rotation = 0 # Reset for flip
		if is_rolling:
			_roll_timer -= delta
			velocity.x = sprite.scale.x * SPEED * 1.5
			if _roll_timer <= 0: is_rolling = false
		elif _is_firing_rpg:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			_rpg_timer -= delta
			if _rpg_timer <= 0: _is_firing_rpg = false
		else:
			var dir_x := Input.get_axis("ui_left", "ui_right")
			if is_on_floor() and Input.is_action_pressed("ui_down"):
				is_crouching = true
				velocity.x = 0
				if shift_just_pressed:
					is_rolling = true; _roll_timer = 0.4
			else:
				is_crouching = false
				if dir_x != 0:
					velocity.x = dir_x * SPEED
					# Lật ảnh AnimatedSprite2D
					animated_sprite.flip_h = dir_x < 0
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

		var s_pressed = Input.is_key_pressed(KEY_S)
		if s_pressed and shoot_timer.is_stopped() and not _is_firing_rpg and not is_reloading:
			_shoot()
			shoot_timer.start(current_fire_rate)
		elif not s_pressed:
			pass

		if Input.is_key_pressed(KEY_A) and rpg_cooldown <= 0 and not is_rolling and not _is_firing_rpg:
			_fire_rpg()

		if Input.is_action_just_pressed("melee") and melee_cooldown <= 0 and not is_dead:
			_melee_attack()

		if Input.is_action_just_pressed("aa_missile") and aa_cooldown <= 0 and not is_dead:
			_fire_aa_missile()

		if is_on_floor() and abs(velocity.x) > 10 and int(_walk_time * 2.0) % 5 == 0:
			var _main := _get_main_scene()
			var _surface := "road" if (_main and _main.current_stage in [4, 5]) else "grass"
			Audio.play_footstep(_surface)

func _fire_rpg() -> void:
	_is_firing_rpg = true
	_rpg_timer = 2.0 # Total animation time
	rpg_cooldown = rpg_max_cooldown
	
	# Play specific firing sequence
	var tw = create_tween()
	# ...existing code...
	
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
		if _heavy_weapon_node != null:
			rocket.global_position = _heavy_weapon_node.global_position + Vector2(30 * sprite.scale.x, -5).rotated(_heavy_weapon_node.rotation)
		else:
			rocket.global_position = global_position
		
		# Calculate effective direction (Auto-aim)
		var fire_dir = Vector2(sprite.scale.x, -0.2).normalized()
		if target_pos != Vector2.ZERO:
			fire_dir = (target_pos - rocket.global_position).normalized()
			# Update RPG visual rotation to aim at target
			if _heavy_weapon_node != null:
				_heavy_weapon_node.rotation = fire_dir.angle()
				if sprite.scale.x < 0: _heavy_weapon_node.rotation = (fire_dir * Vector2(-1, 1)).angle()
		
		rocket.direction = fire_dir
		
		# Play launch sound (High volume as requested)
		Audio.play("b40", 15.0)
		
		# Recoil animation
		if _heavy_weapon_node != null:
			var r_tw = create_tween()
			r_tw.tween_property(_heavy_weapon_node, "position:x", _heavy_weapon_node.position.x - 15, 0.05)
			r_tw.tween_property(_heavy_weapon_node, "position:x", 8, 0.4)
	)
	
	# ...existing code...

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

	# ...existing code...

func _animate(_delta: float) -> void:
	if is_meleeing:
		animated_sprite.play("punch")
		return
	if is_rolling:
		animated_sprite.play("double_jump") # Có thể đổi thành animation roll nếu có
		return
	if is_on_floor():
		if abs(velocity.x) > 10:
			animated_sprite.play("run")
		elif is_crouching:
			animated_sprite.play("crouch")
		else:
			animated_sprite.play("idle")
	else:
		if jump_count >= 2:
			animated_sprite.play("double_jump")
		else:
			animated_sprite.play("jump")

	if is_reloading:
		animated_sprite.play("reload")
	if _is_firing_rpg:
		animated_sprite.play("b40")
	if _is_firing_aa:
		animated_sprite.play("anti_air")

	# Bắn theo hướng
	if Input.is_key_pressed(KEY_S):
		var ad = aim_direction
		if ad.y < 0:
			animated_sprite.play("shoot_45_up")
		elif ad.y > 0:
			animated_sprite.play("shoot_45_down")
		else:
			animated_sprite.play("shoot")

func _shoot() -> void:
	if ammo <= 0 and not is_infinite_ammo:
		is_reloading = true
		reload_timer = RELOAD_TIME
		Audio.play("reload_ak47", 6.0) # Play reload sound, +6dB for clarity
		_spawn_falling_mag() # Visual effect
		return
	Audio.play("ak47_fire")
	var b = BULLET_SCENE.instantiate()
	# Fix bullet direction for sprite flip
	var bullet_dir = aim_direction
	if animated_sprite.flip_h:
		bullet_dir.x = -abs(bullet_dir.x)
	else:
		bullet_dir.x = abs(bullet_dir.x)
	if "direction" in b: b.direction = bullet_dir
	b.is_enemy_bullet = false
	if "damage" in b: b.damage = current_damage
	var main = _get_main_scene()
	if main:
		main.bullet_container.add_child(b)
		if main.has_method("spawn_shell"):
			main.spawn_shell(gun_point.global_position, sign(bullet_dir.x))
		if main.has_method("screen_shake"):
			main.screen_shake(2.0, 0.1)
	else:
		get_parent().add_child(b)
	b.global_position = gun_point.global_position
	b.add_to_group("player_bullet")
	# Hiệu ứng flash, smoke có thể ghép vào AnimatedSprite2D nếu cần
	if not is_infinite_ammo:
		ammo -= 1

func _spawn_falling_mag() -> void:
	# Có thể thay bằng hiệu ứng animation hoặc particle
	pass

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

	var main := _get_main_scene()

	# --- Missile node ---
	var missile := Node2D.new()
	missile.global_position = global_position + Vector2(sprite.scale.x * 20.0, -30.0)
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
					start_pos + Vector2(sprite.scale.x * best_dist, -60.0), t)
			else:
				var cur_target := target.global_position + Vector2(0, -20)
				# Slight arc: peak upward at mid-flight
				var arc_offset := Vector2(0, -80.0 * sin(t * PI))
				missile.global_position = start_pos.lerp(cur_target, t) + arc_offset
			# Rotate missile toward velocity direction
			if t > 0.01:
				var prev := start_pos.lerp(
					(target.global_position if is_instance_valid(target) else start_pos + Vector2(sprite.scale.x * best_dist, 0)),
					maxf(t - 0.02, 0.0))
				var vel_dir := (missile.global_position - prev).normalized()
				missile.rotation = vel_dir.angle()
			# Append trail point
			if is_instance_valid(trail):
				trail.add_point(missile.global_position)
				if trail.get_point_count() > 30:
					trail.remove_point(0),
		0.0, 1.0, travel_time)
	mtw.tween_callback(func():
		# At the end of AA missile callback, reset firing state
		_is_firing_aa = false
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
	var facing := sprite.scale.x

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
	# Cập nhật HP nếu cần
	var main: Node = _get_main_scene()
	if main and main.has_method("flash_damage"):
		main.flash_damage()
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color.RED, 0.1)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.1)
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
	sprite.modulate = Color.WHITE
	# Cập nhật HP nếu cần
