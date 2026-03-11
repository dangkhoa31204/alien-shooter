extends ContraStageBase

func setup():
	main._setup_background_sky(Color(0.08, 0.15, 0.12))
	
	var _parallax_bg = main._parallax_bg
	var STAGE_LENGTH = main.STAGE_LENGTH
	var _world = main._world
	
	for i in 12:
		var mt = Polygon2D.new(); var mx = i * 1500; var mw = randf_range(1000, 1600); var mh = randf_range(500, 800)
		mt.polygon = [Vector2(0, 720), Vector2(mw*0.3, 400), Vector2(mw*0.5, 100), Vector2(mw, 720)]
		mt.color = Color(0.05, 0.1, 0.08); mt.position = Vector2(mx, 0); mt.z_index = -110
		_parallax_bg.add_child(mt)

	main._generate_hilly_terrain(Color(0.22, 0.12, 0.05), Color(0.12, 0.2, 0.08), false)
	
	for i in 20: # Burning wreckage
		var fx = randf_range(200, STAGE_LENGTH)
		var fy = main._get_ground_y(fx)
		main._create_burning_wreckage(Vector2(fx, fy))

	for i in 8: # AA Guns
		var ax = 1200 + i * 1600 + randf_range(-300, 300)
		main._create_aa_gun_bg(Vector2(ax, main._get_ground_y(ax)))

	for i in range(int(STAGE_LENGTH / 1500)):
		var bx = 1000 + i * 1500
		main._create_wooden_log_bridge(Vector2(bx, main._get_ground_y(bx)))
		
		# Functional transport trucks
		var tx_dec = bx + 600 + randf_range(-150, 150)
		main._create_highland_truck(Vector2(tx_dec, main._get_ground_y(tx_dec)))
		
		main._create_gaz_truck_bg(Vector2(bx - 300, main._get_ground_y(bx-300)))
	
	main._spawn_background_soldiers(3)
	main._spawn_enemy_wave(8, 0.3)
	for i in 3:
		var tx = 2500 + i * 3500 + randf_range(-400, 400)
		var ty = main._get_ground_y(tx)
		main._spawn_heavy_enemy(tx, ty, "tank")
	main._bomber_timer = 4.0
	
	# Health and Checkpoints
	for i in range(1, 3):
		var x = i * (STAGE_LENGTH / 3.0)
		main._create_health_kit(Vector2(x + randf_range(-100, 100), main._get_ground_y(x) - 40))
		main._create_checkpoint(Vector2(x, main._get_ground_y(x)))
