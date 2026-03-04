extends Node
class_name ThemePack
# theme_pack.gd — Định nghĩa 4 gói giao diện (visual pack) cho game.
# Truy cập qua ThemePack.PACKS[PlayerData.active_theme]
# Mỗi pack đổi: nền, lưới, tinh vân, sao, hành tinh, màu enemy + boss.
# Gameplay không thay đổi.

const PACKS: Array = [
	# ═══════════════════  0  DEEP SPACE  (mặc định, miễn phí)  ═══════════════════
	{
		"name":    "Deep Space",
		"icon":    "🌌",
		"price":   0,
		"desc":    "Không gian thẩm tím cổ điển",
		"accent":  Color(0.4, 0.7, 1.0),
		# Background gradient (4 góc: top-left, top-right, bot-right, bot-left)
		"bg_top":  Color(0.010, 0.008, 0.055),
		"bg_bot":  Color(0.002, 0.002, 0.022),
		# Grid nối quan điểm
		"grid":    Color(0.12, 0.40, 0.88),
		# Dải ngân hà
		"galaxy":  Color(0.52, 0.42, 0.80),
		# Tinh vân
		"nebulae": [Color(0.28,0.14,0.88), Color(0.08,0.32,0.92), Color(0.90,0.12,0.55),
		            Color(0.12,0.72,0.65), Color(0.65,0.20,0.92), Color(0.92,0.38,0.10),
		            Color(0.18,0.55,0.88)],
		# Màu sao
		"stars":   [Color(1.00,1.00,1.00,0.45), Color(0.72,0.83,1.00,0.55),
		            Color(1.00,0.93,0.65,0.62), Color(0.90,0.72,1.00,0.52), Color(0.65,1.00,0.88,0.48)],
		# Sao băng
		"shooters":[Color(1.0,1.0,1.0), Color(0.85,0.90,1.0), Color(1.00,0.95,0.72), Color(0.72,0.88,1.0)],
		# Hành tinh: [body, glow, has_ring, ring_tilt, rx, ry, px_ratio, py_ratio]
		"planets": [
			[Color(0.12,0.10,0.30), Color(0.40,0.32,0.90), false, 0.0,  66.0, 0.83, 0.17],
			[Color(0.08,0.20,0.28), Color(0.18,0.72,0.85), true,  0.23, 40.0, 0.14, 0.30],
			[Color(0.26,0.16,0.09), Color(0.74,0.50,0.20), false, 0.0,  23.0, 0.52, 0.09],
		],
		# Màu enemy: [Scout, Fighter, Bomber]
		"enemy": [Color(1.0,0.25,0.1), Color(0.2,0.8,1.0), Color(0.55,0.1,0.9)],
		# Màu boss: 5 loại × [phase1, phase2, phase3]
		"boss": [
			[Color(0.8,0.2,0.8),   Color(1.0,0.5,0.0),  Color(1.0,0.1,0.1)],   # Warship
			[Color(0.1,0.6,1.0),   Color(0.0,1.0,0.9),  Color(0.1,1.0,0.4)],   # Interceptor
			[Color(0.55,0.12,0.08),Color(0.85,0.28,0.0),Color(1.0,0.05,0.05)],  # Dreadnought
			[Color(0.6,0.55,0.05), Color(0.9,0.85,0.0), Color(1.0,1.0,0.2)],   # Carrier
			[Color(0.65,0.65,0.8), Color(0.9,0.3,0.95), Color(1.0,0.05,0.85)], # Mothership
		],
	},

	# ═══════════════════  1  FIRESTORM  (Lửa + dung nham, 150 coins)  ═══════════
	{
		"name":    "Firestorm",
		"icon":    "🔥",
		"price":   150,
		"desc":    "Không gian lửa dung nham hừng hực",
		"accent":  Color(1.0, 0.45, 0.05),
		"bg_top":  Color(0.050, 0.010, 0.000),
		"bg_bot":  Color(0.018, 0.004, 0.000),
		"grid":    Color(0.88, 0.22, 0.05),
		"galaxy":  Color(0.80, 0.30, 0.05),
		"nebulae": [Color(0.90,0.12,0.02), Color(0.92,0.38,0.02), Color(0.88,0.55,0.02),
		            Color(0.75,0.08,0.30), Color(0.70,0.08,0.01), Color(0.65,0.20,0.00),
		            Color(1.00,0.55,0.05)],
		"stars":   [Color(1.0,1.0,0.9,0.5), Color(1.0,0.85,0.55,0.5),
		            Color(1.0,0.65,0.3,0.55), Color(1.0,0.78,0.45,0.48), Color(1.0,0.92,0.7,0.42)],
		"shooters":[Color(1.0,0.7,0.2), Color(1.0,0.88,0.4), Color(1.0,1.0,0.8), Color(1.0,0.5,0.1)],
		"planets": [
			[Color(0.28,0.06,0.02), Color(0.92,0.28,0.04), false, 0.0,  62.0, 0.82, 0.18],
			[Color(0.22,0.10,0.00), Color(1.00,0.55,0.08), true,  0.20, 38.0, 0.15, 0.28],
			[Color(0.18,0.08,0.00), Color(0.80,0.38,0.02), false, 0.0,  22.0, 0.50, 0.10],
		],
		"enemy": [Color(1.0,0.85,0.05), Color(1.0,0.35,0.05), Color(0.90,0.10,0.50)],
		"boss": [
			[Color(0.70,0.14,0.04), Color(1.00,0.50,0.00), Color(1.00,0.90,0.10)],
			[Color(0.90,0.35,0.00), Color(1.00,0.70,0.00), Color(1.00,0.30,0.00)],
			[Color(0.60,0.08,0.00), Color(0.90,0.25,0.00), Color(1.00,0.04,0.00)],
			[Color(0.70,0.52,0.00), Color(1.00,0.80,0.00), Color(1.00,0.50,0.05)],
			[Color(0.80,0.20,0.00), Color(1.00,0.45,0.00), Color(0.90,0.08,0.00)],
		],
	},

	# ═══════════════════  2  ARCTIC VOID  (Băng tuyết, 150 coins)  ═══════════════
	{
		"name":    "Arctic Void",
		"icon":    "❄️",
		"price":   150,
		"desc":    "Chân không băng giá lạnh lẽo",
		"accent":  Color(0.55, 0.90, 1.0),
		"bg_top":  Color(0.002, 0.010, 0.035),
		"bg_bot":  Color(0.000, 0.004, 0.014),
		"grid":    Color(0.30, 0.85, 1.00),
		"galaxy":  Color(0.58, 0.82, 1.00),
		"nebulae": [Color(0.55,0.80,1.0), Color(0.72,0.92,1.0), Color(0.38,0.68,0.95),
		            Color(0.80,0.95,1.0), Color(0.45,0.72,0.90), Color(0.90,0.95,1.0),
		            Color(0.65,0.88,1.0)],
		"stars":   [Color(1.0,1.0,1.0,0.55), Color(0.80,0.92,1.0,0.52),
		            Color(0.95,0.98,1.0,0.60), Color(0.70,0.88,1.0,0.50), Color(1.0,1.0,1.0,0.38)],
		"shooters":[Color(1.0,1.0,1.0), Color(0.75,0.92,1.0), Color(0.88,0.96,1.0), Color(0.60,0.85,1.0)],
		"planets": [
			[Color(0.10,0.22,0.38), Color(0.42,0.75,1.00), false, 0.0,  60.0, 0.84, 0.16],
			[Color(0.08,0.15,0.25), Color(0.35,0.80,1.00), true,  0.28, 42.0, 0.13, 0.32],
			[Color(0.18,0.28,0.38), Color(0.70,0.90,1.00), false, 0.0,  25.0, 0.51, 0.08],
		],
		"enemy": [Color(0.55,0.88,1.0), Color(0.88,0.95,1.0), Color(0.40,0.72,0.95)],
		"boss": [
			[Color(0.28,0.52,0.82), Color(0.55,0.88,1.00), Color(0.95,0.98,1.00)],
			[Color(0.30,0.82,1.00), Color(0.70,1.00,1.00), Color(0.40,0.90,0.95)],
			[Color(0.15,0.32,0.58), Color(0.38,0.68,0.92), Color(0.62,0.90,1.00)],
			[Color(0.55,0.72,0.88), Color(0.82,0.95,1.00), Color(1.00,1.00,1.00)],
			[Color(0.45,0.68,0.92), Color(0.72,0.90,1.00), Color(0.88,0.60,1.00)],
		],
	},

	# ═══════════════════  3  TOXIC NEBULA  (Axit độc, 200 coins)  ═════════════════
	{
		"name":    "Toxic Nebula",
		"icon":    "☢",
		"price":   200,
		"desc":    "Tinh vân axit phóng xạ bệnh hoạn",
		"accent":  Color(0.3, 1.0, 0.15),
		"bg_top":  Color(0.005, 0.022, 0.008),
		"bg_bot":  Color(0.002, 0.008, 0.003),
		"grid":    Color(0.18, 0.90, 0.12),
		"galaxy":  Color(0.25, 0.72, 0.18),
		"nebulae": [Color(0.15,0.85,0.08), Color(0.55,0.95,0.05), Color(0.30,0.70,0.05),
		            Color(0.72,0.92,0.08), Color(0.08,0.60,0.30), Color(0.80,0.72,0.02),
		            Color(0.12,0.72,0.18)],
		"stars":   [Color(0.90,1.00,0.70,0.50), Color(0.75,1.00,0.55,0.52),
		            Color(1.00,1.00,0.75,0.55), Color(0.60,0.90,0.50,0.45), Color(1.0,1.0,0.9,0.38)],
		"shooters":[Color(0.7,1.0,0.3), Color(0.9,1.0,0.4), Color(1.0,1.0,0.7), Color(0.4,0.9,0.2)],
		"planets": [
			[Color(0.06,0.18,0.06), Color(0.30,0.88,0.10), false, 0.0,  58.0, 0.83, 0.18],
			[Color(0.04,0.14,0.08), Color(0.18,0.72,0.25), true,  0.22, 36.0, 0.15, 0.29],
			[Color(0.12,0.20,0.02), Color(0.68,0.88,0.05), false, 0.0,  22.0, 0.52, 0.10],
		],
		"enemy": [Color(0.75,1.00,0.05), Color(0.25,0.95,0.15), Color(0.55,0.88,0.02)],
		"boss": [
			[Color(0.10,0.65,0.08), Color(0.55,1.00,0.00), Color(0.90,1.00,0.10)],
			[Color(0.20,0.80,0.10), Color(0.50,1.00,0.20), Color(0.10,0.90,0.40)],
			[Color(0.05,0.45,0.02), Color(0.25,0.85,0.00), Color(0.50,1.00,0.00)],
			[Color(0.55,0.75,0.00), Color(0.85,1.00,0.00), Color(1.00,1.00,0.10)],
			[Color(0.15,0.70,0.10), Color(0.30,1.00,0.20), Color(0.00,0.90,0.30)],
		],
	},

	# ═══════════════════  4  AERIAL WARFARE  (250 coins)  ══════════════════════
	{
		"name":    "Aerial Warfare",
		"icon":    "✈",
		"price":   250,
		"desc":    "Aerial Warfare — MiGs vs B-52s in the night sky",
		"accent":  Color(0.85, 0.78, 0.18),
		"shape_mode": "aerial_warfare",
		"bg_top":  Color(0.010, 0.030, 0.012),
		"bg_bot":  Color(0.002, 0.010, 0.004),
		"grid":    Color(0.20, 0.52, 0.12),
		"galaxy":  Color(0.25, 0.55, 0.15),
		"nebulae": [Color(0.12,0.40,0.08), Color(0.55,0.42,0.05), Color(0.72,0.30,0.05),
		            Color(0.08,0.35,0.18), Color(0.60,0.55,0.08), Color(0.35,0.55,0.05),
		            Color(0.18,0.48,0.10)],
		"stars":   [Color(1.0,0.98,0.80,0.50), Color(0.95,0.92,0.68,0.55),
		            Color(1.0,0.85,0.55,0.45), Color(0.88,0.95,0.70,0.48), Color(1.0,1.0,0.9,0.35)],
		"shooters":[Color(1.0,0.92,0.4), Color(0.95,0.78,0.3), Color(1.0,1.0,0.7), Color(0.85,0.65,0.2)],
		"planets": [
			[Color(0.08,0.18,0.06), Color(0.28,0.68,0.12), false, 0.0,  55.0, 0.80, 0.18],
			[Color(0.06,0.14,0.08), Color(0.18,0.55,0.22), true,  0.20, 38.0, 0.14, 0.28],
			[Color(0.12,0.10,0.04), Color(0.58,0.48,0.12), false, 0.0,  22.0, 0.50, 0.10],
		],
		# Màu thân thực tế — VPAF olive drab mỗi phi cơ [MiG-21, MiG-17, Mi-24, MiG-19, Il-28]
		"player_colors": [
			Color(0.20, 0.28, 0.12),  # MiG-21 — xanh ô liu VPAF
			Color(0.22, 0.30, 0.13),  # MiG-17 — xanh ô liu sáng hơn
			Color(0.18, 0.24, 0.10),  # Mi-24  — xanh đậm bọc giáp
			Color(0.21, 0.29, 0.11),  # MiG-19 — ô liu trung
			Color(0.36, 0.32, 0.15),  # Il-28  — kim loại ô liu
		],
		# Màu enemy — sơn SEA camo Mỹ sáng hơn để dễ nhìn: F-4/F-105/B-52
		"enemy": [Color(0.62, 0.72, 0.32), Color(0.70, 0.62, 0.26), Color(0.48, 0.54, 0.26)],
		"boss": [
			# B-52: ô liu đen SEA → tối hơn → cháy đỏ cam
			[Color(0.16,0.17,0.08), Color(0.22,0.18,0.08), Color(0.40,0.12,0.04)],
			# F-4: SEA xanh lá → ô liu đậm → cháy
			[Color(0.22,0.26,0.11), Color(0.30,0.22,0.09), Color(0.42,0.14,0.04)],
			# AC-130: ô liu đậm → tối → cháy
			[Color(0.20,0.22,0.10), Color(0.26,0.20,0.08), Color(0.38,0.12,0.04)],
			# C-130: ô liu chuẩn → tối → cháy
			[Color(0.22,0.24,0.11), Color(0.28,0.20,0.09), Color(0.40,0.14,0.04)],
			# B-29: kim loại bạc tự nhiên → ô liu vàng → cháy
			[Color(0.48,0.44,0.32), Color(0.36,0.28,0.13), Color(0.40,0.18,0.05)],
		],
		# 5 shapes cho 5 skin — MiG-21 / MiG-17 / Mi-24 Hind / MiG-19 / Il-28
		"player_polys": [
			# 0 MiG-21 Fishbed — cánh delta nhọn, mũi nhọn
			[Vector2(0,-30), Vector2(3,-22), Vector2(5,-12), Vector2(18,2),
			 Vector2(16,12), Vector2(8,18),  Vector2(5,22),  Vector2(-5,22),
			 Vector2(-8,18), Vector2(-16,12),Vector2(-18,2), Vector2(-5,-12),
			 Vector2(-3,-22)],
			# 1 MiG-17 Fresco — cánh xuôi 45°, thân mập
			[Vector2(0,-26), Vector2(4,-18), Vector2(8,-10), Vector2(18,4),
			 Vector2(16,14), Vector2(10,20), Vector2(5,24),  Vector2(-5,24),
			 Vector2(-10,20),Vector2(-16,14),Vector2(-18,4), Vector2(-8,-10),
			 Vector2(-4,-18)],
			# 2 Mi-24 Hind — trực thăng chiến đấu, thân bọc giáp, cánh stub rộng
			[Vector2(0,-20), Vector2(6,-14), Vector2(10,-8), Vector2(24,-2),
			 Vector2(24,6),  Vector2(10,10), Vector2(6,16),  Vector2(3,22),
			 Vector2(-3,22), Vector2(-6,16), Vector2(-10,10),Vector2(-24,6),
			 Vector2(-24,-2),Vector2(-10,-8),Vector2(-6,-14)],
			# 3 MiG-19 Farmer — cánh xuôi mỏng, twin engine
			[Vector2(0,-28), Vector2(2,-20), Vector2(4,-10), Vector2(16,2),
			 Vector2(14,12), Vector2(4,18),  Vector2(3,24),  Vector2(0,26),
			 Vector2(-3,24), Vector2(-4,18), Vector2(-14,12),Vector2(-16,2),
			 Vector2(-4,-10),Vector2(-2,-20)],
			# 4 Il-28 Beagle — máy bay ném bom twin-jet, cánh thẳng rộng
			[Vector2(0,-22), Vector2(5,-15), Vector2(10,-9), Vector2(20,-3),
			 Vector2(26,2),  Vector2(24,10), Vector2(16,18), Vector2(8,22),
			 Vector2(4,26),  Vector2(-4,26), Vector2(-8,22), Vector2(-16,18),
			 Vector2(-24,10),Vector2(-26,2), Vector2(-20,-3),Vector2(-10,-9),
			 Vector2(-5,-15)],
		],
		# 5 boss shapes — B-52 / F-4 lớn / AC-130 / C-130 / B-29
		"boss_polys": [
			# 0 B-52 Stratofortress — cánh xuôi 35°, 8 động cơ treo cuối cánh
			[Vector2(0,-18),  Vector2(6,-13),  Vector2(12,-7),  Vector2(26,-2),
			 Vector2(40,4),   Vector2(52,10),  Vector2(46,17),  Vector2(28,22),
			 Vector2(12,26),  Vector2(4,28),   Vector2(-4,28),  Vector2(-12,26),
			 Vector2(-28,22), Vector2(-46,17), Vector2(-52,10), Vector2(-40,4),
			 Vector2(-26,-2), Vector2(-12,-7), Vector2(-6,-13)],
			# 1 F-4 Phantom lớn — cánh gãy góc cranked + đuôi nâng dihedral
			[Vector2(0,-44),  Vector2(7,-30),  Vector2(12,-16), Vector2(16,-6),
			 Vector2(32,12),  Vector2(30,24),  Vector2(20,32),  Vector2(8,38),
			 Vector2(4,42),   Vector2(-4,42),  Vector2(-8,38),  Vector2(-20,32),
			 Vector2(-30,24), Vector2(-32,12), Vector2(-16,-6), Vector2(-12,-16),
			 Vector2(-7,-30)],
			# 2 AC-130 Spectre — cánh cao thẳng, 4 turboprop, thân to
			[Vector2(0,-30),  Vector2(8,-24),  Vector2(14,-16), Vector2(22,-8),
			 Vector2(48,-4),  Vector2(54,6),   Vector2(46,18),  Vector2(22,26),
			 Vector2(10,32),  Vector2(-10,32), Vector2(-22,26), Vector2(-46,18),
			 Vector2(-54,6),  Vector2(-48,-4), Vector2(-22,-8), Vector2(-14,-16),
			 Vector2(-8,-24)],
			# 3 C-130 Hercules — cánh cao thẳng, 4 cánh quạt, thân mập
			[Vector2(0,-26),  Vector2(8,-20),  Vector2(14,-12), Vector2(22,-6),
			 Vector2(46,-2),  Vector2(52,8),   Vector2(44,20),  Vector2(22,28),
			 Vector2(10,32),  Vector2(-10,32), Vector2(-22,28), Vector2(-44,20),
			 Vector2(-52,8),  Vector2(-46,-2), Vector2(-22,-6), Vector2(-14,-12),
			 Vector2(-8,-20)],
			# 4 B-29 Superfortress — cánh ellip rộng, 4 động cơ hướng kiểu cổ điển
			[Vector2(0,-46),  Vector2(12,-34), Vector2(20,-18), Vector2(22,0),
			 Vector2(46,6),   Vector2(50,16),  Vector2(44,24),  Vector2(22,34),
			 Vector2(6,44),   Vector2(-6,44),  Vector2(-22,34), Vector2(-44,24),
			 Vector2(-50,16), Vector2(-46,6),  Vector2(-22,0),  Vector2(-20,-18),
			 Vector2(-12,-34)],
		],
		"enemy_polys": [
			# 0 F-4 Phantom II — cánh xuôi gãy góc (cranked), bụng rộng, đuôi nâng
			[Vector2(0,-17),  Vector2(3,-12),  Vector2(6,-5),   Vector2(9,-1),
			 Vector2(17,6),   Vector2(15,11),  Vector2(8,14),   Vector2(4,17),
			 Vector2(-4,17),  Vector2(-8,14),  Vector2(-15,11), Vector2(-17,6),
			 Vector2(-9,-1),  Vector2(-6,-5),  Vector2(-3,-12)],
			# 1 F-105 Thunderchief — thân "chai Coca" mũi nhọn + cánh xuôi sâu 60°
			[Vector2(0,-18),  Vector2(2,-14),  Vector2(3,-7),   Vector2(5,-2),
			 Vector2(15,7),   Vector2(12,12),  Vector2(5,15),   Vector2(0,17),
			 Vector2(-5,15),  Vector2(-12,12), Vector2(-15,7),  Vector2(-5,-2),
			 Vector2(-3,-7),  Vector2(-2,-14)],
			# 2 B-52 Stratofortress — cánh xuôi 35° cực dài, thân xìgà hẹp
			[Vector2(0,-10),  Vector2(3,-7),   Vector2(6,-2),   Vector2(18,2),
			 Vector2(27,5),   Vector2(28,9),   Vector2(22,12),  Vector2(10,14),
			 Vector2(4,15),   Vector2(-4,15),  Vector2(-10,14), Vector2(-22,12),
			 Vector2(-28,9),  Vector2(-27,5),  Vector2(-18,2),  Vector2(-6,-2),
			 Vector2(-3,-7)],
		],
	},
]

static func get_pack() -> Dictionary:
	return PACKS[clampi(PlayerData.active_theme, 0, PACKS.size() - 1)]

static func theme_player_poly(sid: int) -> Array:
	var polys: Array = get_pack().get("player_polys", [])
	if sid < polys.size(): return polys[sid]
	return []

static func theme_enemy_poly(etype: int) -> Array:
	var polys: Array = get_pack().get("enemy_polys", [])
	if etype < polys.size(): return polys[etype]
	return []

static func enemy_color(enemy_type: int) -> Color:
	var cols: Array = get_pack().get("enemy", [])
	if enemy_type < cols.size(): return cols[enemy_type]
	return Color(1.0, 0.3, 0.1)

static func boss_color_set(btype: int) -> Array:
	var blist: Array = get_pack().get("boss", [])
	if btype < blist.size(): return blist[btype]
	return [Color(0.8, 0.2, 0.8), Color(1.0, 0.5, 0.0), Color(1.0, 0.1, 0.1)]
