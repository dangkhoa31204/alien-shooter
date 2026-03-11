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

	_create_independence_palace_entrance(14500)
	_create_independence_palace_building(15300)
	_create_historical_moment_panel(13800)

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

# --- PERFECT VISUAL HELPERS ---

func _create_independence_palace_distant(x: float):
	var p = Node2D.new(); p.position = Vector2(x, 600); p.z_index = -98; _get_parallax().add_child(p)
	p.modulate = Color(0.4, 0.45, 0.6, 0.4)
	var body = ColorRect.new(); body.size = Vector2(500, 150); body.position = Vector2(-250, -150); p.add_child(body)
	var dome = Polygon2D.new(); dome.polygon = [Vector2(-80, 0), Vector2(0, -60), Vector2(80, 0)]; dome.position = Vector2(0, -150); p.add_child(dome)

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
	var red = ColorRect.new(); red.size = Vector2(w, h/2); red.color = Color(0.85, 0.1, 0.1); node.add_child(red)
	var blu = ColorRect.new(); blu.size = Vector2(w, h/2); blu.position = Vector2(0, h/2); blu.color = Color(0.1, 0.4, 0.85); node.add_child(blu)
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
		var flag_top = ColorRect.new(); flag_top.size = Vector2(12, 8); flag_top.position = Vector2(5, -52)
		flag_top.color = Color(0.85, 0.1, 0.1); civ.add_child(flag_top)
		var star_pts = PackedVector2Array()
		for j in 10:
			var r2 = 3.0 if j % 2 == 0 else 1.5
			star_pts.append(Vector2(cos(j*TAU/10 - PI/2)*r2 + 11, sin(j*TAU/10 - PI/2)*r2 - 48))
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
			var ft = ColorRect.new(); ft.size = Vector2(18, 10); ft.position = Vector2(8, -50); ft.color = Color(0.85,0.1,0.1); sol.add_child(ft)
			var fb = ColorRect.new(); fb.size = Vector2(18, 10); fb.position = Vector2(8, -40); fb.color = Color(0.1,0.35,0.85); sol.add_child(fb)
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
	var tank = Node2D.new()
	tank.position = Vector2(x, 600)
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
	var ft = ColorRect.new(); ft.size = Vector2(20, 10); ft.position = Vector2(-28, -140); ft.color = Color(0.85,0.1,0.1); tank.add_child(ft)
	var fb = ColorRect.new(); fb.size = Vector2(20, 10); fb.position = Vector2(-28, -130); fb.color = Color(0.1,0.35,0.85); tank.add_child(fb)
	var fstar_pts = PackedVector2Array()
	for j in 10:
		var fr = 4.5 if j%2==0 else 2.0
		fstar_pts.append(Vector2(cos(j*TAU/10-PI/2)*fr - 18, sin(j*TAU/10-PI/2)*fr - 135))
	var fstar = Polygon2D.new(); fstar.polygon = fstar_pts; fstar.color = Color.YELLOW; tank.add_child(fstar)

# --- 1. Independence Palace entrance gate (Historical Crashing Scene) ---
func _create_independence_palace_entrance(x: float) -> void:
	var scene = Node2D.new()
	scene.position = Vector2(x, 600)
	scene.z_index = -5
	main._add_to_level(scene)

	var wall_color = Color(0.9, 0.86, 0.75)
	var trim_color = Color(0.75, 0.7, 0.55)
	var bar_color = Color(0.15, 0.15, 0.18)

	# 1. SIDE WALLS & TOWERS
	var wall_l = ColorRect.new(); wall_l.size = Vector2(600, 35); wall_l.position = Vector2(-850, -35)
	wall_l.color = wall_color; scene.add_child(wall_l)
	var wall_r = ColorRect.new(); wall_r.size = Vector2(600, 35); wall_r.position = Vector2(250, -35)
	wall_r.color = wall_color; scene.add_child(wall_r)

	# Guard Towers with detail
	for side in [-1, 1]:
		var tx = side * 230
		var tower = Node2D.new(); tower.position = Vector2(tx, 0); scene.add_child(tower)
		
		# Tower Body
		var body = ColorRect.new(); body.size = Vector2(110, 220); body.position = Vector2(-55, -220)
		body.color = wall_color; tower.add_child(body)
		
		# Shadow side
		var shadow = ColorRect.new(); shadow.size = Vector2(15, 220); shadow.position = Vector2(40, -220)
		shadow.color = Color(0,0,0,0.1); tower.add_child(shadow)
		
		# Parapet
		var parapet = ColorRect.new(); parapet.size = Vector2(130, 22); parapet.position = Vector2(-65, -225)
		parapet.color = trim_color; tower.add_child(parapet)
		
		# Arched Windows
		for wi in 2:
			var wy = -180 + wi*75
			var win = ColorRect.new(); win.size = Vector2(26, 40); win.position = Vector2(-13, wy)
			win.color = Color(0.12, 0.1, 0.08); tower.add_child(win)
			var arch = Polygon2D.new(); arch.polygon = [Vector2(0,0), Vector2(13,-18), Vector2(26,0)]
			arch.position = win.position; arch.color = win.color; tower.add_child(arch)
		
		# Smoke from damage
		_create_smoke_column(x + tx, 600 - 230, Color(0.4, 0.4, 0.45, 0.8))

	# 2. THE TANK (390/843) CRASHING IN
	var tank_pos = Vector2(0, -10)
	var tank = Node2D.new(); tank.position = tank_pos; tank.z_index = 5; scene.add_child(tank)
	tank.rotation = -0.12 # Tilted as it goes over the curb/debris
	
	var og = Color(0.22, 0.3, 0.15) # Olive Green
	# Tank Chassis
	var chassis = ColorRect.new(); chassis.size = Vector2(240, 65); chassis.position = Vector2(-120, -65)
	chassis.color = og; tank.add_child(chassis)
	# Turret
	var turret = Polygon2D.new()
	turret.polygon = [Vector2(-45,0), Vector2(-40,-40), Vector2(0,-50), Vector2(40,-40), Vector2(45,0)]
	turret.color = Color(0.25, 0.32, 0.18); turret.position = Vector2(10, -65); tank.add_child(turret)
	# Barrel
	var barrel = ColorRect.new(); barrel.size = Vector2(140, 10); barrel.position = Vector2(50, -95)
	barrel.color = Color(0.18, 0.22, 0.1); tank.add_child(barrel)
	# Star
	var star_pts = []
	for j in 10:
		var sr = 12 if j%2==0 else 5
		star_pts.append(Vector2(cos(j*TAU/10-PI/2)*sr + 100, sin(j*TAU/10-PI/2)*sr - 35))
	var star = Polygon2D.new(); star.polygon = PackedVector2Array(star_pts); star.color = Color.RED; tank.add_child(star)
	# NLF Flag on tank
	var ant = ColorRect.new(); ant.size = Vector2(2, 50); ant.position = Vector2(-20, -115); ant.color = bar_color; tank.add_child(ant)
	_add_flag_to_node(tank, Vector2(-18, -155), 0.8)

	# 3. THE MAIN ARCH & GATE BARS
	var arch_bg = ColorRect.new(); arch_bg.size = Vector2(240, 140); arch_bg.position = Vector2(-120, -140)
	arch_bg.color = wall_color; scene.add_child(arch_bg)
	
	# Broken Central Section
	# Left bars (mostly intact)
	for i in 3:
		var bx = -110 + i * 25
		var bar = ColorRect.new(); bar.size = Vector2(6, 120); bar.position = Vector2(bx, -125); bar.color = bar_color; scene.add_child(bar)
	
	# Right bars (mostly intact)
	for i in 3:
		var bx = 45 + i * 25
		var bar = ColorRect.new(); bar.size = Vector2(6, 120); bar.position = Vector2(bx, -125); bar.color = bar_color; scene.add_child(bar)

	# CRASHED BARS (Bent around the tank)
	var crash_offsets = [-35, -15, 5, 25]
	var crash_angles = [-1.2, -0.8, 0.9, 1.4]
	for i in crash_offsets.size():
		var bar = ColorRect.new(); bar.size = Vector2(8, 110); bar.position = Vector2(crash_offsets[i], -100)
		bar.rotation = crash_angles[i]; bar.color = Color(0.1, 0.1, 0.12); bar.z_index = 6; scene.add_child(bar)
		# Debris bits
		var chip = ColorRect.new(); chip.size = Vector2(10, 10); chip.position = Vector2(crash_offsets[i] + randf_range(-40, 40), -10); 
		chip.rotation = randf(); chip.color = bar_color; scene.add_child(chip)

	# 4. BIG VIETNAMESE FLAG (Top of Palace)
	var main_pole = ColorRect.new(); main_pole.size = Vector2(6, 250); main_pole.position = Vector2(-3, -390)
	main_pole.color = Color(0.2, 0.18, 0.15); scene.add_child(main_pole)
	var big_flag = Node2D.new(); big_flag.position = Vector2(3, -380); scene.add_child(big_flag)
	_draw_flag_shapes(big_flag, 120, 80)

	# 5. EFFECTS: Dust and debris clouds
	for i in 8:
		var dust = Polygon2D.new()
		var dpts = []
		var dr = randf_range(20, 45)
		for j in 8: dpts.append(Vector2(cos(j*TAU/8)*dr, sin(j*TAU/8)*dr))
		dust.polygon = PackedVector2Array(dpts)
		dust.color = Color(0.8, 0.75, 0.65, 0.35)
		dust.position = Vector2(randf_range(-150, 150), randf_range(-40, 10))
		scene.add_child(dust)

# --- 12. Detailed Independence Palace Building (Modernist Icon) ---
func _create_independence_palace_building(x: float) -> void:
	var building = Node2D.new()
	building.position = Vector2(x, 600)
	building.z_index = -15 # Behind the gate
	main._add_to_level(building)

	var palace_white = Color(0.92, 0.92, 0.95)
	var shadow_grey = Color(0.75, 0.75, 0.8)
	var glass_blue = Color(0.2, 0.25, 0.35)

	# 1. CENTRAL GREEN LAWN (Perspective)
	var lawn = Polygon2D.new()
	lawn.polygon = [Vector2(-600, 0), Vector2(-400, -80), Vector2(400, -80), Vector2(600, 0)]
	lawn.color = Color(0.15, 0.45, 0.15)
	building.add_child(lawn)

	# 2. MAIN BUILDING STRUCTURE
	# Ground floor (dark/recessed)
	var ground = ColorRect.new(); ground.size = Vector2(700, 60); ground.position = Vector2(-350, -140)
	ground.color = Color(0.3, 0.3, 0.35); building.add_child(ground)

	# Main upper block
	var upper = ColorRect.new(); upper.size = Vector2(740, 180); upper.position = Vector2(-370, -320)
	upper.color = palace_white; building.add_child(upper)

	# 3. ICONIC VERTICAL FINS (Facade)
	# Left side fins
	for i in 12:
		var fx = -350 + i * 22
		var fin = ColorRect.new(); fin.size = Vector2(4, 150); fin.position = Vector2(fx, -305)
		fin.color = Color(0.6, 0.6, 0.65); building.add_child(fin)
	
	# Right side fins
	for i in 12:
		var fx = 100 + i * 22
		var fin = ColorRect.new(); fin.size = Vector2(4, 150); fin.position = Vector2(fx, -305)
		fin.color = Color(0.6, 0.6, 0.65); building.add_child(fin)

	# 4. CENTRAL BALCONY / ENTRANCE
	var center = ColorRect.new(); center.size = Vector2(160, 200); center.position = Vector2(-80, -340)
	center.color = palace_white; building.add_child(center)
	# Shadow/recess behind balcony
	var recess = ColorRect.new(); recess.size = Vector2(140, 140); recess.position = Vector2(-70, -300)
	recess.color = shadow_grey; building.add_child(recess)

	# 5. ROOF FEATURES
	var roof_trim = ColorRect.new(); roof_trim.size = Vector2(760, 15); roof_trim.position = Vector2(-380, -335)
	roof_trim.color = Color(0.8, 0.82, 0.85); building.add_child(roof_trim)

	# The Round Hall / Pavilion on top
	var hall = ColorRect.new(); hall.size = Vector2(80, 40); hall.position = Vector2(-40, -375)
	hall.color = palace_white; building.add_child(hall)
	var hall_roof = ColorRect.new(); hall_roof.size = Vector2(100, 10); hall_roof.position = Vector2(-50, -385)
	hall_roof.color = shadow_grey; building.add_child(hall_roof)

	# CENTRAL FLAGPOLE (The one where the flag was raised)
	var pole = ColorRect.new(); pole.size = Vector2(4, 100); pole.position = Vector2(-2, -485)
	pole.color = Color(0.2, 0.2, 0.22); building.add_child(pole)
	var big_flag = Node2D.new(); big_flag.position = Vector2(2, -475); building.add_child(big_flag)
	_draw_flag_shapes(big_flag, 140, 95)

	# 6. SURROUNDING TREES (Boulevard style)
	for i in 4:
		var side = -1 if i < 2 else 1
		var tx = side * (450 + (i%2) * 100)
		_create_tamarind_tree_simple(building, Vector2(tx, 0))

func _create_tamarind_tree_simple(parent: Node, pos: Vector2):
	var tree = Node2D.new(); tree.position = pos; parent.add_child(tree)
	var trunk = ColorRect.new(); trunk.size = Vector2(10, 80); trunk.position = Vector2(-5, -80); trunk.color = Color(0.3, 0.2, 0.1)
	tree.add_child(trunk)
	var canopy = Polygon2D.new()
	var pts = []
	for j in 12: pts.append(Vector2(cos(j*TAU/12)*60, sin(j*TAU/12)*45))
	canopy.polygon = PackedVector2Array(pts); canopy.position = Vector2(0, -90)
	canopy.color = Color(0.1, 0.35, 0.1); tree.add_child(canopy)

# --- 13. Historical moment popup panel ---
func _create_historical_moment_panel(stage_x: float) -> void:
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
	lbl.text = "[center][b][color=gold]11:30, ngày 30/4/1975[/color][/b]\\\\nXe tăng 843 húc đổ cổng Dinh Độc Lập.\\\\n[color=yellow]Miền Nam hoàn toàn giải phóng![/color][/center]"
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
