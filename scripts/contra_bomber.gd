extends CharacterBody2D

# contra_bomber.gd
# Aerial enemy that flies across the sky and drops bombs.
# Can be shot down — falls with realistic physics + animation.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")

const SPEED: float        = 180.0
const GRAVITY: float      = 520.0   # pixels/s² while falling
const SPIN_SPEED: float   = 3.8     # radians/s while spinning down

var hp: int       = 6
var direction: int = 1  # 1 = Right, -1 = Left

# Falling state
var _dying:      bool    = false
var _fall_vel:   Vector2 = Vector2.ZERO
var _smoke_timer: float  = 0.0
var _fire_timer:  float  = 0.0

@onready var sprite: Node2D    = $Sprite
@onready var shoot_timer: Timer = $ShootTimer

func _ready() -> void:
	add_to_group("enemy")
	_setup_visuals()
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_timer.start(1.5 + randf())

func _setup_visuals() -> void:
	# B-52 style bomber silhouette using polygons
	var fuse = Polygon2D.new()
	fuse.polygon = PackedVector2Array([
		Vector2(-40, -5), Vector2(40, -5), Vector2(45, 2),
		Vector2(40, 8), Vector2(-40, 8), Vector2(-45, 2)
	])
	fuse.color = Color(0.3, 0.32, 0.35)
	sprite.add_child(fuse)

	var cock = ColorRect.new()
	cock.size = Vector2(8, 4); cock.position = Vector2(30, -4)
	cock.color = Color(0.1, 0.4, 0.8, 0.7)
	sprite.add_child(cock)

	var tail = Polygon2D.new()
	tail.polygon = PackedVector2Array([
		Vector2(-40, -5), Vector2(-45, -20), Vector2(-35, -20), Vector2(-30, -5)
	])
	tail.color = Color(0.25, 0.28, 0.3)
	sprite.add_child(tail)

	var wing1 = Polygon2D.new()
	wing1.polygon = PackedVector2Array([
		Vector2(-10, 0), Vector2(-25, -20), Vector2(0, -20), Vector2(15, 0)
	])
	wing1.color = Color(0.2, 0.22, 0.25); wing1.z_index = -1
	sprite.add_child(wing1)

	var eng1 = ColorRect.new()
	eng1.size = Vector2(12, 4); eng1.position = Vector2(-2, -22)
	eng1.color = Color(0.1, 0.1, 0.1)
	wing1.add_child(eng1)

func _physics_process(delta: float) -> void:
	if _dying:
		_update_fall(delta)
		return

	velocity.x = direction * SPEED
	move_and_slide()
	sprite.scale.x = direction

	if abs(global_position.x) > 14000:
		queue_free()

func _update_fall(delta: float) -> void:
	# Apply gravity
	_fall_vel.y += GRAVITY * delta
	global_position += _fall_vel * delta

	# Spin out of control
	sprite.rotation += SPIN_SPEED * delta

	# Smoke trail every 0.08 s
	_smoke_timer -= delta
	if _smoke_timer <= 0.0:
		_smoke_timer = 0.08
		_emit_smoke()

	# Fire spark burst every 0.18 s
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = 0.18
		_emit_fire()

	# Ground impact
	var main = _get_main_scene()
	var ground_y: float = 600.0
	if main and main.has_method("_get_ground_y"):
		ground_y = main._get_ground_y(global_position.x)

	if global_position.y >= ground_y:
		_crash_impact(main)

func _emit_smoke() -> void:
	var main = _get_main_scene()
	if not main: return
	var sm := Polygon2D.new()
	var pts: Array = []
	var r := randf_range(8.0, 18.0)
	for i in 8:
		var a := i * TAU / 8.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	sm.polygon = PackedVector2Array(pts)
	sm.color = Color(0.25, 0.22, 0.20, 0.70)
	sm.global_position = global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-6.0, 6.0))
	sm.z_index = 5
	main._world.add_child(sm)
	var tw: Tween = sm.create_tween().set_parallel(true)
	tw.tween_property(sm, "scale",       Vector2(3.0, 3.0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sm, "modulate:a",  0.0,               0.9).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sm, "position:y",  sm.position.y - 40.0, 0.9).set_trans(Tween.TRANS_QUAD)
	tw.finished.connect(sm.queue_free)

func _emit_fire() -> void:
	var main = _get_main_scene()
	if not main: return
	var sp := Polygon2D.new()
	var pts: Array = []
	var r := randf_range(5.0, 11.0)
	for i in 6:
		var a := i * TAU / 6.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	sp.polygon = PackedVector2Array(pts)
	sp.color = Color(1.0, randf_range(0.3, 0.7), 0.05, 0.9)
	sp.global_position = global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-8.0, 8.0))
	sp.z_index = 6
	main._world.add_child(sp)
	var tw: Tween = sp.create_tween().set_parallel(true)
	tw.tween_property(sp, "scale",      Vector2(2.5, 2.5), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "modulate:a", 0.0,               0.35)
	tw.finished.connect(sp.queue_free)

func _crash_impact(main: Node) -> void:
	if not main: queue_free(); return

	main.screen_shake(22.0, 0.7)
	Audio.play("bomber_explode", 16.0)

	# Big ground explosion
	for ring in 3:
		var blast := Polygon2D.new()
		var pts: Array = []; var rad := 80.0 + ring * 55.0
		for i in 14:
			var a := i * TAU / 14.0
			pts.append(Vector2(cos(a) * rad, sin(a) * rad))
		blast.polygon = PackedVector2Array(pts)
		blast.color   = Color(1.0, 0.5 - ring * 0.1, 0.05, 0.9 - ring * 0.15)
		blast.global_position = global_position
		blast.z_index = 6
		main._world.add_child(blast)
		var tw: Tween = blast.create_tween().set_parallel(true)
		tw.tween_property(blast, "scale",      Vector2(2.5, 2.5), 0.55 + ring * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(blast, "modulate:a", 0.0,               0.55 + ring * 0.12).set_delay(0.1 + ring * 0.05)
		tw.finished.connect(blast.queue_free)

	# Smoke column rising from wreckage
	for _sc in 5:
		var sc := Polygon2D.new(); var pts2: Array = []
		var r2 := randf_range(14.0, 26.0)
		for i in 10:
			var a := i * TAU / 10.0
			pts2.append(Vector2(cos(a) * r2, sin(a) * r2))
		sc.polygon = PackedVector2Array(pts2)
		sc.color = Color(0.18, 0.16, 0.14, 0.6)
		sc.global_position = global_position + Vector2(randf_range(-30.0, 30.0), 0.0)
		sc.z_index = 5
		main._world.add_child(sc)
		var stw: Tween = sc.create_tween().set_parallel(true)
		stw.tween_property(sc, "position:y", sc.global_position.y - randf_range(80.0, 160.0), 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stw.tween_property(sc, "scale",      Vector2(4.0, 4.0), 2.0)
		stw.tween_property(sc, "modulate:a", 0.0,               2.0).set_delay(0.4)
		stw.finished.connect(sc.queue_free)

	# Scattered wreckage debris
	for i in 10:
		var debris := ColorRect.new()
		debris.size  = Vector2(randf_range(6.0, 16.0), randf_range(4.0, 10.0))
		debris.color = Color(0.18, 0.20, 0.22)
		debris.global_position = global_position + Vector2(randf_range(-40.0, 40.0), randf_range(-10.0, 10.0))
		debris.z_index = 4
		main._world.add_child(debris)
		var vx := randf_range(-220.0, 220.0); var vy := randf_range(-300.0, -80.0)
		var dtw: Tween = debris.create_tween().set_parallel(true)
		dtw.tween_property(debris, "position", debris.global_position + Vector2(vx, vy + 350.0), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		dtw.tween_property(debris, "rotation", randf_range(-TAU, TAU), 1.2)
		dtw.tween_property(debris, "modulate:a", 0.0, 0.5).set_delay(0.7)
		dtw.finished.connect(debris.queue_free)

	# Score & feedback
	if main.has_method("add_kill"):
		main.add_kill(500, 40)

	queue_free()

func _on_shoot_timer_timeout() -> void:
	if not _dying:
		_drop_bomb()

func _drop_bomb() -> void:
	var b = BULLET_SCENE.instantiate()
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(0, 10)
	b.set_meta("is_bomb", true)
	if "direction" in b: b.direction = Vector2.DOWN
	b.is_enemy_bullet = true
	if "damage" in b: b.damage = 1
	b.scale = Vector2(2.5, 2.5)
	b.add_to_group("enemy_bullet")

func take_damage(amount: int) -> void:
	if _dying: return
	hp -= amount
	# Flash red
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.06).from(Color.RED)
	if hp <= 0:
		_start_fall()

func _start_fall() -> void:
	_dying = true
	shoot_timer.stop()
	Audio.play("bomber_drop_sound", 10.0)
	# Initial velocity: keep horizontal momentum, slight upward kick
	_fall_vel = Vector2(velocity.x * 0.5, -120.0)
	# Remove from "enemy" group so it no longer counts for targeting
	remove_from_group("enemy")
	# Disable collision so it doesn't push the player while falling
	$CollisionShape2D.set_deferred("disabled", true)

func _get_main_scene() -> Node:
	var curr = get_parent()
	while curr != null:
		if "ContraMain" in curr.name: return curr
		curr = curr.get_parent()
	return null


