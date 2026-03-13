extends ContraStageBase

func setup():
	main._setup_background_sky(Color(0.45, 0.72, 0.85))
	
	# --- Background: Distant Karst limestone mountains (layer 1 — deepest) ---
	for i in 26:
		var mx = i * 500 - 400
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

	# --- Background: Mid-distance mountain ridge (layer 2) ---
	for i in 30:
		var mx2 = i * 430 - 350
		var mw2 = randf_range(220, 380)
		var mh2 = randf_range(180, 340)
		var mt2 = Polygon2D.new()
		mt2.polygon = PackedVector2Array([
			Vector2(-mw2*0.5, 0), Vector2(0, -mh2), Vector2(mw2*0.5, 0)
		])
		mt2.color = Color(0.28, 0.44, 0.32, 0.70)
		mt2.position = Vector2(mx2, 600)
		mt2.z_index = -108
		_get_parallax().add_child(mt2)

	# --- Background: Near ridgeline silhouettes (layer 3 — closest bg) ---
	for i in 34:
		var mx3 = i * 370 - 300
		var mw3 = randf_range(180, 320)
		var mh3 = randf_range(90, 240)
		var mt3 = Polygon2D.new()
		mt3.polygon = PackedVector2Array([
			Vector2(-mw3*0.5, 0), Vector2(0, -mh3), Vector2(mw3*0.5, 0)
		])
		mt3.color = Color(0.12, 0.26, 0.08, 0.82)
		mt3.position = Vector2(mx3, 600)
		mt3.z_index = -106
		_get_parallax().add_child(mt3)
	
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
	
	# --- Hanging vines from cliff edges and tree canopies ---
	for i in 18:
		var vx: float = randf_range(600.0, main.STAGE_LENGTH - 600.0)
		main._create_hanging_vine_detailed(vx)

	# --- Bicycle convoys (Đường mòn Hồ Chí Minh logistics) ---
	for i in 5:
		var bx: float = 900.0 + i * (main.STAGE_LENGTH / 5.5) + randf_range(-200.0, 200.0)
		main._create_bicycle_convoy_bg(Vector2(bx, main._get_ground_y(bx)))

	# --- Burning wreckage: war debris scattered through jungle ---
	for i in 10:
		var wx: float = randf_range(400.0, main.STAGE_LENGTH - 400.0)
		main._create_burning_wreckage(Vector2(wx, main._get_ground_y(wx)))

	# --- Bomb craters from previous air strikes ---
	for i in 8:
		var cx: float = randf_range(600.0, main.STAGE_LENGTH - 600.0)
		main._create_crater(Vector2(cx, main._get_ground_y(cx)))

	# --- Gaz supply trucks in distant background ---
	for i in 4:
		var tx: float = 1200.0 + i * 2500.0 + randf_range(-300.0, 300.0)
		main._create_gaz_truck_bg(Vector2(tx, main._get_ground_y(tx)))

	# --- Log bridges over jungle streams ---
	for i in 3:
		var lbx: float = 1500.0 + i * 3200.0 + randf_range(-400.0, 400.0)
		main._create_wooden_log_bridge(Vector2(lbx, main._get_ground_y(lbx)))

	# --- Rocky outcrops as cover and obstacles ---
	for i in 6:
		var rx: float = randf_range(500.0, main.STAGE_LENGTH - 500.0)
		main._create_rocky_outcrop(Vector2(rx, main._get_ground_y(rx)))

	# --- AA gun positions hidden in the jungle canopy ---
	for i in 3:
		var ax: float = 1800.0 + i * 3500.0 + randf_range(-400.0, 400.0)
		main._create_aa_gun_bg(Vector2(ax, main._get_ground_y(ax)))

	# --- Enemies & Items ---
	main._spawn_background_soldiers(3)
	main._spawn_enemy_wave(8, 0.20)

	# --- Sniper / officer on elevated rocks (mid-stage danger zones) ---
	for i in 2:
		var sx: float = 2500.0 + i * 5000.0
		var sy: float = main._get_ground_y(sx) - 80.0
		main._spawn_enemy(sx, sy, true)

	# Health kits spread across the stage
	for i in range(1, 5):
		var x: float = i * (main.STAGE_LENGTH / 5.0)
		main._create_health_kit(Vector2(x + randf_range(-120, 120), main._get_ground_y(x) - 40))

	# 3 checkpoints spaced evenly
	for i in range(1, 4):
		var cpx: float = i * (main.STAGE_LENGTH / 4.0)
		main._create_checkpoint(Vector2(cpx, main._get_ground_y(cpx) - 10))
