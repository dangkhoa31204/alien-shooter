extends CharacterBody2D

# contra_bomber.gd
# Aerial enemy that flies across the sky and drops bombs.
# Can be shot down — falls with realistic physics + animation.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")

const SPEED: float        = 180.0
const GRAVITY: float      = 520.0   # pixels/s² while falling
const SPIN_SPEED: float   = 3.8     # radians/s while spinning down

const HP_MULT: float = 0.5

var hp: int       = 130
var direction: int = 1  # 1 = Right, -1 = Left

# Falling state

var _dying:      bool    = false
var _fall_vel:   Vector2 = Vector2.ZERO
var _smoke_timer: float  = 0.0
var _fire_timer:  float  = 0.0
var _shot:       bool    = false # Trạng thái vừa bị bắn, chạy animation bay thẳng ngắn
var _shot_timer: float   = 0.0
# Góc nghiêng mục tiêu khi rơi (rad)
const FALL_TARGET_ROT = deg_to_rad(38)
var _fall_rot: float = 0.0 # Góc nghiêng hiện tại
var _fall_rot_speed: float = 0.0 # Tốc độ xoay nghiêng

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shoot_timer: Timer = $ShootTimer

func _ready() -> void:
	add_to_group("enemy")
	hp = maxi(1, int(round(float(hp) * HP_MULT)))
	sprite.play("fly")
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_timer.start(1.5 + randf())

## Đã thay thế bằng AnimatedSprite2D, không cần vẽ Polygon2D thủ công nữa

func _physics_process(delta: float) -> void:
	if _shot:
		_shot_timer -= delta
		# Chạy animation bay thẳng ngắn, chậm hơn
		velocity.x = direction * (SPEED * 0.55)
		move_and_slide()
		sprite.play("fly")
		sprite.scale = Vector2(-1.2, 0.95) # To hơn
		if _shot_timer <= 0.0:
			_shot = false
			_start_fall()
		return

	if _dying:
		_update_fall(delta)
		return

	velocity.x = direction * SPEED
	move_and_slide()
	sprite.scale.x = direction * 0.2
	# Đảm bảo animation luôn là "fly" khi bay
	if not _dying and sprite.animation != "fly":
		sprite.play("fly")
	# Đảm bảo scale dày hơn
	sprite.scale = Vector2(-1.2, 0.95) # To hơn, dày hơn nữa, bay chiều ngược lại

	if abs(global_position.x) > 14000:
		queue_free()

func _update_fall(delta: float) -> void:
	# Apply gravity
	_fall_vel.y += GRAVITY * delta
	# Tăng vận tốc ngang để tạo cảm giác lao nhanh hơn
	_fall_vel.x += direction * 60.0 * delta # Tăng dần vận tốc ngang
	# Giảm nhẹ vận tốc ngang nếu quá lớn
	if abs(_fall_vel.x) > SPEED * 2.2:
		_fall_vel.x = sign(_fall_vel.x) * SPEED * 2.2
	global_position += _fall_vel * delta

	# Chuyển animation sang "fall" khi rơi
	if sprite.animation != "fall":
		sprite.play("fall")
		# Để animation rơi chỉ chạy 1 lần, hãy bỏ tick 'Loop' cho animation 'fall' trong SpriteFrames bằng editor Godot

	# Nghiêng máy bay từ từ về góc mục tiêu
	var target_rot = FALL_TARGET_ROT * direction
	# Tăng tốc độ xoay khi rơi
	_fall_rot_speed += 2.8 * delta
	# Giới hạn tốc độ xoay
	if _fall_rot_speed > 3.2:
		_fall_rot_speed = 3.2
	# Xoay dần về góc mục tiêu
	_fall_rot = lerp(_fall_rot, target_rot, _fall_rot_speed * delta)
	sprite.rotation = _fall_rot

	# Giữ frame cuối nếu animation không lặp
	if not sprite.is_playing():
		sprite.frame = sprite.sprite_frames.get_frame_count("fall") - 1

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
	Audio.play("bomb_explode", 16.0)

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
	if "damage" in b: b.damage = 14
	b.scale = Vector2(2.5, 2.5)
	b.add_to_group("enemy_bullet")

func take_damage(amount: int) -> void:
	if _dying or _shot: return
	if amount <= 0: return
	# One-shot down: any hit makes the bomber fall.
	hp = 0
	# Flash red
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.06).from(Color.RED)
	# Bắt đầu trạng thái bị bắn: bay thẳng ngắn, chậm hơn
	_shot = true
	_shot_timer = 0.55 # Thời gian bay thẳng ngắn (chậm hơn, mượt)

func _start_fall() -> void:
	_dying = true
	shoot_timer.stop()
	Audio.play("bomber_drop_sound", 10.0)
	# Initial velocity: lao xiên (vận tốc ngang lớn hơn)
	_fall_vel = Vector2(velocity.x * 1.2, -120.0)
	# Reset góc nghiêng và tốc độ xoay
	_fall_rot = 0.0
	_fall_rot_speed = 0.0
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
