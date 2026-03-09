extends CharacterBody2D

# contra_tank.gd
# Heavy armored vehicle with AoE cannon.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")

const SPEED: float = 60.0 # Slow but steady
const GRAVITY: float = 1400.0

var hp: int = 15
var patrol_direction: int = -1
var is_ally: bool = false

var sprite: Node2D
var shoot_timer: Timer

# Visual nodes
var _body: Polygon2D
var _turret: Node2D
var _barrel: ColorRect
var _muzzle_flash: Polygon2D

func _ready() -> void:
	if is_ally:
		add_to_group("ally_army")
	else:
		add_to_group("enemy")
		add_to_group("tank")
	
	# Create nodes programmatically
	sprite = Node2D.new(); sprite.name = "Sprite"; add_child(sprite)
	shoot_timer = Timer.new(); shoot_timer.name = "ShootTimer"; add_child(shoot_timer)
	
	# Collision
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new(); shape.size = Vector2(80, 40)
	col.shape = shape; add_child(col)
	
	_setup_visuals()
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_timer.start(2.5 + randf())

func _setup_visuals() -> void:
	# Tank tracks/base
	var tracks = Polygon2D.new()
	tracks.polygon = PackedVector2Array([Vector2(-35, 15), Vector2(35, 15), Vector2(40, 5), Vector2(35, -5), Vector2(-35, -5), Vector2(-40, 5)])
	tracks.color = Color(0.1, 0.1, 0.1)
	sprite.add_child(tracks)
	
	# Main body
	_body = Polygon2D.new()
	_body.polygon = PackedVector2Array([Vector2(-30, -5), Vector2(30, -5), Vector2(25, -20), Vector2(-25, -20)])
	_body.color = Color(0.2, 0.45, 0.15) if is_ally else Color(0.15, 0.25, 0.1)
	sprite.add_child(_body)
	
	# Turret
	_turret = Node2D.new()
	_turret.position = Vector2(0, -18)
	sprite.add_child(_turret)
	
	var t_base = Polygon2D.new()
	t_base.polygon = PackedVector2Array([Vector2(-15, 0), Vector2(15, 0), Vector2(12, -12), Vector2(-12, -12)])
	t_base.color = Color(0.18, 0.3, 0.12)
	_turret.add_child(t_base)
	
	# Barrel
	_barrel = ColorRect.new()
	_barrel.size = Vector2(35, 6)
	_barrel.position = Vector2(0, -9)
	_barrel.color = Color(0.1, 0.12, 0.1)
	_turret.add_child(_barrel)
	
	# Muzzle Flash
	_muzzle_flash = Polygon2D.new()
	_muzzle_flash.polygon = PackedVector2Array([Vector2(0, -8), Vector2(15, 0), Vector2(0, 8)])
	_muzzle_flash.color = Color(1, 0.6, 0.2, 0.0)
	_muzzle_flash.position = Vector2(35, -6)
	_turret.add_child(_muzzle_flash)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	var player = _find_player()
	if player:
		var dist = global_position.x - player.global_position.x
		patrol_direction = -sign(dist) if dist != 0 else patrol_direction
		
		# Only move if not in firing range
		if abs(dist) > 500:
			velocity.x = patrol_direction * SPEED
		else:
			velocity.x = 0
			_aim_at_player(player)
	else:
		velocity.x = patrol_direction * SPEED
	
	sprite.scale.x = patrol_direction
	move_and_slide()
	
	if is_on_wall(): patrol_direction *= -1

func _find_player() -> Node2D:
	if is_ally:
		# If ally, look for enemies to target
		var enemies = get_tree().get_nodes_in_group("enemy")
		if enemies.size() > 0:
			# Return closest enemy
			var closest = enemies[0]
			var min_d = global_position.distance_to(closest.global_position)
			for e in enemies:
				var d = global_position.distance_to(e.global_position)
				if d < min_d:
					min_d = d
					closest = e
			return closest
		return null
	
	var players = get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _aim_at_player(player: Node2D) -> void:
	var dir = (player.global_position - _turret.global_position).normalized()
	var angle = dir.angle()
	if sprite.scale.x < 0:
		angle = (dir * Vector2(-1, 1)).angle()
	_turret.rotation = lerp_angle(_turret.rotation, clamp(angle, -PI/4, PI/4), 0.1)

func _on_shoot_timer_timeout() -> void:
	var p = _find_player()
	if p and global_position.distance_to(p.global_position) < 800:
		_fire_cannon()

func _fire_cannon() -> void:
	var b = BULLET_SCENE.instantiate()
	get_parent().add_child(b)
	b.global_position = _muzzle_flash.global_position
	
	var p = _find_player()
	if p:
		var dir = (p.global_position - b.global_position).normalized()
		b.direction = dir
	
	b.set_meta("is_tank_shell", true)
	b.scale = Vector2(2.5, 2.5)
	if is_ally:
		b.is_enemy_bullet = false
		b.damage = 5
		b.add_to_group("player_bullet")
	else:
		b.is_enemy_bullet = true
		b.damage = 2
		b.add_to_group("enemy_bullet")
	
	_muzzle_flash.color.a = 1.0
	var tw = create_tween()
	tw.tween_property(_muzzle_flash, "color:a", 0.0, 0.1)
	
	# Recoil
	_turret.position.x -= 8.0 * sprite.scale.x
	create_tween().tween_property(_turret, "position:x", 0.0, 0.3)

func take_damage(amount: int) -> void:
	hp -= amount
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.08).from(Color.ORANGE_RED)
	if hp <= 0: _die()

func _die() -> void:
	# Explosion effect
	var main = _get_main_scene()
	if main and main.has_method("screen_shake"):
		main.screen_shake(12.0, 0.5)
	
	# Spawn wreckage/smoke
	for i in 8:
		var debris = ColorRect.new()
		debris.size = Vector2(8, 8)
		debris.color = Color(0.1, 0.1, 0.1)
		debris.position = global_position + Vector2(randf_range(-20, 20), randf_range(-10, 10))
		get_parent().add_child(debris)
		var dtw = create_tween().set_parallel(true)
		dtw.tween_property(debris, "position", debris.position + Vector2(randf_range(-50, 50), -50), 0.5)
		dtw.tween_property(debris, "modulate:a", 0.0, 0.5)
		dtw.finished.connect(debris.queue_free)
		
	queue_free()

func _get_main_scene() -> Node:
	var curr = get_parent()
	while curr != null:
		if curr.name == "ContraMain": return curr
		curr = curr.get_parent()
	return null
