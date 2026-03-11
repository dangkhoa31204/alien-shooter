extends ContraStageBase

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
