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

	# Mid-distance highland ridges (2nd bg layer)
	for i in 20:
		var mx2 = i * 650 - 200; var mw2 = randf_range(700, 1100); var mh2 = randf_range(200, 400)
		var mt2 = Polygon2D.new()
		mt2.polygon = [Vector2(-mw2*0.5, 0), Vector2(0, -mh2), Vector2(mw2*0.5, 0)]
		mt2.color = Color(0.08, 0.14, 0.07, 0.75); mt2.position = Vector2(mx2, 600); mt2.z_index = -108
		_parallax_bg.add_child(mt2)

	# Near background ridgeline (3rd bg layer)
	for i in 26:
		var mx3 = i * 490 - 300; var mw3 = randf_range(400, 700); var mh3 = randf_range(80, 200)
		var mt3 = Polygon2D.new()
		mt3.polygon = [Vector2(-mw3*0.5, 0), Vector2(0, -mh3), Vector2(mw3*0.5, 0)]
		mt3.color = Color(0.10, 0.18, 0.06, 0.85); mt3.position = Vector2(mx3, 600); mt3.z_index = -106
		_parallax_bg.add_child(mt3)

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
	main._spawn_enemy_wave(10, 0.3)
	for i in 3:
		var tx = 2500 + i * 3500 + randf_range(-400, 400)
		var ty = main._get_ground_y(tx)
		main._spawn_heavy_enemy(tx, ty, "tank")
	main._bomber_timer = 4.0

	# --- Giant ancient trees along highland ridgelines ---
	for i in 12:
		var atx: float = 600.0 + i * (STAGE_LENGTH / 12.5) + randf_range(-200.0, 200.0)
		main._create_giant_ancient_tree(Vector2(atx, main._get_ground_y(atx)))

	# --- Jungle ferns in highland valleys ---
	for i in 20:
		var fex: float = randf_range(400.0, STAGE_LENGTH - 400.0)
		main._create_jungle_fern(Vector2(fex, main._get_ground_y(fex)))

	# --- Dense shrubs as cover throughout ---
	for i in 15:
		var dsx: float = randf_range(400.0, STAGE_LENGTH - 400.0)
		main._create_dense_shrub(Vector2(dsx, main._get_ground_y(dsx)))

	# --- Rocky outcrops: highland boulders ---
	for i in 12:
		var rox: float = randf_range(400.0, STAGE_LENGTH - 400.0)
		main._create_rocky_outcrop(Vector2(rox, main._get_ground_y(rox)))

	# --- Bomb craters from intense US aerial bombardment (Highlands = B-52 zone) ---
	for i in 18:
		var crx: float = randf_range(500.0, STAGE_LENGTH - 500.0)
		main._create_crater(Vector2(crx, main._get_ground_y(crx)))

	# --- Bicycle supply convoys on the mountain road ---
	for i in 4:
		var bcx: float = 1200.0 + i * 2600.0 + randf_range(-200.0, 200.0)
		main._create_bicycle_convoy_bg(Vector2(bcx, main._get_ground_y(bcx)))

	# --- Hanging vines on highland cliff faces ---
	for i in 12:
		var hvx: float = randf_range(500.0, STAGE_LENGTH - 500.0)
		main._create_hanging_vine_detailed(hvx)

	# --- Sandbag fortifications at defensive positions ---
	for i in 5:
		var sfx: float = 1000.0 + i * 2000.0 + randf_range(-300.0, 300.0)
		main._create_sandbag_fort(Vector2(sfx, main._get_ground_y(sfx)), 50.0)

	# --- Destroyed truck husks from previous engagements ---
	for i in 4:
		var thx: float = 1500.0 + i * 2800.0 + randf_range(-300.0, 300.0)
		main._create_truck_husk(Vector2(thx, main._get_ground_y(thx)))

	# --- Extra palm trees and rocks to fill gaps ---
	for i in 10:
		var ptx: float = randf_range(400.0, STAGE_LENGTH - 400.0)
		main._create_palm_tree(Vector2(ptx, main._get_ground_y(ptx)))
	for i in 14:
		var rkx: float = randf_range(400.0, STAGE_LENGTH - 400.0)
		main._create_rock(Vector2(rkx, main._get_ground_y(rkx)))

	# --- Flowers scattered in highland clearings ---
	for i in 20:
		var flx: float = randf_range(300.0, STAGE_LENGTH - 300.0)
		main._create_flower(Vector2(flx, main._get_ground_y(flx)))

	# --- Extra log bridges from start to end ---
	for i in range(int(STAGE_LENGTH / 2000) + 1):
		var elb: float = 200.0 + i * 2000.0 + randf_range(-150.0, 150.0)
		main._create_wooden_log_bridge(Vector2(elb, main._get_ground_y(elb)))

	# --- More highland supply trucks from start to end ---
	for i in range(int(STAGE_LENGTH / 2400) + 1):
		var htx: float = 200.0 + i * 2400.0 + randf_range(-200.0, 200.0)
		main._create_highland_truck(Vector2(htx, main._get_ground_y(htx)))

	# --- Layered highland fog banks ---
	for i in 6:
		var fog := ColorRect.new()
		fog.size = Vector2(randf_range(1200.0, 2400.0), randf_range(60.0, 120.0))
		fog.position = Vector2(i * 2000.0 + randf_range(-200.0, 200.0), 350.0 + randf_range(-40.0, 80.0))
		fog.color = Color(0.65, 0.72, 0.7, 0.08)
		fog.z_index = -45
		_parallax_bg.add_child(fog)
		# Drift slowly
		var ftw: Tween = fog.create_tween().set_loops()
		ftw.tween_property(fog, "position:x", fog.position.x + randf_range(80.0, 160.0), randf_range(8.0, 18.0)).set_trans(Tween.TRANS_SINE)
		ftw.tween_property(fog, "position:x", fog.position.x - randf_range(40.0, 100.0), randf_range(8.0, 18.0)).set_trans(Tween.TRANS_SINE)

	# --- Distant mountain silhouettes with haze tint ---
	for i in 5:
		var haze_band := ColorRect.new()
		haze_band.size = Vector2(STAGE_LENGTH + 2000, 40)
		haze_band.position = Vector2(-200.0, 200.0 + i * 35.0)
		haze_band.color = Color(0.35, 0.42, 0.38, 0.06 - i * 0.008)
		haze_band.z_index = -108 + i
		_parallax_bg.add_child(haze_band)

	# Health and Checkpoints (more densely spread for longer combat)
	for i in range(1, 5):
		var hx = i * (STAGE_LENGTH / 5.0)
		main._create_health_kit(Vector2(hx + randf_range(-100, 100), main._get_ground_y(hx) - 40))

	for i in range(1, 4):
		var cpx = i * (STAGE_LENGTH / 4.0)
		main._create_checkpoint(Vector2(cpx, main._get_ground_y(cpx)))
