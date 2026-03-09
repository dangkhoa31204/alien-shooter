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
		if "screen_shake" in get_parent(): get_parent().screen_shake(5.0, 0.3)
		queue_free()
