extends CharacterBody2D

# contra_player.gd
# Advanced Side-scrolling player with Double Jump and Somersault animations.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")
const ROCKET_SCENE = preload("res://scripts/contra_rocket.gd") 

var SPEED: float = 240.0
const JUMP_VELOCITY: float = -500.0
const GRAVITY: float = 1400.0

var hp: int = 5
var max_hp: int = 5
var is_dead: bool = false
var ammo: int = 30
var is_reloading: bool = false
var reload_timer: float = 0.0
const MAX_AMMO: int = 30
const RELOAD_TIME: float = 2.5

var is_god_mode: bool = false
var is_infinite_ammo: bool = false
var _dmg_accum: float = 0.0  # accumulates 0.75× damage for true 25% reduction

# Movement & Aiming state
var is_crouching: bool = false
var is_rolling: bool = false
var _roll_timer: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT
var jump_count: int = 0
const MAX_JUMPS: int = 2

# Anti-tank Weapon (RPG/B40)
var rpg_cooldown: float = 0.0
const RPG_MAX_COOLDOWN: float = 10.0

# Melee attack
var melee_cooldown: float = 0.0
const MELEE_COOLDOWN_MAX: float = 0.6
const MELEE_DAMAGE: int = 2
const MELEE_RANGE: float = 60.0
var is_meleeing: bool = false
var _melee_anim_timer: float = 0.0
const MELEE_ANIM_DUR: float = 0.4
var _melee_flash: ColorRect
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

# Nodes for animation
var _body_node: Node2D
var _head_node: Node2D
var _weapon_node: Node2D
var _leg_l: Node2D # Back leg
var _leg_r: Node2D # Front leg
var _arm_back: Node2D
var _arm_front: Node2D
var _muzzle_flash: Polygon2D

func _ready() -> void:
	add_to_group("player")
	_setup_complex_visuals()
	_sync_hp()
	# Register melee input action for key F
	if not InputMap.has_action("melee"):
		var ev := InputEventKey.new()
		ev.keycode = KEY_F
		InputMap.add_action("melee")
		InputMap.action_add_event("melee", ev)

func _sync_hp() -> void:
	var main = _get_main_scene()
	if main:
		if main.has_method("refresh_hp"):
			main.refresh_hp(hp, max_hp)
		if main.has_method("refresh_ammo"):
			main.refresh_ammo(ammo, MAX_AMMO, is_reloading)
		if main.has_method("refresh_heavy_weapon"):
			main.refresh_heavy_weapon(rpg_cooldown, RPG_MAX_COOLDOWN)

func _setup_complex_visuals() -> void:
	for n in sprite.get_children(): n.queue_free()
	
	_leg_l = Node2D.new(); _leg_r = Node2D.new()
	_body_node = Node2D.new(); _head_node = Node2D.new()
	_weapon_node = Node2D.new(); _heavy_weapon_node = Node2D.new()
	_arm_back = Node2D.new(); _arm_front = Node2D.new()
	
	# Layering: Back Arm -> Back Leg -> Body -> Weapon -> Head -> Front Leg -> Front Arm
	sprite.add_child(_arm_back)
	sprite.add_child(_leg_l)
	sprite.add_child(_body_node)
	_body_node.add_child(_weapon_node)
	_body_node.add_child(_heavy_weapon_node)
	_body_node.add_child(_head_node)
	sprite.add_child(_leg_r)
	_body_node.add_child(_arm_front)
	_heavy_weapon_node.visible = false

	# MeleeFlash — orange rectangle that flashes at the fist on punch impact
	_melee_flash = ColorRect.new()
	_melee_flash.size     = Vector2(50, 28)
	_melee_flash.position = Vector2(14, -24)  # offset from body; mirrored by sprite.scale.x
	_melee_flash.color    = Color(1.0, 0.6, 0.1, 0.0)
	_melee_flash.z_index  = 2
	_body_node.add_child(_melee_flash)

	_setup_rpg_visuals()

	# --- Legs (Powerful Stance) ---
	var poly_leg = PackedVector2Array([Vector2(-4.5, 0), Vector2(4.5, 0), Vector2(5.5, 18), Vector2(-5.5, 18)])
	var l_l = Polygon2D.new(); l_l.polygon = poly_leg; l_l.color = Color(0.1, 0.22, 0.08)
	_leg_l.add_child(l_l); _leg_l.position = Vector2(-3, 0)
	var l_r = Polygon2D.new(); l_r.polygon = poly_leg; l_r.color = Color(0.16, 0.36, 0.14)
	_leg_r.add_child(l_r); _leg_r.position = Vector2(4, 0)
	
	for leg in [_leg_l, _leg_r]:
		var s = ColorRect.new(); s.size = Vector2(13, 4); s.position = Vector2(-6.5, 15); s.color = Color(0.05, 0.05, 0.05)
		leg.add_child(s)

	# --- Body (Leaning Combat Stance) ---
	var body_color = Color(0.18, 0.38, 0.15)
	var torso = Polygon2D.new()
	torso.polygon = PackedVector2Array([Vector2(-11, -19), Vector2(10, -19), Vector2(12, 1), Vector2(-12, 1), Vector2(-13, -10)])
	torso.color = body_color; _body_node.add_child(torso)
	
	# Detail: Collar
	var collar = Polygon2D.new(); collar.polygon = [Vector2(-6, -19), Vector2(6, -19), Vector2(8, -15), Vector2(-8, -15)]
	collar.color = body_color.darkened(0.2); _body_node.add_child(collar)
	
	# Scarf (Khăn rằn - Iconic detail)
	var scarf = Line2D.new(); scarf.width = 3.0; scarf.default_color = Color(0.2, 0.2, 0.3)
	scarf.points = [Vector2(-4, -16), Vector2(0, -14), Vector2(4, -16)]
	_body_node.add_child(scarf)

	# --- Arms (Added Depth) ---
	var arm_poly = PackedVector2Array([Vector2(-3.5, 0), Vector2(3.5, 0), Vector2(4, 14), Vector2(-4, 14)])
	var ab = Polygon2D.new(); ab.polygon = arm_poly; ab.color = body_color.darkened(0.1)
	_arm_back.add_child(ab); _arm_back.position = Vector2(-7, -15)
	var af = Polygon2D.new(); af.polygon = arm_poly; af.color = body_color; _arm_front.add_child(af)
	_arm_front.position = Vector2(6, -15)

	# --- Head (Focused Expression) ---
	var face = Polygon2D.new()
	face.polygon = PackedVector2Array([Vector2(-4.5, -23), Vector2(5.5, -23), Vector2(6.5, -16), Vector2(-6.5, -16)])
	face.color = Color(0.95, 0.82, 0.68); _head_node.add_child(face)
	
	# Eyes with focus
	var el = ColorRect.new(); el.size = Vector2(2.5, 2); el.position = Vector2(1, -21); el.color = Color(0.1, 0, 0)
	var er = ColorRect.new(); er.size = Vector2(2.5, 2); er.position = Vector2(4, -21); er.color = Color(0.1, 0, 0)
	_head_node.add_child(el); _head_node.add_child(er)

	# Curved Mũ Cối
	var helmet_pts = []
	for i in 13:
		var a = i * PI / 12.0 + PI
		helmet_pts.append(Vector2(cos(a) * 11, sin(a) * 9 - 25))
	helmet_pts.append(Vector2(13, -24)); helmet_pts.append(Vector2(-13, -24))
	var helm = Polygon2D.new(); helm.polygon = PackedVector2Array(helmet_pts); helm.color = Color(0.15, 0.38, 0.12)
	_head_node.add_child(helm)
	
	# Star
	var star = Polygon2D.new(); var pts = []
	for i in 10:
		var r = 3.5 if i % 2 == 0 else 1.5; var a = i * TAU / 10.0 - PI/2.0
		pts.append(Vector2(cos(a)*r, sin(a)*r - 28))
	star.polygon = PackedVector2Array(pts); star.color = Color.YELLOW; _head_node.add_child(star)

	# --- AK-47 High Detail ---
	var gun_c = Color(0.1, 0.1, 0.1)
	var stock = Polygon2D.new(); stock.polygon = [Vector2(-12, -2), Vector2(0, -3), Vector2(0, 4), Vector2(-12, 6)]; stock.color = Color(0.48, 0.22, 0.1)
	var receiver = ColorRect.new(); receiver.size = Vector2(18, 7); receiver.position = Vector2(0, -3.5); receiver.color = gun_c
	var handguard = ColorRect.new(); handguard.size = Vector2(10, 5); handguard.position = Vector2(12, -1); handguard.color = Color(0.5, 0.25, 0.1)
	var barrel = ColorRect.new(); barrel.size = Vector2(22, 2.5); barrel.position = Vector2(18, -1.5); barrel.color = gun_c
	var mag = Polygon2D.new(); mag.polygon = [Vector2(5, 3), Vector2(11, 3), Vector2(14, 16), Vector2(7, 18)]; mag.color = Color(0.05, 0.05, 0.05)
	_weapon_node.add_child(stock); _weapon_node.add_child(receiver); _weapon_node.add_child(handguard); _weapon_node.add_child(barrel); _weapon_node.add_child(mag)
	_weapon_node.position = Vector2(10, -6)
	
	_muzzle_flash = Polygon2D.new(); _muzzle_flash.polygon = [Vector2(0, -7), Vector2(24, 0), Vector2(0, 7)]; _muzzle_flash.color = Color(1, 0.9, 0.4, 0)
	_weapon_node.add_child(_muzzle_flash); _muzzle_flash.position = Vector2(40, 0)

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
		# Dropping down through one-way platforms (Down + Jump)
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
		# Don't move while firing heavy weapon
		velocity.x = move_toward(velocity.x, 0, SPEED)
		_rpg_timer -= delta
		if _rpg_timer <= 0: _is_firing_rpg = false
	else:
		var dir_x := Input.get_axis("ui_left", "ui_right")
		if is_on_floor() and Input.is_action_pressed("ui_down"):
			is_crouching = true
			velocity.x = 0
			if shift_just_pressed: # Shift for roll
				is_rolling = true; _roll_timer = 0.4
		else:
			is_crouching = false
			if dir_x != 0:
				velocity.x = dir_x * SPEED
				sprite.scale.x = sign(dir_x)
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

	if melee_cooldown > 0:
		melee_cooldown -= delta

	if is_meleeing:
		_melee_anim_timer += delta
		if _melee_anim_timer >= MELEE_ANIM_DUR:
			is_meleeing = false
			_melee_anim_timer = 0.0
			# Reset nodes modified during melee animation
			_body_node.position.x  = 0.0
			_arm_front.position.x  = 0.0
			_arm_front.rotation    = 0.5
			sprite.scale.x         = sprite.scale.x  # preserve facing
			_melee_flash.color.a   = 0.0
	
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			is_reloading = false
			ammo = MAX_AMMO
			_sync_hp()
	
	var s_pressed = Input.is_key_pressed(KEY_S)
	if s_pressed and shoot_timer.is_stopped() and not _is_firing_rpg and not is_reloading:
		_shoot()
		shoot_timer.start(0.12)
	elif not s_pressed:
		# Force muzzle flash off when button is released
		_muzzle_flash.color.a = 0.0
		_muzzle_flash_timer = 0.0
	
	if Input.is_key_pressed(KEY_A) and rpg_cooldown <= 0 and not is_rolling and not _is_firing_rpg:
		_fire_rpg()

	if Input.is_action_just_pressed("melee") and melee_cooldown <= 0 and not is_dead:
		_melee_attack()

	if is_on_floor() and abs(velocity.x) > 10 and int(_walk_time * 2.0) % 5 == 0:
		_spawn_dust()
		Audio.play_footstep()

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
		
		# Play launch sound (High volume as requested)
		Audio.play("b40", 15.0)
		
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
	# ── Melee punch animation (keyframe-driven, overrides normal anim) ────────
	if is_meleeing:
		var t := _melee_anim_timer
		var facing := sprite.scale.x
		# Keyframe lerp helpers
		# Phase 0–0.08: wind-up
		# Phase 0.08–0.18: lunge forward
		# Phase 0.18–0.28: impact hold + flash
		# Phase 0.28–0.40: return
		var body_x   := 0.0
		var arm_rot  := 0.5      # default grip rotation
		var flash_a  := 0.0
		var squash_y := 1.0

		if t < 0.08:       # wind-up
			var p := t / 0.08
			body_x  = lerp(0.0,  -facing * 5.0, p)
			arm_rot = lerp(0.5,  deg_to_rad(30.0), p)
			squash_y = lerp(1.0, 1.15, p)
		elif t < 0.18:     # lunge
			var p := (t - 0.08) / 0.10
			body_x  = lerp(-facing * 5.0, facing * 14.0, p)
			arm_rot = lerp(deg_to_rad(30.0), deg_to_rad(-85.0), p)
			squash_y = lerp(1.15, 0.88, p)
			if p > 0.6: flash_a = (p - 0.6) / 0.4 * 0.75
		elif t < 0.28:     # impact hold
			var p := (t - 0.18) / 0.10
			body_x  = lerp(facing * 14.0, facing * 6.0, p)
			arm_rot = lerp(deg_to_rad(-85.0), deg_to_rad(-50.0), p)
			squash_y = lerp(0.88, 1.05, p)
			flash_a  = lerp(0.75, 0.0, p)
		else:              # return
			var p := (t - 0.28) / 0.12
			body_x  = lerp(facing * 6.0, 0.0, p)
			arm_rot = lerp(deg_to_rad(-50.0), 0.5, p)
			squash_y = lerp(1.05, 1.0, p)

		_body_node.position.x = body_x
		_arm_front.rotation   = arm_rot
		_arm_back.rotation    = -arm_rot * 0.4
		_melee_flash.position = Vector2(facing * 14.0 + facing * 22.0, -20.0)
		_melee_flash.color.a  = flash_a
		# Squash-stretch on body
		_body_node.scale.y    = squash_y
		_body_node.scale.x    = 2.0 - squash_y  # compensate width
		_leg_l.rotation = 0.1; _leg_r.rotation = -0.1
		sprite.rotation = 0.0
		return  # Skip normal animation while meleeing
	# Reset melee-only scale overrides when not meleeing
	_body_node.scale = Vector2.ONE
	_melee_flash.color.a = 0.0

	if is_rolling:
		sprite.rotation += delta * 25.0 * sprite.scale.x
		_body_node.position.y = 12
		_leg_l.rotation = 1.2; _leg_r.rotation = -0.8
		_arm_back.rotation = 1.0; _arm_front.rotation = -1.0
	elif is_on_floor() and abs(velocity.x) > 10:
		var prev_step := sin(_walk_time)
		_walk_time += delta * 13.0
		var step := sin(_walk_time)
		# Emit footstep dust on each leg strike (sign change in step)
		if prev_step * step < 0.0:
			_spawn_footstep_dust()
			Audio.play_footstep()
		_leg_l.position.x = -4 + step * 9; _leg_r.position.x = 4 - step * 9
		_leg_l.rotation = step * 0.25; _leg_r.rotation = -step * 0.25
		_body_node.position.y = abs(step) * -5 + 2 # Adds "lean" bounce
		_body_node.rotation = 0.1 + step * 0.08 # Leaning forward while running
		_head_node.position.y = abs(step) * -2
		_head_node.rotation = -0.05
		# Arms swing while running
		_arm_back.rotation = -step * 0.4; _arm_front.rotation = step * 0.4
		sprite.rotation = 0
	elif is_on_floor():
		_walk_time += delta * 3.5
		var breathe = sin(_walk_time) * 1.5
		_leg_l.position.x = lerp(_leg_l.position.x, -6.0, 0.1) # Wider stance idle
		_leg_r.position.x = lerp(_leg_r.position.x, 6.0, 0.1)
		_leg_l.rotation = 0.1; _leg_r.rotation = -0.05
		_body_node.position.y = breathe + 2
		_body_node.rotation = 0.1 # Permanent combat lean
		_head_node.position.y = breathe * 0.6
		_head_node.rotation = -0.05
		# Arms grip the weapon
		_arm_back.rotation = -0.4; _arm_front.rotation = 0.5
		sprite.rotation = 0
	else:
		# Air Animation
		if is_rolling: pass
		elif jump_count >= 2:
			_air_rotation += delta * 26.0 * sprite.scale.x
			sprite.rotation = _air_rotation
		else:
			sprite.rotation = lerp_angle(sprite.rotation, 0, 0.2)
			_body_node.rotation = 0.15 # Leaning in air
			_leg_l.rotation = 0.9; _leg_r.rotation = -0.5
			_head_node.rotation = -0.1
			_arm_back.rotation = -0.8; _arm_front.rotation = 0.2

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
	_spawn_muzzle_smoke()

	# Point-blank fix: nếu enemy nằm trong vùng spawn đạn (~50px),
	# Godot sẽ không fire body_entered → gây sát thương trực tiếp.
	var facing := sprite.scale.x
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy): continue
		var diff: Vector2 = (enemy as Node2D).global_position - gun_point.global_position
		if diff.length() <= 50.0 and sign(diff.x) == facing:
			if enemy.has_method("take_damage"):
				enemy.take_damage(1)

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
	wisp.global_position = _muzzle_flash.global_position
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
					# Xe tăng (tank group) chỉ nhận MELEE_DAMAGE bình thường
					# Tất cả enemy khác: 1 đấm chết
					var dmg := MELEE_DAMAGE if enemy.is_in_group("tank") else 999
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
	# Giảm 25% sát thương nhận vào (tích lũy phần thập phân)
	_dmg_accum += amount * 0.75
	var actual := int(_dmg_accum)
	_dmg_accum -= actual
	if actual <= 0: return
	hp -= actual
	_sync_hp()
	var main: Node = _get_main_scene()
	if main and main.has_method("flash_damage"):
		main.flash_damage()
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color.RED, 0.1)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if hp <= 0: _die()

func _die() -> void:
	if is_dead: return
	is_dead = true
	var main = _get_main_scene()
	if main and main.has_method("on_player_die"):
		main.on_player_die()
	else:
		get_tree().call_deferred("reload_current_scene")
