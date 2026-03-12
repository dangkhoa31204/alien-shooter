extends ContraStageBase

func setup():
	main._setup_background_sky(Color(0.02, 0.02, 0.05))
	var STAGE_LENGTH = main.STAGE_LENGTH
	var _world = main._world
	var _parallax_bg = main._parallax_bg
	
	# Dramatic Night Sky with Moon Glow
	var moon = Polygon2D.new(); var mpts = PackedVector2Array()
	for i in 20: mpts.append(Vector2(cos(i*TAU/20)*40, sin(i*TAU/20)*40))
	moon.polygon = mpts; moon.color = Color(0.9, 0.9, 0.8, 0.9)
	moon.position = Vector2(800, 150); moon.z_index = -110; main._add_to_level(moon)
	
	var moon_glow = Polygon2D.new(); var mgpts = PackedVector2Array()
	for i in 12: mgpts.append(Vector2(cos(i*TAU/12)*120, sin(i*TAU/12)*120))
	moon_glow.polygon = mgpts; moon_glow.color = Color(1, 1, 0.8, 0.1); moon_glow.position = moon.position; moon_glow.z_index = -111; main._add_to_level(moon_glow)

	# Distant Base Silhouettes (Parallax)
	for i in 15:
		var bx = i * 1000; var bw = randf_range(400, 800); var bh = randf_range(100, 300)
		var b = ColorRect.new(); b.size = Vector2(bw, bh); b.position = Vector2(bx, 600 - bh); b.z_index = -105
		b.color = Color(0.04, 0.04, 0.08); _parallax_bg.add_child(b)
		# Blinking red warning lights on tall silhouettes
		if bh > 200:
			var light := ColorRect.new()
			light.size = Vector2(5, 5)
			light.position = Vector2(bx + bw * 0.5, 600 - bh - 6)
			light.color = Color.RED
			_parallax_bg.add_child(light)
			var ltw: Tween = light.create_tween().set_loops()
			ltw.tween_property(light, "modulate:a", 0.0, 0.4)
			ltw.tween_interval(randf_range(0.5, 1.5))
			ltw.tween_property(light, "modulate:a", 1.0, 0.2)

	# Rotating Spotlights with floor glow
	for i in 4:
		var sl := Node2D.new()
		sl.position = Vector2(i * 3000 + 400, 600)
		_parallax_bg.add_child(sl); sl.z_index = -100
		var beam := Polygon2D.new()
		beam.polygon = [Vector2(0,0), Vector2(-150, -1200), Vector2(150, -1200)]
		beam.color = Color(1, 1, 0.8, 0.08); sl.add_child(beam)
		# Floor glow pool under spotlight
		var glow := Polygon2D.new()
		var gpts: Array = []
		for gi in 12:
			var ga := gi * TAU / 12.0
			gpts.append(Vector2(cos(ga) * 120.0, sin(ga) * 18.0))
		glow.polygon = PackedVector2Array(gpts)
		glow.color = Color(1.0, 1.0, 0.7, 0.1)
		glow.position = Vector2(0, -2); sl.add_child(glow)
		var stw: Tween = sl.create_tween().set_loops()
		stw.tween_property(beam, "rotation", deg_to_rad(30), 4.0).set_trans(Tween.TRANS_SINE)
		stw.tween_property(beam, "rotation", deg_to_rad(-30), 4.0).set_trans(Tween.TRANS_SINE)

	# Base Floor
	var floor_node = StaticBody2D.new()
	var col = CollisionShape2D.new(); var shape = WorldBoundaryShape2D.new(); shape.normal = Vector2.UP; col.shape = shape
	floor_node.add_child(col); floor_node.position.y = 600; main._add_to_level(floor_node)
	var dirt = ColorRect.new(); dirt.color = Color(0.12, 0.12, 0.15); dirt.size = Vector2(STAGE_LENGTH+2000, 400); dirt.position = Vector2(-1000, 0); floor_node.add_child(dirt)
	var highlight = ColorRect.new(); highlight.color = Color(0.2, 0.2, 0.25); highlight.size = Vector2(STAGE_LENGTH+2000, 10); highlight.position = Vector2(-1000, -5); floor_node.add_child(highlight)

	main._stage_terrain.clear()
	main._stage_terrain.append(Vector2(-1000, 600)); main._stage_terrain.append(Vector2(STAGE_LENGTH + 1000, 600))

	# Wire Fences (Mid-ground) — zigzag barbed wire on I-shaped posts
	for i in range(int(STAGE_LENGTH / 400)):
		var fx := i * 400.0
		# I-shaped post (top cap, stem, base)
		var cap := ColorRect.new(); cap.size = Vector2(10, 3); cap.position = Vector2(fx - 1, 538); cap.color = Color(0.25, 0.25, 0.28); cap.z_index = -10; main._add_to_level(cap)
		var post := ColorRect.new(); post.size = Vector2(4, 56); post.position = Vector2(fx, 540); post.color = Color(0.2, 0.2, 0.22); post.z_index = -10; main._add_to_level(post)
		var base := ColorRect.new(); base.size = Vector2(10, 3); base.position = Vector2(fx - 1, 595); base.color = Color(0.25, 0.25, 0.28); base.z_index = -10; main._add_to_level(base)
		# Zigzag Line2D wire between posts
		if i < int(STAGE_LENGTH / 400) - 1:
			for w in 2:
				var wy := 550.0 + w * 20.0
				var wire_line := Line2D.new()
				wire_line.default_color = Color(0.45, 0.45, 0.48, 0.7)
				wire_line.width = 1.2
				wire_line.z_index = -11
				var seg_count := 10
				for si in seg_count + 1:
					var sx := fx + si * (400.0 / seg_count)
					var sy := wy + (4.0 if si % 2 == 0 else -4.0)
					wire_line.add_point(Vector2(sx, sy))
				main._add_to_level(wire_line)

	# Military Infrastructure: Buildings, Bunkers, Watchtowers
	for i in range(int(STAGE_LENGTH/800)):
		var tx = 600 + i * 800 + randf_range(-100, 100)
		if randf() < 0.4: # Watchtower
			var tower = Node2D.new(); tower.position = Vector2(tx, 600); main._add_to_level(tower); tower.z_index = -15
			var legs = ColorRect.new(); legs.size = Vector2(40, 250); legs.position = Vector2(-20, -250); legs.color = Color(0.15, 0.15, 0.18); tower.add_child(legs)
			var cabin = ColorRect.new(); cabin.size = Vector2(80, 60); cabin.position = Vector2(-40, -310); cabin.color = Color(0.25, 0.25, 0.3)
			var window = ColorRect.new(); window.size = Vector2(60, 20); window.position = Vector2(10, 10); window.color = Color(1, 1, 0.5, 0.3); cabin.add_child(window); tower.add_child(cabin)
			main._spawn_turret(tx, 340)
		else: # Bunker
			var bunker = Node2D.new(); bunker.position = Vector2(tx, 600); main._add_to_level(bunker); bunker.z_index = -5
			var b_body = ColorRect.new(); b_body.size = Vector2(180, 100); b_body.position = Vector2(-90, -100); b_body.color = Color(0.28, 0.3, 0.3)
			var slit = ColorRect.new(); slit.size = Vector2(120, 15); slit.position = Vector2(30, 30); slit.color = Color(0.05, 0.05, 0.05); b_body.add_child(slit); bunker.add_child(b_body)
			# Sandbags around bunker
			for j in 6:
				var sb = ColorRect.new(); sb.size = Vector2(30, 15); sb.position = Vector2(-110 + j*15, -15); sb.color = Color(0.4, 0.35, 0.3); bunker.add_child(sb)
			main._spawn_turret(tx, 505)
	
	# Military Equipment
	for i in 8:
		var ax = 1000 + i * 1500 + randf_range(-400, 400)
		main._create_aa_gun_bg(Vector2(ax, 600))
		if randf() < 0.5:
			main._create_gaz_truck_bg(Vector2(ax + 300, 600))
	
	for i in range(int(STAGE_LENGTH / 2000)):
		main._create_sandbag_fort(Vector2(1500 + i * 2000, 600), 45)

	main._spawn_enemy_wave(22, 0.4) 
	for i in 5:
		var t_tx = 2000 + i * 2200 + randf_range(-200, 200); main._spawn_heavy_enemy(t_tx, 595, "tank")
	
	main._bomber_timer = 3.0
	main._spawn_background_soldiers(6)

	# --- Bomb craters from prior artillery barrages ---
	for i in 14:
		var crx := randf_range(400.0, STAGE_LENGTH - 400.0)
		main._create_crater(Vector2(crx, 600.0))

	# --- Burning wreckage: base facilities hit by allied fire ---
	for i in 12:
		var bwx := randf_range(500.0, STAGE_LENGTH - 500.0)
		main._create_burning_wreckage(Vector2(bwx, 600.0))

	# --- Destroyed truck husks blocking the base road ---
	for i in 6:
		var thx := 1000.0 + i * 1800.0 + randf_range(-200.0, 200.0)
		main._create_truck_husk(Vector2(thx, 600.0))

	# --- Additional wire fence sections with spotlights ---
	for i in 4:
		var wfx := 800.0 + i * 2800.0 + randf_range(-150.0, 150.0)
		# Extra spotlight towers between main fortifications
		var sl := Node2D.new()
		sl.position = Vector2(wfx, 600.0)
		_parallax_bg.add_child(sl); sl.z_index = -95
		var beam := Polygon2D.new()
		beam.polygon = [Vector2(0,0), Vector2(-100, -900), Vector2(100, -900)]
		beam.color = Color(1.0, 1.0, 0.7, 0.06); sl.add_child(beam)
		var stw: Tween = sl.create_tween().set_loops()
		stw.tween_property(beam, "rotation", deg_to_rad(25), 3.5).set_trans(Tween.TRANS_SINE)
		stw.tween_property(beam, "rotation", deg_to_rad(-25), 3.5).set_trans(Tween.TRANS_SINE)

	# --- Ammunition crates and supply dumps ---
	for i in 8:
		var aox := randf_range(300.0, STAGE_LENGTH - 300.0)
		var crate := Node2D.new()
		crate.position = Vector2(aox, 600.0)
		crate.z_index = -6
		main._add_to_level(crate)
		for ci in 3:
			var box := ColorRect.new()
			box.size = Vector2(22, 18)
			box.position = Vector2(ci * 24 - 24, -18)
			box.color = Color(0.28, 0.32, 0.22)
			var stripe := ColorRect.new()
			stripe.size = Vector2(22, 3)
			stripe.position = Vector2(0, 6)
			stripe.color = Color(0.55, 0.5, 0.2)
			box.add_child(stripe)
			crate.add_child(box)

	# --- Rolls of barbed wire (extra obstacle field) ---
	for i in 6:
		var bwrx := 700.0 + i * 1900.0 + randf_range(-150.0, 150.0)
		for wr in 3:
			var roll := Polygon2D.new()
			var rpts: Array = []
			for rpi in 16:
				var ra := rpi * TAU / 16.0
				rpts.append(Vector2(bwrx + wr * 30 + cos(ra) * 12, 595 + sin(ra) * 8))
			roll.polygon = PackedVector2Array(rpts)
			roll.color = Color(0.45, 0.42, 0.38, 0.9)
			main._add_to_level(roll)

	# --- Communications towers (enemy HQ radar/radio) ---
	for i in 3:
		var ctx := 1800.0 + i * 4000.0 + randf_range(-300.0, 300.0)
		var tower := Node2D.new()
		tower.position = Vector2(ctx, 600.0)
		tower.z_index = -12
		main._add_to_level(tower)
		# Lattice tower legs
		var leg_l := ColorRect.new(); leg_l.size = Vector2(5, 300); leg_l.position = Vector2(-30, -300); leg_l.color = Color(0.2, 0.2, 0.25); tower.add_child(leg_l)
		var leg_r := ColorRect.new(); leg_r.size = Vector2(5, 300); leg_r.position = Vector2(30, -300); leg_r.color = Color(0.2, 0.2, 0.25); tower.add_child(leg_r)
		# Cross braces
		for bri in 4:
			var brace := ColorRect.new(); brace.size = Vector2(65, 3); brace.position = Vector2(-30, -60 - bri * 60); brace.color = Color(0.18, 0.18, 0.22); tower.add_child(brace)
		# Dish/antenna at top
		var dish := Polygon2D.new()
		dish.polygon = PackedVector2Array([Vector2(-20, 0), Vector2(20, 0), Vector2(12, -18), Vector2(-12, -18)])
		dish.color = Color(0.35, 0.35, 0.38); dish.position = Vector2(-4, -302); tower.add_child(dish)
		# Blinking warning light
		var blink := ColorRect.new(); blink.size = Vector2(6, 6); blink.position = Vector2(-3, -316); blink.color = Color.RED; tower.add_child(blink)
		var btw: Tween = blink.create_tween().set_loops()
		btw.tween_property(blink, "modulate:a", 0.0, 0.4).set_delay(randf_range(0.3, 1.2))
		btw.tween_property(blink, "modulate:a", 1.0, 0.2)

	# --- Fuel storage tanks (large cylinders — start to end) ---
	for i in range(int(STAGE_LENGTH / 1500) + 1):
		var ftx := 200.0 + i * 1500.0 + randf_range(-200.0, 200.0)
		var tank_node := Node2D.new()
		tank_node.position = Vector2(ftx, 600.0); tank_node.z_index = -8
		main._add_to_level(tank_node)
		# Cylinder body
		var cyl := ColorRect.new(); cyl.size = Vector2(60, 70); cyl.position = Vector2(-30, -70); cyl.color = Color(0.32, 0.32, 0.28); tank_node.add_child(cyl)
		# Top dome cap
		var dome_pts: Array = []
		for di in 7: dome_pts.append(Vector2(cos(di * PI / 6.0 - PI) * 32, sin(di * PI / 6.0 - PI) * 14 - 70))
		var dome := Polygon2D.new(); dome.polygon = PackedVector2Array(dome_pts); dome.color = Color(0.40, 0.38, 0.32); tank_node.add_child(dome)
		# Warning stripe
		var stripe := ColorRect.new(); stripe.size = Vector2(60, 8); stripe.position = Vector2(-30, -40); stripe.color = Color(0.9, 0.5, 0.1); tank_node.add_child(stripe)

	# --- Radar dishes on raised platforms (start to end) ---
	for i in range(int(STAGE_LENGTH / 2000) + 1):
		var rdx := 200.0 + i * 2000.0 + randf_range(-300.0, 300.0)
		var radar := Node2D.new()
		radar.position = Vector2(rdx, 600.0); radar.z_index = -10
		main._add_to_level(radar)
		# Platform
		var plat := ColorRect.new(); plat.size = Vector2(80, 20); plat.position = Vector2(-40, -20); plat.color = Color(0.22, 0.22, 0.26); radar.add_child(plat)
		# Support leg
		var sleg := ColorRect.new(); sleg.size = Vector2(8, 80); sleg.position = Vector2(-4, -100); sleg.color = Color(0.18, 0.18, 0.22); radar.add_child(sleg)
		# Dish
		var rd_dish := Polygon2D.new()
		rd_dish.polygon = PackedVector2Array([Vector2(-30, 0), Vector2(30, 0), Vector2(24, -22), Vector2(-24, -22)])
		rd_dish.color = Color(0.40, 0.40, 0.45); rd_dish.position = Vector2(0, -102); radar.add_child(rd_dish)
		# Rotation tween
		var rtw_r: Tween = rd_dish.create_tween().set_loops()
		rtw_r.tween_property(rd_dish, "rotation", deg_to_rad(20), 2.0).set_trans(Tween.TRANS_SINE)
		rtw_r.tween_property(rd_dish, "rotation", deg_to_rad(-20), 2.0).set_trans(Tween.TRANS_SINE)

	# --- Extra supply crates in depot areas ---
	for i in 10:
		var scx := randf_range(300.0, STAGE_LENGTH - 300.0)
		var depot := Node2D.new(); depot.position = Vector2(scx, 600.0); depot.z_index = -7
		main._add_to_level(depot)
		for ci2 in 4:
			var box2 := ColorRect.new(); box2.size = Vector2(20, 16); box2.position = Vector2(ci2 * 22 - 30, -16)
			box2.color = Color(0.25, 0.30, 0.20); depot.add_child(box2)
			var lid2 := ColorRect.new(); lid2.size = Vector2(20, 3); lid2.position = Vector2(0, 0); lid2.color = Color(0.18, 0.22, 0.15); box2.add_child(lid2)

	# --- Concrete barrier blocks (Hesco / Jersey barriers) ---
	for i in 14:
		var cbx := randf_range(600.0, STAGE_LENGTH - 600.0)
		for bi in 3:
			var barrier := ColorRect.new(); barrier.size = Vector2(28, 22); barrier.position = Vector2(cbx + bi * 30, 578)
			barrier.color = Color(0.45, 0.42, 0.38); barrier.z_index = -4
			main._add_to_level(barrier)

	# Health and Checkpoints
	for i in range(1, 4):
		var x = i * (STAGE_LENGTH / 4.0)
		main._create_health_kit(Vector2(x + randf_range(-100, 100), 570))
		main._create_checkpoint(Vector2(x, 600))

