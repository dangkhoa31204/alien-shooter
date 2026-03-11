extends Area2D
# bullet.gd — Đạn với 6 loại hiệu ứng và 5 cấp độ

enum BulletType { NORMAL, ELECTRIC, FIRE, ICE, EXPLOSIVE, RICOCHET }

const HIT_EFFECT_SCENE = preload("res://scenes/hit_effect.tscn")

# Cấp độ đạn ảnh hưởng damage, tốc độ và kích thước trực quan
var bullet_level: int = 1  # 1..5

var direction: Vector2 = Vector2.UP
var speed: float = 600.0
var damage: int = 1
var is_enemy_bullet: bool = false
var bullet_type: int = BulletType.NORMAL
var _bounce_count: int = 0
var _fx_timer: float = 0.0   # clock cho hiệu ứng pulse
var is_max_power: bool = false  # true khi bullet_level=5 VÀ extra_streams=3
var _pierced: Array = []        # danh sách enemy đã xuyên qua (NORMAL max)
var is_boss_bullet: bool = false  # đạn boss — màu & kích thước đặc trưng
# Laser visuals (set once in _apply_color, used in _draw each frame)
var _lc: Color       = Color.WHITE  # core laser colour
var _gc: Color       = Color.WHITE  # outer glow colour
var _beam_len: float = 22.0         # pixel length of bolt
var _beam_w:   float = 2.2          # core line width

var _vp: Vector2 = Vector2(1152, 720)  # cached once in _ready

@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	_vp = get_viewport_rect().size
	add_to_group("bullet")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(5.0).timeout.connect(queue_free)
	# Áp cấp độ (chỉ với đạn người chơi)
	if not is_enemy_bullet:
		damage = bullet_level
		speed  = 600.0 + (bullet_level - 1) * 50.0  # 600/650/700/750/800
		# RICOCHET: sát thương khởi đầu thấp hơn 1 bậc, giảm dần theo lần nảy
		if bullet_type == BulletType.RICOCHET:
			damage = maxi(1, bullet_level - 1)
	_apply_color()

func _apply_color() -> void:
	if not is_instance_valid(sprite): return
	sprite.visible = false  # All visuals drawn in _draw() as laser beams

	if is_enemy_bullet and not is_boss_bullet:
		_lc = Color(1.0, 0.3, 0.1) # Brighter orange-red
		_gc = Color(1.0, 0.1, 0.0)
		_beam_len = 18.0 # Longer
		_beam_w   = 3.5 # Thicker
		return

	if is_boss_bullet:
		match bullet_type:
			BulletType.FIRE:      _lc = Color(1.0, 0.08, 0.65)
			BulletType.ELECTRIC:  _lc = Color(0.95, 1.0, 0.1)
			BulletType.ICE:       _lc = Color(0.82, 0.08, 1.0)
			BulletType.EXPLOSIVE: _lc = Color(0.0, 0.92, 0.72)
			_:                    _lc = Color(1.0, 0.05, 0.18)
		_gc = Color(_lc.r * 0.5, _lc.g * 0.5, _lc.b * 0.5)
		_beam_len = 20.0
		_beam_w   = 3.5
		return

	# Player laser bolt — colour by type + level
	match bullet_type:
		BulletType.NORMAL:
			match bullet_level:
				1: _lc = Color(1.0, 1.0, 0.25)
				2: _lc = Color(1.0, 0.75, 0.0)
				3: _lc = Color(1.0, 0.40, 0.15)
				4: _lc = Color(1.0, 1.0,  1.0)
				_: _lc = Color(0.85, 0.2, 1.0)
		BulletType.ELECTRIC:  _lc = Color(0.45, 0.55, 1.0)
		BulletType.FIRE:      _lc = Color(1.0, 0.30, 0.0)
		BulletType.ICE:       _lc = Color(0.25, 0.90, 1.0)
		BulletType.EXPLOSIVE: _lc = Color(1.0, 0.65, 0.0)
		BulletType.RICOCHET:  _lc = Color(0.55, 1.0, 0.18)
		_: _lc = Color(1.0, 1.0, 0.2)
	if is_max_power:
		_lc = Color(0.0, 1.0, 1.0) if bullet_type == BulletType.NORMAL else _lc.lightened(0.35)
	_gc = Color(_lc.r * 0.45, _lc.g * 0.45, _lc.b * 0.45)
	var lv_s := 1.0 + float(bullet_level - 1) * 0.12
	if is_max_power: lv_s *= 1.15
	_beam_len = minf((10.0 + float(bullet_level) * 3.5) * lv_s, 30.0)  # cap: tail never reaches plane
	_beam_w   = (2.4 + float(bullet_level) * 0.36) * lv_s

func _physics_process(delta: float) -> void:
	_fx_timer += delta
	position += direction * speed * delta
	queue_redraw()

	# Contra Mode: Ground collision fallback for hilly terrain
	var main = get_tree().current_scene
	if main and main.name == "ContraMain" and main.has_method("_get_ground_y") and main.current_stage != 2:
		var gy = main._get_ground_y(global_position.x)
		if global_position.y >= gy - 5.0:
			_spawn_hit_effect(global_position)
			queue_free()
			return

	if bullet_type == BulletType.RICOCHET and (_bounce_count < 4 or is_max_power):
		var bounced := false
		if position.x < 0.0:
			position.x = 0.0; direction.x = abs(direction.x); bounced = true
		elif position.x > _vp.x:
			position.x = _vp.x; direction.x = -abs(direction.x); bounced = true
		if position.y < 0.0:
			position.y = 0.0; direction.y = abs(direction.y); bounced = true
		if bounced:
			_bounce_count += 1
			damage = maxi(1, damage - 1)   # mỗi lần nảy giảm 1 sát thương
			if is_max_power: _spawn_ricochet_clone()
		if position.y > _vp.y + 60.0: queue_free()
	else:
		# Trong mode màn hình ngang (Contra), đạn có thể bay ra ngoài viewport mặc định của Main.
		# Chúng ta chỉ queue_free nếu đạn thực sự bay quá xa khỏi tầm nhìn hoặc hết thời gian (5s timer có sẵn).
		var is_scrolling = get_tree().current_scene.name == "ContraMain"
		if not is_scrolling:
			if position.y < -60.0 or position.y > _vp.y + 60.0: queue_free()
			if position.x < -60.0 or position.x > _vp.x + 60.0: queue_free()

func _draw() -> void:
	# Star-Wars laser bolt: 3 draw_line + 1 draw_circle — very cheap
	var tip  := Vector2.ZERO
	var tail := -direction * _beam_len
	if is_enemy_bullet and not is_boss_bullet:
		# Enemy: Premium bright pulsing orange blast
		var p := 0.8 + 0.2 * sin(_fx_timer * 15.0)
		draw_line(tip, tail, Color(1.0, 0.1, 0.0, 0.4 * p), _beam_w * 4.0) # Wide glow
		draw_line(tip, tail, Color(1.0, 0.4, 0.1, 0.9 * p), _beam_w)       # Core
		draw_circle(tip, _beam_w * 1.2, Color(1.0, 0.9, 0.4, 1.0))        # Bright tip
		return
	if is_boss_bullet:
		# Boss: wide pulsing bolt
		var p := 0.75 + 0.25 * sin(_fx_timer * 10.0)
		draw_line(tip, tail, Color(_gc.r, _gc.g, _gc.b, 0.30 * p), _beam_w * 4.0)
		draw_line(tip, tail, Color(_lc.r, _lc.g, _lc.b, 0.90 * p), _beam_w)
		draw_line(tip, tail * 0.6, Color(1.0, 1.0, 1.0, 0.70 * p), _beam_w * 0.35)
		draw_circle(tip, _beam_w * 1.4, Color(1.0, 1.0, 1.0, 0.90 * p))
		return
	# Player: bright coloured laser bolt with stronger glow
	var flicker := 1.0
	if bullet_type == BulletType.ELECTRIC:
		flicker = 0.7 + 0.3 * float(int(_fx_timer * 22.0) % 2)
	elif bullet_type == BulletType.RICOCHET:
		var h := fmod(_fx_timer * 0.6, 1.0)
		_lc = Color.from_hsv(h, 0.85, 1.0)
		_gc = Color.from_hsv(h, 0.5, 0.5)
	var pulse := 0.85 + 0.15 * sin(_fx_timer * 14.0)
	draw_line(tip, tail, Color(_gc.r, _gc.g, _gc.b, 0.28 * pulse), _beam_w * 5.0)  # wide soft halo
	draw_line(tip, tail, Color(_lc.r, _lc.g, _lc.b, 0.55 * pulse), _beam_w * 2.4)  # mid glow
	draw_line(tip, tail, Color(_lc.r, _lc.g, _lc.b, 0.96 * flicker), _beam_w)       # core
	draw_line(tip, tail * 0.5, Color(1.0, 1.0, 1.0, 0.82 * flicker), _beam_w * 0.38) # white centre
	draw_circle(tip, _beam_w * 1.6, Color(_lc.r, _lc.g, _lc.b, 0.70 * pulse))        # colour flare
	draw_circle(tip, _beam_w * 0.85, Color(1.0, 1.0, 1.0, 0.95 * flicker))            # bright tip

func _on_body_entered(body: Node) -> void:
	if is_enemy_bullet:
		if body.is_in_group("player"):
			body.take_damage(damage)
			queue_free()
	else:
		if body.is_in_group("enemy") or body is StaticBody2D:
			if body not in _pierced:
				if body.has_method("take_damage"):
					body.take_damage(damage)
				_apply_special(body)
				_spawn_hit_effect(global_position)
			if is_max_power and bullet_type == BulletType.NORMAL:
				# Xuyên qua — không hủy, đánh dấu để không hit lại
				if body not in _pierced: _pierced.append(body)
			elif bullet_type != BulletType.RICOCHET:
				queue_free()

func _spawn_hit_effect(pos: Vector2) -> void:
	var etype: int = 0
	match bullet_type:
		BulletType.ELECTRIC:  etype = 1
		BulletType.FIRE:      etype = 2
		BulletType.ICE:       etype = 3
		BulletType.EXPLOSIVE: etype = 4
		_: return   # NORMAL / RICOCHET — không cần hiệu ứng
	var fx = HIT_EFFECT_SCENE.instantiate()
	fx.effect_type = etype
	fx.global_position = pos
	var container := get_tree().get_root().get_node_or_null("Main/BulletContainer")
	if container:
		container.add_child(fx)

func _on_area_entered(area: Area2D) -> void:
	if is_enemy_bullet: return
	if area.is_in_group("asteroid"):
		area.take_damage(damage)
		if bullet_type != BulletType.RICOCHET:
			queue_free()

func _apply_special(target: Node) -> void:
	match bullet_type:
		BulletType.ELECTRIC:
			var enemies := get_tree().get_nodes_in_group("enemy")
			var chain_range := 160.0 + bullet_level * 20.0
			var candidates: Array = []
			for e in enemies:
				if e == target or not is_instance_valid(e): continue
				var d: float = (e as Node2D).global_position.distance_to((target as Node2D).global_position)
				if d < chain_range:
					candidates.append({"node": e, "dist": d})
			candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])
			if is_max_power:
				# MAX: sét bão — đánh TẤT CẢ enemy trong tầm, sát thương tối đa
				for c in candidates:
					c["node"].take_damage(damage)
					_spawn_hit_effect((c["node"] as Node2D).global_position)
			else:
				var chain_hits := mini(bullet_level, candidates.size())
				for ci in range(chain_hits):
					candidates[ci]["node"].take_damage(maxi(1, bullet_level - 1))
		BulletType.FIRE:
			if is_max_power:
				# MAX: lửa địa ngục — burn mạnh ×2 + nổ nhiệt AoE 80px
				if target.has_method("apply_burn"): target.apply_burn(2)
				var origin: Vector2 = (target as Node2D).global_position
				for e in get_tree().get_nodes_in_group("enemy"):
					if e == target or not is_instance_valid(e): continue
					if (e as Node2D).global_position.distance_to(origin) < 80.0:
						if e.has_method("apply_burn"): e.apply_burn(1)
			else:
				if target.has_method("apply_burn"): target.apply_burn()
		BulletType.ICE:
			if is_max_power:
				# MAX: đóng băng sâu — đóng băng hoàn toàn 2.5 giây
				if target.has_method("apply_freeze"): target.apply_freeze(2.5)
			else:
				if target.has_method("apply_freeze"): target.apply_freeze()
		BulletType.EXPLOSIVE:
			var origin: Vector2 = (target as Node2D).global_position
			var blast_radius := 110.0 + bullet_level * 15.0
			var blast_dmg := 1 + bullet_level
			if is_max_power:
				# MAX: mega blast — bán kính ×2.5, sát thương ×2
				blast_radius *= 2.5
				blast_dmg    *= 2
				if target.has_method("take_damage"): target.take_damage(blast_dmg)  # extra critical hit trực tiếp
			for e in get_tree().get_nodes_in_group("enemy"):
				if e == target or not is_instance_valid(e): continue
				if (e as Node2D).global_position.distance_to(origin) < blast_radius:
					e.take_damage(blast_dmg)
					if is_max_power: _spawn_hit_effect((e as Node2D).global_position)

func _spawn_ricochet_clone() -> void:
	var c = load("res://scenes/bullet.tscn").instantiate()
	c.global_position = global_position
	c.direction       = direction.rotated(randf_range(PI * 0.4, PI * 0.7) * (1.0 if randf() > 0.5 else -1.0))
	c.bullet_type     = BulletType.RICOCHET
	c.bullet_level    = bullet_level
	c.is_max_power    = false   # clone không tạo thêm clone
	c.damage          = damage
	c.is_enemy_bullet = false
	var container := get_tree().get_root().get_node_or_null("Main/BulletContainer")
	if container: container.add_child(c)
