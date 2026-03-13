extends CharacterBody2D

# contra_enemy.gd
# Advanced Side-scrolling US Soldier AI with procedural movement and animations.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")

const SPEED: float = 120.0
const GRAVITY: float = 1400.0
const DETECTION_RANGE: float = 320.0

var hp: int = 30
var patrol_direction: int = -1 # Start walking left
var _walk_time: float = 0.0
var _muzzle_flash_timer: float = 0.0
var _recoil_offset: float = 0.0
var is_officer: bool = false # High rank enemy

@onready var sprite: Node2D = $Sprite
@onready var gun_point: Marker2D = $GunPoint
@onready var shoot_timer: Timer = $ShootTimer

# Nodes for animation
var _body_node: Node2D
var _weapon_node: Node2D
var _heavy_weapon_node: Node2D
var _head_node: Node2D
var _arm_back: Node2D
var _arm_front: Node2D
var _leg_l: Node2D
var _leg_r: Node2D
var _backpack: Node2D
var _muzzle_flash: Polygon2D
var _eye_l: ColorRect
var _eye_r: ColorRect

func _ready() -> void:
	add_to_group("enemy")
	_setup_complex_visuals()
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)

func _setup_complex_visuals() -> void:
	# Clean existing if any
	for n in sprite.get_children(): n.queue_free()
	
	_arm_back = Node2D.new(); sprite.add_child(_arm_back)
	_leg_l = Node2D.new(); sprite.add_child(_leg_l)
	
	_body_node = Node2D.new(); sprite.add_child(_body_node)
	_backpack = Node2D.new(); _body_node.add_child(_backpack)
	
	_weapon_node = Node2D.new(); _body_node.add_child(_weapon_node)
	_head_node = Node2D.new(); _body_node.add_child(_head_node)
	
	_leg_r = Node2D.new(); sprite.add_child(_leg_r)
	_arm_front = Node2D.new(); _body_node.add_child(_arm_front)

	# --- Legs (Grasping ground) ---
	var leg_poly = PackedVector2Array([Vector2(-4.5, 0), Vector2(4.5, 0), Vector2(6, 18), Vector2(-6, 18)])
	var l_color_b = Color(0.3, 0.28, 0.22)
	var l_color_f = Color(0.42, 0.38, 0.3)
	
	var lb = Polygon2D.new(); lb.polygon = leg_poly; lb.color = l_color_b; _leg_l.add_child(lb); _leg_l.position = Vector2(-4, 0)
	var lf = Polygon2D.new(); lf.polygon = leg_poly; lf.color = l_color_f; _leg_r.add_child(lf); _leg_r.position = Vector2(4, 0)
	
	for leg in [_leg_l, _leg_r]:
		var boot = ColorRect.new(); boot.size = Vector2(12, 5); boot.position = Vector2(-6, 14); boot.color = Color(0.08, 0.08, 0.1); leg.add_child(boot)

	# --- Body (US Fatigue Uniform) ---
	var base_khaki = Color(0.52, 0.48, 0.38)
	var torso = Polygon2D.new()
	torso.polygon = PackedVector2Array([Vector2(-9, -20), Vector2(9, -20), Vector2(11, 2), Vector2(-11, 2)])
	torso.color = base_khaki; _body_node.add_child(torso)
	
	# Webbing Detail
	var belt = ColorRect.new(); belt.size = Vector2(24, 4); belt.position = Vector2(-12, -2); belt.color = Color(0.25, 0.2, 0.15); _body_node.add_child(belt)
	var pouch = ColorRect.new(); pouch.size = Vector2(6, 8); pouch.position = Vector2(2, -2); pouch.color = Color(0.3, 0.25, 0.18); _body_node.add_child(pouch)
	
	# --- Backpack / Radio ---
	var pack = ColorRect.new()
	if is_officer:
		pack.size = Vector2(12, 18); pack.position = Vector2(-12, -18); pack.color = Color(0.2, 0.2, 0.25) # Radio grey
		var ant = Line2D.new(); ant.points = [Vector2(-10, -18), Vector2(-14, -35)]; ant.width = 1.0; ant.default_color = Color.BLACK; _backpack.add_child(ant)
		hp = 70
	else:
		pack.size = Vector2(10, 15); pack.position = Vector2(-10, -16); pack.color = Color(0.35, 0.3, 0.25)
	_backpack.add_child(pack)

	# --- Arms ---
	var arm_p = PackedVector2Array([Vector2(-3.5, 0), Vector2(3.5, 0), Vector2(4, 15), Vector2(-4, 15)])
	var ab = Polygon2D.new(); ab.polygon = arm_p; ab.color = base_khaki.darkened(0.2); _arm_back.add_child(ab); _arm_back.position = Vector2(-7, -16)
	var af = Polygon2D.new(); af.polygon = arm_p; af.color = base_khaki; _arm_front.add_child(af); _arm_front.position = Vector2(7, -16)

	# --- Head ---
	var face = Polygon2D.new()
	face.polygon = PackedVector2Array([Vector2(-5, -24), Vector2(5, -24), Vector2(6, -18), Vector2(-6, -18)])
	face.color = Color(0.88, 0.72, 0.58); _head_node.add_child(face)
	
	_eye_l = ColorRect.new(); _eye_l.size = Vector2(2, 2); _eye_l.position = Vector2(0, -22); _eye_l.color = Color.BLACK
	_eye_r = ColorRect.new(); _eye_r.size = Vector2(2, 2); _eye_r.position = Vector2(3, -22); _eye_r.color = Color.BLACK
	_head_node.add_child(_eye_l); _head_node.add_child(_eye_r)

	var helmet = Polygon2D.new()
	if is_officer:
		# Distinct Officer Cap
		helmet.polygon = PackedVector2Array([Vector2(-10, -30), Vector2(10, -30), Vector2(12, -24), Vector2(0, -22), Vector2(-12, -24)])
		helmet.color = Color(0.8, 0.1, 0.1) # Bright Red
		var visor = ColorRect.new(); visor.size = Vector2(20, 3); visor.position = Vector2(-10, -24); visor.color = Color.BLACK; _head_node.add_child(visor)
	else:
		# Realistic M1 Steel Helmet
		var h_pts = []
		for i in 9:
			var a = i * PI / 8.0 + PI; h_pts.append(Vector2(cos(a)*10, sin(a)*7 - 24))
		h_pts.append(Vector2(11, -22)); h_pts.append(Vector2(-11, -22))
		helmet.polygon = PackedVector2Array(h_pts); helmet.color = Color(0.35, 0.38, 0.28)
	_head_node.add_child(helmet)

	# --- M16 Rifle (Tactical Detail) ---
	var g_c = Color(0.1, 0.1, 0.1)
	var stock = ColorRect.new(); stock.size = Vector2(10, 4); stock.position = Vector2(-8, -2); stock.color = g_c
	var receiver = ColorRect.new(); receiver.size = Vector2(14, 6); receiver.position = Vector2(2, -3); receiver.color = g_c
	var handguard = ColorRect.new(); handguard.size = Vector2(15, 4); handguard.position = Vector2(16, -2); handguard.color = Color(0.15, 0.15, 0.15)
	var barrel = ColorRect.new(); barrel.size = Vector2(10, 2); barrel.position = Vector2(31, -1); barrel.color = g_c
	var mag = ColorRect.new(); mag.size = Vector2(4, 9); mag.position = Vector2(8, 2); mag.color = g_c; mag.rotation = 0.1
	_weapon_node.add_child(stock); _weapon_node.add_child(receiver); _weapon_node.add_child(handguard); _weapon_node.add_child(barrel); _weapon_node.add_child(mag)
	_weapon_node.position = Vector2(8, -8)
	
	_muzzle_flash = Polygon2D.new(); _muzzle_flash.polygon = [Vector2(0, -6), Vector2(18, 0), Vector2(0, 6)]; _muzzle_flash.color = Color(1, 0.8, 0.2, 0)
	_weapon_node.add_child(_muzzle_flash); _muzzle_flash.position = Vector2(40, 0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var player = _find_player()
	if player:
		var dist_x = global_position.x - player.global_position.x
		patrol_direction = -sign(dist_x) if dist_x != 0 else patrol_direction
		
		# Engagment range reduced to 420 for easier dodging
		if abs(dist_x) > 420:
			_patrol(delta)
			_eye_l.color = Color.BLACK; _eye_r.color = Color.BLACK
		else:
			velocity.x = 0
			_aim_and_fire(player, delta)
			_eye_l.color = Color.RED; _eye_r.color = Color.RED # Alert eyes
	else:
		_patrol(delta)
		_eye_l.color = Color.BLACK; _eye_r.color = Color.BLACK

	move_and_slide()
	if is_on_wall(): patrol_direction *= -1

	# Flash logic
	if _muzzle_flash_timer > 0:
		_muzzle_flash_timer -= delta
		if _muzzle_flash_timer <= 0: _muzzle_flash.color.a = 0.0
	
	# Animation
	_recoil_offset = lerp(_recoil_offset, 0.0, 0.1)
	_weapon_node.position.x = 6 - _recoil_offset

func _find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _patrol(delta: float) -> void:
	velocity.x = patrol_direction * (SPEED * (1.5 if is_officer else 1.0))
	sprite.scale.x = patrol_direction
	var old_walk = int(_walk_time)
	_walk_time += delta * 12
	var step = sin(_walk_time)
	
	# Limb Movement
	_leg_l.position.x = -4 + step * 9; _leg_r.position.x = 4 - step * 9
	_leg_l.rotation = step * 0.2; _leg_r.rotation = -step * 0.2
	_arm_back.rotation = -step * 0.5; _arm_front.rotation = step * 0.5
	
	_body_node.position.y = abs(step) * -4 + 2
	_body_node.rotation = 0.05 # Sleight lean
	_head_node.position.y = abs(step) * -2
	_head_node.rotation = -0.05
	
	if int(_walk_time) % 4 == 0 and int(_walk_time) != old_walk: 
		_spawn_dust()

func _aim_and_fire(player: Node2D, delta: float) -> void:
	var dir = (player.global_position - global_position).normalized()
	sprite.scale.x = sign(dir.x) if dir.x != 0 else sprite.scale.x
	
	# Alert Eyes
	_eye_l.color = Color.RED; _eye_r.color = Color.RED
	
	# Rotate weapon
	var target_rot = dir.angle()
	if sprite.scale.x < 0: target_rot = (dir * Vector2(-1, 1)).angle()
	_weapon_node.rotation = lerp_angle(_weapon_node.rotation, target_rot, 0.2)
	
	# Aiming Stance
	_leg_l.rotation = 0.2; _leg_r.rotation = -0.1
	_arm_back.rotation = -0.4; _arm_front.rotation = 0.4
	
	# Breathing pulse
	_walk_time += delta * 4.0
	var breathe = sin(_walk_time) * 1.5
	_body_node.position.y = breathe + 2
	_head_node.rotation = lerp_angle(_head_node.rotation, target_rot * 0.1, 0.2)

	if shoot_timer.is_stopped(): 
		var wait = (0.8 if is_officer else 2.0) + randf() * 0.5
		shoot_timer.start(wait)

func _on_shoot_timer_timeout() -> void:
	var p = _find_player()
	# FIX: was using DETECTION_RANGE (320) but engagement is 420 → enemy aimed but never shot
	if p and global_position.distance_to(p.global_position) < 420:
		_shoot(p)

func _shoot(player: Node2D) -> void:
	var b = BULLET_SCENE.instantiate()
	var main = _get_main_scene()
	if main:
		main.bullet_container.add_child(b)
	else:
		get_parent().add_child(b)
		
	b.global_position = _muzzle_flash.global_position
	
	var dir = (player.global_position - b.global_position).normalized()
	b.direction = dir
	b.is_enemy_bullet = true
	b.damage = 8
	b.add_to_group("enemy_bullet")
	Audio.play("m4_fire")
	
	# Shell ejection effect
	var shell = ColorRect.new(); shell.size = Vector2(2, 1); shell.color = Color.GOLD; shell.global_position = global_position + Vector2(0, -10); get_parent().add_child(shell)
	var stw = create_tween(); stw.tween_property(shell, "position", shell.position + Vector2(-sprite.scale.x * 20, -10 + randf()*5), 0.3)
	stw.tween_property(shell, "modulate:a", 0.0, 0.1); stw.finished.connect(shell.queue_free)
	
	_muzzle_flash.color.a = 1.0
	_muzzle_flash_timer = 0.05
	_recoil_offset = 5.0

func _spawn_dust() -> void:
	var d = ColorRect.new(); d.size = Vector2(4, 4); d.color = Color(0.6, 0.5, 0.4, 0.5); d.global_position = global_position + Vector2(0, 15); get_parent().add_child(d)
	var dtw = create_tween(); dtw.set_parallel(true); dtw.tween_property(d, "position:y", d.position.y - 10, 0.4); dtw.tween_property(d, "modulate:a", 0.0, 0.4); dtw.finished.connect(d.queue_free)

func _get_main_scene() -> Node:
	var curr = get_parent()
	while curr != null:
		if curr.name == "ContraMain": return curr
		curr = curr.get_parent()
	return null

func take_damage(amount: int) -> void:
	hp -= amount
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.ORANGE_RED, 0.08)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.08)
	if hp <= 0: _die()

func _die() -> void:
	set_physics_process(false)
	collision_layer = 0; collision_mask = 0

	# Báo điểm và kill cho main
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("add_kill"):
		main_node.add_kill(100, 6)

	# Reaction: Fall backwards based on movement
	var fall_dir = -patrol_direction
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "rotation", deg_to_rad(90) * fall_dir, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:x", sprite.position.x + fall_dir * 30, 0.4)
	tw.tween_property(sprite, "position:y", sprite.position.y + 10, 0.4)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tw.finished.connect(queue_free)
