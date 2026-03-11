extends ContraStageBase

func setup():
	main._setup_background_sky(Color(0.45, 0.72, 0.85))
	
	# --- Background: Distant Karst limestone mountains ---
	for i in 14:
		var mx = i * 900 - 500
		var mw = randf_range(280, 480)
		var mh = randf_range(300, 520)
		var mt = Polygon2D.new()
		mt.polygon = PackedVector2Array([
			Vector2(-mw*0.5, 0), Vector2(0, -mh), Vector2(mw*0.5, 0)
		])
		mt.color = Color(0.38, 0.56, 0.52, 0.55)
		mt.position = Vector2(mx, 600)
		mt.z_index = -110
		_get_parallax().add_child(mt)
	
	# --- God rays: shafts of sunlight filtering through canopy ---
	for i in 8:
		var rx := i * 1600.0 + randf_range(-300.0, 300.0)
		var ray := Polygon2D.new()
		var rw := randf_range(40.0, 100.0)
		ray.polygon = PackedVector2Array([
			Vector2(-rw * 0.3, 0.0), Vector2(rw * 0.3, 0.0),
			Vector2(rw, 600.0), Vector2(-rw * 0.6, 600.0)
		])
		ray.color = Color(0.95, 0.98, 0.8, 0.055)
		ray.position = Vector2(rx, -20.0)
		ray.z_index = -48
		_get_parallax().add_child(ray)
		# Gentle sway
		var rtw: Tween = ray.create_tween().set_loops()
		rtw.tween_property(ray, "modulate:a", 0.8, randf_range(2.5, 5.0)).set_trans(Tween.TRANS_SINE)
		rtw.tween_property(ray, "modulate:a", 0.3, randf_range(2.5, 5.0)).set_trans(Tween.TRANS_SINE)

	# --- Jungle mist / atmosphere layers ---
	for i in 5:
		var mist = ColorRect.new()
		mist.size = Vector2(3000, 80)
		mist.position = Vector2(i * 2400 - 500, 480 + i * 18)
		mist.color = Color(0.7, 0.85, 0.9, 0.12)
		mist.z_index = -50
		_get_parallax().add_child(mist)

	# --- Fireflies: small glowing dots with looping fade-in/out ---
	for i in 30:
		var fx := randf_range(200.0, main.STAGE_LENGTH - 200.0)
		var fy := randf_range(420.0, 570.0)
		var ff := ColorRect.new()
		ff.size = Vector2(4, 4)
		ff.color = Color(0.85, 1.0, 0.4, 0.9)
		ff.position = Vector2(fx, fy)
		ff.z_index = -5
		main._add_to_level(ff)
		var ftw: Tween = ff.create_tween().set_loops()
		ftw.tween_property(ff, "modulate:a", 0.0, randf_range(0.4, 1.2)).set_trans(Tween.TRANS_SINE)
		ftw.tween_property(ff, "modulate:a", 1.0, randf_range(0.4, 1.2)).set_trans(Tween.TRANS_SINE)
		# Gentle float drift
		ftw.parallel().tween_property(ff, "position:y", fy + randf_range(-25.0, 25.0), randf_range(1.5, 3.5)).set_trans(Tween.TRANS_SINE)

	# --- Generate hilly terrain (map 1 uses gentle rolling hills) ---
	main._generate_hilly_terrain(Color(0.15, 0.1, 0.05), Color(0.08, 0.22, 0.05), false)
	
	# --- Enemies & Items ---
	main._spawn_background_soldiers(4)
	main._spawn_enemy_wave(6, 0.15)
	
	# Health kits spread across the stage
	for i in range(1, 4):
		var x = i * (main.STAGE_LENGTH / 4.0)
		main._create_health_kit(Vector2(x + randf_range(-120, 120), main._get_ground_y(x) - 40))
	
	# 1 checkpoint at midpoint (easy stage)
	main._create_checkpoint(Vector2(main.STAGE_LENGTH * 0.5, main._get_ground_y(main.STAGE_LENGTH * 0.5) - 10))
