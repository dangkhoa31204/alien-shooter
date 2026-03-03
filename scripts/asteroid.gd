extends Area2D
# asteroid.gd — Thiên thạch rơi: kích thước random, tách mảnh, rơi vật phẩm

signal died

# 0=nhỏ, 1=vừa, 2=to
var size_tier:  int   = 1
var speed:      float = 180.0
var direction:  Vector2 = Vector2.DOWN
var hp:         int   = 3
var _rot_speed: float = 1.2
var _is_dying:  bool  = false
var _scale_mul: float = 1.0   # nhân thêm trong từng tier để random kích thước

@onready var sprite: Polygon2D = $Sprite

const POWERUP_SCENE = preload("res://scenes/powerup.tscn")

# Tỷ lệ drop powerup theo tier (0/1/2)
const DROP_CHANCE: Array = [0.04, 0.12, 0.25]
# HP mặc định theo tier
const BASE_HP: Array     = [1, 3, 6]
# Scale cơ bản theo tier
const BASE_SCALE: Array  = [0.45, 1.0, 1.75]

func _ready() -> void:
	add_to_group("asteroid")
	body_entered.connect(_on_body_entered)
	# Kích thước = scale cơ bản × _scale_mul (random khi tạo)
	var s: float = BASE_SCALE[size_tier] * _scale_mul
	scale = Vector2(s, s)
	# Nếu hp chưa được gán từ ngoài, dùng default theo tier
	if hp == 3:
		hp = BASE_HP[size_tier]
	get_tree().create_timer(16.0).timeout.connect(_expire)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	rotation  += _rot_speed * delta
	if position.y > get_viewport_rect().size.y + 80.0:
		_expire()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(1 if size_tier == 0 else (2 if size_tier == 1 else 3))
		_destroy()

func take_damage(dmg: int = 1) -> void:
	if _is_dying: return
	hp -= dmg
	if hp <= 0:
		_destroy()
		return
	if is_instance_valid(sprite):
		sprite.color = Color.WHITE
		await get_tree().create_timer(0.07).timeout
		if is_instance_valid(self) and is_instance_valid(sprite):
			sprite.color = _base_color()

func _destroy() -> void:
	if _is_dying: return
	_is_dying = true
	_spawn_debris()
	# Thiên thạch to/vừa tách ra các mảnh nhỏ hơn
	_split()
	# Thói quen drop vật phẩm
	_try_drop_powerup()
	emit_signal("died")
	queue_free()

func _expire() -> void:
	if _is_dying: return
	_is_dying = true
	emit_signal("died")
	queue_free()

func _base_color() -> Color:
	match size_tier:
		0: return Color(0.65, 0.52, 0.38)   # nhỏ: cam nâu nhạt
		1: return Color(0.55, 0.42, 0.28)   # vừa: nâu cổ điển
		_: return Color(0.40, 0.30, 0.18)   # to:  nâu đậm

func _split() -> void:
	if size_tier == 0: return   # nhỏ không tách nữa
	var container := get_tree().get_root().get_node_or_null("Main/AsteroidContainer")
	if container == null:
		container = get_tree().get_root().get_node_or_null("Main/BulletContainer")
	if container == null: return
	var child_tier := size_tier - 1
	var count := 3 if size_tier == 2 else (1 if randf() < 0.5 else 0)
	count = maxi(count, 1)
	for i in range(count):
		var a = load("res://scenes/asteroid.tscn").instantiate()
		a.size_tier = child_tier
		a._scale_mul = randf_range(0.75, 1.25)
		a.hp = BASE_HP[child_tier]
		# Hướng ngẫu nhiên tỏa ra
		var ang := randf_range(-PI * 0.55, PI * 0.55)
		a.direction = direction.rotated(ang).normalized()
		a.speed = speed * randf_range(0.9, 1.3)
		a._rot_speed = randf_range(-2.5, 2.5)
		a.global_position = global_position + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		a.died.connect(func(): pass)   # không đếm vào enemies_alive
		container.add_child(a)

func _try_drop_powerup() -> void:
	if randf() > DROP_CHANCE[size_tier]: return
	var container := get_tree().get_root().get_node_or_null("Main/BulletContainer")
	if container == null: return
	var pu = POWERUP_SCENE.instantiate()
	pu.global_position = global_position
	pu.powerup_type    = randi() % 7   # 0–6 như bình thường
	container.add_child(pu)

func _spawn_debris() -> void:
	var container := get_tree().get_root().get_node_or_null("Main/BulletContainer")
	if container == null: return
	var dcount := 3 + size_tier * 2   # 3/5/7 mảnh
	for i in range(dcount):
		var debris := _make_debris()
		debris.global_position = global_position
		container.add_child(debris)

func _make_debris() -> Node2D:
	var node := Node2D.new()
	var p := Polygon2D.new()
	var sz := randf_range(3.0, 7.0) * (1.0 + float(size_tier) * 0.5)
	p.polygon = PackedVector2Array([
		Vector2(-sz, -sz * 0.6), Vector2(sz * 0.4, -sz),
		Vector2(sz, sz * 0.5),   Vector2(-sz * 0.3, sz)
	])
	p.color = Color(randf_range(0.4, 0.65), randf_range(0.3, 0.5), randf_range(0.18, 0.32))
	node.add_child(p)
	var angle := randf() * TAU
	var spd   := randf_range(60.0, 160.0) * (1.0 + float(size_tier) * 0.3)
	var dir   := Vector2(cos(angle), sin(angle))
	var rot   := randf_range(-4.0, 4.0)
	node.set_meta("vel", dir * spd)
	node.set_meta("rot_spd", rot)
	node.set_meta("life", 0.45)
	node.set_script(_debris_script())
	return node

static func _debris_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = """extends Node2D
func _process(delta):
	var life = get_meta("life") - delta
	set_meta("life", life)
	if life <= 0:
		queue_free()
		return
	position += get_meta("vel") * delta
	rotation  += get_meta("rot_spd") * delta
	modulate.a = life / 0.45
"""
	s.reload()
	return s
