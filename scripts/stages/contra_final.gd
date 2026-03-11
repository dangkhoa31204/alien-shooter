extends ContraStageBase

var _history_shown: bool = false

func setup():
	main.STAGE_LENGTH = 16000.0
	if main.progress_bar: main.progress_bar.max_value = main.STAGE_LENGTH
	
	var STAGE_LENGTH = main.STAGE_LENGTH
	var _world = main._world
	var _parallax_bg = main._parallax_bg
	
	# 1. ATMOSPHERE: Clear Victory Morning (30/4/1975)
	main._setup_background_sky(Color(0.45, 0.75, 1.0)) # Brilliant morning blue
	
	# High Sun with flares
	var sun_pos = Vector2(1100, 160)
	var sun = Polygon2D.new(); var spts = PackedVector2Array()
	for i in 24: spts.append(Vector2(cos(i*TAU/24)*70, sin(i*TAU/24)*70))
	sun.polygon = spts; sun.color = Color(1.0, 1.0, 0.9); sun.position = sun_pos; sun.z_index = -110; main._add_to_level(sun)
	
	# 2. ROAD & SIDEWALK (MOVED TO BACK LAYER TO AVOID COVERING UNITS)
	var floor_node = StaticBody2D.new()
	var col = CollisionShape2D.new(); var shape = WorldBoundaryShape2D.new(); shape.normal = Vector2.UP; col.shape = shape
	floor_node.add_child(col); floor_node.position.y = 600; main._add_to_level(floor_node)
	var road = ColorRect.new(); road.color = Color(0.12, 0.12, 0.15); road.size = Vector2(STAGE_LENGTH+4000, 400); road.position = Vector2(-2000, 0); road.z_index = -105; floor_node.add_child(road)
	var curb = ColorRect.new(); curb.color = Color(0.25, 0.25, 0.28); curb.size = Vector2(STAGE_LENGTH+4000, 15); curb.position = Vector2(-2000, -15); curb.z_index = -104; floor_node.add_child(curb)
	
	main._stage_terrain.clear()
	main._stage_terrain.append(Vector2(-2000, 600)); main._stage_terrain.append(Vector2(STAGE_LENGTH + 2000, 600))

	# 3. BACKGROUND LAYERS (Saigon Skyline)
	for i in 12:
		var bx = i * 1500; _create_independence_palace_distant(bx + 800)
		_create_distant_city_complex(bx + 300)

	# 4. URBAN ARCHITECTURE (METAL SLUG STYLE)
	for i in range(int(STAGE_LENGTH / 850)):
		var bx = 200 + i * 850 + randf_range(-100, 100)
		_create_perfect_avenue_block(bx)
		if i % 2 == 0: _create_power_line_complex(bx)

	# 5. FRONTAGE PROPS & HISTORICAL DETAILS
	for i in range(int(STAGE_LENGTH / 500)):
		var dx = 400 + i * 500 + randf_range(-60, 60)
		
		# Checkpoints at 4000, 9000
		if abs(dx - 4000) < 250 and i % 5 == 0: main._create_checkpoint(Vector2(dx, 600))
		if abs(dx - 9000) < 250 and i % 5 == 0: main._create_checkpoint(Vector2(dx, 600))
		
		# Health Kits scattered
		if i % 6 == 3: main._create_health_kit(Vector2(dx, 580))
		
		# Alternating vegetation
		if i % 3 == 0: _create_detailed_palm_group(dx)
		else: _create_vintage_street_lamp(dx)
		
		# Historical Remnants
		if i % 4 == 2: _create_sandbag_fortification(dx - 120)
		if randf() < 0.25: _create_abandoned_gear_pile(dx + 80)
		
		# Extra Climbing Points
		if i % 5 == 2: _create_urban_scaffold(dx + 250, 480)
		if i % 5 == 4: _create_urban_scaffold(dx - 100, 360)

		# Celebration Elements
		if i % 5 == 1: _create_banner_cable(dx)

		# Vehicles
		var v_dice = randf()
		if v_dice < 0.15: _create_abandoned_jeep(dx + 150)
		elif v_dice < 0.25: _create_abandoned_vespa(dx + 150)

	# Gameplay Logic
	main._spawn_enemy_wave(22, 0.4) 
	
	# Allied Armored Advance (Tanks for our side - Just moving as decor)
	for i in 10:
		var tax = 1500 + i * 1400 
		main._spawn_heavy_enemy(tax, 580, "tank", true, false)

	# Enemy Defense Tanks (These still shoot)
	for i in 4: main._spawn_heavy_enemy(4500 + i*3500, 595, "tank")
	
	main._spawn_background_soldiers(30) 
	main._bomber_timer = 12.0 
	main._spawn_boss(STAGE_LENGTH - 400, 600)

	# === NEW: HISTORICAL ENRICHMENT (30/4/1975) ===
	_create_saigon_river_bg()
	_create_saigon_cathedral_bg(2000)
	_create_saigon_cathedral_bg(9500)

	for i in 5:
		_create_fleeing_helicopter(4000 + i * 2500, 80 + i * 30)

	for i in 15:
		_create_street_crater(randf_range(300, STAGE_LENGTH - 500))
	for i in 6:
		_create_burning_building(1000 + i * 1000)

	for i in range(int(STAGE_LENGTH / 600)):
		_create_crowd_civilians(300 + i * 600)

	for i in 5:
		_create_nlf_soldier_group(800 + i * 2800)

	_create_victory_arch(500)
	_create_victory_arch(8000)

	_create_tank_843(13800)
	_create_independence_palace_entrance(14500)
	_create_historical_moment_panel(12000)

	# === EXTRA BUILDINGS & TREES ===
	# Bưu điện Sài Gòn + Ministry buildings in mid-bg layer
	_create_saigon_post_office_bg(3500)
	_create_saigon_post_office_bg(12000)
	_create_ministry_building_bg(1200)
	_create_ministry_building_bg(5800)
	_create_ministry_building_bg(10400)
	_create_ministry_building_bg(14000)

	# Shophouse rows (nhà phố mặt tiền)
	for i in range(int(STAGE_LENGTH / 1200)):
		_create_shophouse_row(600 + i * 1200)

	# === NHÀ PHỐ SÀI GÒN 1975: kiến trúc đa dạng ===
	# Khách sạn Rex — Nguyễn Huệ / Lê Lợi
	_create_rex_hotel_bg(1800)
	_create_rex_hotel_bg(9200)
	_create_rex_hotel_bg(14800)

	# Khách sạn Continental / Caravelle style
	_create_continental_hotel_bg(3800)
	_create_continental_hotel_bg(8600)
	_create_continental_hotel_bg(13400)

	# Nhà ống Sài Gòn — mỗi 1800px
	for i in range(int(STAGE_LENGTH / 1800)):
		_create_saigon_tube_house_row(900 + i * 1800 + randf_range(-120, 120))

	# Biệt thự Pháp thuộc chi tiết cao
	_create_french_villa_elaborate(2600)
	_create_french_villa_elaborate(6500)
	_create_french_villa_elaborate(10800)
	_create_french_villa_elaborate(15200)

	# Chùa / đền thờ Sài Gòn
	_create_saigon_pagoda_bg(4200)
	_create_saigon_pagoda_bg(11500)

	# Dinh Độc Lập — toàn cảnh chi tiết phía cuối màn chơi
	_create_independence_palace_main_building(13000)

	# Extra foreground vegetation — Saigon boulevard trees
	for i in range(int(STAGE_LENGTH / 320)):
		var tx = 180 + i * 320 + randf_range(-40, 40)
		var tree_roll = randf()
		if tree_roll < 0.35:
			_create_tamarind_tree(tx)
		elif tree_roll < 0.6:
			_create_frangipani_tree(tx)
		elif tree_roll < 0.75:
			_create_banyan_tree(tx)

	# --- Foreground flag poles every 600px ---
	for i in range(int(STAGE_LENGTH / 600)):
		var fpx := 300.0 + i * 600.0
		var fpole := Node2D.new()
		fpole.position = Vector2(fpx, 600.0); fpole.z_index = 1
		main._add_to_level(fpole)
		# Pole stick
		var pstick := ColorRect.new()
		pstick.size = Vector2(3, 80); pstick.position = Vector2(-1, -80)
		pstick.color = Color(0.75, 0.7, 0.6); fpole.add_child(pstick)
		# Flag body (red top, blue bottom)
		var fred2 := ColorRect.new(); fred2.size = Vector2(28, 12); fred2.position = Vector2(2, -80)
		fred2.color = Color(0.85, 0.1, 0.1); fpole.add_child(fred2)
		var fblu2 := ColorRect.new(); fblu2.size = Vector2(28, 12); fblu2.position = Vector2(2, -68)
		fblu2.color = Color(0.04, 0.35, 0.78); fpole.add_child(fblu2)
		# Star on flag
		var fpts2: Array = []
		for j in 10:
			var fsz := 4.5 if j % 2 == 0 else 2.0
			fpts2.append(Vector2(cos(j * TAU / 10.0 - PI / 2.0) * fsz + 16, sin(j * TAU / 10.0 - PI / 2.0) * fsz - 74))
		var fstar2 := Polygon2D.new(); fstar2.polygon = PackedVector2Array(fpts2)
		fstar2.color = Color.YELLOW; fpole.add_child(fstar2)
		# Flag wave tween
		var ftw2: Tween = fblu2.create_tween().set_loops()
		ftw2.tween_property(fblu2, "size:x", 32.0, randf_range(0.4, 0.8)).set_trans(Tween.TRANS_SINE)
		ftw2.tween_property(fblu2, "size:x", 24.0, randf_range(0.4, 0.8)).set_trans(Tween.TRANS_SINE)

	# --- Building smoke from war-damaged structures ---
	for i in 3:
		var smx := 1200.0 + i * 4000.0
		var smoke_emitter := Node2D.new()
		smoke_emitter.position = Vector2(smx, 440.0); smoke_emitter.z_index = 4
		main._add_to_level(smoke_emitter)
		var stw3: Tween = smoke_emitter.create_tween().set_loops()
		stw3.tween_callback(func():
			var sp := Polygon2D.new()
			var smoke_pts: Array = []
			var sr3 := randf_range(12.0, 22.0)
			for si in 8:
				var sa := si * TAU / 8.0
				smoke_pts.append(Vector2(cos(sa) * sr3, sin(sa) * sr3))
			sp.polygon = PackedVector2Array(smoke_pts)
			sp.color = Color(0.3, 0.28, 0.26, 0.45)
			sp.global_position = smoke_emitter.global_position + Vector2(randf_range(-20.0, 20.0), 0.0)
			sp.z_index = 4
			main._add_to_level(sp)
			var ptw2: Tween = sp.create_tween()
			ptw2.tween_property(sp, "position:y", sp.position.y - randf_range(60.0, 110.0), 2.5)
			ptw2.parallel().tween_property(sp, "scale", Vector2(2.5, 2.5), 2.5)
			ptw2.parallel().tween_property(sp, "modulate:a", 0.0, 2.5)
			ptw2.finished.connect(sp.queue_free)
		)
		stw3.tween_interval(randf_range(0.5, 1.2))

# --- PERFECT VISUAL HELPERS ---

func _create_independence_palace_distant(x: float):
	# Dinh Độc Lập (Reunification Palace) — kiến trúc Ngô Viết Thụ 1966
	# Chi tiết 80-90% giống thực tế: lam che nắng, 2 cánh, cầu thang lớn, cột cờ
	var p = Node2D.new(); p.position = Vector2(x, 600); p.z_index = -98; _get_parallax().add_child(p)
	p.modulate = Color(0.48, 0.52, 0.68, 0.5)

	var WALL   = Color(0.93, 0.88, 0.74)  # bê tông màu kem
	var LOUVER = Color(0.75, 0.70, 0.54)  # lam che nắng tối hơn
	var WIN    = Color(0.10, 0.13, 0.20)  # ô cửa sổ
	var GRASS  = Color(0.20, 0.40, 0.16)

	# --- Bãi cỏ trước Dinh ---
	var lawn = ColorRect.new(); lawn.size = Vector2(600, 20); lawn.position = Vector2(-300, -20)
	lawn.color = GRASS; p.add_child(lawn)

	# --- Hai cánh nhà bên trái và phải ---
	for side in [-1, 1]:
		var wx = side * 210
		var wing = ColorRect.new(); wing.size = Vector2(130, 200); wing.position = Vector2(wx - 65, -220)
		wing.color = WALL; p.add_child(wing)
		# Đường ngang phân tầng (3 tầng)
		for fl in 3:
			var wfl = ColorRect.new(); wfl.size = Vector2(134, 5); wfl.position = Vector2(wx - 67, -220 + fl * 66)
			wfl.color = LOUVER; p.add_child(wfl)
		# Cửa sổ cánh (2 tầng × 2 cửa)
		for fl in 2:
			for wc in 2:
				var win = ColorRect.new(); win.size = Vector2(20, 32); win.position = Vector2(wx - 50 + wc * 44, -200 + fl * 66)
				win.color = WIN; p.add_child(win)
		# Parapet cánh
		var w_par = ColorRect.new(); w_par.size = Vector2(136, 12); w_par.position = Vector2(wx - 68, -222)
		w_par.color = LOUVER; p.add_child(w_par)

	# --- Khối trung tâm chính (cao hơn cánh) ---
	var main_body = ColorRect.new(); main_body.size = Vector2(280, 320); main_body.position = Vector2(-140, -340)
	main_body.color = WALL; p.add_child(main_body)

	# --- Lam che nắng đặc trưng — 4 tầng × 10 ô lam ---
	for fl in 4:
		var fy = -310 + fl * 72
		# Thanh ngang phân sàn
		var slab = ColorRect.new(); slab.size = Vector2(280, 6); slab.position = Vector2(-140, fy)
		slab.color = LOUVER; p.add_child(slab)
		# Các ô lam
		for bay in 9:
			var bx = -132 + bay * 29
			var lam = ColorRect.new(); lam.size = Vector2(24, 62); lam.position = Vector2(bx, fy + 6)
			lam.color = LOUVER; p.add_child(lam)
			# Vạch bóng ngang trong ô lam (tạo cảm giác 3D)
			for sl in 3:
				var slat = ColorRect.new(); slat.size = Vector2(24, 2); slat.position = Vector2(bx, fy + 6 + sl * 20)
				slat.color = Color(0.08, 0.08, 0.10, 0.35); p.add_child(slat)
			# Ô tối sau lam (gợi cửa sổ bên trong)
			var bg_win = ColorRect.new(); bg_win.size = Vector2(18, 60); bg_win.position = Vector2(bx + 3, fy + 7)
			bg_win.color = WIN; bg_win.modulate.a = 0.45; p.add_child(bg_win)

	# --- Mặt tiền tầng 1: ban công / cửa lớn ---
	var ground_band = ColorRect.new(); ground_band.size = Vector2(280, 30); ground_band.position = Vector2(-140, -38)
	ground_band.color = LOUVER; p.add_child(ground_band)
	# Cửa vào chính (3 cửa lớn)
	for ci in 3:
		var door = ColorRect.new(); door.size = Vector2(30, 42); door.position = Vector2(-60 + ci * 42, -68)
		door.color = WIN; p.add_child(door)

	# --- Cầu thang trước Dinh (bậc thang rộng) ---
	for step in 4:
		var sw = 200 + step * 22; var sh = 8
		var s = ColorRect.new(); s.size = Vector2(sw, sh); s.position = Vector2(-sw/2.0, -8 - step * sh)
		s.color = Color(0.85, 0.80, 0.66 - step * 0.02); p.add_child(s)

	# --- Parapet mái trung tâm ---
	var roof_par = ColorRect.new(); roof_par.size = Vector2(290, 14); roof_par.position = Vector2(-145, -342)
	roof_par.color = LOUVER; p.add_child(roof_par)

	# --- Tầng thượng / penthouse nhỏ ---
	var pent = ColorRect.new(); pent.size = Vector2(160, 30); pent.position = Vector2(-80, -372)
	pent.color = WALL; p.add_child(pent)
	var pent_par = ColorRect.new(); pent_par.size = Vector2(166, 10); pent_par.position = Vector2(-83, -372)
	pent_par.color = LOUVER; p.add_child(pent_par)

	# --- Cột cờ trên mái + cờ NLF lớn ---
	var flagpole = ColorRect.new(); flagpole.size = Vector2(3, 80); flagpole.position = Vector2(-1, -452)
	flagpole.color = Color(0.55, 0.50, 0.35); p.add_child(flagpole)
	var flag_nd = Node2D.new(); flag_nd.position = Vector2(2, -448); flag_nd.scale = Vector2(0.85, 0.85); p.add_child(flag_nd)
	_draw_flag_shapes(flag_nd, 52, 38)

func _create_distant_city_complex(x: float):
	var node = Node2D.new(); node.position = Vector2(x, 600); node.z_index = -95; _get_parallax().add_child(node)
	node.modulate = Color(0.4, 0.5, 0.7, 0.45)
	for i in 4:
		var bw = randf_range(100, 200); var bh = randf_range(150, 400)
		var b = ColorRect.new(); b.size = Vector2(bw, bh); b.position = Vector2(i*100, -bh); node.add_child(b)

func _create_perfect_avenue_block(x: float):
	var node = Node2D.new(); node.position = Vector2(x, 600); node.z_index = -70; _get_parallax().add_child(node)
	if randf() < 0.5:
		_draw_colonial_villa(node)
	else:
		_draw_premium_apartment(node)

func _draw_colonial_villa(parent: Node2D):
	var body = ColorRect.new(); body.size = Vector2(400, 280); body.position = Vector2(-200, -280); body.color = Color(0.9, 0.8, 0.55); parent.add_child(body)
	var roof = Polygon2D.new(); roof.polygon = [Vector2(-210, -280), Vector2(-100, -350), Vector2(100, -350), Vector2(210, -280)]; roof.color = Color(0.75, 0.3, 0.2); parent.add_child(roof)
	# Window detail with Arches
	for i in 4:
		var wx = -160 + i * 90
		var win = ColorRect.new(); win.size = Vector2(35, 60); win.position = Vector2(wx, -200); win.color = Color(0.2, 0.15, 0.1); parent.add_child(win)
		var arch = Polygon2D.new(); arch.polygon = [Vector2(0,0), Vector2(17.5, -15), Vector2(35, 0)]; arch.position = win.position; arch.color = win.color; parent.add_child(arch)
	# Propaganda Poster
	if randf() < 0.7: _add_propaganda_poster(parent, Vector2(-180, -120))
	_add_flag_to_node(parent, Vector2(0, -280), 1.25)

func _draw_premium_apartment(parent: Node2D):
	var bh = 500; var bw = 300
	var body = ColorRect.new(); body.size = Vector2(bw, bh); body.position = Vector2(-bw/2, -bh); body.color = Color(0.65, 0.65, 0.62); parent.add_child(body)
	# Balconies + Detail
	for r in 4:
		var by = -bh + 80 + r*110
		var bal = ColorRect.new(); bal.size = Vector2(bw+20, 10); bal.position = Vector2(-bw/2-10, by); bal.color = Color(0.4, 0.4, 0.4); parent.add_child(bal)
		# Flower pots
		if randf() < 0.6:
			var pot = ColorRect.new(); pot.size = Vector2(20, 15); pot.position = Vector2(-120, by - 15); pot.color = Color(0.5, 0.25, 0.1); parent.add_child(pot)
			var plant = ColorRect.new(); plant.size = Vector2(15, 10); plant.position = Vector2(-117, by - 25); plant.color = Color.DARK_GREEN; parent.add_child(plant)
		if randf() < 0.8: _add_flag_to_node(parent, Vector2(randf_range(-100, 100), by), 0.7)
	# Weathered walls (detail)
	var crack = ColorRect.new(); crack.size = Vector2(2, 100); crack.position = Vector2(80, -300); crack.color = Color(0,0,0,0.1); parent.add_child(crack)

func _add_propaganda_poster(parent: Node, pos: Vector2):
	var p = ColorRect.new(); p.size = Vector2(45, 65); p.position = pos; p.color = Color(0.95, 0.95, 0.9); parent.add_child(p)
	var b_red = ColorRect.new(); b_red.size = Vector2(45, 15); b_red.color = Color.RED; p.add_child(b_red)
	var txt = ColorRect.new(); txt.size = Vector2(35, 2); txt.position = Vector2(5, 25); txt.color = Color(0,0,0,0.5); p.add_child(txt)

func _create_sandbag_fortification(x: float):
	var s = StaticBody2D.new(); s.position = Vector2(x, 600); s.z_index = -5; main._add_to_level(s)
	# Add collision for climbing
	var col = CollisionShape2D.new(); var shp = RectangleShape2D.new(); shp.size = Vector2(100, 40); col.shape = shp; col.position = Vector2(0, -20); col.one_way_collision = true; s.add_child(col)
	for i in 12:
		var bag = ColorRect.new(); bag.size = Vector2(25, 12); bag.position = Vector2(-60 + (i%4)*28, -12 - (i/4)*10); bag.color = Color(0.5, 0.45, 0.4); s.add_child(bag)

func _create_urban_scaffold(x: float, y: float):
	var s = StaticBody2D.new(); s.position = Vector2(x, y); s.z_index = 0; main._add_to_level(s)
	var w = randf_range(120, 220)
	var col = CollisionShape2D.new(); var shp = RectangleShape2D.new(); shp.size = Vector2(w, 16); col.shape = shp; col.one_way_collision = true; s.add_child(col)
	
	# Visuals: Billboard / Scaffolding look
	var bg = ColorRect.new(); bg.size = Vector2(w, 16); bg.position = Vector2(-w/2, -8); bg.color = Color(0.25, 0.25, 0.28); s.add_child(bg)
	var trim = ColorRect.new(); trim.size = Vector2(w, 4); trim.position = Vector2(-w/2, -10); trim.color = Color.GOLD; s.add_child(trim)
	
	# Supports
	var left_p = ColorRect.new(); left_p.size = Vector2(4, 600-y); left_p.position = Vector2(-w/2 + 10, 8); left_p.color = Color(0.15, 0.15, 0.15); s.add_child(left_p)
	var right_p = ColorRect.new(); right_p.size = Vector2(4, 600-y); right_p.position = Vector2(w/2 - 14, 8); right_p.color = Color(0.15, 0.15, 0.15); s.add_child(right_p)

func _create_power_line_complex(x: float):
	var pole = Node2D.new(); pole.position = Vector2(x, 600); pole.z_index = -25; main._add_to_level(pole)
	var trunk = ColorRect.new(); trunk.size = Vector2(8, 400); trunk.position = Vector2(-4, -400); trunk.color = Color(0.2, 0.15, 0.1); pole.add_child(trunk)
	var cross = ColorRect.new(); cross.size = Vector2(80, 8); cross.position = Vector2(-40, -380); cross.color = trunk.color; pole.add_child(cross)
	# Hanging Flags on power lines
	for i in 4:
		var f = Node2D.new(); f.position = Vector2(i*40, -370); f.scale = Vector2(0.3, 0.3); pole.add_child(f)
		_draw_flag_shapes(f, 40, 30)

func _draw_flag_shapes(node: Node2D, w, h):
	# Cờ Mặt trận Giải phóng miền Nam: đỏ trên, xanh dưới, ngôi sao 5 cánh vàng ở giữa
	var red = ColorRect.new(); red.size = Vector2(w, h/2); red.color = Color(0.85, 0.1, 0.1); node.add_child(red)
	var blu = ColorRect.new(); blu.size = Vector2(w, h/2); blu.position = Vector2(0, h/2); blu.color = Color(0.04, 0.35, 0.78); node.add_child(blu)
	var star = Polygon2D.new(); var pts = []
	for j in 10:
		var r = 9 if j % 2 == 0 else 4; pts.append(Vector2(cos(j*TAU/10-PI/2)*r, sin(j*TAU/10-PI/2)*r))
	star.polygon = PackedVector2Array(pts); star.color = Color.YELLOW; star.position = Vector2(w/2, h/2); node.add_child(star)

func _add_flag_to_node(parent: Node2D, pos: Vector2, sc: float):
	var f = Node2D.new(); f.position = pos; f.scale = Vector2(sc, sc); parent.add_child(f)
	_draw_flag_shapes(f, 44, 32)

func _create_banner_cable(x: float):
	var node = Node2D.new(); node.position = Vector2(x, 240); node.z_index = -30; _get_world().add_child(node)
	var cable = ColorRect.new(); cable.size = Vector2(900, 2); cable.position = Vector2(-450, 0); cable.color = Color(0,0,0,0.8); node.add_child(cable)
	for i in 10: _add_flag_to_node(node, Vector2(-360 + i*80, 2), 0.75)

func _create_detailed_palm_group(x: float):
	for i in 3: main._create_palm_tree(Vector2(x + randf_range(-50, 50), 600))

func _create_vintage_street_lamp(x: float):
	var lamp = Node2D.new(); lamp.position = Vector2(x, 600); lamp.z_index = -40; main._add_to_level(lamp)
	var pole = ColorRect.new(); pole.size = Vector2(6, 250); pole.position = Vector2(-3, -250); pole.color = Color(0.2, 0.2, 0.2); lamp.add_child(pole)
	var light = ColorRect.new(); light.size = Vector2(30, 15); light.position = Vector2(-15, -255); light.color = Color(1, 1, 0.8, 0.8); lamp.add_child(light)

func _create_abandoned_gear_pile(x: float):
	var gear = Node2D.new(); gear.position = Vector2(x, 600); gear.z_index = -2; main._add_to_level(gear)
	for i in 3:
		var boot = ColorRect.new(); boot.size = Vector2(10, 7); boot.position = Vector2(i*12, -7); boot.color = Color(0.1, 0.1, 0.1); gear.add_child(boot)
	var helm = Polygon2D.new(); helm.polygon = [Vector2(-8, 0), Vector2(-6, -8), Vector2(6, -8), Vector2(8, 0)]; helm.color = Color(0.2, 0.25, 0.2); helm.position = Vector2(-10, -5); gear.add_child(helm)

func _create_abandoned_vespa(x: float):
	var v = Node2D.new(); v.position = Vector2(x, 600); v.z_index = -5; main._add_to_level(v)
	var body = Polygon2D.new(); body.polygon = [Vector2(-20, 0), Vector2(-25, -20), Vector2(10, -25), Vector2(25, -5), Vector2(20, 0)]; body.color = Color.AZURE; v.add_child(body)
	var w1 = ColorRect.new(); w1.size = Vector2(12, 12); w1.position = Vector2(-16, -10); w1.color = Color.BLACK; v.add_child(w1)
	var w2 = ColorRect.new(); w2.size = Vector2(w1.size.x, w1.size.y); w2.position = Vector2(10, -10); w2.color = Color.BLACK; v.add_child(w2)

func _create_abandoned_jeep(x: float):
	var j = Node2D.new(); j.position = Vector2(x, 600); j.z_index = -6; main._add_to_level(j)
	var body = ColorRect.new(); body.size = Vector2(100, 35); body.position = Vector2(-50, -45); body.color = Color(0.22, 0.28, 0.18); j.add_child(body)
	var hood = ColorRect.new(); hood.size = Vector2(50, 20); hood.position = Vector2(0, -65); hood.color = body.color; j.add_child(hood)
	var wheels = [Vector2(-40, -18), Vector2(30, -18)]; for wp in wheels:
		var w = ColorRect.new(); w.size = Vector2(24, 24); w.position = wp; w.color = Color.BLACK; j.add_child(w)

# ============================================================
# === MAP 5 EXTRA BUILDINGS & VEGETATION ===================
# ============================================================

# Bưu điện Trung tâm Sài Gòn (Central Post Office) — iconic French dome
func _create_saigon_post_office_bg(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -85
	node.modulate = Color(0.55, 0.58, 0.72, 0.6)
	_get_parallax().add_child(node)
	# Main hall body
	var hall = ColorRect.new(); hall.size = Vector2(360, 160); hall.position = Vector2(-180, -160)
	hall.color = Color(0.88, 0.82, 0.65); node.add_child(hall)
	# Central barrel-vault dome
	var dome_pts = PackedVector2Array()
	for j in 18: dome_pts.append(Vector2(cos(j*PI/17 + PI)*90, sin(j*PI/17 + PI)*45))
	var dome = Polygon2D.new(); dome.polygon = dome_pts
	dome.color = Color(0.75, 0.68, 0.5); dome.position = Vector2(0, -160); node.add_child(dome)
	# Arched windows row
	for i in 5:
		var wx = -150 + i * 68
		var win = ColorRect.new(); win.size = Vector2(28, 50); win.position = Vector2(wx, -110)
		win.color = Color(0.18, 0.15, 0.1); node.add_child(win)
		var arc = Polygon2D.new()
		arc.polygon = PackedVector2Array([Vector2(0,0),Vector2(14,-16),Vector2(28,0)])
		arc.color = win.color; arc.position = win.position; node.add_child(arc)
	# Entrance columns
	for ci in 4:
		var col2 = ColorRect.new(); col2.size = Vector2(14, 160); col2.position = Vector2(-90 + ci * 58, -160)
		col2.color = Color(0.82, 0.77, 0.6); node.add_child(col2)
	# Clock above entrance
	var clock_bg = Polygon2D.new(); var cpts = PackedVector2Array()
	for j in 12: cpts.append(Vector2(cos(j*TAU/12)*18, sin(j*TAU/12)*18))
	clock_bg.polygon = cpts; clock_bg.color = Color(0.7, 0.65, 0.45); clock_bg.position = Vector2(0, -185); node.add_child(clock_bg)
	var clock_face = Polygon2D.new(); var cfpts = PackedVector2Array()
	for j in 12: cfpts.append(Vector2(cos(j*TAU/12)*13, sin(j*TAU/12)*13))
	clock_face.polygon = cfpts; clock_face.color = Color(0.95, 0.92, 0.8); clock_face.position = clock_bg.position; node.add_child(clock_face)

# French colonial Ministry / Government building
func _create_ministry_building_bg(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -88
	node.modulate = Color(0.5, 0.52, 0.68, 0.5)
	_get_parallax().add_child(node)
	# Main facade
	var facade = ColorRect.new(); facade.size = Vector2(440, 220); facade.position = Vector2(-220, -220)
	facade.color = Color(0.86, 0.78, 0.58); node.add_child(facade)
	# Pediment / triangular top
	var ped = Polygon2D.new()
	ped.polygon = PackedVector2Array([Vector2(-230,-220),Vector2(0,-285),Vector2(230,-220)])
	ped.color = Color(0.78, 0.7, 0.5); node.add_child(ped)
	# Cornice line
	var corn = ColorRect.new(); corn.size = Vector2(460, 14); corn.position = Vector2(-230, -222)
	corn.color = Color(0.7, 0.62, 0.45); node.add_child(corn)
	# Columns (6)
	for ci in 6:
		var col2 = ColorRect.new(); col2.size = Vector2(16, 220); col2.position = Vector2(-200 + ci * 78, -220)
		col2.color = Color(0.9, 0.84, 0.65); node.add_child(col2)
		# Capital at top
		var cap = ColorRect.new(); cap.size = Vector2(22, 10); cap.position = Vector2(-200 + ci * 78 - 3, -222)
		cap.color = Color(0.7, 0.62, 0.45); node.add_child(cap)
	# Tall windows with shutters
	for i in 4:
		var wx = -155 + i * 100
		var win = ColorRect.new(); win.size = Vector2(40, 70); win.position = Vector2(wx, -165)
		win.color = Color(0.15, 0.18, 0.22); node.add_child(win)
		var shutL = ColorRect.new(); shutL.size = Vector2(18, 70); shutL.position = Vector2(wx - 18, -165)
		shutL.color = Color(0.3, 0.45, 0.25); node.add_child(shutL)
		var shutR = ColorRect.new(); shutR.size = Vector2(18, 70); shutR.position = Vector2(wx + 40, -165)
		shutR.color = shutL.color; node.add_child(shutR)
	# Flag on roof
	_add_flag_to_node(node, Vector2(0, -290), 1.1)

# Saigon shophouse row (nhà phố mặt tiền)
func _create_shophouse_row(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -72
	_get_parallax().add_child(node)
	var shop_colors = [
		Color(0.92, 0.82, 0.6),
		Color(0.75, 0.88, 0.78),
		Color(0.88, 0.75, 0.72),
		Color(0.8, 0.8, 0.9),
		Color(0.95, 0.88, 0.7)
	]
	var count = randi_range(3, 5)
	for i in count:
		var sw = randf_range(90, 130)
		var sh = randf_range(180, 280)
		var sx = -count * 55 + i * 115
		# Facade
		var face = ColorRect.new(); face.size = Vector2(sw, sh); face.position = Vector2(sx, -sh)
		face.color = shop_colors[i % shop_colors.size()]; node.add_child(face)
		# Roof parapet
		var par = ColorRect.new(); par.size = Vector2(sw + 6, 18); par.position = Vector2(sx - 3, -sh - 10)
		par.color = Color(0.6, 0.55, 0.42); node.add_child(par)
		# Ground floor shop opening
		var shop_open = ColorRect.new(); shop_open.size = Vector2(sw * 0.7, 55); shop_open.position = Vector2(sx + sw * 0.15, -58)
		shop_open.color = Color(0.1, 0.08, 0.06); node.add_child(shop_open)
		# Awning over shop
		var awning = Polygon2D.new()
		awning.polygon = PackedVector2Array([Vector2(sx, -58), Vector2(sx + sw, -58), Vector2(sx + sw + 10, -72), Vector2(sx - 10, -72)])
		awning.color = [Color(0.8,0.2,0.2), Color(0.2,0.5,0.2), Color(0.2,0.2,0.7)][i % 3]; node.add_child(awning)
		# Upper windows (2 floors)
		for fl in 2:
			var wy = -sh + 30 + fl * 80
			var win = ColorRect.new(); win.size = Vector2(28, 40); win.position = Vector2(sx + (sw - 28) / 2.0, wy)
			win.color = Color(0.15, 0.18, 0.22); node.add_child(win)
			# Vietnamese flag or laundry on some
			if randf() < 0.5:
				_add_flag_to_node(node, Vector2(sx + sw * 0.5, wy - 10), 0.45)
			else:
				# Laundry line
				var lc = ColorRect.new(); lc.size = Vector2(sw * 0.6, 2); lc.position = Vector2(sx + sw * 0.2, wy - 5)
				lc.color = Color(0.1, 0.1, 0.1); node.add_child(lc)
				for k in randi_range(2, 4):
					var cloth = ColorRect.new()
					cloth.size = Vector2(randf_range(10, 18), randf_range(16, 26))
					cloth.position = Vector2(sx + sw * 0.2 + k * 18, wy - 5)
					cloth.color = Color(randf(), randf(), randf()); node.add_child(cloth)

# Tamarind tree (cây me) — wide spreading canopy, iconic of Saigon boulevards
func _create_tamarind_tree(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -15
	main._add_to_level(node)
	# Trunk
	var trunk = ColorRect.new(); trunk.size = Vector2(14, 130); trunk.position = Vector2(-7, -130)
	trunk.color = Color(0.32, 0.22, 0.12); node.add_child(trunk)
	# Mid branch forks
	for side in [-1, 1]:
		var branch = ColorRect.new(); branch.size = Vector2(8, 70)
		branch.position = Vector2(side * 8, -130)
		branch.rotation = side * 0.4
		branch.color = Color(0.3, 0.2, 0.1); node.add_child(branch)
	# Wide layered canopy (3 overlapping ellipses)
	for layer in 3:
		var cw = 90 + layer * 30; var ch = 40 + layer * 12
		var cpts = PackedVector2Array()
		for j in 14:
			cpts.append(Vector2(cos(j*TAU/14) * cw, sin(j*TAU/14) * ch))
		var canopy = Polygon2D.new(); canopy.polygon = cpts
		canopy.color = Color(0.15 + layer*0.06, 0.38 + layer*0.05, 0.1, 0.9)
		canopy.position = Vector2(randf_range(-15, 15), -155 - layer * 18)
		node.add_child(canopy)
	# Small fruit/leaf clusters
	for k in randi_range(4, 7):
		var leaf = Polygon2D.new(); var lpts = PackedVector2Array()
		for j in 8: lpts.append(Vector2(cos(j*TAU/8)*10, sin(j*TAU/8)*8))
		leaf.polygon = lpts
		leaf.color = Color(0.1, 0.35 + randf_range(0,0.15), 0.08)
		leaf.position = Vector2(randf_range(-80, 80), -140 + randf_range(-40, 20))
		node.add_child(leaf)

# Banyan tree / cây đa — massive aerial roots, impressive presence
func _create_banyan_tree(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -12
	main._add_to_level(node)
	# Main trunk (thick)
	var trunk = ColorRect.new(); trunk.size = Vector2(22, 160); trunk.position = Vector2(-11, -160)
	trunk.color = Color(0.28, 0.2, 0.12); node.add_child(trunk)
	# Aerial prop roots dropping down
	for ri in randi_range(3, 6):
		var root = ColorRect.new(); root.size = Vector2(4, randf_range(60, 110))
		root.position = Vector2(randf_range(-70, 70), -randf_range(60, 130))
		root.color = Color(0.3, 0.22, 0.13, 0.8); node.add_child(root)
	# Massive dark canopy (layered)
	for layer in 4:
		var cw = 80 + layer * 35; var ch = 50 + layer * 20
		var cpts = PackedVector2Array()
		for j in 16:
			var jitter = randf_range(0.85, 1.15)
			cpts.append(Vector2(cos(j*TAU/16)*cw*jitter, sin(j*TAU/16)*ch*jitter))
		var canopy = Polygon2D.new(); canopy.polygon = cpts
		canopy.color = Color(0.1 + layer*0.04, 0.28 + layer*0.04, 0.07, 0.88)
		canopy.position = Vector2(randf_range(-10, 10), -170 - layer * 22)
		node.add_child(canopy)

# Frangipani / Plumeria (cây sứ) — common in Saigon gardens and courtyards
func _create_frangipani_tree(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -14
	main._add_to_level(node)
	# Trunk (slender, slightly bent)
	var trunk = Polygon2D.new()
	trunk.polygon = PackedVector2Array([Vector2(-6,0),Vector2(-8,-80),Vector2(-2,-100),Vector2(4,-80),Vector2(6,0)])
	trunk.color = Color(0.4, 0.3, 0.18); node.add_child(trunk)
	# Branch forks
	for side in [-1, 0, 1]:
		var branch = ColorRect.new(); branch.size = Vector2(6, 55)
		branch.position = Vector2(side * 6, -95)
		branch.rotation = side * 0.55
		branch.color = Color(0.38, 0.28, 0.16); node.add_child(branch)
		# Flower cluster at branch tip
		var tip_y = -100 - 50 + abs(side) * 5
		var tip_x = side * 30
		for p in 5:
			var petal = Polygon2D.new(); var ppts = PackedVector2Array()
			var pa = p * TAU / 5
			ppts.append(Vector2(tip_x, tip_y))
			ppts.append(Vector2(tip_x + cos(pa)*12, tip_y + sin(pa)*12))
			ppts.append(Vector2(tip_x + cos(pa + TAU/10)*8, tip_y + sin(pa + TAU/10)*8))
			petal.polygon = ppts
			petal.color = Color(1.0, 0.95, 0.75); node.add_child(petal)
		# Yellow center
		var ctr = Polygon2D.new(); var cpts2 = PackedVector2Array()
		for j in 8: cpts2.append(Vector2(cos(j*TAU/8)*4 + tip_x, sin(j*TAU/8)*4 + tip_y))
		ctr.polygon = cpts2; ctr.color = Color(1.0, 0.8, 0.1); node.add_child(ctr)

# ============================================================
# === MAP 5 HISTORICAL ENRICHMENT — 30/4/1975 ===============
# ============================================================

# --- 10. Saigon River (far background) ---
func _create_saigon_river_bg() -> void:
	var STAGE_LENGTH = main.STAGE_LENGTH
	var river = Node2D.new()
	river.z_index = -120
	_get_parallax().add_child(river)

	var band = ColorRect.new()
	band.size = Vector2(STAGE_LENGTH + 4000, 60)
	band.position = Vector2(-2000, 300)
	band.color = Color(0.1, 0.3, 0.55, 0.7)
	river.add_child(band)

	for i in 4:
		var shimmer = ColorRect.new()
		shimmer.size = Vector2(STAGE_LENGTH + 4000, 3)
		shimmer.position = Vector2(-2000, 308 + i * 12)
		shimmer.color = Color(0.4, 0.6, 0.8, 0.3)
		river.add_child(shimmer)

	for i in 6:
		var sx = randf_range(0, STAGE_LENGTH)
		var boat = Node2D.new(); boat.position = Vector2(sx, 348)
		var hull = Polygon2D.new()
		hull.polygon = PackedVector2Array([Vector2(-25, 0), Vector2(-18, -10), Vector2(18, -10), Vector2(25, 0)])
		hull.color = Color(0.05, 0.05, 0.05)
		boat.add_child(hull)
		var mast = ColorRect.new(); mast.size = Vector2(2, 18); mast.position = Vector2(-1, -26); mast.color = Color(0.1, 0.1, 0.1)
		boat.add_child(mast)
		river.add_child(boat)

# --- 3. Nhà thờ Đức Bà (Notre-Dame Cathedral) ---
func _create_saigon_cathedral_bg(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -80
	node.modulate = Color(0.5, 0.55, 0.7, 0.55)
	_get_parallax().add_child(node)

	# Nave body
	var nave = ColorRect.new(); nave.size = Vector2(240, 200); nave.position = Vector2(-120, -200)
	nave.color = Color(0.55, 0.27, 0.15); node.add_child(nave)

	# Two bell towers
	for side in [-1, 1]:
		var tx = side * 100
		var tower = ColorRect.new(); tower.size = Vector2(70, 300); tower.position = Vector2(tx - 35, -300)
		tower.color = Color(0.55, 0.27, 0.15); node.add_child(tower)
		# Gothic spire
		var spire = Polygon2D.new()
		spire.polygon = PackedVector2Array([Vector2(-20, 0), Vector2(0, -60), Vector2(20, 0)])
		spire.color = Color(0.45, 0.22, 0.12); spire.position = Vector2(tx, -300); node.add_child(spire)
		# Cross on top
		var cv = ColorRect.new(); cv.size = Vector2(4, 20); cv.position = Vector2(tx - 2, -360)
		cv.color = Color(0.9, 0.9, 0.8); node.add_child(cv)
		var ch = ColorRect.new(); ch.size = Vector2(14, 4); ch.position = Vector2(tx - 7, -350)
		ch.color = Color(0.9, 0.9, 0.8); node.add_child(ch)
		# Pointed arched windows
		for j in 3:
			var wy = -60 - j * 55
			var win = Polygon2D.new()
			win.polygon = PackedVector2Array([Vector2(-8, 0), Vector2(-8, -28), Vector2(0, -38), Vector2(8, -28), Vector2(8, 0)])
			win.color = Color(0.2, 0.15, 0.1); win.position = Vector2(tx, wy); node.add_child(win)

	# Rose window (circle approximation)
	var rose = Polygon2D.new(); var rpts = PackedVector2Array()
	for j in 16: rpts.append(Vector2(cos(j * TAU / 16) * 22, sin(j * TAU / 16) * 22))
	rose.polygon = rpts; rose.color = Color(0.3, 0.18, 0.08); rose.position = Vector2(0, -140); node.add_child(rose)
	var rose_inner = Polygon2D.new(); var ripts = PackedVector2Array()
	for j in 12: ripts.append(Vector2(cos(j * TAU / 12) * 12, sin(j * TAU / 12) * 12))
	rose_inner.polygon = ripts; rose_inner.color = Color(0.55, 0.27, 0.15); rose_inner.position = rose.position; node.add_child(rose_inner)

# --- 12. Smoke column (reusable) ---
func _create_smoke_column(x: float, y: float, col: Color) -> void:
	var sc_script = GDScript.new()
	sc_script.source_code = """
extends Node2D
var _t: float = 0.0
var _cols: Array = []
func _process(delta):
	_t += delta
	position.y -= 18.0 * delta
	if position.y < -200:
		position.y = 0
	for i in _cols.size():
		var c = _cols[i]
		var a = lerp(0.5, 0.0, float(i) / float(_cols.size()))
		c.modulate.a = a * (0.6 + 0.4 * sin(_t * 2.5 + i))
"""
	var smoke = Node2D.new()
	smoke.position = Vector2(x, y)
	smoke.z_index = 10
	smoke.set_script(sc_script)
	for i in 5:
		var radius = 8 + i * 6
		var pts = PackedVector2Array()
		for j in 12: pts.append(Vector2(cos(j * TAU / 12) * radius, sin(j * TAU / 12) * radius))
		var circle = Polygon2D.new()
		circle.polygon = pts
		circle.color = Color(col.r, col.g, col.b, lerp(0.5, 0.05, float(i) / 4.0))
		circle.position = Vector2(0, -i * 18)
		smoke.add_child(circle)
	smoke.set("_cols", smoke.get_children())
	main._add_to_level(smoke)

# --- 7. Fleeing Huey helicopter ---
func _create_fleeing_helicopter(x: float, y: float) -> void:
	var heli_script = GDScript.new()
	heli_script.source_code = """
extends Node2D
func _process(delta):
	position.x -= 40.0 * delta
"""
	var heli = Node2D.new()
	heli.position = Vector2(x, y)
	heli.z_index = -60
	heli.set_script(heli_script)

	var col = Color(0.15, 0.15, 0.15, 0.6)
	# Body
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-35, 0), Vector2(-40, -15), Vector2(-10, -22), Vector2(20, -15), Vector2(25, 0)])
	body.color = col; heli.add_child(body)
	# Cockpit bubble
	var cab = Polygon2D.new()
	cab.polygon = PackedVector2Array([Vector2(0, 0), Vector2(5, -18), Vector2(20, -18), Vector2(22, 0)])
	cab.color = Color(0.2, 0.2, 0.3, 0.5); heli.add_child(cab)
	# Main rotor
	var rotor = ColorRect.new(); rotor.size = Vector2(90, 4); rotor.position = Vector2(-45, -25)
	rotor.color = col; heli.add_child(rotor)
	# Tail boom
	var tail = ColorRect.new(); tail.size = Vector2(50, 5); tail.position = Vector2(-85, -10)
	tail.color = col; heli.add_child(tail)
	# Tail rotor
	var tail_rotor = ColorRect.new(); tail_rotor.size = Vector2(4, 20); tail_rotor.position = Vector2(-88, -20)
	tail_rotor.color = col; heli.add_child(tail_rotor)

	_get_parallax().add_child(heli)

# --- 5. Street crater ---
func _create_street_crater(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -103
	main._add_to_level(node)

	var pts = PackedVector2Array()
	for i in 16:
		var angle = i * TAU / 16
		var rx = (22 + randf_range(-4, 4)) * cos(angle)
		var ry = (11 + randf_range(-2, 2)) * sin(angle)
		pts.append(Vector2(rx, ry))
	var ellipse = Polygon2D.new(); ellipse.polygon = pts
	ellipse.color = Color(0.06, 0.06, 0.07); node.add_child(ellipse)

	for i in randi_range(4, 6):
		var chunk = ColorRect.new()
		chunk.size = Vector2(randf_range(4, 10), randf_range(3, 7))
		chunk.position = Vector2(randf_range(-35, 35), randf_range(-18, 18))
		chunk.rotation = randf_range(-PI, PI)
		chunk.color = Color(0.2, 0.2, 0.22)
		node.add_child(chunk)

# --- 4. Burning building ---
func _create_burning_building(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -68
	_get_parallax().add_child(node)

	# Colonial villa base
	var body = ColorRect.new(); body.size = Vector2(400, 280); body.position = Vector2(-200, -280)
	body.color = Color(0.5, 0.42, 0.28); node.add_child(body)
	var roof = Polygon2D.new()
	roof.polygon = PackedVector2Array([Vector2(-210, -280), Vector2(-100, -350), Vector2(100, -350), Vector2(210, -280)])
	roof.color = Color(0.45, 0.18, 0.1); node.add_child(roof)
	# Collapsed roof section
	var broken_roof = Polygon2D.new()
	broken_roof.polygon = PackedVector2Array([Vector2(40, -280), Vector2(100, -320), Vector2(170, -260)])
	broken_roof.color = Color(0.2, 0.1, 0.05); broken_roof.rotation = 0.3; node.add_child(broken_roof)

	# Scorch marks on walls
	for i in 3:
		var scorch = ColorRect.new(); scorch.size = Vector2(40 + randf_range(0,30), 80 + randf_range(0,40))
		scorch.position = Vector2(-160 + i * 130, -260); scorch.color = Color(0, 0, 0, 0.45); node.add_child(scorch)

	# Windows (burnt)
	for i in 4:
		var win = ColorRect.new(); win.size = Vector2(35, 60); win.position = Vector2(-160 + i * 90, -200)
		win.color = Color(0.05, 0.03, 0.02); node.add_child(win)
		var arch = Polygon2D.new(); arch.polygon = [Vector2(0,0), Vector2(17.5, -15), Vector2(35, 0)]
		arch.position = win.position; arch.color = win.color; node.add_child(arch)

	# Rubble pile at base
	for i in 8:
		var rub = ColorRect.new(); rub.size = Vector2(randf_range(8,20), randf_range(5,12))
		rub.position = Vector2(-180 + i * 50 + randf_range(-10,10), randf_range(-12, -2))
		rub.rotation = randf_range(-0.8, 0.8); rub.color = Color(randf_range(0.3,0.5), randf_range(0.25,0.4), 0.2)
		node.add_child(rub)

	# Fire pillars (animated via tween loop)
	for i in randi_range(3, 5):
		var fire_x = randf_range(-150, 150)
		var fire_node = Node2D.new(); fire_node.position = Vector2(fire_x, -350); node.add_child(fire_node)
		for layer in 4:
			var fc = ColorRect.new()
			fc.size = Vector2(10 + layer * 4, 20 + layer * 10)
			fc.position = Vector2(-(5 + layer * 2), -(10 + layer * 5))
			fc.color = [Color(1.0, 0.15, 0.0, 0.9), Color(1.0, 0.5, 0.0, 0.7), Color(1.0, 0.8, 0.0, 0.5), Color(0.6, 0.6, 0.6, 0.25)][layer]
			fire_node.add_child(fc)
			var tw = fire_node.get_tree().create_tween()
			tw.set_loops(); tw.tween_property(fc, "modulate:a", 0.1, randf_range(0.2, 0.5))
			tw.tween_property(fc, "modulate:a", 1.0, randf_range(0.2, 0.5))

	# Smoke column above fire
	_create_smoke_column(x, 600 - 380, Color(0.4, 0.4, 0.4, 1.0))

# --- 8. Crowd of civilians ---
func _create_crowd_civilians(x: float) -> void:
	var group = Node2D.new()
	group.position = Vector2(x, 598)
	group.z_index = -3
	main._add_to_level(group)

	var count = randi_range(3, 5)
	for i in count:
		var px = i * 28 + randf_range(-5, 5)
		var civ = Node2D.new(); civ.position = Vector2(px, 0); group.add_child(civ)
		# Head
		var head_pts = PackedVector2Array()
		for j in 8: head_pts.append(Vector2(cos(j*TAU/8)*5, sin(j*TAU/8)*5 - 30))
		var head = Polygon2D.new(); head.polygon = head_pts
		head.color = Color(randf_range(0.7,0.9), randf_range(0.55,0.75), randf_range(0.4,0.6)); civ.add_child(head)
		# Body
		var shirt_col = Color(randf_range(0.3,1.0), randf_range(0.2,0.9), randf_range(0.2,0.9))
		var torso = ColorRect.new(); torso.size = Vector2(10, 18); torso.position = Vector2(-5, -24)
		torso.color = shirt_col; civ.add_child(torso)
		# Arms (raised in celebration for some)
		var raised = randf() < 0.5
		var arm_l = ColorRect.new(); arm_l.size = Vector2(3, 10)
		arm_l.position = Vector2(-8, -22); arm_l.rotation = -0.8 if raised else 0.2
		arm_l.color = shirt_col; civ.add_child(arm_l)
		var arm_r = ColorRect.new(); arm_r.size = Vector2(3, 10)
		arm_r.position = Vector2(5, -22); arm_r.rotation = 0.8 if raised else -0.2
		arm_r.color = shirt_col; civ.add_child(arm_r)
		# Tiny flag above head
		var flag_pole = ColorRect.new(); flag_pole.size = Vector2(2, 14); flag_pole.position = Vector2(3, -44)
		flag_pole.color = Color(0.4, 0.25, 0.1); civ.add_child(flag_pole)
		# Cờ đỏ trên, xanh dưới
		var flag_red = ColorRect.new(); flag_red.size = Vector2(12, 4); flag_red.position = Vector2(5, -52)
		flag_red.color = Color(0.85, 0.1, 0.1); civ.add_child(flag_red)
		var flag_blu = ColorRect.new(); flag_blu.size = Vector2(12, 4); flag_blu.position = Vector2(5, -48)
		flag_blu.color = Color(0.04, 0.35, 0.78); civ.add_child(flag_blu)
		var star_pts = PackedVector2Array()
		for j in 10:
			var r2 = 2.5 if j % 2 == 0 else 1.2
			star_pts.append(Vector2(cos(j*TAU/10 - PI/2)*r2 + 11, sin(j*TAU/10 - PI/2)*r2 - 50))
		var star2 = Polygon2D.new(); star2.polygon = star_pts; star2.color = Color.YELLOW; civ.add_child(star2)

# --- 9. NLF/PAVN marching soldier group ---
func _create_nlf_soldier_group(x: float) -> void:
	var march_script = GDScript.new()
	march_script.source_code = """
extends Node2D
func _process(delta):
	position.x -= 15.0 * delta
"""
	var group = Node2D.new()
	group.position = Vector2(x, 595)
	group.z_index = -10
	group.set_script(march_script)
	main._add_to_level(group)

	var count = randi_range(4, 6)
	for i in count:
		var sx = i * 35
		var sol = Node2D.new(); sol.position = Vector2(sx, 0); group.add_child(sol)
		# Helmet
		var helm = Polygon2D.new()
		helm.polygon = PackedVector2Array([Vector2(-8,0),Vector2(-9,-8),Vector2(0,-14),Vector2(9,-8),Vector2(8,0)])
		helm.color = Color(0.15, 0.22, 0.12); sol.add_child(helm)
		# Head
		var hd = ColorRect.new(); hd.size = Vector2(12, 10); hd.position = Vector2(-6, -12)
		hd.color = Color(0.55, 0.4, 0.3); sol.add_child(hd)
		# Body
		var bd = ColorRect.new(); bd.size = Vector2(14, 20); bd.position = Vector2(-7, -22)
		bd.color = Color(0.18, 0.25, 0.15); sol.add_child(bd)
		# Rifle
		var rifle = ColorRect.new(); rifle.size = Vector2(22, 3); rifle.position = Vector2(5, -25)
		rifle.rotation = -0.35; rifle.color = Color(0.1, 0.08, 0.06); sol.add_child(rifle)
		# NLF flag on first soldier
		if i == 0:
			var fp = ColorRect.new(); fp.size = Vector2(2, 30); fp.position = Vector2(6, -50)
			fp.color = Color(0.35, 0.22, 0.08); sol.add_child(fp)
			# Cờ đỏ trên, xanh dưới
			var ft = ColorRect.new(); ft.size = Vector2(18, 10); ft.position = Vector2(8, -50); ft.color = Color(0.85,0.1,0.1); sol.add_child(ft)
			var fb = ColorRect.new(); fb.size = Vector2(18, 10); fb.position = Vector2(8, -40); fb.color = Color(0.04,0.35,0.78); sol.add_child(fb)
			var fs_pts = PackedVector2Array()
			for j in 10:
				var r3 = 4.0 if j%2==0 else 2.0
				fs_pts.append(Vector2(cos(j*TAU/10-PI/2)*r3+17, sin(j*TAU/10-PI/2)*r3-45))
			var fs2 = Polygon2D.new(); fs2.polygon = fs_pts; fs2.color = Color.YELLOW; sol.add_child(fs2)

# --- 6. Victory arch ---
func _create_victory_arch(x: float) -> void:
	var arch = Node2D.new()
	arch.position = Vector2(x, 600)
	arch.z_index = -20
	main._add_to_level(arch)

	var pole_color = Color(0.4, 0.28, 0.12)
	# Left pole
	var lp = ColorRect.new(); lp.size = Vector2(10, 250); lp.position = Vector2(-80, -250)
	lp.color = pole_color; arch.add_child(lp)
	# Right pole
	var rp = ColorRect.new(); rp.size = Vector2(10, 250); rp.position = Vector2(70, -250)
	rp.color = pole_color; arch.add_child(rp)
	# Horizontal beam
	var beam = ColorRect.new(); beam.size = Vector2(160, 12); beam.position = Vector2(-80, -252)
	beam.color = pole_color; arch.add_child(beam)
	# Red banner hanging down
	var banner = ColorRect.new(); banner.size = Vector2(140, 45); banner.position = Vector2(-70, -245)
	banner.color = Color(0.85, 0.1, 0.1); arch.add_child(banner)
	# "GIẢI PHÓNG" text label
	var lbl = Label.new(); lbl.text = "GIẢI PHÓNG"
	lbl.position = Vector2(-62, -243)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color.YELLOW)
	arch.add_child(lbl)
	# Flags on sides
	_add_flag_to_node(arch, Vector2(-80, -260), 0.6)
	_add_flag_to_node(arch, Vector2(80, -260), 0.6)

# --- 2. Tank 843 ---
func _create_tank_843(x: float) -> void:
	var tank := Node2D.new()
	# Start off-screen to the right, then drive in
	tank.position = Vector2(x + 600.0, 600)
	tank.z_index = 2
	main._add_to_level(tank)

	var og = Color(0.2, 0.28, 0.14) # olive green
	# Dust trail
	for d in 3:
		var dust = ColorRect.new(); dust.size = Vector2(40 + d*20, 18)
		dust.position = Vector2(-260 - d*35, -10); dust.color = Color(0.6, 0.55, 0.45, 0.25 - d*0.07)
		tank.add_child(dust)
	# Body
	var body = ColorRect.new(); body.size = Vector2(220, 60); body.position = Vector2(-110, -60)
	body.color = og; tank.add_child(body)
	# Front angle
	var front = Polygon2D.new()
	front.polygon = PackedVector2Array([Vector2(0,-60),Vector2(30,-80),Vector2(30,-60)])
	front.color = Color(0.18, 0.25, 0.12); front.position = Vector2(110, 0); tank.add_child(front)
	# Turret (dome)
	var turret = Polygon2D.new()
	turret.polygon = PackedVector2Array([Vector2(-40,0),Vector2(-35,-35),Vector2(0,-42),Vector2(35,-35),Vector2(40,0)])
	turret.color = Color(0.22, 0.3, 0.16); turret.position = Vector2(0, -60); tank.add_child(turret)
	# Gun barrel
	var barrel = ColorRect.new(); barrel.size = Vector2(120, 8); barrel.position = Vector2(35, -88)
	barrel.color = Color(0.15, 0.2, 0.1); tank.add_child(barrel)
	# Tank number "843" — three digit blocks
	for di in 3:
		var digit = ColorRect.new(); digit.size = Vector2(10, 14); digit.position = Vector2(-15 + di*14, -95)
		digit.color = Color(0.9, 0.85, 0.1); tank.add_child(digit)
	# Wheels (6 circles)
	for wi in 6:
		var wpts = PackedVector2Array()
		for j in 10: wpts.append(Vector2(cos(j*TAU/10)*10, sin(j*TAU/10)*10))
		var wheel = Polygon2D.new(); wheel.polygon = wpts
		wheel.color = Color(0.08, 0.08, 0.08); wheel.position = Vector2(-90 + wi*38, -8)
		tank.add_child(wheel)
		var hub = Polygon2D.new(); var hpts = PackedVector2Array()
		for j in 6: hpts.append(Vector2(cos(j*TAU/6)*4, sin(j*TAU/6)*4))
		hub.polygon = hpts; hub.color = Color(0.4,0.4,0.4); hub.position = wheel.position; tank.add_child(hub)
	# Red star on front
	var star_pts = PackedVector2Array()
	for j in 10:
		var sr = 10.0 if j%2==0 else 4.5
		star_pts.append(Vector2(cos(j*TAU/10-PI/2)*sr + 95, sin(j*TAU/10-PI/2)*sr - 35))
	var star_front = Polygon2D.new(); star_front.polygon = star_pts
	star_front.color = Color(0.9, 0.1, 0.1); tank.add_child(star_front)
	# Antenna + NLF flag
	var antenna = ColorRect.new(); antenna.size = Vector2(2, 40); antenna.position = Vector2(-30, -102)
	antenna.color = Color(0.2, 0.15, 0.08); tank.add_child(antenna)
	# Cờ đỏ trên, xanh dưới
	var ft = ColorRect.new(); ft.size = Vector2(20, 10); ft.position = Vector2(-28, -140); ft.color = Color(0.85,0.1,0.1); tank.add_child(ft)
	var fb = ColorRect.new(); fb.size = Vector2(20, 10); fb.position = Vector2(-28, -130); fb.color = Color(0.04,0.35,0.78); tank.add_child(fb)
	var fstar_pts = PackedVector2Array()
	for j in 10:
		var fr = 4.5 if j%2==0 else 2.0
		fstar_pts.append(Vector2(cos(j*TAU/10-PI/2)*fr - 18, sin(j*TAU/10-PI/2)*fr - 135))
	var fstar := Polygon2D.new(); fstar.polygon = fstar_pts; fstar.color = Color.YELLOW; tank.add_child(fstar)

	# Entry animation: drive from right to final position with engine rumble shake
	var entry_tw: Tween = tank.create_tween()
	entry_tw.tween_property(tank, "position:x", x, 4.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Dust clouds during entry
	entry_tw.tween_callback(func():
		for _di in 5:
			var dust2 := ColorRect.new()
			dust2.size = Vector2(30, 14)
			dust2.color = Color(0.7, 0.62, 0.5, 0.4)
			dust2.global_position = tank.global_position + Vector2(randf_range(-80.0, -20.0), randf_range(-8.0, 4.0))
			dust2.z_index = 3
			main._add_to_level(dust2)
			var d_tw: Tween = dust2.create_tween()
			d_tw.tween_property(dust2, "modulate:a", 0.0, 0.8)
			d_tw.finished.connect(dust2.queue_free)
	)

# --- 1. Independence Palace entrance gate ---
func _create_independence_palace_entrance(x: float) -> void:
	var gate = Node2D.new()
	gate.position = Vector2(x, 600)
	gate.z_index = -5
	main._add_to_level(gate)

	var wall_color = Color(0.88, 0.84, 0.72)
	var trim_color = Color(0.7, 0.65, 0.5)

	# Long stone wall
	var wall_l = ColorRect.new(); wall_l.size = Vector2(500, 30); wall_l.position = Vector2(-750, -30)
	wall_l.color = wall_color; gate.add_child(wall_l)
	var wall_r = ColorRect.new(); wall_r.size = Vector2(500, 30); wall_r.position = Vector2(250, -30)
	wall_r.color = wall_color; gate.add_child(wall_r)

	# Left guard tower
	for side in [-1, 1]:
		var tx = side * 210
		var tower = ColorRect.new(); tower.size = Vector2(100, 200); tower.position = Vector2(tx - 50, -200)
		tower.color = wall_color; gate.add_child(tower)
		var parapet = ColorRect.new(); parapet.size = Vector2(110, 18); parapet.position = Vector2(tx - 55, -200)
		parapet.color = trim_color; gate.add_child(parapet)
		# Tower windows (2)
		for wi in 2:
			var win = ColorRect.new(); win.size = Vector2(22, 35); win.position = Vector2(tx - 11, -170 + wi*65)
			win.color = Color(0.15, 0.12, 0.08); gate.add_child(win)
			var wa = Polygon2D.new(); wa.polygon = PackedVector2Array([Vector2(0,0),Vector2(11,-12),Vector2(22,0)])
			wa.color = win.color; wa.position = win.position; gate.add_child(wa)
		# Fire/smoke on tower tops
		_create_smoke_column(x + tx, 600 - 210, Color(0.5, 0.45, 0.4, 1.0))

	# Central arch gate structure
	var arch_body = ColorRect.new(); arch_body.size = Vector2(200, 120); arch_body.position = Vector2(-100, -120)
	arch_body.color = wall_color; gate.add_child(arch_body)
	var arch_top = Polygon2D.new()
	arch_top.polygon = PackedVector2Array([Vector2(-110,-120),Vector2(-110,-150),Vector2(0,-175),Vector2(110,-150),Vector2(110,-120)])
	arch_top.color = wall_color; gate.add_child(arch_top)
	# Ornate arch trim
	var arch_trim = Polygon2D.new()
	arch_trim.polygon = PackedVector2Array([Vector2(-105,-120),Vector2(-105,-148),Vector2(0,-170),Vector2(105,-148),Vector2(105,-120)])
	arch_trim.color = trim_color; gate.add_child(arch_trim)

	# Broken/crashed gate bars (tilted to show tank impact)
	var angles = [-0.7, -0.3, 0.2, 0.6, 0.9]
	for i in 5:
		var bar = ColorRect.new(); bar.size = Vector2(8, 90); bar.position = Vector2(-90 + i * 40, -110)
		bar.rotation = angles[i]; bar.color = Color(0.25, 0.25, 0.3); gate.add_child(bar)

	# Flag pole + large Vietnamese flag above arch
	var pole = ColorRect.new(); pole.size = Vector2(5, 220); pole.position = Vector2(-2, -340)
	pole.color = Color(0.25, 0.2, 0.12); gate.add_child(pole)
	# Flag (large)
	var flag_node = Node2D.new(); flag_node.position = Vector2(3, -330); gate.add_child(flag_node)
	_draw_flag_shapes(flag_node, 80, 55)

# --- 11. Historical moment popup panel ---
func _create_historical_moment_panel(stage_x: float) -> void:
	# Panel is created lazily when player reaches stage_x (checked in a watcher node)
	var watcher_script = GDScript.new()
	watcher_script.source_code = """
extends Node
var _trigger_x: float = 12000.0
var _shown: bool = false
var _main_ref: Node2D

func _process(_delta):
	if _shown: return
	if not is_instance_valid(_main_ref): return
	if not is_instance_valid(_main_ref.player): return
	if _main_ref.player.global_position.x >= _trigger_x:
		_shown = true
		_show_panel()

func _show_panel():
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(520, 100)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, 200)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.82)
	style.border_color = Color(0.85, 0.72, 0.1)
	style.border_width_left = 3; style.border_width_right = 3
	style.border_width_top = 3; style.border_width_bottom = 3
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

	var lbl = RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.text = "[center][b][color=gold]11:30, ngày 30/4/1975[/color][/b]\\nXe tăng 843 húc đổ cổng Dinh Độc Lập.\\n[color=yellow]Miền Nam hoàn toàn giải phóng![/color][/center]"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left = 8; lbl.offset_top = 8; lbl.offset_right = -8; lbl.offset_bottom = -8
	lbl.add_theme_font_size_override("normal_font_size", 15)
	panel.add_child(lbl)

	var ui = _main_ref.get_node_or_null("UI")
	if ui: ui.add_child(panel)
	else: _main_ref.add_child(panel)

	var timer = panel.get_tree().create_timer(4.0)
	timer.timeout.connect(panel.queue_free)
"""
	var watcher = Node.new()
	watcher.name = "HistoryWatcher"
	watcher.set_script(watcher_script)
	watcher.set("_trigger_x", stage_x)
	watcher.set("_main_ref", main)
	main._add_to_level(watcher)

# ============================================================
# === DINH ĐỘC LẬP — CHI TIẾT CAO (80-90% THỰC TẾ) =========
# ============================================================
# Thiết kế KTS Ngô Viết Thụ 1962-1966: lam che nắng bê-tông,
# hai cánh đối xứng, cầu thang lớn, sân trực thăng trên mái,
# cổng sắt + tường rào bên ngoài, vườn cỏ xanh.
func _create_independence_palace_main_building(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -55
	_get_parallax().add_child(node)

	var WALL   = Color(0.94, 0.90, 0.76)  # bê tông màu kem
	var LOUVER = Color(0.74, 0.69, 0.52)  # lam che nắng
	var SHADOW = Color(0.06, 0.06, 0.08, 0.32)
	var WIN    = Color(0.10, 0.13, 0.20, 0.92)
	var TRIM   = Color(0.80, 0.74, 0.58)
	var GRASS  = Color(0.18, 0.40, 0.14)
	var FENCE  = Color(0.62, 0.60, 0.46)

	# ── Bãi cỏ trước Dinh ──────────────────────────────────
	var lawn = ColorRect.new(); lawn.size = Vector2(900, 28); lawn.position = Vector2(-450, -28)
	lawn.color = GRASS; node.add_child(lawn)
	# Lối đi trung tâm (đường nhựa)
	var path = ColorRect.new(); path.size = Vector2(80, 28); path.position = Vector2(-40, -28)
	path.color = Color(0.20, 0.20, 0.22); node.add_child(path)

	# ── Hàng rào + cổng sắt ──────────────────────────────
	var fence_rail = ColorRect.new(); fence_rail.size = Vector2(900, 4); fence_rail.position = Vector2(-450, -32)
	fence_rail.color = FENCE; node.add_child(fence_rail)
	for fi in 20:
		var fp = ColorRect.new(); fp.size = Vector2(4, 22); fp.position = Vector2(-440 + fi * 46, -52)
		fp.color = FENCE; node.add_child(fp)
		# Đầu nhọn kiểu Pháp
		var tip = Polygon2D.new()
		tip.polygon = PackedVector2Array([Vector2(-3,0),Vector2(0,-8),Vector2(3,0)])
		tip.color = FENCE; tip.position = Vector2(-438 + fi * 46, -52); node.add_child(tip)
	# Cổng trung tâm (mở toang do xe tăng húc)
	for gi in 2:
		var gbar = ColorRect.new(); gbar.size = Vector2(6, 75)
		gbar.position = Vector2(-30 + gi * 56, -105)
		gbar.rotation = (1.2 if gi == 0 else -1.2)
		gbar.color = Color(0.22, 0.22, 0.26); node.add_child(gbar)

	# ── Nền móng / bậc thềm lớn ──────────────────────────
	var plinth = ColorRect.new(); plinth.size = Vector2(820, 32); plinth.position = Vector2(-410, -62)
	plinth.color = Color(0.74, 0.70, 0.56); node.add_child(plinth)
	for step in 5:
		var sw = 320 + step * 40
		var s = ColorRect.new(); s.size = Vector2(sw, 10); s.position = Vector2(-sw/2.0, -62 - step * 10)
		s.color = Color(0.87, 0.82, 0.68 - step * 0.015); node.add_child(s)

	# ── Hai cánh nhà (trái và phải) ──────────────────────
	for side in [-1, 1]:
		var wx = side * 295
		# Thân cánh (3 tầng)
		var wing = ColorRect.new(); wing.size = Vector2(220, 310); wing.position = Vector2(wx - 110, -372)
		wing.color = WALL; node.add_child(wing)
		# Đường ngang phân tầng × 3
		for fl in 4:
			var wfl = ColorRect.new(); wfl.size = Vector2(224, 6); wfl.position = Vector2(wx - 112, -372 + fl * 100)
			wfl.color = LOUVER; node.add_child(wfl)
		# Lam che nắng cánh (3 tầng × 6 ô)
		for fl in 3:
			for bay in 6:
				var bx = wx - 100 + bay * 33
				var lam = ColorRect.new(); lam.size = Vector2(28, 88); lam.position = Vector2(bx, -366 + fl * 100)
				lam.color = LOUVER; node.add_child(lam)
				for sl in 3:
					var slat = ColorRect.new(); slat.size = Vector2(28, 2); slat.position = Vector2(bx, -366 + fl * 100 + sl * 28)
					slat.color = SHADOW; node.add_child(slat)
				var bwin = ColorRect.new(); bwin.size = Vector2(22, 86); bwin.position = Vector2(bx + 3, -365 + fl * 100)
				bwin.color = WIN; bwin.modulate.a = 0.42; node.add_child(bwin)
		# Parapet cánh
		var w_par = ColorRect.new(); w_par.size = Vector2(226, 16); w_par.position = Vector2(wx - 113, -374)
		w_par.color = LOUVER; node.add_child(w_par)
		# Cờ nhỏ đầu cánh
		var sf_pole = ColorRect.new(); sf_pole.size = Vector2(3, 45); sf_pole.position = Vector2(wx - 2, -419)
		sf_pole.color = Color(0.52, 0.47, 0.32); node.add_child(sf_pole)
		var sf_flag = Node2D.new(); sf_flag.position = Vector2(wx + 1, -415); sf_flag.scale = Vector2(0.55, 0.55)
		node.add_child(sf_flag); _draw_flag_shapes(sf_flag, 44, 32)

	# ── Khối trung tâm chính (cao nhất) ──────────────────
	var central = ColorRect.new(); central.size = Vector2(420, 440); central.position = Vector2(-210, -502)
	central.color = WALL; node.add_child(central)

	# ── Lam che nắng đặc trưng khối trung tâm (4 tầng × 14 ô) ──
	for fl in 4:
		var fy = -472 + fl * 108
		# Sàn ngang
		var slab = ColorRect.new(); slab.size = Vector2(420, 8); slab.position = Vector2(-210, fy)
		slab.color = LOUVER; node.add_child(slab)
		for bay in 13:
			var bx = -202 + bay * 30
			var lam = ColorRect.new(); lam.size = Vector2(26, 96); lam.position = Vector2(bx, fy + 8)
			lam.color = LOUVER; node.add_child(lam)
			for sl in 4:
				var slat = ColorRect.new(); slat.size = Vector2(26, 2); slat.position = Vector2(bx, fy + 8 + sl * 23)
				slat.color = SHADOW; node.add_child(slat)
			var bg_win = ColorRect.new(); bg_win.size = Vector2(20, 94); bg_win.position = Vector2(bx + 3, fy + 9)
			bg_win.color = WIN; bg_win.modulate.a = 0.40; node.add_child(bg_win)

	# ── Ban công + hành lang mặt tiền tầng 1 ──
	var portico_slab = ColorRect.new(); portico_slab.size = Vector2(260, 14); portico_slab.position = Vector2(-130, -118)
	portico_slab.color = LOUVER; node.add_child(portico_slab)
	# Cột hành lang (4 cột)
	for ci in 4:
		var col = ColorRect.new(); col.size = Vector2(14, 52); col.position = Vector2(-120 + ci * 78, -170)
		col.color = WALL; node.add_child(col)
		var cap = ColorRect.new(); cap.size = Vector2(20, 8); cap.position = Vector2(-123 + ci * 78, -170)
		cap.color = LOUVER; node.add_child(cap)
	# Cửa lớn tầng 1 (3 cửa đôi)
	for ci in 3:
		var door = ColorRect.new(); door.size = Vector2(36, 60); door.position = Vector2(-74 + ci * 52, -170)
		door.color = WIN; node.add_child(door)
		var d_arch = Polygon2D.new()
		d_arch.polygon = PackedVector2Array([Vector2(0,0),Vector2(18,-16),Vector2(36,0)])
		d_arch.color = WIN; d_arch.position = door.position; node.add_child(d_arch)

	# ── Parapet mái trung tâm ──
	var roof_par = ColorRect.new(); roof_par.size = Vector2(432, 20); roof_par.position = Vector2(-216, -504)
	roof_par.color = LOUVER; node.add_child(roof_par)
	# Tường nhỏ phân ô trên parapet
	for pi in 8:
		var pblock = ColorRect.new(); pblock.size = Vector2(40, 20); pblock.position = Vector2(-210 + pi * 55, -524)
		pblock.color = WALL; node.add_child(pblock)

	# ── Tầng thượng (penthouse) ──
	var pent = ColorRect.new(); pent.size = Vector2(240, 46); pent.position = Vector2(-120, -550)
	pent.color = WALL; node.add_child(pent)
	var pent_par = ColorRect.new(); pent_par.size = Vector2(248, 12); pent_par.position = Vector2(-124, -550)
	pent_par.color = LOUVER; node.add_child(pent_par)
	# Cửa sổ penthouse (5 ô)
	for pi in 5:
		var pw = ColorRect.new(); pw.size = Vector2(26, 30); pw.position = Vector2(-105 + pi * 44, -538)
		pw.color = WIN; node.add_child(pw)

	# ── Sân thượng + bãi đáp trực thăng ──
	var helipad_base = ColorRect.new(); helipad_base.size = Vector2(100, 8); helipad_base.position = Vector2(-50, -558)
	helipad_base.color = Color(0.28, 0.28, 0.30); node.add_child(helipad_base)
	var hcpts = PackedVector2Array()
	for j in 20: hcpts.append(Vector2(cos(j*TAU/20)*40, sin(j*TAU/20)*26))
	var helipad = Polygon2D.new(); helipad.polygon = hcpts
	helipad.color = Color(0.25, 0.25, 0.28, 0.6); helipad.position = Vector2(-50, -568); node.add_child(helipad)
	# Chữ H sân đáp
	var hv = ColorRect.new(); hv.size = Vector2(4, 20); hv.position = Vector2(-58, -578); hv.color = Color(0.85, 0.85, 0.85, 0.7); node.add_child(hv)
	var hv2 = ColorRect.new(); hv2.size = Vector2(4, 20); hv2.position = Vector2(-46, -578); hv2.color = Color(0.85, 0.85, 0.85, 0.7); node.add_child(hv2)
	var hh = ColorRect.new(); hh.size = Vector2(16, 3); hh.position = Vector2(-58, -569); hh.color = Color(0.85, 0.85, 0.85, 0.7); node.add_child(hh)

	# ── Cột cờ chính trên mái + cờ NLF lớn ──
	var flagpole = ColorRect.new(); flagpole.size = Vector2(5, 150); flagpole.position = Vector2(-2, -700)
	flagpole.color = Color(0.70, 0.65, 0.50); node.add_child(flagpole)
	var flag_nd = Node2D.new(); flag_nd.position = Vector2(3, -695); node.add_child(flag_nd)
	_draw_flag_shapes(flag_nd, 110, 78)

# ============================================================
# === KHÁCH SẠN REX (REX HOTEL) STYLE — NGÔ ĐỨC KẾ / LÊ LỢI
# ============================================================
func _create_rex_hotel_bg(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -82
	node.modulate = Color(0.52, 0.55, 0.72, 0.58)
	_get_parallax().add_child(node)

	var WALL  = Color(0.88, 0.80, 0.60)
	var TRIM  = Color(0.70, 0.62, 0.44)
	var WIN   = Color(0.12, 0.15, 0.22)
	var ROOF  = Color(0.30, 0.35, 0.22)   # vườn trên mái (màu xanh lá)

	# Thân khách sạn (5 tầng)
	var body = ColorRect.new(); body.size = Vector2(340, 360); body.position = Vector2(-170, -360)
	body.color = WALL; node.add_child(body)
	# Đường phân tầng × 5
	for fl in 5:
		var fline = ColorRect.new(); fline.size = Vector2(344, 6); fline.position = Vector2(-172, -360 + fl * 72)
		fline.color = TRIM; node.add_child(fline)
	# Cửa sổ vòng cung kiểu Pháp (5 tầng × 5 cửa)
	for fl in 5:
		for wc in 5:
			var win = ColorRect.new(); win.size = Vector2(30, 48); win.position = Vector2(-150 + wc * 62, -340 + fl * 72)
			win.color = WIN; node.add_child(win)
			var arc = Polygon2D.new()
			arc.polygon = PackedVector2Array([Vector2(0,0),Vector2(15,-14),Vector2(30,0)])
			arc.color = WIN; arc.position = win.position; node.add_child(arc)
			# Cánh cửa chớp xanh
			var shutter = ColorRect.new(); shutter.size = Vector2(12, 48)
			shutter.position = Vector2(win.position.x + 30, win.position.y)
			shutter.color = Color(0.22, 0.40, 0.22, 0.75); node.add_child(shutter)
	# Tầng trệt arcade (hành lang mái vòm Pháp)
	for ai in 5:
		var arch_body = ColorRect.new(); arch_body.size = Vector2(54, 44); arch_body.position = Vector2(-162 + ai * 66, -56)
		arch_body.color = TRIM; node.add_child(arch_body)
		var arch_top = Polygon2D.new()
		arch_top.polygon = PackedVector2Array([Vector2(0,0),Vector2(27,-24),Vector2(54,0)])
		arch_top.color = TRIM; arch_top.position = Vector2(-162 + ai * 66, -56); node.add_child(arch_top)
		var arch_in = ColorRect.new(); arch_in.size = Vector2(40, 44); arch_in.position = Vector2(-155 + ai * 66, -56)
		arch_in.color = WIN; node.add_child(arch_in)
	# Mái vườn trên nóc (đặc trưng Rex Hotel có vườn rooftop)
	var roof_garden = ColorRect.new(); roof_garden.size = Vector2(350, 28); roof_garden.position = Vector2(-175, -388)
	roof_garden.color = ROOF; node.add_child(roof_garden)
	# Cây cảnh trên mái (4 cây)
	for ti in 4:
		var tree_trunk = ColorRect.new(); tree_trunk.size = Vector2(5, 22); tree_trunk.position = Vector2(-150 + ti * 100, -410)
		tree_trunk.color = Color(0.28, 0.18, 0.10); node.add_child(tree_trunk)
		var tree_crown = Polygon2D.new(); var tcpts = PackedVector2Array()
		for j in 8: tcpts.append(Vector2(cos(j*TAU/8)*16, sin(j*TAU/8)*12))
		tree_crown.polygon = tcpts; tree_crown.color = Color(0.18, 0.42, 0.14)
		tree_crown.position = Vector2(-147 + ti * 100, -418); node.add_child(tree_crown)
	# Parapet nóc + bảng hiệu REX
	var par = ColorRect.new(); par.size = Vector2(350, 18); par.position = Vector2(-175, -390)
	par.color = TRIM; node.add_child(par)
	var sign = ColorRect.new(); sign.size = Vector2(120, 24); sign.position = Vector2(-60, -408)
	sign.color = Color(0.85, 0.10, 0.08); node.add_child(sign)
	var sign_lbl = Label.new(); sign_lbl.text = "REX"
	sign_lbl.position = Vector2(-50, -409)
	sign_lbl.add_theme_font_size_override("font_size", 14)
	sign_lbl.add_theme_color_override("font_color", Color.YELLOW); node.add_child(sign_lbl)
	# Cột cờ
	var sp = ColorRect.new(); sp.size = Vector2(3, 55); sp.position = Vector2(-1, -445)
	sp.color = Color(0.55, 0.50, 0.38); node.add_child(sp)
	var sf = Node2D.new(); sf.position = Vector2(2, -441); sf.scale = Vector2(0.6, 0.6); node.add_child(sf)
	_draw_flag_shapes(sf, 44, 32)

# ============================================================
# === KHÁCH SẠN CONTINENTAL / CARAVELLE STYLE ================
# ============================================================
func _create_continental_hotel_bg(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = Vector2(-84, 0).x
	node.z_index = -84
	node.modulate = Color(0.50, 0.53, 0.70, 0.55)
	_get_parallax().add_child(node)

	var WALL = Color(0.90, 0.84, 0.64)
	var TRIM = Color(0.68, 0.60, 0.42)
	var WIN  = Color(0.12, 0.14, 0.20)

	# Khối chính (6 tầng)
	var body = ColorRect.new(); body.size = Vector2(300, 420); body.position = Vector2(-150, -420)
	body.color = WALL; node.add_child(body)
	# Đường phân tầng
	for fl in 6:
		var fl_line = ColorRect.new(); fl_line.size = Vector2(304, 5); fl_line.position = Vector2(-152, -420 + fl * 70)
		fl_line.color = TRIM; node.add_child(fl_line)
	# Cửa sổ (6 tầng × 4 cửa)
	for fl in 6:
		for wc in 4:
			var win = ColorRect.new(); win.size = Vector2(34, 52); win.position = Vector2(-132 + wc * 76, -400 + fl * 70)
			win.color = WIN; node.add_child(win)
			var arc = Polygon2D.new()
			arc.polygon = PackedVector2Array([Vector2(0,0),Vector2(17,-15),Vector2(34,0)])
			arc.color = WIN; arc.position = win.position; node.add_child(arc)
	# Mái tam giác kiểu Pháp (mansard)
	var mansard = Polygon2D.new()
	mansard.polygon = PackedVector2Array([Vector2(-155,-420),Vector2(-130,-460),Vector2(0,-480),Vector2(130,-460),Vector2(155,-420)])
	mansard.color = Color(0.42, 0.30, 0.20); node.add_child(mansard)
	# Cửa sổ mái (dormer windows) × 3
	for di in 3:
		var dwx = -80 + di * 80
		var dw = Polygon2D.new()
		dw.polygon = PackedVector2Array([Vector2(-10,0),Vector2(0,-18),Vector2(10,0)])
		dw.color = WALL; dw.position = Vector2(dwx, -440); node.add_child(dw)
		var dwin = ColorRect.new(); dwin.size = Vector2(14, 14); dwin.position = Vector2(dwx - 7, -436)
		dwin.color = WIN; node.add_child(dwin)
	# Arcade tầng trệt
	for ai in 4:
		var col = ColorRect.new(); col.size = Vector2(10, 55); col.position = Vector2(-130 + ai * 80, -65)
		col.color = TRIM; node.add_child(col)
	var awning = ColorRect.new(); awning.size = Vector2(310, 12); awning.position = Vector2(-155, -62)
	awning.color = Color(0.80, 0.15, 0.12); node.add_child(awning)
	# Cờ
	var sp = ColorRect.new(); sp.size = Vector2(3, 60); sp.position = Vector2(-1, -542)
	sp.color = Color(0.55, 0.50, 0.38); node.add_child(sp)
	var sf = Node2D.new(); sf.position = Vector2(2, -537); sf.scale = Vector2(0.6, 0.6); node.add_child(sf)
	_draw_flag_shapes(sf, 44, 32)

# ============================================================
# === NHÀ ỐNG SÀI GÒN (TUBE HOUSES ROW) =====================
# ============================================================
func _create_saigon_tube_house_row(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -75
	_get_parallax().add_child(node)

	var palette = [
		Color(0.94, 0.85, 0.62), Color(0.78, 0.90, 0.80),
		Color(0.92, 0.78, 0.74), Color(0.82, 0.82, 0.94),
		Color(0.96, 0.90, 0.70), Color(0.74, 0.88, 0.86)
	]
	var count = randi_range(4, 7)
	for i in count:
		var sw = randf_range(65, 95)
		var sh = randf_range(200, 360)
		var sx = -count * 48 + i * 100.0
		var col = palette[i % palette.size()]

		# Mặt tiền
		var face = ColorRect.new(); face.size = Vector2(sw, sh); face.position = Vector2(sx, -sh)
		face.color = col; node.add_child(face)

		# Tường ngăn giữa
		var div = ColorRect.new(); div.size = Vector2(2, sh); div.position = Vector2(sx + sw, -sh)
		div.color = Color(0.4, 0.38, 0.3, 0.6); node.add_child(div)

		# Parapet (gờ sênô trên đỉnh)
		var par = ColorRect.new(); par.size = Vector2(sw + 4, 16); par.position = Vector2(sx - 2, -sh - 10)
		par.color = Color(0.60, 0.55, 0.40); node.add_child(par)

		# Tầng trệt: cửa cuốn hoặc shop
		var shutter = ColorRect.new(); shutter.size = Vector2(sw * 0.72, 62); shutter.position = Vector2(sx + sw * 0.14, -64)
		shutter.color = Color(0.08, 0.06, 0.05); node.add_child(shutter)
		# Thanh sắt cửa cuốn
		for bar in 5:
			var bline = ColorRect.new(); bline.size = Vector2(sw * 0.72, 2)
			bline.position = Vector2(sx + sw * 0.14, -62 + bar * 12)
			bline.color = Color(0.22, 0.20, 0.18); node.add_child(bline)

		# Mái che vải / hiên (awning)
		var awning = Polygon2D.new()
		awning.polygon = PackedVector2Array([
			Vector2(sx - 4, -64), Vector2(sx + sw + 4, -64),
			Vector2(sx + sw + 14, -80), Vector2(sx - 14, -80)
		])
		awning.color = [Color(0.80,0.18,0.12), Color(0.18,0.50,0.22), Color(0.18,0.22,0.72)][i % 3]
		node.add_child(awning)

		# Số tầng: 2-3 tầng trên
		var floors = randi_range(2, 3)
		for fl in floors:
			var wy = -sh + 28 + fl * (sh / float(floors + 1))
			# Cửa sổ khung gỗ
			var win = ColorRect.new(); win.size = Vector2(sw * 0.5, 38); win.position = Vector2(sx + sw * 0.25, wy)
			win.color = Color(0.10, 0.13, 0.20); node.add_child(win)
			var win_frame = ColorRect.new(); win_frame.size = Vector2(sw * 0.5 + 4, 40)
			win_frame.position = Vector2(sx + sw * 0.25 - 2, wy - 1)
			win_frame.color = Color(0.58, 0.50, 0.36, 0.8); win_frame.z_index = -1; node.add_child(win_frame)
			# Cờ / đồ phơi trên cửa sổ
			if randf() < 0.45:
				_add_flag_to_node(node, Vector2(sx + sw * 0.5, wy - 10), 0.40)
			else:
				var rope = ColorRect.new(); rope.size = Vector2(sw * 0.6, 2); rope.position = Vector2(sx + sw * 0.2, wy - 4)
				rope.color = Color(0.08,0.08,0.08); node.add_child(rope)
				for k in randi_range(2, 4):
					var cloth = ColorRect.new(); cloth.size = Vector2(randf_range(8,16), randf_range(12,22))
					cloth.position = Vector2(sx + sw * 0.2 + k * 16, wy - 4 + randf_range(0,4))
					cloth.color = Color(randf(), randf(), randf()); node.add_child(cloth)

		# Bảng hiệu tầng trệt
		if randf() < 0.6:
			var sign = ColorRect.new(); sign.size = Vector2(sw * 0.8, 14); sign.position = Vector2(sx + sw * 0.1, -82)
			sign.color = Color(randf_range(0.7,1.0), randf_range(0.1,0.3), randf_range(0.05,0.2)); node.add_child(sign)

# ============================================================
# === BIỆT THỰ PHÁP THUỘC (ELABORATE FRENCH COLONIAL VILLA) ==
# ============================================================
func _create_french_villa_elaborate(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -74
	_get_parallax().add_child(node)

	var WALL   = Color(0.92, 0.84, 0.62)
	var TRIM   = Color(0.72, 0.64, 0.44)
	var WIN    = Color(0.14, 0.16, 0.22)
	var SHUTTER = Color(0.22, 0.42, 0.22)
	var ROOF   = Color(0.72, 0.28, 0.18)

	# Tường cổng + hàng rào villa
	var fence = ColorRect.new(); fence.size = Vector2(480, 10); fence.position = Vector2(-240, -10)
	fence.color = TRIM; node.add_child(fence)
	for fi in 10:
		var fp = ColorRect.new(); fp.size = Vector2(5, 22); fp.position = Vector2(-230 + fi * 48, -30)
		fp.color = TRIM; node.add_child(fp)

	# Bãi cỏ trước villa
	var lawn = ColorRect.new(); lawn.size = Vector2(480, 22); lawn.position = Vector2(-240, -22)
	lawn.color = Color(0.20, 0.42, 0.16); node.add_child(lawn)

	# Thân villa chính (2 tầng)
	var body = ColorRect.new(); body.size = Vector2(380, 240); body.position = Vector2(-190, -270)
	body.color = WALL; node.add_child(body)

	# Mái ngói kiểu Pháp (hip roof 4 mặt)
	var roof_front = Polygon2D.new()
	roof_front.polygon = PackedVector2Array([Vector2(-200,-270),Vector2(-80,-340),Vector2(80,-340),Vector2(200,-270)])
	roof_front.color = ROOF; node.add_child(roof_front)
	var chimney = ColorRect.new(); chimney.size = Vector2(18, 40); chimney.position = Vector2(60, -370)
	chimney.color = Color(0.60, 0.25, 0.14); node.add_child(chimney)

	# Đường phân tầng
	var floor_band = ColorRect.new(); floor_band.size = Vector2(384, 8); floor_band.position = Vector2(-192, -152)
	floor_band.color = TRIM; node.add_child(floor_band)

	# Ban công tầng 2 (với lan can trụ đứng kiểu Pháp)
	var bal_slab = ColorRect.new(); bal_slab.size = Vector2(240, 10); bal_slab.position = Vector2(-120, -154)
	bal_slab.color = TRIM; node.add_child(bal_slab)
	for bi in 12:
		var baluster = ColorRect.new(); baluster.size = Vector2(5, 24); baluster.position = Vector2(-118 + bi * 19, -178)
		baluster.color = Color(0.88, 0.82, 0.64); node.add_child(baluster)
	var bal_rail = ColorRect.new(); bal_rail.size = Vector2(240, 5); bal_rail.position = Vector2(-120, -178)
	bal_rail.color = TRIM; node.add_child(bal_rail)

	# Cửa sổ tầng 1 (3 cửa đôi vòm Pháp)
	for ci in 3:
		var win = ColorRect.new(); win.size = Vector2(38, 65); win.position = Vector2(-148 + ci * 100, -215)
		win.color = WIN; node.add_child(win)
		var arc = Polygon2D.new()
		arc.polygon = PackedVector2Array([Vector2(0,0),Vector2(19,-18),Vector2(38,0)])
		arc.color = WIN; arc.position = win.position; node.add_child(arc)
		# Cánh cửa chớp xanh
		for sh in 2:
			var s = ColorRect.new(); s.size = Vector2(16, 65)
			s.position = Vector2(win.position.x + sh * 22, win.position.y)
			s.color = SHUTTER; node.add_child(s)

	# Cửa sổ tầng 2 (3 cửa có ô lưới)
	for ci in 3:
		var win2 = ColorRect.new(); win2.size = Vector2(34, 52); win2.position = Vector2(-146 + ci * 100, -112)
		win2.color = WIN; node.add_child(win2)
		var arc2 = Polygon2D.new()
		arc2.polygon = PackedVector2Array([Vector2(0,0),Vector2(17,-14),Vector2(34,0)])
		arc2.color = WIN; arc2.position = win2.position; node.add_child(arc2)
		var sh2 = ColorRect.new(); sh2.size = Vector2(14, 52); sh2.position = Vector2(win2.position.x + 34, win2.position.y)
		sh2.color = SHUTTER; node.add_child(sh2)

	# Hàng cột hành lang tầng trệt (4 cột)
	for ci in 4:
		var col = ColorRect.new(); col.size = Vector2(12, 60); col.position = Vector2(-170 + ci * 106, -270)
		col.color = Color(0.94, 0.90, 0.72); node.add_child(col)
		var base = ColorRect.new(); base.size = Vector2(18, 10); base.position = Vector2(-173 + ci * 106, -270)
		base.color = TRIM; node.add_child(base)
		var cap = ColorRect.new(); cap.size = Vector2(18, 8); cap.position = Vector2(-173 + ci * 106, -274)
		cap.color = TRIM; node.add_child(cap)

	# Cửa ra vào chính (cửa đôi lớn)
	var main_door = ColorRect.new(); main_door.size = Vector2(52, 70); main_door.position = Vector2(-26, -270)
	main_door.color = Color(0.18, 0.12, 0.08); node.add_child(main_door)
	var door_arc = Polygon2D.new()
	door_arc.polygon = PackedVector2Array([Vector2(0,0),Vector2(26,-24),Vector2(52,0)])
	door_arc.color = Color(0.18, 0.12, 0.08); door_arc.position = main_door.position; node.add_child(door_arc)

	# Cột cờ + cờ
	var sp = ColorRect.new(); sp.size = Vector2(3, 65); sp.position = Vector2(-1, -335)
	sp.color = Color(0.52, 0.47, 0.32); node.add_child(sp)
	var sf = Node2D.new(); sf.position = Vector2(2, -331); sf.scale = Vector2(0.65, 0.65); node.add_child(sf)
	_draw_flag_shapes(sf, 44, 32)

	# Con đường lát gạch dẫn vào cửa
	for pi in 5:
		var pstone = ColorRect.new(); pstone.size = Vector2(22, 10); pstone.position = Vector2(-11 + randf_range(-4,4), -22 - pi * 8)
		pstone.color = Color(0.60, 0.56, 0.44); node.add_child(pstone)

# ============================================================
# === CHÙA / ĐỀN THỜ SÀI GÒN (BUDDHIST PAGODA) ==============
# ============================================================
func _create_saigon_pagoda_bg(x: float) -> void:
	var node = Node2D.new()
	node.position = Vector2(x, 600)
	node.z_index = -86
	node.modulate = Color(0.50, 0.52, 0.65, 0.52)
	_get_parallax().add_child(node)

	var WALL = Color(0.88, 0.78, 0.55)
	var ROOF = Color(0.24, 0.42, 0.20)   # ngói xanh chùa
	var TRIM = Color(0.82, 0.55, 0.18)   # viền vàng son

	# Thân chính
	var body = ColorRect.new(); body.size = Vector2(280, 180); body.position = Vector2(-140, -180)
	body.color = WALL; node.add_child(body)
	# Cổng tam quan (3 vòm)
	for ai in 3:
		var ax = -100 + ai * 90
		var arch = Polygon2D.new()
		arch.polygon = PackedVector2Array([Vector2(-20,0),Vector2(-20,-55),Vector2(0,-75),Vector2(20,-55),Vector2(20,0)])
		arch.color = Color(0.08,0.08,0.10); arch.position = Vector2(ax, -18); node.add_child(arch)
		var at = Polygon2D.new()
		at.polygon = PackedVector2Array([Vector2(-24, 0), Vector2(-22,-57), Vector2(0,-78), Vector2(22,-57), Vector2(24,0)])
		at.color = TRIM; at.position = Vector2(ax, -18); at.z_index = -1; node.add_child(at)

	# Tháp chính (tháp chuông phía trên)
	var tower = ColorRect.new(); tower.size = Vector2(100, 160); tower.position = Vector2(-50, -340)
	tower.color = WALL; node.add_child(tower)
	# Mái 3 tầng kiểu chùa (3 eaves giật cấp)
	for tier in 3:
		var tw = 130 - tier * 28; var ty = -340 - tier * 40
		var eave_pts = PackedVector2Array()
		eave_pts.append(Vector2(-tw/2.0 - 10, 0)); eave_pts.append(Vector2(-tw/2.0 + 6, -12))
		eave_pts.append(Vector2(tw/2.0 - 6, -12)); eave_pts.append(Vector2(tw/2.0 + 10, 0))
		var eave = Polygon2D.new(); eave.polygon = eave_pts; eave.color = ROOF; eave.position = Vector2(0, ty); node.add_child(eave)
		var eave_ridge = ColorRect.new(); eave_ridge.size = Vector2(tw - 12, 5)
		eave_ridge.position = Vector2(-(tw - 12)/2.0, ty - 5)
		eave_ridge.color = TRIM; node.add_child(eave_ridge)
	# Ngọn tháp (đỉnh nhọn)
	var spire = Polygon2D.new()
	spire.polygon = PackedVector2Array([Vector2(-10,0),Vector2(0,-50),Vector2(10,0)])
	spire.color = TRIM; spire.position = Vector2(0, -460); node.add_child(spire)
	# Tường bao + sân chùa
	for side2 in [-1, 1]:
		var wwall = ColorRect.new(); wwall.size = Vector2(14, 140); wwall.position = Vector2(side2 * 140 - 7, -140)
		wwall.color = WALL; node.add_child(wwall)
	var yard = ColorRect.new(); yard.size = Vector2(296, 16); yard.position = Vector2(-148, -16)
	yard.color = Color(0.62, 0.58, 0.45); node.add_child(yard)
