extends Area2D

# contra_rocket.gd
# Anti-tank rocket RPG-7/B40 with massive AoE.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 800.0
var damage: int = 90 # Massive damage
var life_time: float = 3.0

func _ready() -> void:
	add_to_group("player_bullet")
	
	# Create collision shape programmatically
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10.0
	col.shape = shape
	add_child(col)
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	monitorable = false # So enemies don't hit the rocket with bullets
	monitoring = true
	
	_setup_visuals()

func _setup_visuals() -> void:
	# RPG-7 Warhead shape
	var head = Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(0, -3), Vector2(10, -5), Vector2(15, 0), 
		Vector2(10, 5), Vector2(0, 3), Vector2(-2, 0)
	])
	head.color = Color(0.2, 0.4, 0.2)
	add_child(head)
	
	# Tail fins
	var tail = ColorRect.new()
	tail.size = Vector2(8, 2); tail.position = Vector2(-8, -1); tail.color = Color(0.3, 0.3, 0.3)
	add_child(tail)
	
	# Smoke trail (Particles equivalent)
	var trail = ColorRect.new()
	trail.size = Vector2(30, 2); trail.position = Vector2(-40, -1); trail.color = Color(0.8, 0.8, 0.8, 0.4)
	add_child(trail)

var _smoke_timer: float = 0.0

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	rotation = direction.angle()

	# Per-frame smoke trail puff
	_smoke_timer -= delta
	if _smoke_timer <= 0.0:
		_smoke_timer = 0.04
		_spawn_smoke_puff()

	# Fallback ground check (for hilly terrain where physics might miss)
	var main = _get_main_scene()
	if main and main.has_method("_get_ground_y"):
		var gy = main._get_ground_y(global_position.x)
		if global_position.y >= gy - 5.0:
			_explode()
			return

	life_time -= delta
	if life_time <= 0: _explode()

func _spawn_smoke_puff() -> void:
	var puff := Polygon2D.new()
	var pts: Array = []
	var r := randf_range(4.0, 9.0)
	for i in 7:
		var a := i * TAU / 7.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	puff.polygon = PackedVector2Array(pts)
	puff.color = Color(0.75, 0.72, 0.68, 0.6)
	# Emit behind the rocket
	puff.global_position = global_position - direction * 12.0
	puff.z_index = 2
	var parent := get_parent()
	if parent: parent.add_child(puff)
	var tw: Tween = puff.create_tween()
	tw.tween_property(puff, "scale", Vector2(2.5, 2.5), 0.5)
	tw.parallel().tween_property(puff, "position:y", puff.position.y - 12.0, 0.5)
	tw.parallel().tween_property(puff, "modulate:a", 0.0, 0.5)
	tw.finished.connect(puff.queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("tank") or body is StaticBody2D:
		_explode()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy") or area.is_in_group("tank"):
		_explode()

func _explode() -> void:
	# Create a massive visual explosion
	var blast = Polygon2D.new()
	var res = 16; var radius = 120.0
	var pts = []
	for i in res:
		var a = i * TAU / res
		pts.append(Vector2(cos(a)*radius, sin(a)*radius))
	blast.polygon = PackedVector2Array(pts)
	blast.color = Color(1.0, 0.4, 0.0, 0.8)
	blast.global_position = global_position
	get_parent().add_child(blast)
	
	# Flash & Shake
	var main = _get_main_scene()
	if main:
		main.screen_shake(15.0, 0.4)
		Audio.play("b40", 12.0)
	
	# Damage everything in radius
	var tree = get_tree()
	if tree:
		var targets = tree.get_nodes_in_group("enemy") + tree.get_nodes_in_group("tank")
		for enemy in targets:
			if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) < radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage)
	
	# Animate explosion out - Bind to blast so it lives after rocket is freed
	var tw = blast.create_tween().set_parallel(true)
	tw.tween_property(blast, "scale", Vector2(1.5, 1.5), 0.2)
	tw.tween_property(blast, "modulate:a", 0.0, 0.4).set_delay(0.1)
	tw.finished.connect(blast.queue_free)
	
	queue_free()

func _get_main_scene() -> Node:
	var curr = get_parent()
	while curr != null:
		if curr.name == "ContraMain": return curr
		curr = curr.get_parent()
	return null
