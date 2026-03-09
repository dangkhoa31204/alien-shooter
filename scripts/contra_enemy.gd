extends CharacterBody2D

# contra_enemy.gd
# Advanced Side-scrolling US Soldier AI with procedural movement and animations.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")

const SPEED: float = 120.0
const GRAVITY: float = 1400.0
const DETECTION_RANGE: float = 400.0

var hp: int = 2
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
var _head_node: Node2D
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
	
	_body_node = Node2D.new(); sprite.add_child(_body_node)
	_head_node = Node2D.new(); _body_node.add_child(_head_node)
	_weapon_node = Node2D.new(); _body_node.add_child(_weapon_node)

	# --- Legs (Layered) ---
	var leg_poly = PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(5, 16), Vector2(-5, 16)])
	var l1 = Polygon2D.new(); l1.polygon = leg_poly; l1.color = Color(0.35, 0.3, 0.2); sprite.add_child(l1); l1.position = Vector2(-3, 2); l1.name = "LegL"
	var l2 = Polygon2D.new(); l2.polygon = leg_poly; l2.color = Color(0.45, 0.4, 0.3); sprite.add_child(l2); l2.position = Vector2(3, 2); l2.name = "LegR"
	# Boots
	for leg in [l1, l2]:
		var boot = ColorRect.new(); boot.size = Vector2(10, 4); boot.position = Vector2(-5, 12); boot.color = Color(0.05, 0.05, 0.05); leg.add_child(boot)

	# --- Body (US Uniform with detail) ---
	var uniform_color = Color(0.48, 0.43, 0.33)
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-8, -14), Vector2(8, -14), Vector2(10, 2), Vector2(-10, 2)])
	body.color = uniform_color
	_body_node.add_child(body)
	
	# Shading
	var b_shade = Polygon2D.new(); b_shade.polygon = PackedVector2Array([Vector2(3, -14), Vector2(8, -14), Vector2(10, 2), Vector2(5, 2)])
	b_shade.color = uniform_color.darkened(0.15); _body_node.add_child(b_shade)
	
	# Straps/Webbing
	var strap_l = ColorRect.new(); strap_l.size = Vector2(2, 14); strap_l.position = Vector2(-5, -14); strap_l.color = Color(0.2, 0.18, 0.12); _body_node.add_child(strap_l)
	var strap_r = ColorRect.new(); strap_r.size = Vector2(2, 14); strap_r.position = Vector2(3, -14); strap_r.color = Color(0.2, 0.18, 0.12); _body_node.add_child(strap_r)

	# --- Head (Detailed Skin & M1 Helmet) ---
	var face = Polygon2D.new()
	face.polygon = PackedVector2Array([Vector2(-4.5, -18), Vector2(4.5, -18), Vector2(5, -14), Vector2(-5, -14)])
	face.color = Color(0.9, 0.75, 0.62)
	_head_node.add_child(face)
	
	_eye_l = ColorRect.new(); _eye_l.size = Vector2(2, 2); _eye_l.position = Vector2(1, -17); _eye_l.color = Color.BLACK
	_eye_r = ColorRect.new(); _eye_r.size = Vector2(2, 2); _eye_r.position = Vector2(4, -17); _eye_r.color = Color.BLACK
	_head_node.add_child(_eye_l); _head_node.add_child(_eye_r)

	var helmet = Polygon2D.new()
	if is_officer:
		# Officer Red Cap (Kê-pi style detailed)
		helmet.polygon = PackedVector2Array([Vector2(-9, -23), Vector2(9, -23), Vector2(10, -17), Vector2(7, -15), Vector2(-7, -15), Vector2(-10, -17)])
		helmet.color = Color(0.75, 0.1, 0.1)
		var rim = ColorRect.new(); rim.size = Vector2(18, 3); rim.position = Vector2(-9, -17); rim.color = Color.BLACK; _head_node.add_child(rim)
		var badge = ColorRect.new(); badge.size = Vector2(4, 4); badge.position = Vector2(-2, -21); badge.color = Color.GOLD; _head_node.add_child(badge)
		hp = 5
	else:
		# M1 Helmet with depth
		helmet.polygon = PackedVector2Array([Vector2(-8, -24), Vector2(8, -24), Vector2(10, -18), Vector2(6, -16), Vector2(-6, -16), Vector2(-10, -18)])
		helmet.color = Color(0.38, 0.36, 0.28)
		# Strap
		var c_strap = Line2D.new(); c_strap.points = [Vector2(-6, -16), Vector2(-4, -13), Vector2(4, -13), Vector2(6, -16)]; c_strap.width = 1.0; c_strap.default_color = Color(0.2, 0.15, 0.1); _head_node.add_child(c_strap)
	_head_node.add_child(helmet)

	# --- M16 Rifle Visuals ---
	var gun_body = ColorRect.new(); gun_body.size = Vector2(18, 4); gun_body.position = Vector2(0, -2); gun_body.color = Color(0.12, 0.12, 0.12)
	var gun_stock = Polygon2D.new(); gun_stock.polygon = [Vector2(-8,-2), Vector2(0,-2), Vector2(0,2), Vector2(-8,4)]; gun_stock.color = Color(0.1, 0.1, 0.1)
	var gun_barrel = ColorRect.new(); gun_barrel.size = Vector2(14, 2); gun_barrel.position = Vector2(18, -1); gun_barrel.color = Color(0.1, 0.1, 0.1)
	var carry_handle = ColorRect.new(); carry_handle.size = Vector2(8, 2); carry_handle.position = Vector2(2, -4); carry_handle.color = Color(0.1, 0.1, 0.1)
	_weapon_node.add_child(gun_body); _weapon_node.add_child(gun_stock); _weapon_node.add_child(gun_barrel); _weapon_node.add_child(carry_handle)
	_weapon_node.position = Vector2(7, -6)
	
	# --- Muzzle Flash ---
	_muzzle_flash = Polygon2D.new()
	_muzzle_flash.polygon = PackedVector2Array([Vector2(0, -4), Vector2(12, 0), Vector2(0, 4)])
	_muzzle_flash.color = Color(1.0, 0.7, 0.2, 0.0)
	_weapon_node.add_child(_muzzle_flash)
	_muzzle_flash.position = Vector2(30, 0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var player = _find_player()
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < DETECTION_RANGE:
			_aim_and_fire(player, delta)
			velocity.x = 0
			_eye_l.color = Color.RED; _eye_r.color = Color.RED # Alert eyes
		else:
			_patrol(delta)
			_eye_l.color = Color.BLACK; _eye_r.color = Color.BLACK
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
	velocity.x = patrol_direction * (SPEED * (1.4 if is_officer else 1.0))
	sprite.scale.x = patrol_direction
	var old_walk = int(_walk_time)
	_walk_time += delta * 12
	var step = sin(_walk_time)
	var l1 = sprite.get_node("LegL"); var l2 = sprite.get_node("LegR")
	l1.position.x = -3 + step * 8
	l2.position.x = 3 - step * 8
	l1.rotation = step * 0.15
	l2.rotation = -step * 0.15
	_body_node.position.y = abs(step) * -3.5
	_head_node.position.y = abs(step) * -1.5
	
	# Dust particles when running (Only once per cycle to prevent Tween memory leak / lag)
	if int(_walk_time) % 4 == 0 and int(_walk_time) != old_walk: 
		_spawn_dust()

func _aim_and_fire(player: Node2D, delta: float) -> void:
	var dir = (player.global_position - global_position).normalized()
	sprite.scale.x = sign(dir.x) if dir.x != 0 else sprite.scale.x
	
	# Rotate weapon
	var target_rot = dir.angle()
	if sprite.scale.x < 0: target_rot = (dir * Vector2(-1, 1)).angle()
	_weapon_node.rotation = lerp_angle(_weapon_node.rotation, target_rot, 0.2)
	
	# Breathing/Anticipation while aiming
	_walk_time += delta * 4.0
	var breathe = sin(_walk_time) * 1.5
	_body_node.position.y = breathe
	_head_node.rotation = lerp_angle(_head_node.rotation, target_rot * 0.1, 0.2)

	if shoot_timer.is_stopped(): 
		var wait = (0.5 if is_officer else 1.3) + randf() * 0.4
		shoot_timer.start(wait)

func _on_shoot_timer_timeout() -> void:
	var p = _find_player()
	if p and global_position.distance_to(p.global_position) < DETECTION_RANGE:
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
	b.damage = 1
	b.add_to_group("enemy_bullet")
	
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
	
	# Reaction: Fall backwards based on movement
	var fall_dir = -patrol_direction
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "rotation", deg_to_rad(90) * fall_dir, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:x", sprite.position.x + fall_dir * 30, 0.4)
	tw.tween_property(sprite, "position:y", sprite.position.y + 10, 0.4)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tw.finished.connect(queue_free)
