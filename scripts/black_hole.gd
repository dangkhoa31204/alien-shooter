extends Node2D
# black_hole.gd — Hố đen hút enemy trong 220px vào tâm suốt 4.5 giây rồi sụp đổ

const RADIUS:       float = 240.0
const PULL_FORCE:   float = 500.0
const DURATION:     float = 6.0
const COLLAPSE_DMG: int   = 15

var _t:         float = 0.0
var _collapsing: bool = false
var _col_t:     float = 0.0

func _ready() -> void:
	z_index = 3

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

	if not _collapsing:
		# Hút tất cả enemy
		for n in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(n): continue
			var en := n as Node2D
			var diff := global_position - en.global_position
			if diff.length() < RADIUS:
				var force := diff.normalized() * PULL_FORCE * delta
				en.position += force

		if _t >= DURATION:
			_collapsing = true
			_col_t = 0.0
	else:
		_col_t += delta
		# Sụp đổ: gây damage 1 lần rồi biến mất
		if _col_t < 0.05:
			for n in get_tree().get_nodes_in_group("enemy"):
				if not is_instance_valid(n): continue
				if global_position.distance_to((n as Node2D).global_position) < RADIUS * 0.6:
					n.call("take_damage", COLLAPSE_DMG)
		if _col_t >= 0.5:
			queue_free()

func _draw() -> void:
	var progress: float = clamp(_t / DURATION, 0.0, 1.0)

	if _collapsing:
		# Thu nhỏ dần rồi vỡ tung
		var r := RADIUS * (1.0 - _col_t / 0.5)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64,
			Color(0.5, 0.0, 1.0, 1.0 - _col_t / 0.5), 4.0)
		draw_circle(Vector2.ZERO, r * 0.25, Color(1.0, 0.5, 1.0, 1.0 - _col_t / 0.5))
		return

	# Vòng ngoài xanh đậm
	var outer_r := RADIUS * (0.5 + sin(_t * 2.0) * 0.05)
	draw_arc(Vector2.ZERO, outer_r, 0.0, TAU, 72,
		Color(0.15, 0.0, 0.6, 0.35), 2.0)

	# Vòng giữa nhấp nháy
	var mid_r := 55.0 + sin(_t * 5.0) * 8.0
	draw_arc(Vector2.ZERO, mid_r, 0.0, TAU, 48,
		Color(0.5, 0.0, 1.0, 0.7 + sin(_t * 7.0) * 0.2), 3.5)

	# Lõi tối
	draw_circle(Vector2.ZERO, 22.0 + sin(_t * 8.0) * 3.0,
		Color(0.02, 0.0, 0.1, 0.95))

	# Tia hút xoắn ốc (8 tia)
	for i in range(8):
		var angle := TAU * float(i) / 8.0 + _t * 2.5
		var from_r := mid_r + 10.0
		var to_r   := 24.0
		draw_line(
			Vector2(cos(angle) * from_r, sin(angle) * from_r),
			Vector2(cos(angle) * to_r,   sin(angle) * to_r),
			Color(0.6, 0.1, 1.0, 0.6), 1.5
		)

	# Thanh tiến trình thời gian còn lại (vòng cung dưới cùng)
	var remain: float = 1.0 - progress
	draw_arc(Vector2.ZERO, outer_r + 8.0, -PI / 2.0, -PI / 2.0 + TAU * remain, 64,
		Color(0.8, 0.3, 1.0, 0.8), 2.0)
