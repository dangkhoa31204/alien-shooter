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

	main._spawn_enemy_wave(18, 0.4) 
	for i in 4:
		var t_tx = 2000 + i * 3000 + randf_range(-200, 200); main._spawn_heavy_enemy(t_tx, 595, "tank")
	
	main._bomber_timer = 3.0
	main._spawn_background_soldiers(4)
	
	# Health and Checkpoints
	for i in range(1, 3):
		var x = i * (STAGE_LENGTH / 3.0)
		main._create_health_kit(Vector2(x + randf_range(-100, 100), 570))
		main._create_checkpoint(Vector2(x, 600))

