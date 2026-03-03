extends Area2D
# powerup.gd — Power-up item rơi từ enemy. Mỗi loại có hình dạng riêng qua _draw().
# 0=EXTRA_STREAM  1=ELECTRIC  2=FIRE  3=ICE  4=EXPLOSIVE  5=RICOCHET  6=UPGRADE

const COLORS: Array = [
	Color(0.2,  1.0,  0.3),   # 0 xanh      — extra stream
	Color(0.45, 0.55, 1.0),   # 1 xanh tím  — electric
	Color(1.0,  0.32, 0.0),   # 2 cam đỏ    — fire
	Color(0.15, 0.85, 1.0),   # 3 cyan       — ice
	Color(1.0,  0.62, 0.0),   # 4 cam vàng  — explosive
	Color(0.5,  1.0,  0.18),  # 5 xanh lá   — ricochet
	Color(1.0,  0.9,  0.08),  # 6 vàng      — upgrade
]

const LABELS: Array = ["+STREAM", "ELEC", "FIRE", "ICE", "BOOM", "RICO", "LV.UP"]

var powerup_type: int = 0
var fall_speed:   float = 70.0
var _collected:   bool  = false
var _t:           float = 0.0   # animation clock

@onready var label: Label = $Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(8.0).timeout.connect(_expire)
	# Ẩn ColorRect gốc — dùng _draw() thay thế
	var spr := get_node_or_null("Sprite")
	if spr: spr.visible = false
	# Label nhỏ phía trên, màu theo type
	if is_instance_valid(label):
		label.text = LABELS[powerup_type % LABELS.size()]
		var c: Color = COLORS[powerup_type % COLORS.size()]
		label.add_theme_color_override("font_color", c)
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.add_theme_font_size_override("font_size", 9)

func _physics_process(delta: float) -> void:
	_t += delta
	position.y += fall_speed * delta
	position.x += sin(_t * 2.8) * 0.45
	var vp := get_viewport_rect().size
	if position.y > vp.y + 30.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var col: Color = COLORS[powerup_type % COLORS.size()]
	var p     := 0.65 + sin(_t * 5.5) * 0.35        # pulse 0.3 → 1.0
	var cb    := Color(col.r, col.g, col.b, p)
	var cglow := Color(col.r * 0.45, col.g * 0.45, col.b * 0.45, p * 0.38)
	# Outer glow blob
	draw_circle(Vector2.ZERO, 14.5, cglow)

	match powerup_type:
		0:  # EXTRA_STREAM — Plus / cross +
			var arms := PackedVector2Array([
				Vector2(-10,-3), Vector2(-3,-3), Vector2(-3,-10), Vector2(3,-10),
				Vector2(3,-3),   Vector2(10,-3), Vector2(10,3),   Vector2(3,3),
				Vector2(3,10),   Vector2(-3,10), Vector2(-3,3),   Vector2(-10,3),
			])
			draw_colored_polygon(arms, cb)
			draw_polyline(PackedVector2Array([
				Vector2(-10,-3), Vector2(10,-3), Vector2(10,3), Vector2(-10,3), Vector2(-10,-3)
			]), Color(1,1,1, p * 0.45), 1.0)

		1:  # ELECTRIC — Tia sét zigzag
			var bolt := PackedVector2Array([
				Vector2(4,-12), Vector2(-1,-1), Vector2(3.5,-2),
				Vector2(-4,12), Vector2(1,1),   Vector2(-3.5,2),
			])
			draw_colored_polygon(bolt, cb)
			draw_polyline(PackedVector2Array([
				Vector2(4,-12), Vector2(-1,-1), Vector2(3.5,-2), Vector2(-4,12)
			]), Color(1,1,1, p * 0.75), 1.8)

		2:  # FIRE — Ngọn lửa
			var flame := PackedVector2Array()
			for i in 14:
				var a  := float(i) / 14.0 * TAU - PI * 0.5
				var rx := 6.5 + sin(a * 2.5) * 2.8
				var ry := 10.0 - sin(a * 0.5 + 0.3) * 3.2
				flame.append(Vector2(cos(a) * rx, sin(a) * ry - 1.5))
			draw_colored_polygon(flame, cb)
			# Lõi nóng trắng vàng
			var core := PackedVector2Array()
			for i in 8:
				var a := float(i) / 8.0 * TAU
				core.append(Vector2(cos(a) * 4.0, sin(a) * 5.5 - 2.0))
			draw_colored_polygon(core, Color(1.0, 0.96, 0.42, p))

		3:  # ICE — Bông tuyết lục giác
			var hex := PackedVector2Array()
			for i in 6:
				var a := float(i) / 6.0 * TAU - PI / 6.0
				hex.append(Vector2(cos(a) * 10.5, sin(a) * 10.5))
			draw_colored_polygon(hex, cb)
			# Gân bông tuyết
			for i in 6:
				var a    := float(i) / 6.0 * TAU - PI / 6.0
				var tip  := Vector2(cos(a) * 10.5, sin(a) * 10.5)
				draw_line(Vector2.ZERO, tip, Color(1,1,1, p * 0.75), 1.5)
				var cp   := tip * 0.55
				var perp := Vector2(-tip.y, tip.x).normalized() * 3.8
				draw_line(cp - perp, cp + perp, Color(1,1,1, p * 0.5), 1.0)

		4:  # EXPLOSIVE — Ngôi sao 8 cánh
			var star := PackedVector2Array()
			for i in 16:
				var a := float(i) / 16.0 * TAU - PI * 0.5
				var r := 11.5 if i % 2 == 0 else 5.0
				star.append(Vector2(cos(a) * r, sin(a) * r))
			draw_colored_polygon(star, cb)
			draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.92, 0.25, p))

		5:  # RICOCHET — Kim cương + mũi tên bật
			var diamond := PackedVector2Array([
				Vector2(0,-11), Vector2(8,0), Vector2(0,11), Vector2(-8,0),
			])
			draw_colored_polygon(diamond, cb)
			# Mũi tên trái
			draw_polyline(PackedVector2Array([
				Vector2(-5,-4), Vector2(-10,0), Vector2(-5,4)
			]), Color(1,1,1, p * 0.9), 1.8)
			# Mũi tên phải
			draw_polyline(PackedVector2Array([
				Vector2(5,-4), Vector2(10,0), Vector2(5,4)
			]), Color(1,1,1, p * 0.9), 1.8)

		6:  # UPGRADE — Mũi tên lên
			var arrow := PackedVector2Array([
				Vector2(0,-13), Vector2(8,-3),  Vector2(4,-3),
				Vector2(4,10),  Vector2(-4,10), Vector2(-4,-3), Vector2(-8,-3),
			])
			draw_colored_polygon(arrow, cb)
			draw_polyline(PackedVector2Array([
				Vector2(0,-13), Vector2(8,-3), Vector2(4,-3), Vector2(4,10),
				Vector2(-4,10), Vector2(-4,-3), Vector2(-8,-3), Vector2(0,-13)
			]), Color(1,1,1, p * 0.55), 1.0)

func _on_body_entered(body: Node) -> void:
	if _collected: return
	if body.is_in_group("player"):
		_collected = true
		Audio.play("powerup")
		body.apply_powerup(powerup_type)
		queue_free()

func _expire() -> void:
	if not _collected:
		queue_free()
