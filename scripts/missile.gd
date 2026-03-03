extends Area2D
# missile.gd — Tên lửa theo dõi enemy, nổ tung diện rộng khi chạm

const HIT_EFFECT_SCENE = preload("res://scenes/hit_effect.tscn")
const AoE_RADIUS: float  = 140.0
const SPEED:      float  = 260.0
const DAMAGE:     int    = 18
const TURN_SPEED: float  = 3.5

var _dir:     Vector2 = Vector2.UP
var _target:  Node2D = null
var _spin:    float  = 0.0
var _trail:   Array  = []        # vết đạn
const TRAIL_LEN: int = 8

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_visuals()
	_find_target()

func _build_visuals() -> void:
	var poly := Polygon2D.new()
	var pv := PackedVector2Array()
	for v in [Vector2(0,-10),Vector2(4,-2),Vector2(3,8),Vector2(0,12),Vector2(-3,8),Vector2(-4,-2)]:
		pv.append(v)
	poly.polygon = pv
	poly.color   = Color(1.0, 0.35, 0.0)
	poly.name    = "Body"
	add_child(poly)
	# Đầu đạn sáng
	var tip := Polygon2D.new()
	var tv := PackedVector2Array()
	for v in [Vector2(0,-14),Vector2(3,-8),Vector2(0,-6),Vector2(-3,-8)]: tv.append(v)
	tip.polygon = tv; tip.color = Color(1.0, 0.9, 0.4)
	add_child(tip)
	z_index = 4

func _find_target() -> void:
	var best: Node2D = null
	var bd  := INF
	for n in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(n): continue
		var d := global_position.distance_squared_to((n as Node2D).global_position)
		if d < bd: bd = d; best = n as Node2D
	_target = best

func _physics_process(delta: float) -> void:
	_spin += delta * 6.0
	# Tìm lại mục tiêu nếu mục tiêu cũ đã chết
	if _target == null or not is_instance_valid(_target):
		_find_target()

	if _target != null and is_instance_valid(_target):
		var desired := (_target.global_position - global_position).normalized()
		_dir = _dir.rotated(
			clamp(desired.angle() - _dir.angle(), -TURN_SPEED * delta, TURN_SPEED * delta)
		)
	position += _dir * SPEED * delta
	# Xoay tất cả polygon con theo hướng bay
	for child in get_children():
		if child is Polygon2D:
			child.rotation = _dir.angle() + PI / 2.0

	# Kiểm tra va chạm gần (fallback phòng khi Area2D không bắt được)
	for n in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(n): continue
		if global_position.distance_to((n as Node2D).global_position) < 20.0:
			_explode()
			return

	# Tự huỷ khi ra ngoài màn hình
	var vp := get_viewport_rect().size
	if position.x < -60 or position.x > vp.x + 60 \
		or position.y < -60 or position.y > vp.y + 60:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"): return
	if body.is_in_group("enemy") or body.is_in_group("asteroid"):
		_explode()

func _explode() -> void:
	# Gây sát thương tất cả enemy trong AoE_RADIUS
	for n in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(n): continue
		var en := n as Node2D
		if global_position.distance_to(en.global_position) <= AoE_RADIUS:
			n.call("take_damage", DAMAGE)
	# Hiệu ứng nổ
	if is_inside_tree():
		var fx := HIT_EFFECT_SCENE.instantiate()
		fx.global_position = global_position
		fx.effect_type = 4   # EXPLOSIVE
		if has_node(".."):
			get_parent().add_child(fx)
	queue_free()
