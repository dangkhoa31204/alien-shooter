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

func _ready() -> void:
	slot = randi() % 2
	body_entered.connect(_on_body_entered)
	_build_visuals()

func _add_poly(pts: Array, col: Color) -> void:
	var poly := Polygon2D.new()
	var pv := PackedVector2Array()
	for v in pts: pv.append(v)
	poly.polygon = pv
	poly.color   = col
	add_child(poly)

# ── 0 MACHINEGUN — thân dẹt rộng + 3 nòng súng chĩa lên ─────────────────────
func _build_machinegun() -> void:
	var col := COLORS[0]
	# Thân hộp rộng
	_add_poly([
		Vector2(-13,-7), Vector2(13,-7), Vector2(15,0),
		Vector2(13, 9), Vector2(-13, 9), Vector2(-15,0)
	], col)
	# 3 nòng súng (pointing up = forward)
	for bx: float in [-6.0, 0.0, 6.0]:
		_add_poly([
			Vector2(bx-1.4,-7), Vector2(bx+1.4,-7),
			Vector2(bx+1.2,-20), Vector2(bx-1.2,-20)
		], col.lightened(0.28))
		# Đầu nòng sáng
		_add_poly([
			Vector2(bx-1.6,-20), Vector2(bx+1.6,-20), Vector2(bx,-23)
		], Color(1.0, 0.95, 0.45, 0.95))
	# Đường viền sáng trên thân
	_add_poly([
		Vector2(-10,-6), Vector2(10,-6), Vector2(12,-1),
		Vector2(10, 4), Vector2(-10, 4), Vector2(-12,-1)
	], Color(1.0, 0.88, 0.3, 0.35))

# ── 1 MISSILE — thân tên lửa nhọn mũi + 2 cánh đuôi ─────────────────────────
func _build_missile() -> void:
	var col := COLORS[1]
	# Thân tên lửa
	_add_poly([
		Vector2(0,-22),
		Vector2(5,-14), Vector2(7,-4), Vector2(7, 8),
		Vector2(4, 15), Vector2(-4, 15),
		Vector2(-7, 8), Vector2(-7,-4), Vector2(-5,-14)
	], col)
	# Cánh đuôi trái
	_add_poly([Vector2(-7, 5), Vector2(-14,15), Vector2(-7,15)],
		col.darkened(0.18))
	# Cánh đuôi phải
	_add_poly([Vector2( 7, 5), Vector2( 14,15), Vector2( 7,15)],
		col.darkened(0.18))
	# Mũi sáng
	_add_poly([Vector2(-2,-20), Vector2(2,-20), Vector2(0,-24)],
		Color(1.0, 0.72, 0.62, 0.92))
	# Cửa sổ giữa thân
	_add_poly([
		Vector2(-4,-5), Vector2(4,-5), Vector2(5, 1), Vector2(-5, 1)
	], Color(0.35, 0.82, 1.0, 0.68))
	# Đuôi phụt lửa
	_add_poly([Vector2(-3,15), Vector2(3,15), Vector2(1,20), Vector2(-1,20)],
		Color(1.0, 0.55, 0.08, 0.85))

# ── 2 BLACK HOLE — vòng hấp dẫn đồng tâm + lõi ──────────────────────────────
func _build_blackhole() -> void:
	var col := COLORS[2]   # deep blue
	# Vòng ngoài (12 đỉnh)
	var outer: Array = []
	for i in 12:
		var a := float(i)/12.0*TAU
		outer.append(Vector2(cos(a)*16.0, sin(a)*16.0))
	_add_poly(outer, col)
	# Vòng giữa (tím)
	var mid: Array = []
	for i in 10:
		var a := float(i)/10.0*TAU
		mid.append(Vector2(cos(a)*10.5, sin(a)*10.5))
	_add_poly(mid, Color(0.45, 0.0, 0.95, 0.92))
	# Lõi (sáng tím)
	var core: Array = []
	for i in 8:
		var a := float(i)/8.0*TAU
		core.append(Vector2(cos(a)*6.0, sin(a)*6.0))
	_add_poly(core, Color(0.82, 0.5, 1.0, 0.96))
	# Tâm trắng
	var dot: Array = []
	for i in 6:
		var a := float(i)/6.0*TAU
		dot.append(Vector2(cos(a)*2.5, sin(a)*2.5))
	_add_poly(dot, Color.WHITE)

func _build_visuals() -> void:
	match weapon_type:
		0: _build_machinegun()
		1: _build_missile()
		2: _build_blackhole()

	# Chữ loại súng nhỏ
	_label = Label.new()
	_label.text = NAMES[weapon_type]
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.position = Vector2(-20, 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(40, 14)
	add_child(_label)

	# Collision shape
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	cs.shape = shape
	add_child(cs)

	z_index = 5

func _physics_process(delta: float) -> void:
	_pulse += delta * 3.0
	position.y += FALL_SPEED * delta
	# Nhấp nháy toàn bộ node
	var brightness := 0.72 + sin(_pulse) * 0.28
	modulate = Color(brightness, brightness, brightness, 1.0)
	# Tự huỷ khi ra ngoài màn hình
	var vp := get_viewport_rect().size
	if position.y > vp.y + 40.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		Audio.play("special_collect")
		(body as Node).call("collect_special", weapon_type, slot)
		queue_free()
