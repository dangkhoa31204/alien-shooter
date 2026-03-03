extends CharacterBody2D
# boss.gd — Boss với 3 phase, đổi phase theo % máu

signal died   # phát khi boss chết, wave_manager lắng nghe

const BULLET_SCENE   = preload("res://scenes/bullet.tscn")
const HEART_SCENE    = preload("res://scenes/heart.tscn")
const POWERUP_SCENE  = preload("res://scenes/powerup.tscn")
const ENEMY_SCENE    = preload("res://scenes/enemy.tscn")

# Tính cách chiến đấu mỗi boss:
# 0 Warship     — xả đạn liên tục, không lao, không gọi quân
# 1 Interceptor — lách thường xuyên, bắn ít
# 2 Dreadnought — gọi quân, bắn chậm, không lao
# 3 Carrier     — gọi quân liên tục, bắn vừa, không lao
# 4 Mothership  — tất cả: bắn + lao + gọi quân
const BOSS_CAN_CHARGE: Array = [false, true, false, false, true]

# ── CONFIG ────────────────────────────────────────────────────────────────────
var max_hp: int   = 300
var hp: int       = 300
var speed: float  = 120.0
var score_value: int = 5000
var boss_type:   int   = 0   # 0–4, gán từ wave_manager

# ── HÌNH DẠNG & MÀU 5 BOSS ───────────────────────────────────────────────────
# Polygon per boss_type (center at origin, up = negative Y)
const BOSS_POLYGONS: Array = [
	# 0 Warship — dàn rộng, cánh dày
	[Vector2(0,-35), Vector2(22,-20), Vector2(42,-8),  Vector2(30,4),
	 Vector2(18,14), Vector2(10,30),  Vector2(-10,30), Vector2(-18,14),
	 Vector2(-30,4), Vector2(-42,-8), Vector2(-22,-20)],
	# 1 Interceptor — mũi nhọn dài, thân hẹp
	[Vector2(0,-44), Vector2(10,-26), Vector2(16,-8),   Vector2(14,10),
	 Vector2(8,28),  Vector2(0,36),   Vector2(-8,28),   Vector2(-14,10),
	 Vector2(-16,-8), Vector2(-10,-26)],
	# 2 Dreadnought — siêu rộng, giáp dày
	[Vector2(0,-28), Vector2(14,-22), Vector2(30,-18),  Vector2(50,-8),
	 Vector2(54,4),  Vector2(46,16),  Vector2(28,26),   Vector2(14,32),
	 Vector2(-14,32), Vector2(-28,26), Vector2(-46,16), Vector2(-54,4),
	 Vector2(-50,-8), Vector2(-30,-18), Vector2(-14,-22)],
	# 3 Carrier — ngang dẹt, cánh cong
	[Vector2(0,-22), Vector2(12,-18), Vector2(20,-12),  Vector2(40,-6),
	 Vector2(44,4),  Vector2(34,16),  Vector2(16,24),   Vector2(-16,24),
	 Vector2(-34,16), Vector2(-44,4), Vector2(-40,-6),  Vector2(-20,-12),
	 Vector2(-12,-18)],
	# 4 Mothership — bát giác lớn đối xứng
	[Vector2(0,-46), Vector2(22,-36), Vector2(40,-18),  Vector2(46,0),
	 Vector2(40,18), Vector2(22,36),  Vector2(0,42),    Vector2(-22,36),
	 Vector2(-40,18), Vector2(-46,0), Vector2(-40,-18), Vector2(-22,-36)],
]

# Loại đạn đặc trưng cho từng boss (NORMAL=0,ELECTRIC=1,FIRE=2,ICE=3,EXPLOSIVE=4)
const BOSS_BULLET_TYPES: Array = [2, 1, 3, 4, 0]  # Warship=FIRE, Interceptor=ELECTRIC, Dreadnought=ICE, Carrier=EXPLOSIVE, Mothership=NORMAL

# Màu [phase1, phase2, phase3] cho từng boss_type
const BOSS_COLORS: Array = [
	[Color(0.8,  0.2,  0.8),  Color(1.0, 0.5,  0.0),  Color(1.0, 0.1,  0.1)],  # 0 Warship
	[Color(0.1,  0.6,  1.0),  Color(0.0, 1.0,  0.9),  Color(0.1, 1.0,  0.4)],  # 1 Interceptor
	[Color(0.55, 0.12, 0.08), Color(0.85,0.28, 0.0),  Color(1.0, 0.05, 0.05)], # 2 Dreadnought
	[Color(0.6,  0.55, 0.05), Color(0.9, 0.85, 0.0),  Color(1.0, 1.0,  0.2)],  # 3 Carrier
	[Color(0.65, 0.65, 0.8),  Color(0.9, 0.3,  0.95), Color(1.0, 0.05, 0.85)], # 4 Mothership
]

# Phase thresholds (theo % máu còn lại)
const PHASE2_HP: float = 0.66  # dưới 66% → phase 2
const PHASE3_HP: float = 0.33  # dưới 33% → phase 3

enum Phase { ONE, TWO, THREE }
var current_phase: Phase = Phase.ONE

var time_elapsed: float = 0.0
var move_dir: float = 1.0
var _is_dying: bool = false
var _special_cd: float = 5.0   # countdown đến chiêu đặc trưng

# ── CHARGE ────────────────────────────────────────────────────────────────────
var _charge_cd:        float = 8.0    # giây đến lần lao tới tiếp theo
var _charging:         bool  = false
var _charge_dir:       Vector2 = Vector2.ZERO
var _charge_remaining: float = 0.0
const CHARGE_SPEED:    float = 580.0
const CHARGE_DURATION: float = 0.65

# ── ANIMATION ────────────────────────────────────────────────────────────────
var _anim_time:    float   = 0.0
var _engine_nodes: Array   = []   # động cơ — pulse độ sáng
var _weapon_nodes: Array   = []   # vũ khí  — flash khi bắn
var _core_node:    Polygon2D = null  # lõi  — scale pulse

@onready var shoot_timer: Timer = $ShootTimer
@onready var sprite: Polygon2D  = $Sprite
var _dr: Node2D = null

func _clear_dr() -> void:
	_engine_nodes.clear()
	_weapon_nodes.clear()
	_core_node = null
	if is_instance_valid(_dr): _dr.queue_free()
	_dr = Node2D.new(); _dr.z_index = 1
	sprite.add_child(_dr)

func _make_poly(pts: Array, col: Color) -> Polygon2D:
	var p2d := Polygon2D.new()
	var pv := PackedVector2Array()
	for v in pts: pv.append(v)
	p2d.polygon = pv; p2d.color = col
	return p2d

func _dp(pts: Array, col: Color) -> void:
	_dr.add_child(_make_poly(pts, col))

func _dp_e(pts: Array, col: Color) -> void:   # engine node → pulse
	var p := _make_poly(pts, col)
	_dr.add_child(p)
	_engine_nodes.append(p)

func _dp_w(pts: Array, col: Color) -> void:   # weapon node → flash when fire
	var p := _make_poly(pts, col)
	_dr.add_child(p)
	_weapon_nodes.append(p)

func _dp_c(pts: Array, col: Color) -> void:   # core node → scale + hue pulse
	var p := _make_poly(pts, col)
	_dr.add_child(p)
	_core_node = p

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	shoot_timer.timeout.connect(_on_shoot_timer)
	_apply_boss_type()
	_apply_phase()
	Audio.play("boss_appear")
	# Khởi tạo charge_cd theo kiểu boss
	match boss_type:
		1: _charge_cd = 3.0   # Interceptor lách ngay sau phase 1
		4: _charge_cd = 8.0
		_: _charge_cd = 999.0  # không bao giờ lao

# ── BOSS TYPE SETUP ───────────────────────────────────────────────────────────
func _apply_boss_type() -> void:
	if sprite:
		var pts: Array = BOSS_POLYGONS[boss_type]
		var packed := PackedVector2Array()
		for p in pts:
			packed.append(p)
		sprite.polygon = packed
		_add_type_details()

func _add_type_details() -> void:
	_clear_dr()
	match boss_type:

		# ══════════ 0 WARSHIP ══════════ tím-lửa, thiết giáp hạm nặng
		0:
			# Armor hull stripes
			_dp([Vector2(-20,-14),Vector2(-10,-14),Vector2(-8,-4),Vector2(-18,-4)],
				Color(0.25, 0.05, 0.35))            # giáp cánh trái — tím đen
			_dp([Vector2(10,-14),Vector2(20,-14),Vector2(18,-4),Vector2(8,-4)],
				Color(0.25, 0.05, 0.35))            # giáp cánh phải
			# Central hull rib
			_dp([Vector2(-3,-10),Vector2(3,-10),Vector2(3,22),Vector2(-3,22)],
				Color(0.45, 0.08, 0.55, 0.65))      # trục thân
			# Bridge tower
			_dp([Vector2(-9,-26),Vector2(9,-26),Vector2(11,-15),Vector2(0,-9),Vector2(-11,-15)],
				Color(0.95, 0.72, 0.0))             # tháp chỉ huy vàng
			# Bridge glass
			_dp([Vector2(-5,-23),Vector2(5,-23),Vector2(6,-16),Vector2(0,-11),Vector2(-6,-16)],
				Color(0.05, 0.9, 1.0, 0.9))         # kính tháp — cyan
			# Left heavy cannon mount
			_dp([Vector2(-35,1),Vector2(-27,-4),Vector2(-24,1),Vector2(-27,5)],
				Color(0.85, 0.28, 0.0))             # gá pháo trái
			# Right heavy cannon mount
			_dp([Vector2(35,1),Vector2(27,-4),Vector2(24,1),Vector2(27,5)],
				Color(0.85, 0.28, 0.0))             # gá pháo phải
			# Left barrel (WEAPON — flashes)
			_dp_w([Vector2(-43,-1),Vector2(-34,-1),Vector2(-34,2),Vector2(-43,2)],
				Color(1.0, 0.6, 0.0))               # nòng trái
			_dp_w([Vector2(34,-1),Vector2(43,-1),Vector2(43,2),Vector2(34,2)],
				Color(1.0, 0.6, 0.0))               # nòng phải
			# Wing mini guns (WEAPON)
			_dp_w([Vector2(-28,-1),Vector2(-23,-5),Vector2(-21,-1),Vector2(-23,3)],
				Color(1.0, 0.08, 0.9))              # súng cánh mini trái
			_dp_w([Vector2(23,-5),Vector2(28,-1),Vector2(23,3),Vector2(21,-1)],
				Color(1.0, 0.08, 0.9))              # súng cánh mini phải
			# Vent panels
			_dp([Vector2(-15,4),Vector2(-8,4),Vector2(-8,13),Vector2(-15,13)],
				Color(1.0, 0.38, 0.08, 0.7))        # thông gió trái
			_dp([Vector2(8,4),Vector2(15,4),Vector2(15,13),Vector2(8,13)],
				Color(1.0, 0.38, 0.08, 0.7))        # thông gió phải
			# Engine nozzles (ANIM — pulse)
			_dp_e([Vector2(-9,23),Vector2(-2,23),Vector2(-2,32),Vector2(-9,32)],
				Color(1.0, 0.52, 0.0))              # động cơ trái
			_dp_e([Vector2(2,23),Vector2(9,23),Vector2(9,32),Vector2(2,32)],
				Color(1.0, 0.52, 0.0))              # động cơ phải
			_dp_e([Vector2(-11,28),Vector2(11,28),Vector2(12,35),Vector2(-12,35)],
				Color(1.0, 0.88, 0.15, 0.5))        # glow động cơ rộng
			# Nose sensor (WEAPON)
			_dp_w([Vector2(-3,-30),Vector2(3,-30),Vector2(3,-26),Vector2(-3,-26)],
				Color(1.0, 0.1, 0.95))              # cảm biến mũi
			# Core energy cell (CORE — scale pulse)
			_dp_c([Vector2(-6,-3),Vector2(6,-3),Vector2(7,4),Vector2(0,8),Vector2(-7,4)],
				Color(0.95, 0.15, 1.0, 0.55))       # lõi năng lượng

		# ══════════ 1 INTERCEPTOR ══════════ xanh-điện, chiến đấu cơ thon
		1:
			# Body spine
			_dp([Vector2(-2,-38),Vector2(2,-38),Vector2(2,28),Vector2(-2,28)],
				Color(0.0, 0.6, 0.9, 0.5))          # trục thân
			# Cockpit outer
			_dp([Vector2(-5,-36),Vector2(5,-36),Vector2(7,-23),Vector2(0,-15),Vector2(-7,-23)],
				Color(0.0, 0.75, 1.0))              # buồng lái
			# Cockpit glass
			_dp([Vector2(-3,-33),Vector2(3,-33),Vector2(4,-24),Vector2(0,-18),Vector2(-4,-24)],
				Color(0.55, 1.0, 1.0, 0.9))         # kính lái sáng
			# Left wing edge
			_dp([Vector2(-16,-8),Vector2(-10,-12),Vector2(-8,-8),Vector2(-10,-4)],
				Color(0.0, 0.5, 0.85))              # gờ cánh trái đậm
			_dp([Vector2(10,-12),Vector2(16,-8),Vector2(10,-4),Vector2(8,-8)],
				Color(0.0, 0.5, 0.85))              # gờ cánh phải đậm
			# Side gun pods (WEAPON)
			_dp_w([Vector2(-15,4),Vector2(-10,1),Vector2(-8,4),Vector2(-10,7)],
				Color(0.15, 1.0, 0.55))             # pod súng trái
			_dp_w([Vector2(10,1),Vector2(15,4),Vector2(10,7),Vector2(8,4)],
				Color(0.15, 1.0, 0.55))             # pod súng phải
			# Thruster arm
			_dp([Vector2(-13,16),Vector2(-8,16),Vector2(-8,24),Vector2(-13,24)],
				Color(0.0, 0.45, 0.75))             # thanh đẩy trái
			_dp([Vector2(8,16),Vector2(13,16),Vector2(13,24),Vector2(8,24)],
				Color(0.0, 0.45, 0.75))             # thanh đẩy phải
			# Afterburner (ANIM)
			_dp_e([Vector2(-13,24),Vector2(-8,24),Vector2(-8,36),Vector2(-13,36)],
				Color(0.0, 1.0, 0.55))              # luồng đẩy trái
			_dp_e([Vector2(8,24),Vector2(13,24),Vector2(13,36),Vector2(8,36)],
				Color(0.0, 1.0, 0.55))              # luồng đẩy phải
			_dp_e([Vector2(-7,32),Vector2(7,32),Vector2(5,38),Vector2(-5,38)],
				Color(0.3, 1.0, 0.9, 0.5))          # hào quang đẩy trung tâm
			# Wing stripe accents
			_dp([Vector2(-14,-2),Vector2(-9,-2),Vector2(-9,12),Vector2(-14,12)],
				Color(0.0, 0.85, 1.0, 0.4))         # vệt cánh trái
			_dp([Vector2(9,-2),Vector2(14,-2),Vector2(14,12),Vector2(9,12)],
				Color(0.0, 0.85, 1.0, 0.4))         # vệt cánh phải
			# Nose spike (WEAPON)
			_dp_w([Vector2(-2,-40),Vector2(2,-40),Vector2(2,-36),Vector2(-2,-36)],
				Color(0.4, 1.0, 1.0))               # mũi giáo
			# Core energy (CORE)
			_dp_c([Vector2(-5,-12),Vector2(5,-12),Vector2(5,-6),Vector2(0,-3),Vector2(-5,-6)],
				Color(0.0, 1.0, 0.75, 0.6))         # lõi năng lượng

		# ══════════ 2 DREADNOUGHT ══════════ đỏ-dung nham, pháo đài siêu nặng
		2:
			# Thick hull bands
			_dp([Vector2(-50,0),Vector2(50,0),Vector2(48,8),Vector2(-48,8)],
				Color(0.22, 0.04, 0.04))            # đai giáp ngang
			_dp([Vector2(-30,-8),Vector2(30,-8),Vector2(28,-2),Vector2(-28,-2)],
				Color(0.3, 0.06, 0.06))             # đai giáp trên
			# Left/right armor plates
			_dp([Vector2(-44,-2),Vector2(-30,-10),Vector2(-26,-2),Vector2(-36,4)],
				Color(0.45, 0.08, 0.04, 0.85))      # tấm giáp cánh trái
			_dp([Vector2(30,-10),Vector2(44,-2),Vector2(36,4),Vector2(26,-2)],
				Color(0.45, 0.08, 0.04, 0.85))      # tấm giáp cánh phải
			# Bridge
			_dp([Vector2(-7,-20),Vector2(7,-20),Vector2(9,-10),Vector2(0,-5),Vector2(-9,-10)],
				Color(0.9, 0.5, 0.0))               # tháp chỉ huy
			_dp([Vector2(-4,-17),Vector2(4,-17),Vector2(5,-11),Vector2(0,-7),Vector2(-5,-11)],
				Color(0.1, 0.85, 1.0, 0.85))        # kính tháp
			# Main turrets (WEAPON — flash)
			_dp_w([Vector2(-46,5),Vector2(-38,1),Vector2(-35,5),Vector2(-38,9)],
				Color(1.0, 0.32, 0.0))              # turret trái
			_dp_w([Vector2(46,5),Vector2(38,1),Vector2(35,5),Vector2(38,9)],
				Color(1.0, 0.32, 0.0))              # turret phải
			# Turret barrels
			_dp_w([Vector2(-54,4),Vector2(-46,4),Vector2(-46,6),Vector2(-54,6)],
				Color(1.0, 0.6, 0.0))               # nòng pháo trái
			_dp_w([Vector2(46,4),Vector2(54,4),Vector2(54,6),Vector2(46,6)],
				Color(1.0, 0.6, 0.0))               # nòng pháo phải
			# Lava vents
			_dp([Vector2(-22,10),Vector2(-16,10),Vector2(-16,18),Vector2(-22,18)],
				Color(1.0, 0.3, 0.0, 0.75))         # khe dung nham trái
			_dp([Vector2(-8,12),Vector2(-2,12),Vector2(-2,20),Vector2(-8,20)],
				Color(1.0, 0.2, 0.0, 0.75))         # khe dung nham trái 2
			_dp([Vector2(2,12),Vector2(8,12),Vector2(8,20),Vector2(2,20)],
				Color(1.0, 0.2, 0.0, 0.75))         # khe dung nham phải 2
			_dp([Vector2(16,10),Vector2(22,10),Vector2(22,18),Vector2(16,18)],
				Color(1.0, 0.3, 0.0, 0.75))         # khe dung nham phải
			# Engine blocks (ANIM)
			_dp_e([Vector2(-14,25),Vector2(-4,25),Vector2(-4,33),Vector2(-14,33)],
				Color(1.0, 0.42, 0.0))              # động cơ trái
			_dp_e([Vector2(4,25),Vector2(14,25),Vector2(14,33),Vector2(4,33)],
				Color(1.0, 0.42, 0.0))              # động cơ phải
			_dp_e([Vector2(-16,30),Vector2(16,30),Vector2(16,36),Vector2(-16,36)],
				Color(1.0, 0.75, 0.1, 0.45))        # glow động cơ
			# Core crystal (CORE)
			_dp_c([Vector2(0,-20),Vector2(8,-12),Vector2(8,0),Vector2(0,6),Vector2(-8,0),Vector2(-8,-12)],
				Color(1.0, 0.12, 0.05, 0.5))        # lõi dung nham

		# ══════════ 3 CARRIER ══════════ vàng-xanh, hàng không mẫu hạm
		3:
			# Hull deck plates
			_dp([Vector2(-38,-4),Vector2(38,-4),Vector2(36,2),Vector2(-36,2)],
				Color(0.3, 0.28, 0.0))              # boong tàu giữa
			_dp([Vector2(-42,2),Vector2(42,2),Vector2(40,10),Vector2(-40,10)],
				Color(0.25, 0.22, 0.0))             # boong tàu dưới
			# Bridge tower
			_dp([Vector2(-7,-16),Vector2(7,-16),Vector2(9,-8),Vector2(0,-3),Vector2(-9,-8)],
				Color(0.8, 0.72, 0.0))              # đài chỉ huy
			_dp([Vector2(-4,-13),Vector2(4,-13),Vector2(5,-8),Vector2(0,-4),Vector2(-5,-8)],
				Color(0.05, 0.85, 1.0, 0.9))        # kính đài
			# Flight deck lights (runway strip)
			for _i in range(5):
				var lx := -20.0 + _i * 10.0
				_dp([Vector2(lx,-1),Vector2(lx+4,-1),Vector2(lx+4,2),Vector2(lx,2)],
					Color(0.9, 0.9, 0.2, 0.8))      # đèn đường băng
			# Hangar bay doors (WEAPON color — animated during summon)
			_dp_w([Vector2(-32,6),Vector2(-20,6),Vector2(-20,18),Vector2(-32,18)],
				Color(0.0, 0.45, 0.9, 0.85))        # khoang bay trái
			_dp_w([Vector2(-8,8),Vector2(8,8),Vector2(8,20),Vector2(-8,20)],
				Color(0.0, 0.5, 1.0, 0.85))         # khoang bay giữa
			_dp_w([Vector2(20,6),Vector2(32,6),Vector2(32,18),Vector2(20,18)],
				Color(0.0, 0.45, 0.9, 0.85))        # khoang bay phải
			# Engine pods (ANIM)
			_dp_e([Vector2(-42,2),Vector2(-36,-2),Vector2(-34,2),Vector2(-36,6)],
				Color(1.0, 0.82, 0.0))              # pod động cơ trái
			_dp_e([Vector2(42,2),Vector2(36,-2),Vector2(34,2),Vector2(36,6)],
				Color(1.0, 0.82, 0.0))              # pod động cơ phải
			_dp_e([Vector2(-40,4),Vector2(-38,2),Vector2(-36,4),Vector2(-38,6)],
				Color(1.0, 1.0, 0.4, 0.6))          # glow động cơ trái
			_dp_e([Vector2(38,2),Vector2(40,4),Vector2(38,6),Vector2(36,4)],
				Color(1.0, 1.0, 0.4, 0.6))          # glow động cơ phải
			# Defense turrets
			_dp_w([Vector2(-22,-10),Vector2(-18,-14),Vector2(-16,-10),Vector2(-18,-6)],
				Color(1.0, 0.75, 0.0))              # turret phòng thủ trái
			_dp_w([Vector2(18,-14),Vector2(22,-10),Vector2(18,-6),Vector2(16,-10)],
				Color(1.0, 0.75, 0.0))              # turret phòng thủ phải
			# Core power cell (CORE)
			_dp_c([Vector2(-5,-7),Vector2(5,-7),Vector2(6,0),Vector2(0,4),Vector2(-6,0)],
				Color(1.0, 1.0, 0.1, 0.55))         # lõi điện

		# ══════════ 4 MOTHERSHIP ══════════ tím-hồng, đĩa bay siêu lớn
		4:
			# Outer ring segments (alternating)
			for _i in range(12):
				var a0 := TAU * _i / 12.0
				var a1 := TAU * (_i + 0.9) / 12.0
				var r0 := 38.0; var r1 := 46.0
				var pts4 := [
					Vector2(cos(a0)*r0, sin(a0)*r0),
					Vector2(cos(a0)*r1, sin(a0)*r1),
					Vector2(cos(a1)*r1, sin(a1)*r1),
					Vector2(cos(a1)*r0, sin(a1)*r0)
				]
				var ring_col := Color(0.55, 0.1, 0.75) if _i % 2 == 0 else Color(0.35, 0.05, 0.5)
				_dp(pts4, ring_col)                  # vành ngoài
			# Inner ring
			for _i in range(8):
				var a0 := TAU * _i / 8.0
				var a1 := TAU * (_i + 0.88) / 8.0
				var r0 := 22.0; var r1 := 32.0
				var pts4 := [
					Vector2(cos(a0)*r0, sin(a0)*r0),
					Vector2(cos(a0)*r1, sin(a0)*r1),
					Vector2(cos(a1)*r1, sin(a1)*r1),
					Vector2(cos(a1)*r0, sin(a1)*r0)
				]
				_dp(pts4, Color(0.7, 0.15, 0.9, 0.7)) # vành trong
			# 6 energy pods (WEAPON + ENGINE alternating)
			for _i in range(6):
				var pa := TAU * _i / 6.0
				var px := cos(pa) * 36.0;  var py := sin(pa) * 36.0
				var pts4 := [
					Vector2(px - 4, py - 4), Vector2(px + 4, py - 4),
					Vector2(px + 4, py + 4), Vector2(px - 4, py + 4)
				]
				if _i % 2 == 0:
					_dp_w(pts4, Color(1.0, 0.2, 0.9))   # pod vũ khí
				else:
					_dp_e(pts4, Color(0.5, 0.15, 1.0))  # pod động cơ
			# Core hexagon (CORE — scale pulse)
			_dp_c([Vector2(0,-14),Vector2(12,-7),Vector2(12,7),Vector2(0,14),
				Vector2(-12,7),Vector2(-12,-7)],
				Color(1.0, 0.05, 0.9, 0.6))          # lõi trung tâm
			# Core inner eye
			_dp([Vector2(0,-7),Vector2(6,-3),Vector2(6,3),Vector2(0,7),Vector2(-6,3),Vector2(-6,-3)],
				Color(1.0, 0.6, 1.0, 0.9))           # mắt trung tâm
			# Power conduits (4 beams)
			_dp_e([Vector2(-3,-34),Vector2(3,-34),Vector2(3,-16),Vector2(-3,-16)],
				Color(0.85, 0.3, 1.0, 0.7))          # ống năng lượng trên
			_dp_e([Vector2(-3,16),Vector2(3,16),Vector2(3,34),Vector2(-3,34)],
				Color(0.85, 0.3, 1.0, 0.7))          # ống năng lượng dưới
			_dp_e([Vector2(-34,-3),Vector2(-16,-3),Vector2(-16,3),Vector2(-34,3)],
				Color(0.85, 0.3, 1.0, 0.7))          # ống năng lượng trái
			_dp_e([Vector2(16,-3),Vector2(34,-3),Vector2(34,3),Vector2(16,3)],
				Color(0.85, 0.3, 1.0, 0.7))          # ống năng lượng phải
			# Tractor beam bottom
			_dp([Vector2(-5,36),Vector2(5,36),Vector2(3,44),Vector2(-3,44)],
				Color(0.0, 1.0, 0.9, 0.8))           # chùm kéo dưới

func _physics_process(delta: float) -> void:
	time_elapsed += delta
	# Charge override
	if _charging:
		_charge_remaining -= delta
		velocity = _charge_dir * CHARGE_SPEED * (1.0 + float(boss_type) * 0.08)
		move_and_slide()
		# Kiểm tra chạm player
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if col.get_collider() and (col.get_collider() as Node).is_in_group("player"):
				(col.get_collider() as Node).take_damage(2)
		if _charge_remaining <= 0.0:
			_charging = false
			_charge_cd = randf_range(6.0, 10.0)
			shoot_timer.start()
			# Khôi phục màu bosss đúng phase sau khi lao
			if is_instance_valid(sprite):
				var ph_idx := 0
				match current_phase:
					Phase.TWO:   ph_idx = 1
					Phase.THREE: ph_idx = 2
				var tw := create_tween()
				tw.tween_property(sprite, "color",
					(BOSS_COLORS[boss_type] as Array)[ph_idx], 0.25) \
					.set_trans(Tween.TRANS_SINE)
		return
	_update_anim(delta)
	_special_cd -= delta
	if _special_cd <= 0.0:
		_special_cd = 5.5 - float(current_phase) * 1.2
		_do_special()
	_charge_cd -= delta
	if _charge_cd <= 0.0 and current_phase != Phase.ONE \
			and BOSS_CAN_CHARGE[boss_type]:
		_start_charge()
	_update_phase()
	_move(delta)

# ── PHASE MANAGEMENT ──────────────────────────────────────────────────────────
func _update_phase() -> void:
	var ratio := float(hp) / float(max_hp)
	var new_phase: Phase

	if ratio > PHASE2_HP:
		new_phase = Phase.ONE
	elif ratio > PHASE3_HP:
		new_phase = Phase.TWO
	else:
		new_phase = Phase.THREE

	if new_phase != current_phase:
		current_phase = new_phase
		_apply_phase()

func _apply_phase() -> void:
	var colors: Array = BOSS_COLORS[boss_type]
	# Shoot timer per boss_type per phase
	# Warship: nhanh | Interceptor: chậm | Dreadnought: chậm | Carrier: vừa | Mothership: vừa
	const SHOOT_TIMES: Array = [
		[0.7,  0.38, 0.22],   # 0 Warship — xả đạn rất nhanh
		[3.5,  2.4,  1.6 ],   # 1 Interceptor — hiếm khi bắn
		[2.8,  2.0,  1.3 ],   # 2 Dreadnought — chậm, gọi quân là chính
		[2.2,  1.6,  1.0 ],   # 3 Carrier — bắn vừa + gọi quân
		[1.2,  0.7,  0.45],   # 4 Mothership — all-rounder
	]
	var phase_idx: int
	match current_phase:
		Phase.ONE:   phase_idx = 0; if sprite: sprite.color = colors[0]
		Phase.TWO:   phase_idx = 1; if sprite: sprite.color = colors[1]
		Phase.THREE: phase_idx = 2; if sprite: sprite.color = colors[2]
		_:           phase_idx = 0
	shoot_timer.wait_time = (SHOOT_TIMES[boss_type] as Array)[phase_idx]
	shoot_timer.start()
	_anim_phase_transition(phase_idx)

# ── MOVEMENT (dispatch by boss_type) ─────────────────────────────────────────
func _move(_delta: float) -> void:
	match boss_type:
		0: _move_warship()
		1: _move_interceptor()
		2: _move_dreadnought()
		3: _move_carrier()
		4: _move_mothership()

# 0 Warship — ngang bình thường + sin Y nhẹ
func _move_warship() -> void:
	var vp_w := get_viewport_rect().size.x
	velocity.x = move_dir * speed
	velocity.y = sin(time_elapsed * 1.2) * 30.0
	move_and_slide()
	if position.x > vp_w - 60.0: move_dir = -1.0
	elif position.x < 60.0:      move_dir = 1.0

# 1 Interceptor — rất nhanh, lắc Y mạnh
func _move_interceptor() -> void:
	var vp_w := get_viewport_rect().size.x
	velocity.x = move_dir * speed * 1.7
	velocity.y = sin(time_elapsed * 2.8) * 55.0
	move_and_slide()
	if position.x > vp_w - 50.0: move_dir = -1.0
	elif position.x < 50.0:      move_dir = 1.0

# 2 Dreadnought — rất chậm, gần như không lắc Y
func _move_dreadnought() -> void:
	var vp_w := get_viewport_rect().size.x
	velocity.x = move_dir * speed * 0.4
	velocity.y = sin(time_elapsed * 0.5) * 10.0
	move_and_slide()
	if position.x > vp_w - 80.0: move_dir = -1.0
	elif position.x < 80.0:      move_dir = 1.0

# 3 Carrier — vẽ hình số 8 ngang màn hình
func _move_carrier() -> void:
	var vp := get_viewport_rect().size
	position.x = vp.x * 0.5 + sin(time_elapsed * 0.7) * (vp.x * 0.36)
	position.y = 115.0 + sin(time_elapsed * 1.4) * 38.0

# 4 Mothership — vòng tròn chậm, uy nghi
func _move_mothership() -> void:
	var vp := get_viewport_rect().size
	position.x = vp.x * 0.5 + cos(time_elapsed * 0.4) * (vp.x * 0.3)
	position.y = 130.0 + sin(time_elapsed * 0.4) * 44.0

# ── SHOOT PATTERNS ────────────────────────────────────────────────────────────
func _on_shoot_timer() -> void:
	Audio.play("boss_shoot", -4.0)
	_anim_fire_flash()
	match current_phase:
		Phase.ONE:   _phase1_attack()
		Phase.TWO:   _phase2_attack()
		Phase.THREE: _phase3_attack()

# ── PHASE 1 (> 66% HP): phụ thuộc boss_type ─────────────────────────────────
var _p1_step: int = 0
func _phase1_attack() -> void:
	if boss_type == 0:       # Warship
		match _p1_step % 3:
			0: _shoot_straight()
			1: _shoot_aimed()
			2: _shoot_cross()
	elif boss_type == 1:     # Interceptor — burst ngắm
		if _p1_step % 2 == 0: _shoot_aimed()
		else:                  _shoot_aimed_spread()
	elif boss_type == 2:     # Dreadnought — vòng tròn nặng
		match _p1_step % 3:
			0: _shoot_circle(8)
			1: _shoot_straight()
			2: _shoot_double_ring()
	elif boss_type == 3:     # Carrier — xoắn ốc + tản
		match _p1_step % 3:
			0: _shoot_aimed_spread()
			1: _shoot_straight()
			2: _shoot_spiral()
	else:                    # Mothership — full pattern
		match _p1_step % 4:
			0: _shoot_circle(10)
			1: _shoot_aimed()
			2: _shoot_spiral()
			3: _shoot_cross()
	_p1_step += 1

# ── PHASE 2 (33–66% HP): 4 kiểu ────────────────────────────────────────────────
var _p2_step: int = 0
func _phase2_attack() -> void:
	match _p2_step % 4:
		0: _shoot_circle(8)          # giảm từ 12 → 8
		1: _shoot_double_ring()      # 2 vòng xen kẽ
		2: _shoot_aimed_spread()     # ngắm + 2 đạn lệch hai bên
		3: _shoot_spiral()           # xoắn ốc 6 đạn
	_p2_step += 1

# ── PHASE 3 (< 33% HP): tổng hợp tất cả ─────────────────────────────────────
var _p3_step: int = 0
func _phase3_attack() -> void:
	match _p3_step % 6:
		0: _shoot_circle(10)         # giảm từ 16 → 10
		1: _shoot_aimed_burst(4)     # giảm từ 6 → 4
		2: _shoot_double_ring()
		3: _shoot_cross()
		4: _shoot_spiral()
		5: _shoot_aimed_spread()
	_p3_step += 1

# ── CÁC PATTERN ───────────────────────────────────────────────────────────────
func _shoot_straight() -> void:
	for i in range(-1, 2):
		_spawn_bullet(Vector2(i * 0.3, 1.0).normalized())

func _shoot_aimed() -> void:
	var p := _get_player_dir()
	if p != Vector2.ZERO:
		_spawn_bullet(p)

func _shoot_cross() -> void:
	for angle_deg in [0, 90, 180, 270]:
		var a := deg_to_rad(float(angle_deg))
		_spawn_bullet(Vector2(cos(a), sin(a)))

func _shoot_aimed_spread() -> void:
	var p := _get_player_dir()
	if p == Vector2.ZERO: p = Vector2.DOWN
	for offset in [-20.0, 0.0, 20.0]:
		_spawn_bullet(p.rotated(deg_to_rad(offset)))

func _shoot_aimed_burst(count: int) -> void:
	var p := _get_player_dir()
	if p == Vector2.ZERO: p = Vector2.DOWN
	var clamped := mini(count, 4)   # tối đa 4 đạn / burst
	for i in range(clamped):
		var spread := randf_range(-0.18, 0.18)
		_spawn_bullet(p.rotated(spread))

func _shoot_circle(count: int = 8) -> void:
	for i in range(count):
		var angle := TAU * i / count
		_spawn_bullet(Vector2(cos(angle), sin(angle)))

func _shoot_double_ring() -> void:
	var count := 7   # giảm từ 10 → 7 (14 → 10 đạn tổng)
	for i in range(count):
		var a1 := TAU * i / count
		var a2 := TAU * (i + 0.5) / count
		_spawn_bullet(Vector2(cos(a1), sin(a1)))
		_spawn_bullet(Vector2(cos(a2), sin(a2)))

func _shoot_spiral() -> void:
	# Giảm từ 8 → 6 đạn
	var base_angle := float(Time.get_ticks_msec()) * 0.002
	for i in range(6):
		var a := base_angle + TAU * i / 6.0
		_spawn_bullet(Vector2(cos(a), sin(a)))

func _get_player_dir() -> Vector2:
	var p := get_tree().current_scene.get_node_or_null("Player")
	if p == null or not is_instance_valid(p):
		return Vector2.ZERO
	return (p.global_position - global_position).normalized()

func _spawn_bullet(dir: Vector2, btype: int = -1, spd: float = 280.0) -> void:
	var bullet = BULLET_SCENE.instantiate()
	bullet.global_position  = global_position
	bullet.direction        = dir
	bullet.speed            = spd
	bullet.is_enemy_bullet  = true
	bullet.is_boss_bullet   = true
	bullet.bullet_type      = BOSS_BULLET_TYPES[boss_type] if btype < 0 else btype
	var container = get_tree().current_scene.get_node_or_null("BulletContainer")
	if container:
		container.add_child(bullet)

# ── CHIÊU ĐẶC TRƯNG MỖI BOSS ─────────────────────────────────────────────────
func _do_special() -> void:
	if _is_dying or _charging: return
	_anim_pre_special()
	match boss_type:
		0: _special_warship_barrage()        # xả đạn tạp trung
		1: _special_interceptor_dash()       # teleport rồi bắn chéo
		2: _special_dreadnought_summon()     # gọi quân + quet đạn ICE
		3: _special_carrier_summon()         # gọi quân + tản đạn
		4: _special_mothership_nova()        # nova + gọi quân

# 0 Warship: giảm từ 6 → 4 đạn FIRE
func _special_warship_barrage() -> void:
	for i in range(4):
		if not is_instance_valid(self): return
		var d := _get_player_dir()
		if d == Vector2.ZERO: d = Vector2.DOWN
		_spawn_bullet(d.rotated(randf_range(-0.12, 0.12)), 2, 320.0)
		await get_tree().create_timer(0.09).timeout

# 1 Interceptor: teleport đến X của player, rồi bắn 4 hướng chéo ELECTRIC
func _special_interceptor_dash() -> void:
	var p := get_tree().current_scene.get_node_or_null("Player")
	if p and is_instance_valid(p):
		position.x = clamp((p as Node2D).global_position.x, 50.0, get_viewport_rect().size.x - 50.0)
	for angle_deg in [45, 135, 225, 315]:
		var a := deg_to_rad(float(angle_deg))
		_spawn_bullet(Vector2(cos(a), sin(a)), 1, 300.0)

# 2 Dreadnought: gọi 3 enemy + quét đạn ICE để cản đường player
func _special_dreadnought_summon() -> void:
	_summon_enemies(3)
	await get_tree().create_timer(0.6).timeout
	if _is_dying or not is_instance_valid(self): return
	for i in range(9):
		var frac := float(i) / 8.0
		var angle: float = lerp(-PI * 0.45, PI * 0.45, frac)
		_spawn_bullet(Vector2(sin(angle), cos(angle)), 3, 100.0)

# 3 Carrier: gọi 5 enemy, bắn tản nộ EXPLOSIVE
func _special_carrier_summon() -> void:
	_summon_enemies(5)
	await get_tree().create_timer(0.4).timeout
	if _is_dying or not is_instance_valid(self): return
	var d := _get_player_dir()
	if d == Vector2.ZERO: d = Vector2.DOWN
	for offset in [-0.55, -0.25, 0.0, 0.25, 0.55]:
		_spawn_bullet(d.rotated(offset), 4, 300.0)

# 2 Dreadnought (cũ — giữ để dùng trong phase 3 nếu muốn)
func _special_dreadnought_sweep() -> void:
	for i in range(13):
		var frac := float(i) / 12.0
		var angle: float = lerp(-PI * 0.5, PI * 0.5, frac)
		_spawn_bullet(Vector2(sin(angle), cos(angle)), 3, 110.0)

# 3 Carrier (cũ)
func _special_carrier_drones() -> void:
	var d := _get_player_dir()
	if d == Vector2.ZERO: d = Vector2.DOWN
	for offset in [-0.5, -0.18, 0.18, 0.5]:
		_spawn_bullet(d.rotated(offset), 4, 360.0)

# 4 Mothership: giảm từ 24 → 14 đạn nova
func _special_mothership_nova() -> void:
	for i in range(14):
		var angle := TAU * float(i) / 14.0
		_spawn_bullet(Vector2(cos(angle), sin(angle)), 0, 200.0)
	var d := _get_player_dir()
	if d != Vector2.ZERO:
		for offset in [-0.25, 0.0, 0.25]:
			_spawn_bullet(d.rotated(offset), 0, 340.0)
	_summon_enemies(2)

# ── GỌI QUÂN (Dreadnought / Carrier / Mothership) ─────────────────────────────────
func _summon_enemies(count: int) -> void:
	var spawner := get_tree().current_scene.get_node_or_null("EnemySpawner")
	var wm      := get_tree().current_scene.get_node_or_null("WaveManager")
	if spawner == null: return
	var vp := get_viewport_rect().size
	for i in range(count):
		var enemy = ENEMY_SCENE.instantiate()
		enemy.enemy_type = randi() % 3
		enemy.base_speed = 80.0 + randf() * 40.0
		enemy.hp = 2
		enemy.max_hp = 2
		enemy.score_value = 100
		var half: float = count * 0.5
		var offset_x := (float(i) - half) * (vp.x * 0.18)
		enemy.global_position = Vector2(
			clamp(global_position.x + offset_x, 60.0, vp.x - 60.0),
			global_position.y + randf_range(60.0, 120.0)
		)
		if wm and wm.has_method("_on_enemy_died"):
			enemy.died.connect(wm._on_enemy_died)
			wm.enemies_alive += 1
		spawner.add_child(enemy)

# ── CHARGE (lao thẳng về phía player) ────────────────────────────────────────
func _start_charge() -> void:
	if _is_dying: return
	var p := get_tree().current_scene.get_node_or_null("Player")
	if p == null or not is_instance_valid(p): return
	_charge_dir = (p.global_position - global_position).normalized()
	_charge_remaining = CHARGE_DURATION
	_charging = true
	shoot_timer.stop()
	_anim_charge_windup()
	# Interceptor rạp tới lần nữa nhanh hơn
	_charge_cd = randf_range(3.0, 5.5) if boss_type == 1 else randf_range(6.0, 10.0)

# ── HEALTH ────────────────────────────────────────────────────────────────────
func take_damage(dmg: int = 1) -> void:
	if _is_dying:
		return
	hp -= dmg
	var main = get_tree().current_scene
	if main and main.has_method("update_boss_hp"):
		main.update_boss_hp(max(hp, 0))
	if hp <= 0:
		_die()

func _die() -> void:
	if _is_dying:
		return
	_is_dying = true
	var main = get_tree().current_scene
	if main and main.has_method("add_score"):
		main.add_score(score_value)
		main.hide_boss_hp()
	if main and main.has_method("screen_shake"):
		main.screen_shake(18.0, 0.65)
	_drop_boss_reward()
	emit_signal("died")
	queue_free()

func _drop_boss_reward() -> void:
	var container := get_tree().current_scene.get_node_or_null("BulletContainer")
	if container == null: return
	# Luôn rơi 2 trái tim
	for i in range(2):
		var heart = HEART_SCENE.instantiate()
		heart.global_position = global_position + Vector2(randf_range(-50.0, 50.0), randf_range(-20.0, 20.0))
		container.add_child(heart)
	# Powerup đặc trưng theo boss_type
	# 0=Warship→FIRE, 1=Interceptor→ELECTRIC, 2=Dreadnought→ICE, 3=Carrier→EXPLOSIVE, 4=Mothership→UPGRADE
	var reward_types: Array = [2, 1, 3, 4, 6]
	var powerup = POWERUP_SCENE.instantiate()
	powerup.global_position = global_position
	powerup.powerup_type = reward_types[boss_type]
	container.add_child(powerup)
	# Cũng rơi thêm 1 UPGRADE nếu phase 3
	if current_phase == Phase.THREE:
		var bonus = POWERUP_SCENE.instantiate()
		bonus.global_position = global_position + Vector2(30.0, 0.0)
		bonus.powerup_type = 6
		container.add_child(bonus)

# ══ ANIMATION SYSTEM ══════──────────────────────────────────────────

func _update_anim(delta: float) -> void:
	if _is_dying: return
	_anim_time += delta

	# 1) Nhấp nháy động cơ: sóng sin độ sáng
	var ep := 0.55 + 0.45 * sin(_anim_time * 4.5)
	for eng in _engine_nodes:
		if is_instance_valid(eng):
			var base_col: Color = (eng as Polygon2D).color
			(eng as Polygon2D).color = Color(base_col.r, base_col.g, base_col.b,
				clampf(ep, 0.3, 1.0))

	# 2) Vũ khí nhấp nháy nhanh hơn
	var wp := 0.6 + 0.4 * sin(_anim_time * 7.0)
	for w in _weapon_nodes:
		if is_instance_valid(w):
			var bc: Color = (w as Polygon2D).color
			(w as Polygon2D).color = Color(bc.r, bc.g, bc.b, clampf(wp, 0.45, 1.0))

	# 3) Lõi: scale pulse nhẹ
	if is_instance_valid(_core_node):
		var sc := 1.0 + 0.1 * sin(_anim_time * 3.2)
		_core_node.scale = Vector2(sc, sc)

	# 4) Boss lắc lư nhẹ (rotation sway)
	if is_instance_valid(sprite) and not _charging:
		sprite.rotation = sin(_anim_time * 1.6) * deg_to_rad(1.8)

# Phóng to + flash màu khi chuyển phase
func _anim_phase_transition(phase_idx: int) -> void:
	if not is_instance_valid(sprite): return
	var target_col: Color = (BOSS_COLORS[boss_type] as Array)[phase_idx]
	# Scale bounce
	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.12) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.25) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# Màu flash riêng biệt
	var cw := create_tween()
	cw.tween_property(sprite, "color", Color.WHITE, 0.07)
	cw.tween_property(sprite, "color", target_col, 0.35) \
		.set_trans(Tween.TRANS_SINE)

# Đỏ đỏ nhấp màu vàng/trắng trước chiêu đặc biệt
func _anim_pre_special() -> void:
	if not is_instance_valid(sprite): return
	var ph_idx := 0
	match current_phase:
		Phase.TWO:   ph_idx = 1
		Phase.THREE: ph_idx = 2
	var base_col: Color = (BOSS_COLORS[boss_type] as Array)[ph_idx]
	var warn := Color(1.0, 0.9, 0.1)
	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_property(sprite, "color", warn, 0.08)
	tw.tween_property(sprite, "color", base_col, 0.08)
	tw.tween_property(sprite, "color", warn, 0.08)
	tw.tween_property(sprite, "color", base_col, 0.12)

# Xây trắng dần + rung trước khi lao
func _anim_charge_windup() -> void:
	if not is_instance_valid(sprite): return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "color", Color(2.0, 2.0, 2.0, 1.0), 0.3) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	for w in _weapon_nodes:
		if is_instance_valid(w):
			create_tween().tween_property(w, "color",
				 Color(2.0, 2.0, 0.5, 1.0), 0.3).set_trans(Tween.TRANS_EXPO)

# Flash nhanh vũ khí khi bắn
func _anim_fire_flash() -> void:
	for w in _weapon_nodes:
		if is_instance_valid(w):
			var wn := w as Polygon2D
			var tw := create_tween()
			tw.set_parallel(false)
			tw.tween_property(wn, "color", Color(1.8, 1.8, 0.6, 1.0), 0.04)
			tw.tween_property(wn, "color", wn.color, 0.14) \
				.set_trans(Tween.TRANS_SINE)
