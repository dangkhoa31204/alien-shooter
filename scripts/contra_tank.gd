extends CharacterBody2D

# contra_tank.gd
# Heavy armored vehicle with AoE cannon.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")

const HP_MULT: float = 0.5

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
		hp = maxi(1, int(round(float(hp) * HP_MULT)))
	
	# Create nodes programmatically
	sprite = Node2D.new(); sprite.name = "Sprite"; add_child(sprite)
	shoot_timer = Timer.new(); shoot_timer.name = "ShootTimer"; add_child(shoot_timer)
	
	# Collision — bigger to match enlarged visuals
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new(); shape.size = Vector2(140, 65)
	col.shape = shape; add_child(col)
	col.position = Vector2(0, -18)
	
	_setup_visuals()
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_timer.start(2.5 + randf())

func _setup_visuals() -> void:
	# === ENLARGED TANK (~1.7x) ===
	# Base Tracks Structure
	var base = Polygon2D.new()
	base.polygon = PackedVector2Array([
		Vector2(-72, 30), Vector2(72, 30),
		Vector2(82, 14), Vector2(72, -4),
		Vector2(-72, -4), Vector2(-82, 14)
	])
	base.color = Color(0.12, 0.12, 0.12); sprite.add_child(base)
	
	# Road Wheels (6 per side for a longer tank)
	for i in 6:
		var w = Polygon2D.new()
		var pts = []
		for j in 8:
			var a = j * PI / 4.0; pts.append(Vector2(cos(a)*10, sin(a)*10))
		w.polygon = PackedVector2Array(pts); w.color = Color(0.22, 0.22, 0.22)
		w.position = Vector2(-55 + i * 22, 16); sprite.add_child(w); _wheels.append(w)
		# Wheel hub
		var hub = ColorRect.new(); hub.size = Vector2(6, 6); hub.position = Vector2(-3, -3)
		hub.color = Color(0.08, 0.08, 0.08); w.add_child(hub)

	# Main Armored Hull
	_body = Node2D.new(); sprite.add_child(_body)
	var hull = Polygon2D.new()
	hull.polygon = PackedVector2Array([
		Vector2(-60, -4), Vector2(60, -4),
		Vector2(48, -38), Vector2(-48, -38)
	])
	var hull_color = Color(0.22, 0.38, 0.15) if is_ally else Color(0.18, 0.22, 0.12)
	hull.color = hull_color; _body.add_child(hull)
	
	# Camo panel detail
	var panel = Polygon2D.new()
	panel.polygon = [Vector2(8, -38), Vector2(26, -38), Vector2(42, -4)]
	panel.color = hull_color.darkened(0.2); _body.add_child(panel)
	
	if is_ally:
		var star = Polygon2D.new(); var spts = []
		for i in 10:
			var r = 10 if i % 2 == 0 else 5; var a = i * TAU / 10.0 - PI/2.0
			spts.append(Vector2(cos(a)*r, sin(a)*r - 20))
		star.polygon = PackedVector2Array(spts); star.color = Color.YELLOW; _body.add_child(star)

	# Turret
	_turret = Node2D.new(); _turret.position = Vector2(4, -36); sprite.add_child(_turret)
	
	var t_base = Polygon2D.new()
	t_base.polygon = PackedVector2Array([
		Vector2(-30, 0), Vector2(30, 0),
		Vector2(24, -24), Vector2(-24, -24)
	])
	t_base.color = hull_color.darkened(0.1); _turret.add_child(t_base)
	
	# Hatch & Gunner
	_hatch = Node2D.new(); _hatch.position = Vector2(-12, -24); _turret.add_child(_hatch)
	var hatch_lid = ColorRect.new(); hatch_lid.size = Vector2(18, 4)
	hatch_lid.position = Vector2(-9, -3); hatch_lid.color = Color(0.1, 0.1, 0.1); _hatch.add_child(hatch_lid)
	# Gunner head
	var gunner = Node2D.new(); _hatch.add_child(gunner)
	var head = ColorRect.new(); head.size = Vector2(9, 9); head.position = Vector2(-4, -14)
	head.color = Color(0.9, 0.7, 0.5); gunner.add_child(head)
	var helmet = ColorRect.new(); helmet.size = Vector2(12, 6); helmet.position = Vector2(-6, -17)
	helmet.color = Color(0.1, 0.2, 0.1); gunner.add_child(helmet)

	# Main Cannon Barrel — long and impressive
	_barrel = ColorRect.new()
	_barrel.size = Vector2(75, 12); _barrel.position = Vector2(0, -16)
	_barrel.color = Color(0.1, 0.1, 0.1); _turret.add_child(_barrel)
	# Muzzle brake
	var muzzle_brake = ColorRect.new(); muzzle_brake.size = Vector2(10, 20)
	muzzle_brake.position = Vector2(70, -20); muzzle_brake.color = Color(0.05, 0.05, 0.05)
	_turret.add_child(muzzle_brake)
	
	# Muzzle Flash
	_muzzle_flash = Polygon2D.new()
	_muzzle_flash.polygon = [Vector2(0, -18), Vector2(36, 0), Vector2(0, 18)]
	_muzzle_flash.color = Color(1, 0.7, 0.2, 0)
	_muzzle_flash.position = Vector2(80, -10); _turret.add_child(_muzzle_flash)

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
		Audio.play("tank_shoot", 15.0) # Tank firing sound
		_fire_cannon()

func _fire_cannon() -> void:
	var b = BULLET_SCENE.instantiate()
	# FIX: use bullet_container via main scene instead of get_parent() for proper management
	var main = _get_main_scene()
	var bullet_container: Node = null
	if main:
		bullet_container = main.get_node_or_null("BulletContainer")
	if is_instance_valid(bullet_container):
		bullet_container.add_child(b)
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
		# Support fire: deal 1/10 of player's current damage (minimum 1).
		var player_dmg: int = 1
		var main2 := _get_main_scene()
		var player_node: Node = null
		if main2:
			var cand = main2.get("player")
			if cand is Node and is_instance_valid(cand):
				player_node = cand
		if not is_instance_valid(player_node):
			var players := get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				player_node = players[0]
		if is_instance_valid(player_node):
			var dmg_val = player_node.get("current_damage")
			if dmg_val != null:
				player_dmg = maxi(1, int(dmg_val))
		b.damage = maxi(1, int(round(float(player_dmg) / 10.0)))
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
	set_physics_process(false)
	collision_layer = 0
	collision_mask  = 0
	# CRITICAL: stop shoot timer immediately to prevent _fire_cannon on freed node
	if is_instance_valid(shoot_timer):
		shoot_timer.stop()
		shoot_timer.queue_free()
	
	# Capture position NOW before any deferred calls or queue_free
	var die_pos: Vector2 = global_position
	
	var main = _get_main_scene()
	if not is_ally and main and main.has_method("add_kill"):
		main.add_kill(250, 24)

	# ── PHASE 1 (t=0): First hit — big shake + first boom ──────────────────
	if main and main.has_method("screen_shake"):
		main.screen_shake(14.0, 0.6)
	Audio.play("b40", 14.0)
	var exp_parent = get_parent()
	if is_instance_valid(exp_parent):
		_spawn_explosion(die_pos + Vector2(randf_range(-15, 15), -20), 60, exp_parent)

	# ── PHASE 2 (t=0): Turret flies off ────────────────────────────────────
	if is_instance_valid(_turret):
		var turret_parent = _turret.get_parent()
		turret_parent.remove_child(_turret)
		get_parent().add_child(_turret)
		_turret.global_position = die_pos + Vector2(0, -50)
		var ttw = _turret.create_tween().set_parallel(true)
		var fly_dir = Vector2(randf_range(-60,60), -randf_range(120,200))
		ttw.tween_property(_turret, "position", _turret.position + fly_dir, 1.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ttw.tween_property(_turret, "rotation", randf_range(-PI, PI), 1.2)
		ttw.tween_property(_turret, "modulate:a", 0.0, 0.4).set_delay(0.9)
		ttw.finished.connect(_turret.queue_free)

	# ── PHASE 3 (t=0): Tank tilts and sinks ────────────────────────────────
	var body_tween = create_tween().set_parallel(true)
	body_tween.tween_property(sprite, "rotation", deg_to_rad(randf_range(-18, 18)), 0.3)
	body_tween.tween_property(sprite, "position:y", sprite.position.y + 12, 0.3)\
		.set_trans(Tween.TRANS_BOUNCE)

	# ── PHASE 4 (t=0.3 / 0.7 / 1.1): Chain explosions ──────────────────────
	for bi in 3:
		var delay = 0.3 + bi * 0.4
		var intensity = 8.0 - bi * 2.0
		var pitch = 12.0 - bi * 1.5
		var radius = 50 - bi * 8
		var offset = Vector2(randf_range(-50, 50), randf_range(-40, 0))
		get_tree().create_timer(delay).timeout.connect(func():
			if not is_instance_valid(exp_parent): return
			if main and main.has_method("screen_shake"):
				main.screen_shake(intensity, 0.3)
			Audio.play("bomb_explode", pitch)
			_spawn_explosion(die_pos + offset, radius, exp_parent)
		)

	# ── PHASE 5 (t=0): Continuous black smoke columns ───────────────────────
	var smoke_state = {"count": 0}
	var smoke_parent = get_parent() # Capture parent ref before queue_free
	var smoke_timer_node = Timer.new()
	smoke_timer_node.wait_time = 0.12
	smoke_timer_node.autostart = true
	smoke_parent.add_child(smoke_timer_node) # Add to parent, not self
	smoke_timer_node.timeout.connect(func():
		smoke_state.count += 1
		if smoke_state.count > 14 or not is_instance_valid(smoke_parent):
			if is_instance_valid(smoke_timer_node): smoke_timer_node.queue_free()
			return
		var sc = Polygon2D.new()
		var scpts = []
		var sr = randf_range(10, 22)
		for si in 8:
			var sa = si * TAU / 8.0
			scpts.append(Vector2(cos(sa)*sr, sin(sa)*sr))
		sc.polygon = PackedVector2Array(scpts)
		sc.color = Color(0.08, 0.08, 0.08, 0.85)
		sc.global_position = die_pos + Vector2(randf_range(-30, 30), -randf_range(10, 40))
		sc.z_index = 10
		smoke_parent.add_child(sc)
		var stw = sc.create_tween().set_parallel(true)
		stw.tween_property(sc, "position", sc.position + Vector2(randf_range(-20,20), -randf_range(50,90)), 1.4)
		stw.tween_property(sc, "scale", Vector2(2.5, 2.5), 1.4).set_trans(Tween.TRANS_QUAD)
		stw.tween_property(sc, "modulate:a", 0.0, 1.4).set_delay(0.2)
		stw.finished.connect(sc.queue_free)
	)

	# ── PHASE 6 (t=1.4): Debris shower ─────────────────────────────────────
	var debris_parent = get_parent()
	get_tree().create_timer(1.4).timeout.connect(func():
		if not is_instance_valid(debris_parent): return
		for di in 14:
			var deb = Polygon2D.new()
			deb.polygon = PackedVector2Array([
				Vector2(-randf_range(3,8), -randf_range(3,8)),
				Vector2(randf_range(3,8), -randf_range(2,6)),
				Vector2(randf_range(2,6), randf_range(3,8)),
				Vector2(-randf_range(2,6), randf_range(3,8))
			])
			deb.color = Color(randf_range(0.08, 0.22), 0.08, 0.05)
			deb.global_position = die_pos + Vector2(randf_range(-40,40), -randf_range(5,30))
			deb.z_index = 9
			debris_parent.add_child(deb)
			var vel_x = randf_range(-160, 160)
			var vel_y = randf_range(-220, -60)
			var dtw2 = deb.create_tween().set_parallel(true)
			dtw2.tween_property(deb, "position", deb.position + Vector2(vel_x * 0.8, -vel_y * 0.2 + 80), 1.0)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			dtw2.tween_property(deb, "rotation", randf_range(-PI*4, PI*4), 1.0)
			dtw2.tween_property(deb, "modulate:a", 0.0, 0.5).set_delay(0.6)
			dtw2.finished.connect(deb.queue_free)
	)

	# ── PHASE 7 (t=2.0): Tank body fade and queue_free ──────────────────────
	get_tree().create_timer(1.9).timeout.connect(func():
		if not is_instance_valid(self): return
		var fade = create_tween()
		fade.tween_property(sprite, "modulate:a", 0.0, 0.6)
		fade.finished.connect(queue_free)
	)

func _spawn_explosion(pos: Vector2, radius: int, parent_node: Node) -> void:
	if not is_instance_valid(parent_node): return
	# Core flash
	var core = Polygon2D.new()
	var cpts = []
	for ci in 10:
		var ca = ci * TAU / 10.0
		cpts.append(Vector2(cos(ca) * radius * 0.5, sin(ca) * radius * 0.5))
	core.polygon = PackedVector2Array(cpts)
	core.color = Color(1.0, 1.0, 0.85, 1.0)
	core.global_position = pos; core.z_index = 11
	parent_node.add_child(core)
	var ctw = core.create_tween().set_parallel(true)
	ctw.tween_property(core, "scale", Vector2(1.8, 1.8), 0.18).set_trans(Tween.TRANS_QUAD)
	ctw.tween_property(core, "modulate:a", 0.0, 0.22).set_delay(0.06)
	ctw.finished.connect(core.queue_free)
	# Orange ring
	var ring = Polygon2D.new()
	var rpts = []
	for ri in 14:
		var ra = ri * TAU / 14.0
		var rr = radius * (0.8 + randf() * 0.4)
		rpts.append(Vector2(cos(ra) * rr, sin(ra) * rr))
	ring.polygon = PackedVector2Array(rpts)
	ring.color = Color(1.0, 0.42, 0.08, 0.92)
	ring.global_position = pos; ring.z_index = 10
	parent_node.add_child(ring)
	var rtw = ring.create_tween().set_parallel(true)
	rtw.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.35).set_trans(Tween.TRANS_QUAD)
	rtw.tween_property(ring, "modulate:a", 0.0, 0.4).set_delay(0.1)
	rtw.finished.connect(ring.queue_free)

func _get_main_scene() -> Node:
	var curr = get_parent()
	while curr != null:
		if curr.name == "ContraMain": return curr
		curr = curr.get_parent()
	return null
