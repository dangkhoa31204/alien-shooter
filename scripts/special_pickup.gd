extends Area2D
# special_pickup.gd — Vũ khí đặc biệt rơi xuống, player nhặt để trang bị vào pod trái/phải

# 0 = MACHINEGUN | 1 = MISSILE | 2 = BLACK_HOLE
var weapon_type: int = 0
var slot:        int = 0   # 0=LEFT, 1=RIGHT (ngẫu nhiên khi spawn)

const FALL_SPEED: float = 70.0
const NAMES: Array = ["MACHINEGUN", "MISSILE", "BLACK HOLE"]
const COLORS: Array = [
	Color(1.0, 0.7, 0.0),   # vàng cam — súng máy
	Color(1.0, 0.2, 0.1),   # đỏ — tên lửa
	Color(0.2, 0.0, 0.9),   # xanh đậm — hố đen
]

var _pulse: float = 0.0
var _label: Label = null

# Polygon hình viên kim cương cho pickup
const DIAMOND: Array = [
	Vector2(0,-18), Vector2(14,-4), Vector2(0,18), Vector2(-14,-4)
]

func _ready() -> void:
	slot = randi() % 2
	body_entered.connect(_on_body_entered)
	_build_visuals()

func _build_visuals() -> void:
	var poly := Polygon2D.new()
	var pv := PackedVector2Array()
	for v in DIAMOND: pv.append(v)
	poly.polygon = pv
	poly.color   = COLORS[weapon_type]
	poly.name    = "Sprite"
	add_child(poly)

	# Chữ loại súng nhỏ bên trong
	_label = Label.new()
	_label.text = NAMES[weapon_type]
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.position = Vector2(-20, -6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(40, 14)
	add_child(_label)

	# Collision shape
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	cs.shape = shape
	add_child(cs)

	z_index = 5

func _physics_process(delta: float) -> void:
	_pulse += delta * 3.0
	position.y += FALL_SPEED * delta
	# Nhấp nháy màu
	var brightness := 0.7 + sin(_pulse) * 0.3
	if has_node("Sprite"):
		($Sprite as Polygon2D).color = COLORS[weapon_type] * Color(brightness, brightness, brightness)
	# Tự huỷ khi ra ngoài màn hình
	var vp := get_viewport_rect().size
	if position.y > vp.y + 40.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		(body as Node).call("collect_special", weapon_type, slot)
		queue_free()
