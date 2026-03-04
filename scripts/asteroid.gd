extends Area2D
# asteroid.gd — Thiên thạch / Tên lửa phòng không (Aerial Warfare pack)

signal died

# 0=nhỏ, 1=vừa, 2=to
var size_tier:  int   = 1
var speed:      float = 180.0
var direction:  Vector2 = Vector2.DOWN
var hp:         int   = 3
var _rot_speed: float = 1.2
var _is_dying:  bool  = false
var _scale_mul: float = 1.0

# ── Aerial Warfare missile mode ──────────────────────────────────────────────
var _is_missile: bool  = false   # true khi Aerial Warfare pack đang active
var _fx_timer:  float  = 0.0    # clock hiệu ứng engine glow
var _smoke_trail: Array[Vector2] = []  # vết khói phía sau
const _TRAIL_LEN: int = 18
# Các node con tên lửa (để flash khi bị bắn)
var _m_body: Polygon2D = null
var _m_cone: Polygon2D = null
var _m_fin_l: Polygon2D = null
var _m_fin_r: Polygon2D = null

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
	# Kiểm tra Aerial Warfare pack → chuyển sang tên lửa AA
	if ThemePack.get_pack().get("shape_mode", "") == "aerial_warfare":
		_is_missile = true
		sprite.visible = false       # ẩn polygon thiên thạch
		_rot_speed     = 0.0         # tên lửa không xoay loạn
		# Tìm player → tính hướng bay ban đầu
		var player := get_tree().get_first_node_in_group("player")
		if player:
			direction = (player.global_position - global_position).normalized()
		# Xoay node để đầu tên lửa hướng về phía bay
		rotation = direction.angle() + PI * 0.5
		# HP và speed theo tier
		hp    = [1, 2, 3][clampi(size_tier, 0, 2)]
		speed = speed * randf_range(1.1, 1.6)   # nhanh hơn thiên thạch
		# Scale tăng theo tier để dễ nhìn
		var ms: float = [1.0, 1.4, 1.8][clampi(size_tier, 0, 2)]
		scale = Vector2(ms, ms)
		# ── Xây dựng hiệnh vực tên lửa bằng Polygon2D con ──
		_build_missile_visuals()
		return
	# ── Chế độ thiên thạch bình thường ──────────────────────────────────
	var s: float = BASE_SCALE[size_tier] * _scale_mul
	scale = Vector2(s, s)
	if hp == 3:
		hp = BASE_HP[size_tier]
	get_tree().create_timer(16.0).timeout.connect(_expire)

func _build_missile_visuals() -> void:
	var body_col := Color(0.30, 0.38, 0.16)   # olive drab
	# Thân chính (dẻt dài)
	_m_body = Polygon2D.new()
	_m_body.polygon = PackedVector2Array([
		Vector2(-5.0, -22.0), Vector2(5.0, -22.0),
		Vector2(5.0,  14.0),  Vector2(-5.0, 14.0)
	])
	_m_body.color = body_col
	_m_body.z_index = 1
	add_child(_m_body)
	# Mũi nhọn (đỏ)
	_m_cone = Polygon2D.new()
	_m_cone.polygon = PackedVector2Array([
		Vector2(-5.0, -22.0), Vector2(5.0, -22.0), Vector2(0.0, -36.0)
	])
	_m_cone.color = Color(0.68, 0.18, 0.10)
	_m_cone.z_index = 2
	add_child(_m_cone)
	# Cánh đuôi trái
	_m_fin_l = Polygon2D.new()
	_m_fin_l.polygon = PackedVector2Array([
		Vector2(-5.0, 2.0), Vector2(-15.0, 16.0), Vector2(-5.0, 16.0)
	])
	_m_fin_l.color = body_col
	_m_fin_l.z_index = 1
	add_child(_m_fin_l)
	# Cánh đuôi phải
	_m_fin_r = Polygon2D.new()
	_m_fin_r.polygon = PackedVector2Array([
		Vector2(5.0, 2.0), Vector2(15.0, 16.0), Vector2(5.0, 16.0)
	])
	_m_fin_r.color = body_col
	_m_fin_r.z_index = 1
	add_child(_m_fin_r)

func _physics_process(delta: float) -> void:
	_fx_timer += delta
	position += direction * speed * delta
	if _is_missile:
		# Homing — lái dần về phía player (tốc độ giữ nguyên)
		var _player := get_tree().get_first_node_in_group("player")
		if _player and is_instance_valid(_player):
			var to_p: Vector2 = ((_player as Node2D).global_position - global_position).normalized()
			direction = direction.lerp(to_p, 3.5 * delta).normalized()
			rotation = direction.angle() + PI * 0.5
		# Ghi vết khói mỗi frame
		_smoke_trail.push_back(global_position)
		if _smoke_trail.size() > _TRAIL_LEN:
			_smoke_trail.pop_front()
		queue_redraw()
		var vp := get_viewport_rect().size
		if (position.y > vp.y + 80.0 or position.y < -80.0
				or position.x < -80.0 or position.x > vp.x + 80.0):
			_expire()
		return
	rotation  += _rot_speed * delta
	if position.y > get_viewport_rect().size.y + 80.0:
		_expire()

# ── Vẽ tên lửa AA — CHỈ khói trail + exhaust glow (thân dùng Polygon2D con) ──
func _draw() -> void:
	if not _is_missile: return
	# Vết khói — vòng tròn mờ theo local trail
	if _smoke_trail.size() >= 2:
		for i in range(_smoke_trail.size()):
			var t := float(i) / float(_TRAIL_LEN)
			var lp := to_local(_smoke_trail[i])
			draw_circle(lp, lerp(6.0, 1.5, t),
				Color(0.55, 0.50, 0.46, (1.0 - t) * 0.38))
	# ── Engine glow phía đuôi (nhấp nháy) ──
	var pulse := 0.75 + 0.25 * sin(_fx_timer * 18.0)
	draw_circle(Vector2(0.0, 15.0), 7.0 * pulse, Color(1.0, 0.45, 0.05, 0.70 * pulse))
	draw_circle(Vector2(0.0, 15.0), 3.5,         Color(1.0, 0.88, 0.3,  0.92))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var dmg := 1 if size_tier == 0 else (2 if size_tier == 1 else 3)
		if _is_missile: dmg = 2   # tên lửa luôn gây 2 damage
		body.take_damage(dmg)
		_destroy()

func take_damage(dmg: int = 1) -> void:
	if _is_dying: return
	hp -= dmg
	if hp <= 0:
		_destroy()
		return
	Audio.play("asteroid_hit", -5.0)
	if _is_missile:
		# Flash th\u00e2n t\u00ean l\u1eeda
		for n: Polygon2D in [_m_body, _m_cone, _m_fin_l, _m_fin_r]:
			if is_instance_valid(n): n.modulate = Color(2.0, 2.0, 2.0)
		await get_tree().create_timer(0.07).timeout
		for n: Polygon2D in [_m_body, _m_cone, _m_fin_l, _m_fin_r]:
			if is_instance_valid(n): n.modulate = Color.WHITE
	elif is_instance_valid(sprite):
		sprite.color = Color.WHITE
		await get_tree().create_timer(0.07).timeout
		if is_instance_valid(self) and is_instance_valid(sprite):
			sprite.color = _base_color()

func _destroy() -> void:
	if _is_dying: return
	_is_dying = true
	if _is_missile:
		_missile_explode()
		emit_signal("died")
		queue_free()
		return
	_spawn_debris()
	_split()
	_try_drop_powerup()
	emit_signal("died")
	queue_free()

func _missile_explode() -> void:
	# Rung màn hình
	var main := get_tree().get_root().get_node_or_null("Main")
	if main and main.has_method("screen_shake"): main.screen_shake(10.0, 0.28)
	Audio.play("explosion", -4.0)
	# Mảnh nổ văng ra tứ phía
	var container := get_tree().get_root().get_node_or_null("Main/BulletContainer")
	if container == null: return
	for i in range(12):
		var node := Node2D.new()
		var p := Polygon2D.new()
		var sz := randf_range(3.0, 7.0)
		p.polygon = PackedVector2Array([
			Vector2(-sz, -sz * 0.5), Vector2(sz * 0.4, -sz),
			Vector2(sz, sz * 0.4),   Vector2(-sz * 0.3, sz)
		])
		var fire_mix := randf()
		p.color = Color(randf_range(0.7,1.0), randf_range(0.2,0.6)*fire_mix, 0.0)
		node.add_child(p)
		var ang := float(i) / 12.0 * TAU + randf_range(-0.3, 0.3)
		var spd := randf_range(80.0, 240.0)
		node.set_meta("vel", Vector2(cos(ang), sin(ang)) * spd)
		node.set_meta("rot_spd", randf_range(-5.0, 5.0))
		node.set_meta("life", randf_range(0.35, 0.65))
		node.global_position = global_position
		node.set_script(_debris_script())
		container.add_child(node)
	# Vòng lửa flash
	var flash := Node2D.new()
	var script := GDScript.new()
	script.source_code = """extends Node2D
var _t: float = 0.0
func _process(d):
\t_t += d * 5.0
\tif _t >= 1.0: queue_free()
\telse: queue_redraw()
func _draw():
\tvar r = lerp(4.0, 42.0, _t)
\tdraw_circle(Vector2.ZERO, r, Color(1.0, lerp(0.8,0.1,_t), 0.0, (1.0-_t)*0.72))
"""
	script.reload()
	flash.set_script(script)
	flash.global_position = global_position
	container.add_child(flash)

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
	if _is_missile: return      # tên lửa không tách mảnh
	if size_tier == 0: return
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
