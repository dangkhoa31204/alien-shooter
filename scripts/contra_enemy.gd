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

	# --- Legs ---
	var leg_poly = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(4, 16), Vector2(-4, 16)])
	var l1 = Polygon2D.new(); l1.polygon = leg_poly; l1.color = Color(0.4, 0.35, 0.25); sprite.add_child(l1); l1.position = Vector2(-3, 2); l1.name = "LegL"
	var l2 = Polygon2D.new(); l2.polygon = leg_poly; l2.color = Color(0.42, 0.38, 0.28); sprite.add_child(l2); l2.position = Vector2(3, 2); l2.name = "LegR"

	# --- Body (US Uniform) ---
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-7, -14), Vector2(7, -14), Vector2(8, 2), Vector2(-8, 2)])
	body.color = Color(0.5, 0.45, 0.35)
	_body_node.add_child(body)
	
	# Straps
	var strap = ColorRect.new(); strap.size = Vector2(1, 14); strap.position = Vector2(2, -14); strap.color = Color(0.2, 0.15, 0.1)
	_body_node.add_child(strap)

	# --- Head (M1 Helmet) ---
	var face = Polygon2D.new()
	face.polygon = PackedVector2Array([Vector2(-4, -18), Vector2(4, -18), Vector2(4.5, -14), Vector2(-4.5, -14)])
	face.color = Color(1.0, 0.85, 0.7)
	_head_node.add_child(face)
	
	_eye_l = ColorRect.new(); _eye_l.size = Vector2(1, 1); _eye_l.position = Vector2(1, -16.5); _eye_l.color = Color.BLACK
	_eye_r = ColorRect.new(); _eye_r.size = Vector2(1, 1); _eye_r.position = Vector2(3, -16.5); _eye_r.color = Color.BLACK
	_head_node.add_child(_eye_l); _head_node.add_child(_eye_r)

	var helmet = Polygon2D.new()
	if is_officer:
		# Officer Red Cap (Kê-pi style)
		helmet.polygon = PackedVector2Array([Vector2(-8, -22), Vector2(8, -22), Vector2(9, -17), Vector2(6, -15), Vector2(-6, -15), Vector2(-9, -17)])
		helmet.color = Color(0.8, 0.1, 0.1)
		var rim = ColorRect.new(); rim.size = Vector2(16, 2); rim.position = Vector2(-8, -17); rim.color = Color.BLACK
		_head_node.add_child(rim)
		hp = 4 # Tougher
	else:
		helmet.polygon = PackedVector2Array([Vector2(-7, -24), Vector2(7, -24), Vector2(9, -18), Vector2(5, -16), Vector2(-5, -16), Vector2(-9, -18)])
		helmet.color = Color(0.4, 0.38, 0.3)
	_head_node.add_child(helmet)

	# --- Weapon (M16 Style) ---
	var gun_body = ColorRect.new(); gun_body.size = Vector2(15, 3); gun_body.position = Vector2(0, -1.5); gun_body.color = Color(0.15, 0.15, 0.15)
	var handle = ColorRect.new(); handle.size = Vector2(6, 2); handle.position = Vector2(2, -3.5); handle.color = Color(0.1, 0.1, 0.1)
	_weapon_node.add_child(gun_body); _weapon_node.add_child(handle)
	_weapon_node.position = Vector2(6, -6)
	
	# --- Muzzle Flash ---
	_muzzle_flash = Polygon2D.new()
	_muzzle_flash.polygon = PackedVector2Array([Vector2(0, -3), Vector2(10, 0), Vector2(0, 3)])
	_muzzle_flash.color = Color(1.0, 0.6, 0.0, 0.0)
	_weapon_node.add_child(_muzzle_flash)
	_muzzle_flash.position = Vector2(18, 0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var player = _find_player()
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < DETECTION_RANGE:
			_aim_and_fire(player)
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
	l1.position.x = -3 + step * 6
	l2.position.x = 3 - step * 6
	_body_node.position.y = abs(step) * -3
	
	# Dust particles when running (Only once per cycle to prevent Tween memory leak / lag)
	if int(_walk_time) % 4 == 0 and int(_walk_time) != old_walk: 
		_spawn_dust()

func _aim_and_fire(player: Node2D) -> void:
	var dir = (player.global_position - global_position).normalized()
	sprite.scale.x = sign(dir.x) if dir.x != 0 else sprite.scale.x
	
	# Rotate weapon
	var target_rot = dir.angle()
	if sprite.scale.x < 0: target_rot = (dir * Vector2(-1, 1)).angle()
	_weapon_node.rotation = lerp_angle(_weapon_node.rotation, target_rot, 0.2)
	
	if shoot_timer.is_stopped(): 
		var wait = (0.6 if is_officer else 1.4) + randf() * 0.5
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
