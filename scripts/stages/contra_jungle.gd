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
	
	# --- Jungle mist / atmosphere layers ---
	for i in 5:
		var mist = ColorRect.new()
		mist.size = Vector2(3000, 80)
		mist.position = Vector2(i * 2400 - 500, 480 + i * 18)
		mist.color = Color(0.7, 0.85, 0.9, 0.12)
		mist.z_index = -50
		_get_parallax().add_child(mist)
	
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
