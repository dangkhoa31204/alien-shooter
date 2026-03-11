extends CharacterBody2D

# contra_bomber.gd
# Aerial enemy that flies across the sky and drops bombs.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")

const SPEED: float = 180.0
var hp: int = 5
var direction: int = 1 # 1 for Right, -1 for Left

@onready var sprite: Node2D = $Sprite
@onready var shoot_timer: Timer = $ShootTimer

func _ready() -> void:
	add_to_group("enemy")
	_setup_visuals()
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	shoot_timer.start(1.5 + randf())

func _setup_visuals() -> void:
	# B-52 style bomber Silhouette using polygons
	# Fuselage
	var fuse = Polygon2D.new()
	fuse.polygon = PackedVector2Array([
		Vector2(-40, -5), Vector2(40, -5), Vector2(45, 2), 
		Vector2(40, 8), Vector2(-40, 8), Vector2(-45, 2)
	])
	fuse.color = Color(0.3, 0.32, 0.35) # Metal gray
	sprite.add_child(fuse)
	
	# Cockpit
	var cock = ColorRect.new()
	cock.size = Vector2(8, 4); cock.position = Vector2(30, -4); cock.color = Color(0.1, 0.4, 0.8, 0.7)
	sprite.add_child(cock)

	# Tail fin
	var tail = Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(-40, -5), Vector2(-45, -20), Vector2(-35, -20), Vector2(-30, -5)])
	tail.color = Color(0.25, 0.28, 0.3)
	sprite.add_child(tail)

	# Wings (Far side)
	var wing1 = Polygon2D.new()
	wing1.polygon = PackedVector2Array([Vector2(-10, 0), Vector2(-25, -20), Vector2(0, -20), Vector2(15, 0)])
	wing1.color = Color(0.2, 0.22, 0.25); wing1.z_index = -1
	sprite.add_child(wing1)

	# Engine pods
	var eng1 = ColorRect.new(); eng1.size = Vector2(12, 4); eng1.position = Vector2(-2, -22); eng1.color = Color(0.1, 0.1, 0.1)
	wing1.add_child(eng1)

func _physics_process(delta: float) -> void:
	velocity.x = direction * SPEED
	move_and_slide()
	
	# Face movement direction
	sprite.scale.x = direction
	
	# Auto cleanup if flies too far
	if abs(global_position.x) > 10000: queue_free()

func _on_shoot_timer_timeout() -> void:
	_drop_bomb()

func _drop_bomb() -> void:
	var b = BULLET_SCENE.instantiate()
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(0, 10)
	
	# Mark as bomb for special handling in contra_main
	b.set_meta("is_bomb", true)
	if "direction" in b: b.direction = Vector2.DOWN
	b.is_enemy_bullet = true
	if "damage" in b: b.damage = 2
	b.scale = Vector2(2.5, 2.5) # Larger visuals
	b.add_to_group("enemy_bullet")

func take_damage(amount: int) -> void:
	hp -= amount
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.05).from(Color.RED)
	if hp <= 0:
		_die()

func _die() -> void:
	var main = _get_main_scene()
	if main:
		main.screen_shake(18.0, 0.6)
		# Mid-air Explosion Visual (B40 style)
		var blast = Polygon2D.new()
		var res = 20; var radius = 180.0
		var pts = []
		for i in res:
			var a = i * TAU / res
			pts.append(Vector2(cos(a)*radius, sin(a)*radius))
		blast.polygon = PackedVector2Array(pts)
		blast.color = Color(1.0, 0.35, 0.1, 0.95)
		blast.global_position = global_position
		main._world.add_child(blast)
		
		Audio.play("b40", 15.0) # Massive plane explosion sound

		var tw = blast.create_tween().set_parallel(true)
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(blast, "scale", Vector2(2.2, 2.2), 0.35)
		tw.tween_property(blast, "modulate:a", 0.0, 0.6).set_delay(0.2)
		tw.finished.connect(blast.queue_free)
		
		# Falling Plane Debris
		for i in 12:
			var debris = ColorRect.new()
			debris.size = Vector2(10, 8)
			debris.color = Color(0.18, 0.2, 0.22) # Dark metal
			debris.position = global_position + Vector2(randf_range(-50, 50), randf_range(-20, 20))
			main._world.add_child(debris)
			
			var d_tw = create_tween().set_parallel(true)
			var land_y = global_position.y + 450
			d_tw.tween_property(debris, "position", debris.position + Vector2(randf_range(-200, 200), 500), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			d_tw.parallel().tween_property(debris, "rotation", randf_range(-PI*4, PI*4), 1.0)
			d_tw.tween_property(debris, "modulate:a", 0.0, 0.5).set_delay(0.8)
			d_tw.finished.connect(debris.queue_free)
	
	queue_free()

func _get_main_scene() -> Node:
	var curr = get_parent()
	while curr != null:
		if "ContraMain" in curr.name: return curr
		curr = curr.get_parent()
	return null
