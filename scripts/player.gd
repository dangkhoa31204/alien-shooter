extends CharacterBody2D
# player.gd

const BULLET_SCENE         = preload("res://scenes/bullet.tscn")
const MISSILE_SCENE        = preload("res://scenes/missile.tscn")
const BLACK_HOLE_SCENE     = preload("res://scenes/black_hole.tscn")

const SPEED: float = 300.0
const FIRE_RATE: float = 0.2

# Passive theo skin (thay đổi trong _apply_skin)
var _move_speed:       float = SPEED
var _fire_rate:        float = FIRE_RATE
var skin_damage_bonus: int   = 0
var skin_speed_bonus:  float = 0.0   # cộng vào bullet.speed sau add_child
var overflow_damage:   int   = 0     # tích luĩ khi nhặn powerup lúc đã max
var _skin_id:          int   = 0     # skin đang dùng
# Blue Classic: khiën (tái nạp sau 6s không bị thương)
var _skin_shield:        bool  = false
var _shield_regen_timer: float = 0.0

# ── SKILL (J) ──────────────────────────────────────────────────────
const SKILL_COOLDOWNS: Array = [18.0, 13.0, 14.0, 17.0, 21.0]  # theo sid
const SKILL_DURATIONS: Array = [ 8.0,  5.0,  5.0, 10.0, 10.0]
var _skill_cd:           float = 0.0   # thời gian chờ trước lần kế
var _skill_active:       bool  = false
var _skill_timer:        float = 0.0   # thời gian còn lại của skill
# lưu giá trị trước khi dùng skill để khôi phục
var _saved_fire_rate:    float = 0.0
var _saved_move_speed:   float = 0.0
var _saved_dmg_bonus:    int   = 0
var _saved_bullet_level: int   = 0
var _saved_streams:      int   = 0
var _saved_max_hp:       int   = 0
var _blink_cd:           float = 0.0   # Neon Dart: cooldown giữa mỗi lần blink

var hp: int = 5
var _max_hp: int = 5   # cập nhật theo skin
var can_shoot: bool = true
var _is_dead: bool = false

# ── POWER-UP STATE ─────────────────────────────────────────────────────────────
# Powerup types: 0=EXTRA_STREAM, 1=ELECTRIC, 2=FIRE, 3=ICE, 4=EXPLOSIVE, 5=RICOCHET
var extra_streams: int = 0   # số luồng thêm mỗi bên (tối đa 5)
var bullet_type:   int = 0   # loại đạn hiện tại (theo BulletType enum trong bullet.gd)
var bullet_level:  int = 1   # cấp độ đạn (1–10), tăng qua powerup UPGRADE

# ── VŨ KHÍ ĐẶC BIỆT (pod trái/phải, K = trái, L = phải) ───────────────────────
var sw_left:  int = -1
var sw_right: int = -1
var _sw_cd_left:  float = 0.0
var _sw_cd_right: float = 0.0
var sw_left_ammo:  int = 0
var sw_right_ammo: int = 0
const SW_CD: Array      = [0.10, 2.5, 15.0]   # machinegun/missile/black_hole
const SW_AMMO: Array    = [12,   3,   2     ]  # số lần dùng tối đa
const SW_NAMES: Array   = ["MACHINEGUN", "MISSILE", "BLACK HOLE"]
# Màu pod theo weapon_type
const SW_POD_COLORS: Array = [
	Color(1.0, 0.6, 0.0),   # MACHINEGUN — cam
	Color(1.0, 0.15, 0.1),  # MISSILE    — đỏ
	Color(0.2, 0.0, 0.9),   # BLACK HOLE — xanh đậm
]
var _pod_left_node:  Node2D = null
var _pod_right_node: Node2D = null
var _pod_label_left:  Label = null
var _pod_label_right: Label = null

# ── ANIMATION STATE ────────────────────────────────────────────────
var _exhaust_groups:  Array = []      # [[outer,mid,inner],...] per engine
var _blink_glow_tween: Tween = null  # Neon Dart skill glow
var _engine_phase: float = 0.0       # pha sáng engine (0..2PI)
var _hover_phase:  float = 0.0       # pha hover nhẹ lên xuống
var _bank:         float = 1.0       # 2.5D banking scale.x (1.0=flat, 0.72=max tilt)

const SKIN_POLYGONS: Array = [
	# 0 Blue Classic — tiêm kích cân đối, cánh tam giác lùi
	[Vector2(0,-24), Vector2(4,-18), Vector2(7,-10), Vector2(14,-4),
	 Vector2(18,4),  Vector2(14,12), Vector2(8,18),  Vector2(5,22),
	 Vector2(-5,22), Vector2(-8,18), Vector2(-14,12),Vector2(-18,4),
	 Vector2(-14,-4),Vector2(-7,-10),Vector2(-4,-18)],
	# 1 Red Fighter — interceptor tấn công, cánh delta + canard
	[Vector2(0,-26), Vector2(4,-16), Vector2(10,-12),Vector2(7,-7),
	 Vector2(6,-2),  Vector2(22,2),  Vector2(20,12), Vector2(12,20),
	 Vector2(6,24),  Vector2(3,26),  Vector2(-3,26), Vector2(-6,24),
	 Vector2(-12,20),Vector2(-20,12),Vector2(-22,2), Vector2(-6,-2),
	 Vector2(-7,-7), Vector2(-10,-12),Vector2(-4,-16)],
	# 2 Gold Cruiser — tuần dương hạm rộng, vai vuông
	[Vector2(0,-20), Vector2(5,-14), Vector2(10,-10),Vector2(18,-6),
	 Vector2(22,0),  Vector2(24,6),  Vector2(20,14), Vector2(14,20),
	 Vector2(8,24),  Vector2(4,26),  Vector2(-4,26), Vector2(-8,24),
	 Vector2(-14,20),Vector2(-20,14),Vector2(-24,6), Vector2(-22,0),
	 Vector2(-18,-6),Vector2(-10,-10),Vector2(-5,-14)],
	# 3 Neon Dart — phi thuyền kim tiêm, cánh delta mỏng
	[Vector2(0,-28), Vector2(2,-20), Vector2(5,-8),  Vector2(16,4),
	 Vector2(12,14), Vector2(4,18),  Vector2(3,24),  Vector2(1,26),
	 Vector2(0,28),  Vector2(-1,26), Vector2(-3,24), Vector2(-4,18),
	 Vector2(-12,14),Vector2(-16,4), Vector2(-5,-8), Vector2(-2,-20)],
	# 4 Purple Heavy — thiết giáp hạm, giáp dày đa giác
	[Vector2(0,-22), Vector2(5,-18), Vector2(10,-14),Vector2(14,-10),
	 Vector2(20,-4), Vector2(24,4),  Vector2(22,12), Vector2(18,18),
	 Vector2(12,22), Vector2(8,24),  Vector2(4,26),  Vector2(-4,26),
	 Vector2(-8,24), Vector2(-12,22),Vector2(-18,18),Vector2(-22,12),
	 Vector2(-24,4), Vector2(-20,-4),Vector2(-14,-10),Vector2(-10,-14),
	 Vector2(-5,-18)],
]

@onready var gun_point: Marker2D = $GunPoint
@onready var shoot_timer: Timer = $ShootTimer
@onready var sprite: Polygon2D = $Sprite

var _aim_target: Node2D = null   # boss hoặc enemy gần nhất để ngắm
var _dr: Node2D = null           # container cho các chi tiết màu

# ── DETAIL POLYGON HELPERS ────────────────────────────────────────────────
func _clear_dr() -> void:
	if is_instance_valid(_dr): _dr.queue_free()
	_dr = Node2D.new(); _dr.z_index = 1
	sprite.add_child(_dr)

func _dp(pts: Array, col: Color) -> void:
	var p2d := Polygon2D.new()
	var pv := PackedVector2Array()
	for v in pts: pv.append(v)
	p2d.polygon = pv; p2d.color = col
	_dr.add_child(p2d)

func _ready() -> void:
	add_to_group("player")
	shoot_timer.wait_time = FIRE_RATE
	shoot_timer.one_shot = true
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	# Áp loadout từ PlayerData (autoload)
	_apply_skin()
	bullet_type  = PlayerData.get_starter_bullet_type()
	bullet_level = PlayerData.get_starter_bullet_level()
	await get_tree().process_frame
	_notify_weapon()
	_spawn_engine_exhaust()

func _apply_skin() -> void:
	if not is_instance_valid(sprite): return
	var sid: int = PlayerData.equipped_skin
	var pts: Array = SKIN_POLYGONS[sid]
	# Gói Aerial Warfare ghi đè hình dạng phi thuyền (giữ nguyên stats của skin đã chọn)
	var theme_pts: Array = ThemePack.theme_player_poly(sid)
	if theme_pts.size() > 0:
		pts = theme_pts
	var packed := PackedVector2Array()
	for p in pts: packed.append(p)
	sprite.polygon = packed
	sprite.color = _get_sprite_color()
	# ── Passive theo skin ────────────────────────────────────────
	_move_speed       = SPEED
	_fire_rate        = FIRE_RATE
	skin_damage_bonus = 0
	skin_speed_bonus  = 0.0
	_skin_shield      = false
	_shield_regen_timer = 0.0
	_max_hp = 5
	hp    = 5
	_skin_id = sid
	match sid:
		0:  # Blue Classic — khiën tái nạp: mỗi 6s không bị thương → hấp thụ 1 đòn
			_skin_shield = true
			_shield_regen_timer = 0.0
		1:  # Red Fighter — bắn rất nhanh, đạn rất nhanh; bị đánh chỉ mất level đạn (giữ streams)
			_fire_rate       = 0.11
			skin_speed_bonus = 160.0
		2:  # Gold Cruiser — bắt đầu 2 luồng miễn phí, bị đánh giữ streams (chỉ giảm level)
			extra_streams = maxi(extra_streams, 2)
			_fire_rate    = 0.17
		3:  # Neon Dart — di chuyển nhanh, bắn vừa, 30% né tránh đòn
			_move_speed = SPEED * 1.38
			_fire_rate  = 0.13
		4:  # Purple Heavy — 7HP, sát thương +1, LV đạn +1, mỗi đòn giảm 1 sát thương (min 1)
			skin_damage_bonus = 1
			bullet_level = mini(bullet_level + 1, 10)
			hp = 7
			_max_hp = 7
	shoot_timer.wait_time = _fire_rate
	# Cập nhật UI tim theo skin
	var _main := get_tree().current_scene
	if _main and _main.has_method("set_max_hp"):
		_main.set_max_hp(_max_hp)
		_main.refresh_hp(hp, _max_hp)
	_add_skin_details(sid)

# Màu thật của sprite: trả về màu camo quân sự khi Aerial Warfare theme đang bật
func _get_sprite_color() -> Color:
	if ThemePack.get_pack().get("shape_mode", "") == "aerial_warfare":
		var vcols: Array = ThemePack.get_pack().get("player_colors", [])
		if _skin_id < vcols.size(): return vcols[_skin_id]
		return Color(0.20, 0.28, 0.12)
	return PlayerData.get_skin_color()

func _add_skin_details(sid: int) -> void:
	_clear_dr()
	match sid:
		0: # ── Blue Classic ─────────────────────────────────────────
			# Khung cockpit
			_dp([Vector2(-4,-17),Vector2(4,-17),Vector2(6,-11),
				 Vector2(4,-7), Vector2(-4,-7),Vector2(-6,-11)],
				Color(0.05, 0.25, 0.65))                          # khung cockpit
			# Kính cockpit (lớp trong sáng hơn)
			_dp([Vector2(-2,-16),Vector2(2,-16),Vector2(4,-12),
				 Vector2(2,-9), Vector2(-2,-9), Vector2(-4,-12)],
				Color(0.45, 0.82, 1.0, 0.75))                     # kính cockpit
			# Điểm phản quang nhỏ
			_dp([Vector2(-1,-15),Vector2(1,-15),Vector2(1.5,-12),Vector2(-1.5,-12)],
				Color(0.9, 1.0, 1.0, 0.55))                       # highlight
			# Tấm cánh trái
			_dp([Vector2(-7,-10),Vector2(-14,-4),Vector2(-16,2),Vector2(-10,2)],
				Color(0.18, 0.65, 0.9, 0.45))                     # cánh trái
			# Tấm cánh phải
			_dp([Vector2(7,-10),Vector2(14,-4),Vector2(16,2),Vector2(10,2)],
				Color(0.18, 0.65, 0.9, 0.45))                     # cánh phải
			# Đầu cánh trái (accent)
			_dp([Vector2(-14,-4),Vector2(-18,4),Vector2(-17,7),Vector2(-13,-1)],
				Color(0.5, 0.95, 1.0, 0.8))                       # tip cánh trái
			# Đầu cánh phải (accent)
			_dp([Vector2(14,-4),Vector2(18,4),Vector2(17,7),Vector2(13,-1)],
				Color(0.5, 0.95, 1.0, 0.8))                       # tip cánh phải
			# Lõi lò phản ứng trung tâm
			_dp([Vector2(-2,0),Vector2(2,0),Vector2(3,8),Vector2(-3,8)],
				Color(0.3, 0.85, 1.0, 0.38))                      # reactor
			# Bell động cơ trái
			_dp([Vector2(-7,17),Vector2(-4,17),Vector2(-4,23),Vector2(-8,23)],
				Color(0.2, 0.22, 0.3))                            # nozzle trái
			# Bell động cơ phải
			_dp([Vector2(4,17),Vector2(7,17),Vector2(8,23),Vector2(4,23)],
				Color(0.2, 0.22, 0.3))                            # nozzle phải
			# Gờ nozzle sáng
			_dp([Vector2(-8,17),Vector2(-3,17),Vector2(-3,18.5),Vector2(-8,18.5)],
				Color(0.4, 0.7, 1.0, 0.7))                        # vành nozzle trái
			_dp([Vector2(3,17),Vector2(8,17),Vector2(8,18.5),Vector2(3,18.5)],
				Color(0.4, 0.7, 1.0, 0.7))                        # vành nozzle phải
		1: # ── Red Fighter ─────────────────────────────────────────
			# Khung cockpit góc cạnh
			_dp([Vector2(-4,-20),Vector2(4,-20),Vector2(5,-14),
				 Vector2(3,-9), Vector2(-3,-9),Vector2(-5,-14)],
				Color(0.55, 0.0, 0.02))                           # khung cockpit
			# Kính cockpit đỏ
			_dp([Vector2(-2,-19),Vector2(2,-19),Vector2(4,-14),
				 Vector2(2,-10),Vector2(-2,-10),Vector2(-4,-14)],
				Color(1.0, 0.35, 0.35, 0.7))                      # kính
			# Canard phải
			_dp([Vector2(4,-16),Vector2(10,-12),Vector2(8,-8),Vector2(3,-12)],
				Color(0.85, 0.06, 0.0))                           # canard phải
			# Canard trái
			_dp([Vector2(-4,-16),Vector2(-10,-12),Vector2(-8,-8),Vector2(-3,-12)],
				Color(0.85, 0.06, 0.0))                           # canard trái
			# Cánh delta phải (đường accent)
			_dp([Vector2(6,-2),Vector2(22,2),Vector2(20,7),Vector2(5,3)],
				Color(1.0, 0.28, 0.0, 0.5))                       # cánh delta phải
			# Cánh delta trái
			_dp([Vector2(-6,-2),Vector2(-22,2),Vector2(-20,7),Vector2(-5,3)],
				Color(1.0, 0.28, 0.0, 0.5))                       # cánh delta trái
			# Đầu cánh phải (vàng cam)
			_dp([Vector2(22,2),Vector2(20,12),Vector2(18,12),Vector2(21,2)],
				Color(1.0, 0.65, 0.0, 0.9))                       # tip cánh phải
			# Đầu cánh trái
			_dp([Vector2(-22,2),Vector2(-20,12),Vector2(-18,12),Vector2(-21,2)],
				Color(1.0, 0.65, 0.0, 0.9))                       # tip cánh trái
			# Sống lưng giáp
			_dp([Vector2(-2,-7),Vector2(2,-7),Vector2(2,8),Vector2(-2,8)],
				Color(0.6, 0.04, 0.04, 0.4))                      # giáp spine
			# Bell động cơ trái
			_dp([Vector2(-8,19),Vector2(-4,19),Vector2(-3,26),Vector2(-9,26)],
				Color(0.2, 0.2, 0.25))                            # nozzle trái
			# Bell động cơ phải
			_dp([Vector2(4,19),Vector2(8,19),Vector2(9,26),Vector2(3,26)],
				Color(0.2, 0.2, 0.25))                            # nozzle phải
			# Vành nozzle
			_dp([Vector2(-9,19),Vector2(-3,19),Vector2(-3,20.5),Vector2(-9,20.5)],
				Color(1.0, 0.5, 0.1, 0.8))                        # vành trái
			_dp([Vector2(3,19),Vector2(9,19),Vector2(9,20.5),Vector2(3,20.5)],
				Color(1.0, 0.5, 0.1, 0.8))                        # vành phải
		2: # ── Gold Cruiser ───────────────────────────────────────
			# Vòm cockpit
			_dp([Vector2(-5,-13),Vector2(5,-13),Vector2(7,-7),
				 Vector2(4,-3), Vector2(-4,-3),Vector2(-7,-7)],
				Color(0.12, 0.08, 0.0))                           # khung cockpit
			# Kính vàng amber
			_dp([Vector2(-3,-12),Vector2(3,-12),Vector2(5,-7),
				 Vector2(3,-4), Vector2(-3,-4),Vector2(-5,-7)],
				Color(1.0, 0.92, 0.45, 0.7))                      # kính amber
			# Mảng vai phải
			_dp([Vector2(10,-10),Vector2(18,-6),Vector2(20,0),Vector2(12,-2)],
				Color(0.75, 0.6, 0.0, 0.48))                      # vai phải
			# Mảng vai trái
			_dp([Vector2(-10,-10),Vector2(-18,-6),Vector2(-20,0),Vector2(-12,-2)],
				Color(0.75, 0.6, 0.0, 0.48))                      # vai trái
			# Nòng súng phải
			_dp([Vector2(22,0),Vector2(26,-2),Vector2(26,2),Vector2(22,3)],
				Color(0.65, 0.52, 0.05))                          # súng phải
			# Nòng súng trái
			_dp([Vector2(-22,0),Vector2(-26,-2),Vector2(-26,2),Vector2(-22,3)],
				Color(0.65, 0.52, 0.05))                          # súng trái
			# Panel thân phải
			_dp([Vector2(3,2),Vector2(9,2),Vector2(9,14),Vector2(3,14)],
				Color(1.0, 0.88, 0.0, 0.28))                      # panel phải
			# Panel thân trái
			_dp([Vector2(-9,2),Vector2(-3,2),Vector2(-3,14),Vector2(-9,14)],
				Color(1.0, 0.88, 0.0, 0.28))                      # panel trái
			# Viền mũi
			_dp([Vector2(-3,-14),Vector2(3,-14),Vector2(5,-10),Vector2(-5,-10)],
				Color(0.8, 0.65, 0.05))                           # mũi
			# Bell động cơ trái
			_dp([Vector2(-8,21),Vector2(-4,21),Vector2(-3,26),Vector2(-9,26)],
				Color(0.28, 0.22, 0.02))                          # nozzle trái
			# Bell động cơ phải
			_dp([Vector2(4,21),Vector2(8,21),Vector2(9,26),Vector2(3,26)],
				Color(0.28, 0.22, 0.02))                          # nozzle phải
			# Vành nozzle vàng
			_dp([Vector2(-9,21),Vector2(-3,21),Vector2(-3,22.5),Vector2(-9,22.5)],
				Color(1.0, 0.85, 0.1, 0.85))                      # vành trái
			_dp([Vector2(3,21),Vector2(9,21),Vector2(9,22.5),Vector2(3,22.5)],
				Color(1.0, 0.85, 0.1, 0.85))                      # vành phải
		3: # ── Neon Dart ──────────────────────────────────────────
			# Visor cockpit mỏng
			_dp([Vector2(-2,-22),Vector2(2,-22),Vector2(3,-14),
				 Vector2(0,-10),Vector2(-3,-14)],
				Color(0.0, 0.85, 0.9))                            # visor khung
			# Kính visor sáng
			_dp([Vector2(-1,-21),Vector2(1,-21),Vector2(2,-15),
				 Vector2(0,-11),Vector2(-2,-15)],
				Color(0.5, 1.0, 1.0, 0.65))                       # visor kính
			# Sọc sống lưng
			_dp([Vector2(-1,-8),Vector2(1,-8),Vector2(1,18),Vector2(-1,18)],
				Color(0.25, 1.0, 0.9, 0.42))                      # spine
			# Cánh delta phải
			_dp([Vector2(2,-8),Vector2(16,4),Vector2(13,9),Vector2(1,0)],
				Color(0.0, 1.0, 0.85, 0.38))                      # wing phải
			# Cánh delta trái
			_dp([Vector2(-2,-8),Vector2(-16,4),Vector2(-13,9),Vector2(-1,0)],
				Color(0.0, 1.0, 0.85, 0.38))                      # wing trái
			# Tip cánh phải (neon sáng)
			_dp([Vector2(16,4),Vector2(12,14),Vector2(10,12),Vector2(15,3)],
				Color(0.0, 1.0, 0.7, 0.9))                        # tip phải
			# Tip cánh trái
			_dp([Vector2(-16,4),Vector2(-12,14),Vector2(-10,12),Vector2(-15,3)],
				Color(0.0, 1.0, 0.7, 0.9))                        # tip trái
			# Bell động cơ
			_dp([Vector2(-2,22),Vector2(2,22),Vector2(2,28),Vector2(-2,28)],
				Color(0.0, 0.45, 0.55))                           # nozzle
			# Vành nozzle cyan
			_dp([Vector2(-3,22),Vector2(3,22),Vector2(3,23.5),Vector2(-3,23.5)],
				Color(0.0, 1.0, 0.95, 0.9))                       # vành nozzle
			# Intake cạnh phải
			_dp([Vector2(4,-6),Vector2(9,-3),Vector2(9,2),Vector2(4,0)],
				Color(0.0, 0.55, 0.72, 0.72))                     # intake phải
			# Intake cạnh trái
			_dp([Vector2(-4,-6),Vector2(-9,-3),Vector2(-9,2),Vector2(-4,0)],
				Color(0.0, 0.55, 0.72, 0.72))                     # intake trái
			# Neon core stripe
			_dp([Vector2(-0.7,-18),Vector2(0.7,-18),Vector2(0.7,18),Vector2(-0.7,18)],
				Color(0.0, 1.0, 1.0, 0.95))                       # core stripe
			# Inner wing panel phải
			_dp([Vector2(3,-5),Vector2(12,2),Vector2(10,6),Vector2(2,-1)],
				Color(0.2, 0.75, 0.88, 0.22))                     # inner panel phải
			# Inner wing panel trái
			_dp([Vector2(-3,-5),Vector2(-12,2),Vector2(-10,6),Vector2(-2,-1)],
				Color(0.2, 0.75, 0.88, 0.22))                     # inner panel trái
			# Pre-nozzle glow
			_dp([Vector2(-2,18),Vector2(2,18),Vector2(3,22),Vector2(-3,22)],
				Color(0.0, 0.88, 1.0, 0.55))                      # pre-nozzle glow
		4: # ── Purple Heavy ────────────────────────────────────────
			# Vòm cockpit bọc giáp
			_dp([Vector2(-6,-15),Vector2(6,-15),Vector2(8,-9),
				 Vector2(5,-5), Vector2(-5,-5),Vector2(-8,-9)],
				Color(0.1, 0.0, 0.22))                            # khung cockpit
			# Kính ngắm bắn
			_dp([Vector2(-4,-14),Vector2(4,-14),Vector2(5,-9),
				 Vector2(2,-5),Vector2(-2,-5),Vector2(-5,-9)],
				Color(0.78, 0.2, 1.0, 0.68))                      # kính
			# Nòng pháo chính
			_dp([Vector2(-2,-18),Vector2(2,-18),Vector2(2.5,-26),Vector2(-2.5,-26)],
				Color(0.65, 0.25, 1.0))                           # pháo chính
			# Đầu pháo
			_dp([Vector2(-2.5,-26),Vector2(2.5,-26),Vector2(1.5,-29),Vector2(-1.5,-29)],
				Color(1.0, 0.6, 1.0))                             # đầu pháo
			# Giáp vai phải
			_dp([Vector2(10,-14),Vector2(20,-4),Vector2(22,2),Vector2(11,-8)],
				Color(0.42, 0.0, 0.65, 0.55))                     # giáp vai phải
			# Giáp vai trái
			_dp([Vector2(-10,-14),Vector2(-20,-4),Vector2(-22,2),Vector2(-11,-8)],
				Color(0.42, 0.0, 0.65, 0.55))                     # giáp vai trái
			# Súng bên phải
			_dp([Vector2(20,-4),Vector2(25,-6),Vector2(25,-2),Vector2(20,0)],
				Color(0.88, 0.18, 1.0))                           # súng phải
			# Súng bên trái
			_dp([Vector2(-20,-4),Vector2(-25,-6),Vector2(-25,-2),Vector2(-20,0)],
				Color(0.88, 0.18, 1.0))                           # súng trái
			# Panel thân phải
			_dp([Vector2(4,-5),Vector2(11,-1),Vector2(11,10),Vector2(4,10)],
				Color(0.35, 0.0, 0.52, 0.45))                     # panel phải
			# Panel thân trái
			_dp([Vector2(-4,-5),Vector2(-11,-1),Vector2(-11,10),Vector2(-4,10)],
				Color(0.35, 0.0, 0.52, 0.45))                     # panel trái
			# Bell động cơ trái
			_dp([Vector2(-13,19),Vector2(-7,19),Vector2(-6,26),Vector2(-14,26)],
				Color(0.18, 0.08, 0.28))                          # nozzle trái
			# Bell động cơ phải
			_dp([Vector2(7,19),Vector2(13,19),Vector2(14,26),Vector2(6,26)],
				Color(0.18, 0.08, 0.28))                          # nozzle phải
			# Vành nozzle tím
			_dp([Vector2(-14,19),Vector2(-6,19),Vector2(-6,20.5),Vector2(-14,20.5)],
				Color(0.85, 0.15, 1.0, 0.9))                      # vành trái
			_dp([Vector2(6,19),Vector2(14,19),Vector2(14,20.5),Vector2(6,20.5)],
				Color(0.85, 0.15, 1.0, 0.9))                      # vành phải
	# Lớp overlay Aerial Warfare — vẽ đè lên mọi skin khi pack Aerial Warfare đang bật
	if ThemePack.get_pack().get("shape_mode", "") == "aerial_warfare":
		_add_vnam_details_player()

# Chi tiết sơn máy bay VPAF — gọi khi Aerial Warfare theme đang bật
func _add_vnam_details_player() -> void:
	match _skin_id:
		0: _vnam_mig21()
		1: _vnam_mig17()
		2: _vnam_mi24()
		3: _vnam_mig19()
		4: _vnam_il28()

func _vnam_star(sx: float, sy: float, rs: float = 3.8) -> void:
	var ri := rs * 0.40
	var pts: Array = []
	for i in 5:
		var ao := float(i)*TAU/5.0 - PI/2.0
		var ai := ao + TAU/10.0
		pts.append(Vector2(cos(ao)*rs+sx, sin(ao)*rs+sy))
		pts.append(Vector2(cos(ai)*ri+sx, sin(ai)*ri+sy))
	_dp(pts, Color(1.0, 0.92, 0.05, 0.95))

func _vnam_mig21() -> void:
	# Miệng hút không khí tròn ở mũi (đặc trưng MiG-21)
	var intake: Array = []
	for i in 14:
		var a := float(i) / 14.0 * TAU
		intake.append(Vector2(cos(a) * 4.5, sin(a) * 4.5 - 20.0))
	_dp(intake, Color(0.06, 0.06, 0.08))
	var intake_c: Array = []
	for i in 14:
		var a := float(i) / 14.0 * TAU
		intake_c.append(Vector2(cos(a) * 2.8, sin(a) * 2.8 - 20.0))
	_dp(intake_c, Color(0.02, 0.02, 0.04))
	# Buồng lái dạng bong bóng nhỏ
	_dp([Vector2(-3,-12),Vector2(3,-12),Vector2(4,-7),Vector2(0,-4),Vector2(-4,-7)],
		Color(0.08, 0.25, 0.55))                                  # khung cockpit
	_dp([Vector2(-2,-11),Vector2(2,-11),Vector2(3,-8),Vector2(0,-6),Vector2(-3,-8)],
		Color(0.4, 0.78, 1.0, 0.65))                              # kính
	_dp([Vector2(-0.8,-10),Vector2(0.8,-10),Vector2(1.2,-7.5),Vector2(-1.2,-7.5)],
		Color(0.9, 1.0, 1.0, 0.5))                               # điểm sáng
	# Bề mặt cánh delta (xanh rêu quân sự)
	_dp([Vector2(2,-12),Vector2(14,-2),Vector2(16,4),Vector2(6,4)],
		Color(0.25, 0.38, 0.15, 0.45))                           # cánh phải
	_dp([Vector2(-2,-12),Vector2(-14,-2),Vector2(-16,4),Vector2(-6,4)],
		Color(0.25, 0.38, 0.15, 0.45))                           # cánh trái
	# Vạch nhận dạng đỏ trên cánh
	_dp([Vector2(6,0),Vector2(14,-1),Vector2(14,1.5),Vector2(6,2.5)],
		Color(0.82, 0.06, 0.06, 0.80))                           # vạch đỏ phải
	_dp([Vector2(-6,0),Vector2(-14,-1),Vector2(-14,1.5),Vector2(-6,2.5)],
		Color(0.82, 0.06, 0.06, 0.80))                           # vạch đỏ trái
	# Ngôi sao vàng (sao 5 cánh — biểu tượng VPAF) — cánh phải
	var col_star := Color(1.0, 0.92, 0.05, 0.95)
	var sx := 12.0; var sy := 6.0; var rs := 4.0; var ri := 1.6
	for tier in [col_star]:
		var spts: Array = []
		for i in 5:
			var ao := float(i) * TAU / 5.0 - PI / 2.0
			var ai := ao + TAU / 10.0
			spts.append(Vector2(cos(ao) * rs + sx, sin(ao) * rs + sy))
			spts.append(Vector2(cos(ai) * ri + sx, sin(ai) * ri + sy))
		_dp(spts, tier)
	# Ngôi sao cánh trái (đối xứng)
	for tier in [col_star]:
		var spts: Array = []
		for i in 5:
			var ao := float(i) * TAU / 5.0 - PI / 2.0
			var ai := ao + TAU / 10.0
			spts.append(Vector2(cos(ao) * rs - sx, sin(ao) * rs + sy))
			spts.append(Vector2(cos(ai) * ri - sx, sin(ai) * ri + sy))
		_dp(spts, tier)
	# Ống phun đuôi đơn (afterburner)
	_dp([Vector2(-3.5,18),Vector2(3.5,18),Vector2(4,24),Vector2(-4,24)],
		Color(0.18, 0.18, 0.22))                                  # vỏ nozzle
	_dp([Vector2(-3.5,18),Vector2(3.5,18),Vector2(4.5,20),Vector2(-4.5,20)],
		Color(1.0, 0.55, 0.10, 0.88))                            # vành lửa
	# Cánh đuôi đứng
	_dp([Vector2(4,16),Vector2(8,12),Vector2(9,20),Vector2(5,22)],
		Color(0.30, 0.45, 0.18))
	_dp([Vector2(-4,16),Vector2(-8,12),Vector2(-9,20),Vector2(-5,22)],
		Color(0.30, 0.45, 0.18))

func _vnam_mig17() -> void:
	# MiG-17 Fresco — cánh xuôi 45°, thân mập xanh rêu
	_dp([Vector2(-3,-18),Vector2(3,-18),Vector2(4,-13),Vector2(0,-10),Vector2(-4,-13)],
		Color(0.12, 0.28, 0.55))
	_dp([Vector2(-2,-17),Vector2(2,-17),Vector2(3,-14),Vector2(0,-11),Vector2(-3,-14)],
		Color(0.45, 0.78, 1.0, 0.60))
	_dp([Vector2(3,-8),Vector2(18,4),Vector2(16,8),Vector2(2,-2)],
		Color(0.28, 0.40, 0.16, 0.50))
	_dp([Vector2(-3,-8),Vector2(-18,4),Vector2(-16,8),Vector2(-2,-2)],
		Color(0.28, 0.40, 0.16, 0.50))
	_dp([Vector2(4,14),Vector2(12,10),Vector2(13,18),Vector2(5,20)],
		Color(0.30, 0.44, 0.18))
	_dp([Vector2(-4,14),Vector2(-12,10),Vector2(-13,18),Vector2(-5,20)],
		Color(0.30, 0.44, 0.18))
	_dp([Vector2(-3.5,18),Vector2(3.5,18),Vector2(4,24),Vector2(-4,24)],
		Color(0.16, 0.16, 0.20))
	_dp([Vector2(-3.5,18),Vector2(3.5,18),Vector2(4.2,20),Vector2(-4.2,20)],
		Color(1.0, 0.55, 0.10, 0.88))
	# Vạch nhận dạng đỏ + sao
	_dp([Vector2(4,2),Vector2(14,4),Vector2(14,7),Vector2(4,5)],
		Color(0.82, 0.06, 0.06, 0.80))
	_dp([Vector2(-4,2),Vector2(-14,4),Vector2(-14,7),Vector2(-4,5)],
		Color(0.82, 0.06, 0.06, 0.80))
	_vnam_star(11.0, 5.5, 3.2)
	_vnam_star(-11.0, 5.5, 3.2)

func _vnam_mi24() -> void:
	# Mi-24 Hind — trực thăng tấn công, thân armored, stub wings
	# Đĩa rotor chính (từ trên nhìn xuống)
	var rot_pts: Array = []
	for i in 24:
		var a := float(i)/24.0*TAU
		rot_pts.append(Vector2(cos(a)*22.0, sin(a)*4.5))
	_dp(rot_pts, Color(0.28, 0.38, 0.20, 0.30))
	# Thân bọc giáp
	_dp([Vector2(-4,-14),Vector2(4,-14),Vector2(5,-8),Vector2(0,-5),Vector2(-5,-8)],
		Color(0.10, 0.24, 0.08))
	_dp([Vector2(-2,-13),Vector2(2,-13),Vector2(3,-9),Vector2(0,-6),Vector2(-3,-9)],
		Color(0.40, 0.75, 0.95, 0.60))
	# Stub wings
	_dp([Vector2(8,-2),Vector2(24,-2),Vector2(24,4),Vector2(8,4)],
		Color(0.25, 0.38, 0.14, 0.60))
	_dp([Vector2(-8,-2),Vector2(-24,-2),Vector2(-24,4),Vector2(-8,4)],
		Color(0.25, 0.38, 0.14, 0.60))
	# Pods tên lửa dưới cánh
	_dp([Vector2(20,-3),Vector2(24,-3),Vector2(24,10),Vector2(20,10)],
		Color(0.55, 0.52, 0.20))
	_dp([Vector2(-24,-3),Vector2(-20,-3),Vector2(-20,10),Vector2(-24,10)],
		Color(0.55, 0.52, 0.20))
	_dp([Vector2(20,10),Vector2(24,10),Vector2(23,13),Vector2(21,13)],
		Color(0.85, 0.20, 0.05))
	_dp([Vector2(-24,10),Vector2(-20,10),Vector2(-21,13),Vector2(-23,13)],
		Color(0.85, 0.20, 0.05))
	# Súng nose 12.7mm
	_dp([Vector2(-1.5,-15),Vector2(1.5,-15),Vector2(1.5,-22),Vector2(-1.5,-22)],
		Color(0.45, 0.42, 0.18))
	# Đuôi ngắn + tail rotor
	_dp([Vector2(-2,16),Vector2(2,16),Vector2(3,22),Vector2(-3,22)],
		Color(0.22, 0.32, 0.12))
	_vnam_star(0.0, 8.0, 3.5)

func _vnam_mig19() -> void:
	# MiG-19 Farmer — twin engine, swept wing
	# Buồng lái
	_dp([Vector2(-3,-20),Vector2(3,-20),Vector2(4,-15),Vector2(0,-12),Vector2(-4,-15)],
		Color(0.10, 0.26, 0.50))
	_dp([Vector2(-2,-19),Vector2(2,-19),Vector2(3,-16),Vector2(0,-13),Vector2(-3,-16)],
		Color(0.45, 0.78, 1.0, 0.62))
	# Cánh xuôi mỏng
	_dp([Vector2(2,-8),Vector2(16,2),Vector2(14,8),Vector2(1,0)],
		Color(0.26, 0.38, 0.14, 0.50))
	_dp([Vector2(-2,-8),Vector2(-16,2),Vector2(-14,8),Vector2(-1,0)],
		Color(0.26, 0.38, 0.14, 0.50))
	# Twin engine intakes
	_dp([Vector2(-5,-6),Vector2(-2,-6),Vector2(-2,4),Vector2(-5,4)],
		Color(0.12, 0.12, 0.16))
	_dp([Vector2(2,-6),Vector2(5,-6),Vector2(5,4),Vector2(2,4)],
		Color(0.12, 0.12, 0.16))
	# Twin nozzles
	_dp([Vector2(-6,18),Vector2(-2,18),Vector2(-2,26),Vector2(-6,26)],
		Color(0.16, 0.16, 0.20))
	_dp([Vector2(2,18),Vector2(6,18),Vector2(6,26),Vector2(2,26)],
		Color(0.16, 0.16, 0.20))
	_dp([Vector2(-7,18),Vector2(-1,18),Vector2(-1,20),Vector2(-7,20)],
		Color(1.0, 0.55, 0.10, 0.88))
	_dp([Vector2(1,18),Vector2(7,18),Vector2(7,20),Vector2(1,20)],
		Color(1.0, 0.55, 0.10, 0.88))
	# Cánh đuôi + sao
	_dp([Vector2(3,14),Vector2(8,10),Vector2(9,18),Vector2(4,20)],
		Color(0.28, 0.42, 0.16))
	_dp([Vector2(-3,14),Vector2(-8,10),Vector2(-9,18),Vector2(-4,20)],
		Color(0.28, 0.42, 0.16))
	_vnam_star(0.0, 6.0, 3.2)

func _vnam_il28() -> void:
	# Il-28 Beagle — máy bay ném bom twin-jet, cánh thẳng rộng
	# Phòng lái mũi kính lớn
	_dp([Vector2(-4,-14),Vector2(4,-14),Vector2(5,-9),Vector2(0,-6),Vector2(-5,-9)],
		Color(0.08, 0.20, 0.45))
	_dp([Vector2(-3,-13),Vector2(3,-13),Vector2(4,-10),Vector2(0,-7),Vector2(-4,-10)],
		Color(0.45, 0.75, 0.95, 0.60))
	# Cánh thẳng rộng
	_dp([Vector2(4,-2),Vector2(25,2),Vector2(24,8),Vector2(4,6)],
		Color(0.26, 0.38, 0.14, 0.48))
	_dp([Vector2(-4,-2),Vector2(-25,2),Vector2(-24,8),Vector2(-4,6)],
		Color(0.26, 0.38, 0.14, 0.48))
	# Pod động cơ pod dưới cánh (đặc trưng Il-28)
	_dp([Vector2(14,-4),Vector2(18,-4),Vector2(18,12),Vector2(14,12)],
		Color(0.20, 0.20, 0.26))
	_dp([Vector2(-18,-4),Vector2(-14,-4),Vector2(-14,12),Vector2(-18,12)],
		Color(0.20, 0.20, 0.26))
	_dp([Vector2(13.5,12),Vector2(18.5,12),Vector2(19,14),Vector2(13,14)],
		Color(1.0, 0.55, 0.10, 0.88))
	_dp([Vector2(-18.5,12),Vector2(-13.5,12),Vector2(-13,14),Vector2(-19,14)],
		Color(1.0, 0.55, 0.10, 0.88))
	# Khoang bom bụng
	_dp([Vector2(-3,2),Vector2(3,2),Vector2(3,14),Vector2(-3,14)],
		Color(0.28, 0.26, 0.10, 0.60))
	# Đuôi đứng + ngang
	_dp([Vector2(-1,18),Vector2(1,18),Vector2(1.5,24),Vector2(-1.5,24)],
		Color(0.30, 0.44, 0.18))
	_dp([Vector2(-8,22),Vector2(8,22),Vector2(8,24),Vector2(-8,24)],
		Color(0.30, 0.44, 0.18))
	# Sao vàng cánh
	_vnam_star(18.0, 4.0, 3.0)
	_vnam_star(-18.0, 4.0, 3.0)

func _physics_process(_delta: float) -> void:
	_sw_cd_left  = maxf(_sw_cd_left  - _delta, 0.0)
	_sw_cd_right = maxf(_sw_cd_right - _delta, 0.0)
	_skill_cd    = maxf(_skill_cd    - _delta, 0.0)
	_blink_cd    = maxf(_blink_cd    - _delta, 0.0)
	_animate_engine(_delta)
	# Blue Classic: tái nạp khiën sau 6s không bị thương
	if _skin_id == 0 and not _skin_shield:
		_shield_regen_timer -= _delta
		if _shield_regen_timer <= 0.0:
			_skin_shield = true
			_flash_shield_ready()
	# Đếm ngược skill
	if _skill_active:
		_skill_timer -= _delta
		if _skill_timer <= 0.0:
			_deactivate_skill()
	# Cập nhật skill UI mọi frame
	var _main_sk := get_tree().current_scene
	if _main_sk and _main_sk.has_method("refresh_skill"):
		_main_sk.refresh_skill(_skill_active, _skill_timer, _skill_cd, _skin_id)
	_handle_movement()
	# 2.5D banking: tilt when moving horizontally
	if is_instance_valid(sprite):
		var bank_target := 1.0 - absf(velocity.x) / maxf(1.0, velocity.length()) * 0.28
		_bank = lerpf(_bank, bank_target, 14.0 * _delta)
		sprite.scale.x = _bank
	queue_redraw()
	_update_aim(_delta)
	_handle_shoot()
	_handle_special()
	# J — kích hoạt skill
	if Input.is_action_just_pressed("skill") and _skill_cd <= 0.0 and not _skill_active:
		_activate_skill()

# ── 2.5D UNDERSIDE ENGINE GLOW ──────────────────────────────────────────────
func _draw() -> void:
	if not is_instance_valid(sprite): return
	# Back of ship = Vector2(0,+22) in sprite-local space.
	# Convert to player-local: rotate then add sprite.position (hover bob).
	var rot  := sprite.rotation
	var back := sprite.position + Vector2(-sin(rot), cos(rot)) * 22.0
	var glow := _get_sprite_color()
	var pulse := 0.7 + 0.3 * sin(_hover_phase * 2.8)
	for i in range(4):
		var r := 20.0 - float(i) * 4.5
		var a := (0.22 - float(i) * 0.045) * pulse
		draw_circle(back, r, Color(glow.r, glow.g, glow.b, a))
	# Thin shadow blob (depth) — follows sprite hover bob
	draw_circle(sprite.position + Vector2(0.0, 10.0), 26.0, Color(0.0, 0.0, 0.0, 0.18 * pulse))

# ── AIM / ROTATE TOWARD TARGET ────────────────────────────────────────────────
func _update_aim(delta: float) -> void:
	# ── Ưu tiên xoay thủ công khi nhấn 2 phím hướng đồng thời ──
	var dx := 0.0
	var dy := 0.0
	if Input.is_action_pressed("ui_right"): dx += 1.0
	if Input.is_action_pressed("ui_left"):  dx -= 1.0
	if Input.is_action_pressed("ui_up"):    dy -= 1.0
	if Input.is_action_pressed("ui_down"):  dy += 1.0
	var keys_held: int = (int(dx > 0) + int(dx < 0) + int(dy > 0) + int(dy < 0))
	if keys_held >= 2:
		# 2 phím cùng lúc → xoay về hướng kết hợp (override auto-aim)
		var manual_dir := Vector2(dx, dy).normalized()
		var manual_angle := manual_dir.angle() + PI / 2.0
		sprite.rotation = lerp_angle(sprite.rotation, manual_angle, 14.0 * delta)
		return

	# ── Auto-aim: asteroid đe dọa gần (≤320px) > boss > enemy > asteroid xa ──
	var near_ast := _nearest_in_group_within("asteroid", 320.0)
	if near_ast != null:
		_aim_target = near_ast
	else:
		_aim_target = _nearest_in_group("boss")
		if _aim_target == null:
			_aim_target = _nearest_in_group("enemy")
		if _aim_target == null:
			_aim_target = _nearest_in_group("asteroid")

	if _aim_target != null and is_instance_valid(_aim_target):
		var to_target := _aim_target.global_position - global_position
		# Góc: sprite mặc định đầu hướng lên (Vector2.UP = -π/2)
		var desired_angle := to_target.angle() + PI / 2.0
		sprite.rotation = lerp_angle(sprite.rotation, desired_angle, 8.0 * delta)
	else:
		# Không có mục tiêu → xoay về hướng lên từ từ
		sprite.rotation = lerp_angle(sprite.rotation, 0.0, 6.0 * delta)

func _nearest_in_group(group: String) -> Node2D:
	var nodes := get_tree().get_nodes_in_group(group)
	var best: Node2D = null
	var best_dist := INF
	for n in nodes:
		if not is_instance_valid(n): continue
		var d := global_position.distance_squared_to((n as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = n as Node2D
	return best

func _nearest_in_group_within(group: String, max_dist: float) -> Node2D:
	var nodes := get_tree().get_nodes_in_group(group)
	var best: Node2D = null
	var best_dist := max_dist * max_dist
	for n in nodes:
		if not is_instance_valid(n): continue
		var d := global_position.distance_squared_to((n as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = n as Node2D
	return best

# ── MOVEMENT ───────────────────────────────────────────────────────────────────
func _handle_movement() -> void:
	# Neon Dart skill: di chuyển như thường + tự động né đạn bằng teleport
	if _skin_id == 3 and _skill_active:
		var vp := get_viewport_rect().size
		var dir := Vector2.ZERO
		if Input.is_action_pressed("ui_right"): dir.x += 1.0
		if Input.is_action_pressed("ui_left"):  dir.x -= 1.0
		if Input.is_action_pressed("ui_up"):    dir.y -= 1.0
		if Input.is_action_pressed("ui_down"):  dir.y += 1.0
		velocity = dir.normalized() * _move_speed * 1.25
		move_and_slide()
		position.x = clamp(position.x, 22.0, vp.x - 22.0)
		position.y = clamp(position.y, 22.0, vp.y - 22.0)
		if _blink_cd <= 0.0:
			_try_auto_dodge()
		return
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_right"): dir.x += 1.0
	if Input.is_action_pressed("ui_left"):  dir.x -= 1.0
	if Input.is_action_pressed("ui_up"):    dir.y -= 1.0
	if Input.is_action_pressed("ui_down"):  dir.y += 1.0
	velocity = dir.normalized() * _move_speed
	move_and_slide()
	# Giữ player trong màn hình
	var vp2 := get_viewport_rect().size
	position.x = clamp(position.x, 20.0, vp2.x - 20.0)
	position.y = clamp(position.y, 20.0, vp2.y - 20.0)

# ── SHOOT ──────────────────────────────────────────────────────────────────────
func _handle_shoot() -> void:
	if Input.is_action_pressed("ui_accept") and can_shoot:
		_shoot()

func _handle_special() -> void:
	# K — pod trái
	if Input.is_action_just_pressed("special_weapon") and sw_left >= 0 and _sw_cd_left <= 0.0:
		_fire_special(sw_left, -1)
		_sw_cd_left = SW_CD[sw_left]
		sw_left_ammo -= 1
		if sw_left_ammo <= 0:
			sw_left = -1
			sw_left_ammo = 0
		_rebuild_pods()
		_notify_special()
	# L — pod phải
	if Input.is_action_just_pressed("special_weapon_right") and sw_right >= 0 and _sw_cd_right <= 0.0:
		_fire_special(sw_right, 1)
		_sw_cd_right = SW_CD[sw_right]
		sw_right_ammo -= 1
		if sw_right_ammo <= 0:
			sw_right = -1
			sw_right_ammo = 0
		_rebuild_pods()
		_notify_special()

# ── SKILL (J) ────────────────────────────────────────────────────────────────
func _activate_skill() -> void:
	_skill_active = true
	_skill_timer  = SKILL_DURATIONS[_skin_id]
	_skill_cd     = SKILL_COOLDOWNS[_skin_id]
	Audio.play("skill_use")
	if _skin_id == 3: _update_blink_mode_glow(true)
	var main := get_tree().current_scene
	match _skin_id:
		0:  # Blue Classic \u2014 t\u0103ng ch\u1ec9 s\u1ed1 t\u1ed5ng h\u1ee3p 8s
			_saved_fire_rate  = _fire_rate
			_saved_move_speed = _move_speed
			_saved_dmg_bonus  = skin_damage_bonus
			_fire_rate        = maxf(0.07, _fire_rate * 0.5)
			_move_speed       = _move_speed * 1.5
			skin_damage_bonus += 2
			shoot_timer.wait_time = _fire_rate
			if main: main.show_alert("\u26a1 OVERDRIVE 8s!")
		1:  # Red Fighter \u2014 max level \u0111\u1ea1n 4s
			_saved_bullet_level = bullet_level
			bullet_level = 10
			_notify_weapon()
			if main: main.show_alert("MAX LEVEL 4s!")
		2:  # Gold Cruiser \u2014 max tia 4s
			_saved_streams = extra_streams
			extra_streams  = 5
			_notify_weapon()
			if main: main.show_alert("\u2605 MAX STREAMS 4s!")
		3:  # Neon Dart \u2014 teleport mode 10s
			if main: main.show_alert("\u26a1 BLINK MODE 10s!")
		4:  # Purple Heavy \u2014 t\u0103ng l\u00ean 10 tim 10s
			_saved_max_hp = _max_hp
			_max_hp = 10
			if hp < 10: hp = 10
			if main:
				main.refresh_hp(hp, _max_hp)
				main.show_alert("IRON FORTRESS 10s!")

func _deactivate_skill() -> void:
	_skill_active = false
	if _skin_id == 3: _update_blink_mode_glow(false)
	var main := get_tree().current_scene
	match _skin_id:
		0:
			_fire_rate        = _saved_fire_rate
			_move_speed       = _saved_move_speed
			skin_damage_bonus = _saved_dmg_bonus
			shoot_timer.wait_time = _fire_rate
		1:
			bullet_level = _saved_bullet_level
			_notify_weapon()
		2:
			extra_streams = _saved_streams
			_notify_weapon()
		3:
			if main: main.show_alert("Tho\u00e1t blink mode")
		4:
			_max_hp = _saved_max_hp
			hp = mini(hp, _max_hp)
			if main: main.refresh_hp(hp, _max_hp)

# ── BLINK ANIMATIONS ─────────────────────────────────────────────────────────
func _flash_blink() -> void:
	if not is_instance_valid(sprite): return
	sprite.color = Color(0.2, 1.0, 0.8)
	await get_tree().create_timer(0.07).timeout
	if is_instance_valid(self) and is_instance_valid(sprite):
		sprite.color = _get_sprite_color()

func _flash_blink_smooth() -> void:
	# Tween: trắng cyan -> màu skin trong 0.12s
	if not is_instance_valid(sprite): return
	var tw := create_tween()
	sprite.color = Color(0.7, 1.0, 1.0, 1.0)
	tw.tween_property(sprite, "color", _get_sprite_color(), 0.12).set_trans(Tween.TRANS_EXPO)

func _squish_sprite(dir: Vector2) -> void:
	# Squish theo hướng di chuyển rồi nảy đàn hồi về
	if not is_instance_valid(sprite): return
	var stretch_axis := dir.abs()
	var sx := 1.0 + stretch_axis.x * 0.42
	var sy := 1.0 + stretch_axis.y * 0.42
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(sx, sy), 0.05).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC)

func _try_auto_dodge() -> void:
	# Chỉ blink khi có đạn đang bay THẲNG VỀ PHÍA player và đủ gần
	var vp := get_viewport_rect().size
	var danger: Array = []
	var max_threat: float = 0.0

	# --- lọc đạn địch đang nhắm vào player ---
	for b in get_tree().get_nodes_in_group("bullet"):
		if not is_instance_valid(b): continue
		if not b.get("is_enemy_bullet"): continue
		var bpos: Vector2 = b.global_position
		var d := global_position.distance_to(bpos)
		if d > 220.0: continue
		var bdir: Vector2 = b.get("direction") if b.get("direction") != null else Vector2.DOWN
		var incoming := bdir.dot((global_position - bpos).normalized())
		if incoming < 0.40: continue
		var threat := incoming * (1.0 - d / 220.0)
		max_threat  = maxf(max_threat, threat)
		danger.append({"pos": bpos, "dir": bdir, "dist": d})

	# --- thiên thạch / tên lửa AA đang nhắm vào player ---
	for a in get_tree().get_nodes_in_group("asteroid"):
		if not is_instance_valid(a): continue
		var apos: Vector2 = (a as Node2D).global_position
		var d := global_position.distance_to(apos)
		if d > 270.0: continue
		var adir: Vector2 = a.get("direction") if a.get("direction") != null else Vector2.DOWN
		var incoming := adir.dot((global_position - apos).normalized())
		if incoming < 0.28: continue
		var threat := incoming * (1.0 - d / 270.0)
		max_threat  = maxf(max_threat, threat)
		danger.append({"pos": apos, "dir": adir, "dist": d})

	# Không có mối đe dọa thực sự → giữ nguyên vị trí
	if max_threat < 0.28: return

	# --- thu thập vật phẩm gần kề ---
	var items: Array = []
	for grp in ["powerup", "heart", "special_pickup"]:
		for item in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(item): continue
			var ipos: Vector2 = (item as Node2D).global_position
			var idist := global_position.distance_to(ipos)
			items.append({"pos": ipos, "dist": idist})

	# Nếu có item rất gần (< 80px) và mối đe dọa không cực kỳ lớn → nhịn blink
	if max_threat < 0.70:
		for it in items:
			if (it["dist"] as float) < 80.0:
				return   # sắp nhặt vật phẩm, không né vội

	# Tìm vùng an toàn: quét lưới 5×5 toàn màn hình ưu tiên nửa dưới
	var margin    := 36.0
	var best_pos  := global_position
	var best_score := _danger_score(global_position, danger) * 1.50

	for ci in 5:
		for ri in 5:
			var cx := margin + (vp.x - margin * 2.0) * float(ci) / 4.0
			var cy := vp.y * 0.45 + (vp.y * 0.50) * float(ri) / 4.0
			cy = clampf(cy, margin, vp.y - margin)
			var cand := Vector2(cx, cy)
			var sc   := _danger_score(cand, danger)
			# Bonus nếu ứng viên gần vật phẩm (bán kính 200px → tối đa +25% điểm)
			for it in items:
				var id: float = cand.distance_to(it["pos"] as Vector2)
				if id < 200.0:
					sc *= 1.0 + 0.25 * (1.0 - id / 200.0)
			if sc > best_score:
				best_score = sc
				best_pos   = cand

	# Vị trí tốt nhất quá gần vị trí hiện tại → không blink
	if best_pos.distance_to(global_position) < 45.0: return

	_spawn_blink_afterimage()
	var old_pos := global_position
	position    = best_pos
	_blink_cd   = 0.60
	_flash_blink_smooth()
	_squish_sprite((best_pos - old_pos).normalized())

func _danger_score(pos: Vector2, danger: Array) -> float:
	# Điểm an toàn cao hơn = ít nguy hiểm hơn
	var score := 0.0
	for d in danger:
		var to_pos: Vector2 = pos - (d["pos"] as Vector2)
		var dist: float = to_pos.length()
		if dist < 0.1: return 0.0
		var threat := maxf(0.0, d["dir"].dot(to_pos.normalized()))
		score += dist / (1.0 + threat * 3.0)
	return score

func _spawn_blink_afterimage() -> void:
	# Tạo bóng ma Polygon2D mờ dần từ vị trí hiện tại
	if not is_instance_valid(sprite): return
	var ghost := Polygon2D.new()
	ghost.polygon = sprite.polygon
	ghost.color   = Color(0.0, 1.0, 0.85, 0.55)
	ghost.global_position = sprite.global_position
	ghost.rotation        = sprite.rotation
	ghost.scale           = sprite.scale
	ghost.z_index         = -1
	var container := get_tree().current_scene
	if container: container.add_child(ghost)
	# Tween mờ dần và thu nhỏ
	var tw := ghost.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "color:a", 0.0, 0.22).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(ghost, "scale", Vector2(0.7, 0.7), 0.22).set_trans(Tween.TRANS_EXPO)
	await tw.finished
	if is_instance_valid(ghost): ghost.queue_free()

# ── ENGINE EXHAUST (3 lớp: outer glow / mid flame / inner core) ──────────────
func _spawn_engine_exhaust() -> void:
	for grp in _exhaust_groups:
		for p in grp:
			if is_instance_valid(p): p.queue_free()
	_exhaust_groups.clear()
	if not is_instance_valid(sprite): return

	var engine_offsets: Array = []
	match _skin_id:
		0: engine_offsets = [Vector2(-5.5, 20.0), Vector2(5.5, 20.0)]
		1: engine_offsets = [Vector2(-6.0, 22.0), Vector2(6.0, 22.0)]
		2: engine_offsets = [Vector2(-6.0, 23.0), Vector2(6.0, 23.0)]
		3: engine_offsets = [Vector2(0.0, 24.0)]
		4: engine_offsets = [Vector2(-10.0, 22.0), Vector2(10.0, 22.0)]

	var base_cols: Array = [
		Color(0.35, 0.65, 1.0),   # Blue Classic
		Color(1.0,  0.42, 0.05),  # Red Fighter
		Color(1.0,  0.85, 0.08),  # Gold Cruiser
		Color(0.0,  1.0,  0.88),  # Neon Dart
		Color(0.72, 0.08, 1.0),   # Purple Heavy
	]
	var col: Color = base_cols[_skin_id]

	for off in engine_offsets:
		var grp: Array = []
		# Outer glow: rộng, alpha thấp
		var outer := Polygon2D.new()
		outer.polygon = PackedVector2Array([
			Vector2(-4.5, 0), Vector2(4.5, 0),
			Vector2(2.5, 12), Vector2(-2.5, 12)
		])
		outer.color    = Color(col.r * 0.8, col.g * 0.8, col.b, 0.22)
		outer.position = off
		outer.z_index  = -3
		sprite.add_child(outer)
		grp.append(outer)
		# Mid flame: vừa, sáng
		var mid := Polygon2D.new()
		mid.polygon = PackedVector2Array([
			Vector2(-2.8, 0), Vector2(2.8, 0),
			Vector2(1.6, 9),  Vector2(-1.6, 9)
		])
		mid.color    = Color(col.r, col.g, col.b, 0.72)
		mid.position = off
		mid.z_index  = -2
		sprite.add_child(mid)
		grp.append(mid)
		# Inner core: hẹp, rất sáng gần trắng
		var inner := Polygon2D.new()
		inner.polygon = PackedVector2Array([
			Vector2(-1.3, 0), Vector2(1.3, 0),
			Vector2(0.6, 5.5),Vector2(-0.6, 5.5)
		])
		inner.color    = Color(
			minf(col.r * 1.4 + 0.35, 1.0),
			minf(col.g * 1.4 + 0.35, 1.0),
			minf(col.b * 1.4 + 0.35, 1.0), 0.96)
		inner.position = off
		inner.z_index  = -1
		sprite.add_child(inner)
		grp.append(inner)
		_exhaust_groups.append(grp)

func _animate_engine(delta: float) -> void:
	# Hover bob nhẹ cho toàn bộ sprite
	_hover_phase  += delta * 2.3
	_hover_phase   = fmod(_hover_phase, TAU)
	if is_instance_valid(sprite):
		sprite.position.y = sin(_hover_phase) * 1.6

	_engine_phase += delta * 11.0
	_engine_phase  = fmod(_engine_phase, TAU)

	if _exhaust_groups.is_empty(): return

	var is_blink := (_skin_id == 3 and _skill_active)
	var base_cols: Array = [
		Color(0.35, 0.65, 1.0),  Color(1.0, 0.42, 0.05),
		Color(1.0,  0.85, 0.08), Color(0.0, 1.0, 0.88),
		Color(0.72, 0.08, 1.0),
	]
	var col: Color = base_cols[_skin_id]

	for idx in range(_exhaust_groups.size()):
		var grp: Array = _exhaust_groups[idx]
		if grp.size() < 3: continue
		# Mỗi engine lệch pha một chút để trông tự nhiên
		var ph   := _engine_phase + float(idx) * 0.8
		var p1   := sin(ph) * 0.5 + 0.5          # nhịp chậm 0..1
		var p2   := sin(ph * 2.4) * 0.5 + 0.5    # nhịp nhanh cho core

		var outer_len := 0.55 + p1 * 0.75
		var mid_len   := 0.65 + p1 * 0.85
		var inner_len := 0.75 + p2 * 0.95
		if is_blink:
			outer_len *= 2.4
			mid_len   *= 2.2
			inner_len *= 2.5

		var outer: Polygon2D = grp[0]
		var mid:   Polygon2D = grp[1]
		var inner: Polygon2D = grp[2]

		if is_instance_valid(outer):
			outer.scale = Vector2(1.0 + p1 * 0.28, outer_len)
			outer.color = Color(col.r * 0.75, col.g * 0.75, col.b * 0.9,
				0.18 + p1 * 0.18)
		if is_instance_valid(mid):
			mid.scale = Vector2(1.0, mid_len)
			mid.color = Color(col.r, col.g, col.b, 0.58 + p1 * 0.28)
		if is_instance_valid(inner):
			inner.scale = Vector2(1.0, inner_len)
			inner.color = Color(
				minf(col.r * 1.35 + 0.3, 1.0),
				minf(col.g * 1.35 + 0.3, 1.0),
				minf(col.b * 1.35 + 0.3, 1.0),
				0.88 + p2 * 0.12)

func _update_blink_mode_glow(active: bool) -> void:
	# Khi BLINK MODE bật: sprite lấp lánh cyan, tắt thì về màu skin
	if not is_instance_valid(sprite): return
	if _blink_glow_tween and _blink_glow_tween.is_running():
		_blink_glow_tween.kill()
	if active:
		# Glow pulsing: tween lặp vô hạn giữa cyan nhạt và màu skin
		_blink_glow_tween = create_tween().set_loops()
		_blink_glow_tween.tween_property(sprite, "color",
			Color(0.3, 1.0, 0.95, 1.0), 0.35).set_trans(Tween.TRANS_SINE)
		_blink_glow_tween.tween_property(sprite, "color",
			_get_sprite_color(), 0.35).set_trans(Tween.TRANS_SINE)
	else:
		_blink_glow_tween = null
		var tw := create_tween()
		tw.tween_property(sprite, "color", _get_sprite_color(), 0.25)

func _fire_special(type: int, side: int) -> void:
	# side: -1 = trái, +1 = phải (dùng để xác định vị trí xuyển ra)
	var forward := Vector2.UP.rotated(sprite.rotation)
	var right_v := Vector2.RIGHT.rotated(sprite.rotation)
	var pod_offset := right_v * float(side) * 22.0
	var container := _get_bullet_container()
	match type:
		0: # MACHINEGUN — 5 đạn FIRE tốc độ cao, sát thương cao
			for i in range(5):
				var bullet = BULLET_SCENE.instantiate()
				bullet.global_position = global_position + pod_offset
				bullet.direction = forward.rotated(randf_range(-0.07, 0.07))
				bullet.speed = 750.0
				bullet.damage = 5
				bullet.is_enemy_bullet = false
				bullet.bullet_type = 2  # FIRE
				if container: container.add_child(bullet)
		1: # MISSILE
			var m = MISSILE_SCENE.instantiate()
			m.global_position = global_position + pod_offset
			if container: container.add_child(m)
		2: # BLACK HOLE
			var bh = BLACK_HOLE_SCENE.instantiate()
			bh.global_position = global_position + forward * 200.0
			if container: container.add_child(bh)

# ── POD VISUALS ────────────────────────────────────────────────────────────────────────
func _rebuild_pods() -> void:
	if not is_instance_valid(sprite): return
	# Xóa pod cũ
	if is_instance_valid(_pod_left_node):  _pod_left_node.queue_free()
	if is_instance_valid(_pod_right_node): _pod_right_node.queue_free()
	if is_instance_valid(_pod_label_left):  _pod_label_left.queue_free()
	if is_instance_valid(_pod_label_right): _pod_label_right.queue_free()
	_pod_left_node = null; _pod_right_node = null
	_pod_label_left = null; _pod_label_right = null
	# Tạo pod trái
	if sw_left >= 0:
		_pod_left_node  = _make_pod(-1, sw_left)
		_pod_label_left = _make_pod_label(-1, sw_left)
	# Tạo pod phải
	if sw_right >= 0:
		_pod_right_node  = _make_pod(1, sw_right)
		_pod_label_right = _make_pod_label(1, sw_right)

func _make_pod_poly(parent: Node2D, pts: Array, col: Color) -> void:
	var poly := Polygon2D.new()
	var pv := PackedVector2Array()
	for v in pts: pv.append(v)
	poly.polygon = pv
	poly.color   = col
	poly.z_index = 2
	parent.add_child(poly)

func _make_pod(side: int, wtype: int) -> Node2D:
	var root := Node2D.new()
	root.z_index = 2
	sprite.add_child(root)
	var s := float(side)   # +1 = phải, -1 = trái
	var col: Color = SW_POD_COLORS[wtype]
	match wtype:
		0: # MACHINEGUN — hộp dẹt rộng + 3 nòng súng
			# Thân pod
			_make_pod_poly(root, [
				Vector2(s*12,-5), Vector2(s*25,-5), Vector2(s*27, 0),
				Vector2(s*25, 5), Vector2(s*12, 5), Vector2(s*10, 0)
			], col)
			# Highlight thân
			_make_pod_poly(root, [
				Vector2(s*13,-3), Vector2(s*24,-3), Vector2(s*25, 0), Vector2(s*24, 1), Vector2(s*13, 1)
			], col.lightened(0.35))
			# 3 nòng (hướng -y = phía trước)
			for bx: float in [s*14.5, s*18.5, s*22.5]:
				_make_pod_poly(root, [
					Vector2(bx - s*0.9, -5), Vector2(bx + s*0.9, -5),
					Vector2(bx + s*0.7,-12), Vector2(bx - s*0.7,-12)
				], col.lightened(0.22))
				_make_pod_poly(root, [
					Vector2(bx - s*1.1,-12), Vector2(bx + s*1.1,-12), Vector2(bx,-14)
				], Color(1.0, 0.95, 0.4, 0.9))
		1: # MISSILE — thân nhọn dài + 2 cánh đuôi
			# Thân tên lửa
			_make_pod_poly(root, [
				Vector2(s*18,-15),
				Vector2(s*23,-10), Vector2(s*24,-2), Vector2(s*24, 7),
				Vector2(s*21, 12), Vector2(s*15, 12),
				Vector2(s*14, 7),  Vector2(s*14,-2), Vector2(s*13,-10)
			], col)
			# Cánh đuôi trong (phía tâm tàu)
			_make_pod_poly(root, [
				Vector2(s*14,4), Vector2(s*10,11), Vector2(s*14,11)
			], col.darkened(0.22))
			# Cánh đuôi ngoài
			_make_pod_poly(root, [
				Vector2(s*24,4), Vector2(s*28,11), Vector2(s*24,11)
			], col.darkened(0.22))
			# Mũi sáng
			_make_pod_poly(root, [
				Vector2(s*18,-15), Vector2(s*21,-12), Vector2(s*18,-10)
			], Color(1.0, 0.68, 0.6, 0.9))
			# Cửa sổ
			_make_pod_poly(root, [
				Vector2(s*15,-3), Vector2(s*23,-3), Vector2(s*23, 2), Vector2(s*15, 2)
			], Color(0.35, 0.85, 1.0, 0.65))
		2: # BLACK HOLE — cầu tròn + vòng quỹ đạo
			# Thân cầu (14 đỉnh)
			var body: Array = []
			for i in 14:
				var a := float(i)/14.0*TAU
				body.append(Vector2(s*(19.0+cos(a)*7.5), sin(a)*7.5))
			_make_pod_poly(root, body, col)
			# Vòng tím giữa
			var mid: Array = []
			for i in 10:
				var a := float(i)/10.0*TAU
				mid.append(Vector2(s*(19.0+cos(a)*4.5), sin(a)*4.5))
			_make_pod_poly(root, mid, Color(0.55, 0.1, 1.0, 0.9))
			# Lõi trắng
			var core: Array = []
			for i in 8:
				var a := float(i)/8.0*TAU
				core.append(Vector2(s*(19.0+cos(a)*2.0), sin(a)*2.0))
			_make_pod_poly(root, core, Color(0.88, 0.72, 1.0, 0.95))
	return root

func _make_pod_label(side: int, wtype: int) -> Label:
	var short_names: Array = ["MGun", "Msl", "BHole"]
	var ammo := sw_left_ammo if side == -1 else sw_right_ammo
	var lb := Label.new()
	lb.text = "%s x%d" % [short_names[wtype], ammo]
	lb.add_theme_font_size_override("font_size", 8)
	lb.add_theme_color_override("font_color", Color.WHITE)
	lb.position = Vector2(float(side) * 14.0 - 14.0, 10.0)
	lb.z_index = 3
	sprite.add_child(lb)
	return lb

# Nhặt vũ khí đặc biệt từ special_pickup.gd
func collect_special(type: int, slot: int) -> void:
	# Tự động vào slot còn trống nếu slot được chọn đã có vũ khí
	if slot == 0 and sw_left >= 0 and sw_right < 0:
		slot = 1
	elif slot == 1 and sw_right >= 0 and sw_left < 0:
		slot = 0
	if slot == 0:
		sw_left      = type
		sw_left_ammo = SW_AMMO[type]
	else:
		sw_right      = type
		sw_right_ammo = SW_AMMO[type]
	_rebuild_pods()
	_notify_special()
	var key := "K" if slot == 0 else "L"
	var side_name := "trái" if slot == 0 else "phải"
	var main := get_tree().current_scene
	if main and main.has_method("show_alert"):
		main.show_alert("%s x%d gắn pod %s — nhấn %s" % [SW_NAMES[type], SW_AMMO[type], side_name, key])

func _notify_special() -> void:
	var main := get_tree().current_scene
	if main and main.has_method("refresh_special"):
		main.refresh_special(sw_left, sw_right)

func _shoot() -> void:
	can_shoot = false
	Audio.play("ak47_fire", -12.0)
	var container := _get_bullet_container()
	if container == null:
		shoot_timer.start()
		return

	# Hướng bắn theo chiều phi thuyền đang nhìn (sprite.rotation)
	# Đầu sprite ban đầu là Vector2.UP nên forward = Vector2.UP.rotated(rotation)
	var forward := Vector2.UP.rotated(sprite.rotation)
	var right   := Vector2.RIGHT.rotated(sprite.rotation)

	var half: int = extra_streams
	for i in range(-half, half + 1):
		var dir := (forward + right * float(i) * 0.22).normalized()
		_spawn_player_bullet(dir, container)

	shoot_timer.start()

func _spawn_player_bullet(dir: Vector2, container: Node) -> void:
	var bullet = BULLET_SCENE.instantiate()
	# sprite.to_global tính đúng: vị trí sprite (hover bob) + xoay + tỉ lệ
	bullet.global_position = sprite.to_global(Vector2(0.0, -22.0))
	bullet.direction = dir
	bullet.is_enemy_bullet = false
	bullet.bullet_type = bullet_type
	bullet.bullet_level = bullet_level
	bullet.is_max_power = (bullet_level >= 10 and extra_streams >= 5)
	container.add_child(bullet)
	# Áp passive bonus sau khi _ready() đã chạy
	if skin_speed_bonus > 0.0:  bullet.speed  += skin_speed_bonus
	if skin_damage_bonus > 0:   bullet.damage += skin_damage_bonus
	if overflow_damage   > 0:   bullet.damage += overflow_damage

func _on_shoot_timer_timeout() -> void:
	can_shoot = true

func _get_bullet_container() -> Node:
	return get_tree().current_scene.get_node_or_null("BulletContainer")

# ── POWER-UP ────────────────────────────────────────────────────────────────────
# 0=EXTRA_STREAM, 1=ELECTRIC, 2=FIRE, 3=ICE, 4=EXPLOSIVE, 5=RICOCHET, 6=UPGRADE
func apply_powerup(type: int) -> void:
	if type == 0:
		# EXTRA_STREAM: tăng luồng (nếu cùng loại & đang dùng type 0 thì tăng level)
		if bullet_type == 0 and extra_streams == 0:
			# lần đầu nhặt stream
			extra_streams += 1
		elif bullet_type == 0:
			# đã đang dùng stream → tăng level
			if bullet_level < 10:
				bullet_level += 1
			elif extra_streams < 5:
				extra_streams += 1
			else:
				overflow_damage += 1
				_show_overflow_alert()
		else:
			# đang dùng loại khác → chuyển sang stream
			bullet_type = 0
			extra_streams = maxi(extra_streams, 1)
	elif type == 6:
		# UPGRADE luôn tăng level
		if bullet_level < 10:
			bullet_level += 1
		else:
			overflow_damage += 1
			_show_overflow_alert()
	else:
		# Đạn loại 1-5
		if bullet_type == type:
			# Cùng loại → tăng level
			if bullet_level < 10:
				bullet_level += 1
			else:
				overflow_damage += 1
				_show_overflow_alert()
		else:
			# Khác loại → đổi loại, giữ nguyên level
			bullet_type = type
	_notify_weapon()

func _show_overflow_alert() -> void:
	var main := get_tree().current_scene
	if main and main.has_method("show_alert"):
		main.show_alert("Đã MAX! Sát thương +1 (tổng cộng +%d)" % overflow_damage)

func _notify_weapon() -> void:
	var main := get_tree().current_scene
	if main and main.has_method("refresh_weapon"):
		main.refresh_weapon(bullet_type, bullet_level, extra_streams)

# ── HEAL ──────────────────────────────────────────────────────────────────────
func heal(amount: int = 1) -> void:
	var main_node := get_tree().current_scene
	hp = mini(hp + amount, _max_hp)
	if main_node and main_node.has_method("refresh_hp"):
		main_node.refresh_hp(hp, _max_hp)
	if is_instance_valid(sprite):
		sprite.color = Color(0.4, 1.0, 0.4)  # flash xanh lá
		await get_tree().create_timer(0.18).timeout
		if is_instance_valid(self) and is_instance_valid(sprite):
			sprite.color = _get_sprite_color()
			# shape không cần reapply saat flash restore

# ── HEALTH ─────────────────────────────────────────────────────────────────────
func take_damage(dmg: int = 1) -> void:
	# Neon Dart: 30% cơ hội né tránh hoàn toàn
	if _skin_id == 3 and randf() < 0.30:
		_show_dodge_text()
		return
	# Purple Heavy: giảm sát thương đầu vào 1 (min 1)
	if _skin_id == 4:
		dmg = maxi(1, dmg - 1)
	# Blue Classic: khiën hấp thụ 1 đòn
	if _skin_id == 0 and _skin_shield:
		_skin_shield = false
		_shield_regen_timer = 6.0
		_flash_shield_break()
		return   # không mất HP, không phạt vũ khí
	hp -= dmg
	Audio.play("player_hurt", -3.0)
	# Phạt vũ khí khi bị thương:
	# Red Fighter & Gold Cruiser: chỉ giảm level, giữ streams
	if _skin_id == 1 or _skin_id == 2:
		bullet_level = maxi(1, bullet_level - 2)
	else:
		extra_streams = mini(extra_streams, 1)
		bullet_level  = maxi(1, bullet_level - 2)
	_notify_weapon()
	# Camera shake khi nhận đòn
	var main_sh := get_tree().current_scene
	if main_sh and main_sh.has_method("screen_shake"):
		main_sh.screen_shake(7.0, 0.20)
	# Cập nhật HP label trên UI
	var main := get_tree().current_scene
	if main and main.has_method("refresh_hp"):
		main.refresh_hp(hp, _max_hp)
	if main and main.has_method("screen_shake"):
		main.screen_shake(6.0, 0.18)
	# Chết TRƯỚC khi await
	if hp <= 0:
		_die()
		return
	# Flash chỉ khi còn sống
	if is_instance_valid(sprite):
		sprite.color = Color.RED
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and is_instance_valid(sprite):
			sprite.color = _get_sprite_color()

func _flash_shield_ready() -> void:
	if not is_instance_valid(sprite): return
	sprite.color = Color.CYAN
	await get_tree().create_timer(0.18).timeout
	if is_instance_valid(self) and is_instance_valid(sprite):
		sprite.color = _get_sprite_color()

func _flash_shield_break() -> void:
	if not is_instance_valid(sprite): return
	sprite.color = Color(0.5, 1.0, 1.0)
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self) and is_instance_valid(sprite):
		sprite.color = _get_sprite_color()

func _show_dodge_text() -> void:
	Audio.play("dodge", -4.0)
	var main := get_tree().current_scene
	if main and main.has_method("show_alert"):
		main.show_alert("NÉ TRÁNH!")
	if is_instance_valid(sprite):
		sprite.color = Color.YELLOW
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and is_instance_valid(sprite):
			sprite.color = _get_sprite_color()

func _die() -> void:
	if _is_dead: return
	_is_dead = true
	set_physics_process(false)
	set_process(false)
	can_shoot = false
	# Tắt collision để không nhận thêm damage
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	# Dọn exhaust
	for grp in _exhaust_groups:
		for p in grp:
			if is_instance_valid(p): p.queue_free()
	_exhaust_groups.clear()
	Audio.play("explosion", 0.0)
	if not is_instance_valid(sprite):
		get_tree().current_scene.trigger_game_over()
		return
	sprite.color = _get_sprite_color()   # xóa flash màu
	# ── Hoạt ảnh rơi + xoay ──
	var tw := create_tween()
	tw.set_parallel(true)
	# Xoay 2.5 vòng khi rơi
	tw.tween_property(sprite, "rotation",
		sprite.rotation + TAU * 2.5, 1.15
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Rơi xuống
	tw.tween_property(self, "position:y",
		position.y + 160.0, 1.15
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Lắc ngang
	tw.tween_property(self, "position:x",
		position.x + randf_range(-55.0, 55.0), 1.15
	).set_trans(Tween.TRANS_SINE)
	# Mờ dần từ giây 0.45
	tw.tween_property(sprite, "modulate:a",
		0.0, 0.70
	).set_trans(Tween.TRANS_EXPO).set_delay(0.45)
	# 5 vụ nổ tuần tự
	_spawn_death_burst(0.05, 22.0)
	_spawn_death_burst(0.24, 30.0)
	_spawn_death_burst(0.44, 38.0)
	_spawn_death_burst(0.65, 28.0)
	_spawn_death_burst(0.88, 20.0)
	await get_tree().create_timer(1.30).timeout
	if is_instance_valid(self):
		get_tree().current_scene.trigger_game_over()

func _spawn_death_burst(delay: float, radius: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self): return
	var container := get_tree().current_scene
	if container == null: return
	var col := _get_sprite_color()
	var offset := Vector2(randf_range(-20.0, 20.0), randf_range(-16.0, 16.0))
	# Vòng nổ ngoài (cam/vàng mở rộng)
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := float(i)/16.0*TAU
		pts.append(Vector2(cos(a), sin(a)) * 3.5)
	ring.polygon = pts
	ring.color = Color(1.0, 0.6 + randf()*0.35, 0.08, 0.92)
	ring.global_position = global_position + offset
	ring.z_index = 10
	container.add_child(ring)
	var tw1 := ring.create_tween()
	tw1.set_parallel(true)
	tw1.tween_property(ring, "scale", Vector2.ONE * (radius/3.5), 0.42).set_trans(Tween.TRANS_EXPO)
	tw1.tween_property(ring, "color:a", 0.0, 0.42).set_trans(Tween.TRANS_EXPO)
	await tw1.finished
	if is_instance_valid(ring): ring.queue_free()
	# Flash trắng gọi tâm
	var flash := Polygon2D.new()
	var fpts := PackedVector2Array()
	for i in 10:
		var a := float(i)/10.0*TAU
		fpts.append(Vector2(cos(a), sin(a)) * 2.0)
	flash.polygon = fpts
	flash.color = Color(1.0, 1.0, 1.0, 0.95)
	flash.global_position = global_position + offset
	flash.z_index = 11
	container.add_child(flash)
	var tw2 := flash.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(flash, "scale", Vector2.ONE * (radius*0.38), 0.24).set_trans(Tween.TRANS_EXPO)
	tw2.tween_property(flash, "color:a", 0.0, 0.24).set_trans(Tween.TRANS_EXPO)
	await tw2.finished
	if is_instance_valid(flash): flash.queue_free()


func _input(event: InputEvent) -> void:
	# Play punch SFX when melee key is pressed (mapped to action 'melee')
	if event is InputEventKey and event.pressed and not event.echo:
		if Input.is_action_pressed("melee"):
			Audio.play("punch")
