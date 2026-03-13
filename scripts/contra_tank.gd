extends CharacterBody2D

# contra_tank.gd
# Heavy armored vehicle with AoE cannon.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")

const SPEED: float = 60.0 # Slow but steady
const GRAVITY: float = 1400.0

var hp: int = 240
var patrol_direction: int = -1
var is_ally: bool = false
var can_shoot: bool = true

var sprite: Node2D
var shoot_timer: Timer

# Visual nodes
var _body: Node2D
var _turret: Node2D
var _wheels: Array[Polygon2D] = []
var _barrel: ColorRect
var _muzzle_flash: Polygon2D
var _hatch: Node2D
var _exhaust_timer: float = 0.0

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
	# Base Tracks Structure
	var base = Polygon2D.new()
	base.polygon = PackedVector2Array([Vector2(-42, 18), Vector2(42, 18), Vector2(48, 8), Vector2(42, -2), Vector2(-42, -2), Vector2(-48, 8)])
	base.color = Color(0.12, 0.12, 0.12); sprite.add_child(base)
	
	# Rotating Wheels (4 per side)
	for i in 4:
		var w = Polygon2D.new()
		var pts = []
		for j in 6:
			var a = j * PI / 3.0; pts.append(Vector2(cos(a)*7, sin(a)*7))
		w.polygon = PackedVector2Array(pts); w.color = Color(0.2, 0.2, 0.2)
		w.position = Vector2(-28 + i * 19, 10); sprite.add_child(w); _wheels.append(w)
		# Wheel hub
		var hub = ColorRect.new(); hub.size = Vector2(4, 4); hub.position = Vector2(-2, -2); hub.color = Color.BLACK; w.add_child(hub)

	# Main Armored Hull
	_body = Node2D.new(); sprite.add_child(_body)
	var hull = Polygon2D.new()
	hull.polygon = PackedVector2Array([Vector2(-35, -2), Vector2(35, -2), Vector2(28, -22), Vector2(-28, -22)])
	var hull_color = Color(0.22, 0.38, 0.15) if is_ally else Color(0.18, 0.22, 0.12)
	hull.color = hull_color; _body.add_child(hull)
	
	# Camo / Panel details
	var panel = Polygon2D.new(); panel.polygon = [Vector2(5, -22), Vector2(15, -22), Vector2(25, -2)]; panel.color = hull_color.darkened(0.2); _body.add_child(panel)
	
	if is_ally:
		# Gold Star on the hull
		var star = Polygon2D.new(); var spts = []
		for i in 10:
			var r = 6 if i % 2 == 0 else 3; var a = i * TAU / 10.0 - PI/2.0
			spts.append(Vector2(cos(a)*r, sin(a)*r - 12))
		star.polygon = PackedVector2Array(spts); star.color = Color.YELLOW; _body.add_child(star)

	# Turret
	_turret = Node2D.new(); _turret.position = Vector2(0, -20); sprite.add_child(_turret)
	
	var t_base = Polygon2D.new()
	t_base.polygon = PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(14, -14), Vector2(-14, -14)])
	t_base.color = hull_color.darkened(0.1); _turret.add_child(t_base)
	
	# Hatch & Machine Gunner
	_hatch = Node2D.new(); _hatch.position = Vector2(-8, -14); _turret.add_child(_hatch)
	var hatch_lid = ColorRect.new(); hatch_lid.size = Vector2(12, 3); hatch_lid.position = Vector2(-6, -2); hatch_lid.color = Color(0.1, 0.1, 0.1); _hatch.add_child(hatch_lid)
	
	# The Gunner (Metal Slug style)
	var gunner = Node2D.new(); _hatch.add_child(gunner)
	var head = ColorRect.new(); head.size = Vector2(6, 6); head.position = Vector2(-3, -8); head.color = Color(0.9, 0.7, 0.5); gunner.add_child(head)
	var helmet = ColorRect.new(); helmet.size = Vector2(8, 4); helmet.position = Vector2(-4, -10); helmet.color = Color(0.1, 0.2, 0.1); gunner.add_child(helmet)

	# Main Cannon Barrel
	_barrel = ColorRect.new()
	_barrel.size = Vector2(45, 8); _barrel.position = Vector2(0, -10); _barrel.color = Color(0.1, 0.1, 0.1); _turret.add_child(_barrel)
	var muzzle_brake = ColorRect.new(); muzzle_brake.size = Vector2(6, 12); muzzle_brake.position = Vector2(42, -12); muzzle_brake.color = Color(0.05, 0.05, 0.05); _turret.add_child(muzzle_brake)
	
	# Muzzle Flash
	_muzzle_flash = Polygon2D.new(); _muzzle_flash.polygon = [Vector2(0, -12), Vector2(25, 0), Vector2(0, 12)]; _muzzle_flash.color = Color(1, 0.7, 0.2, 0); _muzzle_flash.position = Vector2(48, -6); _turret.add_child(_muzzle_flash)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	var player = _find_player()
	if player:
		var dist = global_position.x - player.global_position.x
		# Enemies face player; Allies follow/face enemies but don't turn back if decorative
		if not is_ally:
			if dist != 0: patrol_direction = -sign(dist)
		else:
			# Decorative allied tanks just keep pushing forward
			if not can_shoot:
				patrol_direction = 1 # Always advance
			else:
				if dist != 0: patrol_direction = -sign(dist)
		
		if abs(dist) > 380:
			velocity.x = patrol_direction * SPEED
		else:
			velocity.x = 0
			_aim_at_player(player)
	else:
		velocity.x = patrol_direction * SPEED
	
	# Wheel Rotation Logic
	if abs(velocity.x) > 1.0:
		for w in _wheels:
			w.rotation += delta * 10 * patrol_direction
		_exhaust_timer += delta
		if _exhaust_timer > 0.15:
			_spawn_exhaust_smoke()
			_exhaust_timer = 0.0

	sprite.scale.x = patrol_direction
	move_and_slide()
	
	if is_on_wall(): patrol_direction *= -1

func _spawn_exhaust_smoke() -> void:
	var smoke = ColorRect.new(); smoke.size = Vector2(6, 6); smoke.color = Color(0.4, 0.4, 0.4, 0.6)
	smoke.global_position = global_position + Vector2(-40 * patrol_direction, -10)
	get_parent().add_child(smoke)
	var tw = create_tween(); tw.set_parallel(true)
	tw.tween_property(smoke, "position", smoke.position + Vector2(-30 * patrol_direction, -40), 0.6)
	tw.tween_property(smoke, "modulate:a", 0.0, 0.6); tw.finished.connect(smoke.queue_free)

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
	if not can_shoot: return
	
	var p = _find_player()
	if p and global_position.distance_to(p.global_position) < 500:
		# Play launch sound (High volume as requested)
		Audio.play("b40", 15.0) # Tank firing sound
		_fire_cannon()

func _fire_cannon() -> void:
	var b = BULLET_SCENE.instantiate()
	# FIX: use bullet_container via main scene instead of get_parent() for proper management
	var main = _get_main_scene()
	if main and is_instance_valid(main.bullet_container):
		main.bullet_container.add_child(b)
	else:
		get_parent().add_child(b)
	b.global_position = _muzzle_flash.global_position
	
	var p = _find_player()
	if p:
		var dir = (p.global_position - b.global_position).normalized()
		b.direction = dir
	
	b.set_meta("is_tank_shell", true)
	b.set_meta("is_bomb", true)  # FIX: needed for _process_bombs to handle it
	b.scale = Vector2(2.5, 2.5)
	if is_ally:
		b.is_enemy_bullet = false
		b.damage = 30
		b.add_to_group("player_bullet")
	else:
		b.is_enemy_bullet = true
		b.damage = 20
		b.add_to_group("enemy_bullet")
	
	_muzzle_flash.color.a = 1.0
	var tw = create_tween()
	tw.tween_property(_muzzle_flash, "color:a", 0.0, 0.1)
	
	# FIX: track original turret x so recoil doesn't permanently drift
	var orig_x = _turret.position.x
	_turret.position.x -= 8.0 * patrol_direction
	create_tween().tween_property(_turret, "position:x", orig_x, 0.3)

func take_damage(amount: int) -> void:
	hp -= amount
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.08).from(Color.ORANGE_RED)
	if hp <= 0: _die()

func _die() -> void:
	# Explosion effect
	var main = _get_main_scene()
	if not is_ally and main and main.has_method("add_kill"):
		main.add_kill(250, 24)
	if main and main.has_method("screen_shake"):
		main.screen_shake(12.0, 0.5)
		Audio.play("b40", 12.0) # Exploding tank sound
	
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
