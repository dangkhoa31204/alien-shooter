extends ContraStageBase

func setup():
	# Stage 2: Củ Chi Tunnels (Dual-path System with Vertical Depth)
	main._setup_background_sky(Color(0.4, 0.7, 0.9))
	
	var STAGE_LENGTH = main.STAGE_LENGTH
	var _world = main._world
	
	# Background Mountains — increased to 16 for denser skyline
	for i in 16:
		var mt = Polygon2D.new(); var mx = i * 800 - 200; var mw = 2200
		mt.polygon = PackedVector2Array([Vector2(0, 600), Vector2(mw/2, 100), Vector2(mw, 600)])
		mt.color = Color(0.1, 0.25, 0.35, 0.4); mt.position = Vector2(mx, 100); mt.z_index = -90
		main._add_to_level(mt)

	# Mid-distance jungle ridges (second hill layer)
	for i in 20:
		var mx2 = i * 650 - 150
		var mw2 = randf_range(600, 1000); var mh2 = randf_range(80, 180)
		var mt2 = Polygon2D.new()
		mt2.polygon = PackedVector2Array([Vector2(-mw2*0.5, 0), Vector2(0, -mh2), Vector2(mw2*0.5, 0)])
		mt2.color = Color(0.06, 0.18, 0.06, 0.60); mt2.position = Vector2(mx2, 520); mt2.z_index = -70
		main._add_to_level(mt2)

	# Mid-ground decorative hills
	for i in 25:
		var hill = Polygon2D.new()
		var hx = i * 500 + randf_range(-100, 100)
		var hw = randf_range(200, 400); var hh = randf_range(50, 120)
		hill.polygon = PackedVector2Array([Vector2(-hw/2, 600), Vector2(0, 600-hh), Vector2(hw/2, 600)])
		hill.color = Color(0.08, 0.2, 0.05); hill.position.x = hx; hill.z_index = -40
		main._add_to_level(hill)

	var surface_y  = 490.0
	var tunnel_y   = 660.0
	var soil_top_y = 555.0

	var soil_bg = ColorRect.new()
	soil_bg.size = Vector2(STAGE_LENGTH + 400, 800)
	soil_bg.position = Vector2(-200, soil_top_y)
	soil_bg.color = Color(0.11, 0.065, 0.038)
	soil_bg.z_index = -22
	main._add_to_level(soil_bg)

	var divider = ColorRect.new()
	divider.size = Vector2(STAGE_LENGTH + 400, soil_top_y - surface_y - 8)
	divider.position = Vector2(-200, surface_y + 8)
	divider.color = Color(0.165, 0.092, 0.052)
	divider.z_index = -17
	main._add_to_level(divider)

	var hole_width  = 100.0
	var hole_gap    = 1000.0
	var seg_start   = -200.0
	while seg_start < STAGE_LENGTH + 200:
		var hole_x = seg_start + hole_gap
		var seg_end = min(hole_x, STAGE_LENGTH + 200.0)
		var seg_w = seg_end - seg_start
		if seg_w > 10:
			var seg_body = StaticBody2D.new()
			var seg_col  = CollisionShape2D.new()
			var seg_shp  = RectangleShape2D.new()
			seg_shp.size = Vector2(seg_w, 40)
			seg_col.shape = seg_shp
			seg_body.position = Vector2(seg_start + seg_w * 0.5, surface_y + 20)
			seg_body.add_child(seg_col)
			main._add_to_level(seg_body)
			
			var gv = ColorRect.new()
			gv.size = Vector2(seg_w, 14)
			gv.position = Vector2(seg_start, surface_y - 7)
			gv.color = Color(0.16, 0.44, 0.11)
			gv.z_index = -10
			main._add_to_level(gv)
			
			var dv = ColorRect.new()
			dv.size = Vector2(seg_w, soil_top_y - surface_y)
			dv.position = Vector2(seg_start, surface_y)
			dv.color = Color(0.19, 0.11, 0.055)
			dv.z_index = -14
			main._add_to_level(dv)
			
			for ti in range(int(seg_w / 50)):
				var gx = seg_start + ti * 50 + randf_range(-10, 10)
				var tuft = Polygon2D.new()
				tuft.polygon = PackedVector2Array([Vector2(-4, 0), Vector2(0, -randf_range(8, 16)), Vector2(4, 0)])
				tuft.color = Color(0.11, 0.40, 0.08)
				tuft.position = Vector2(gx, surface_y - 7)
				tuft.z_index = -9
				main._add_to_level(tuft)
			
			if seg_end < STAGE_LENGTH + 100:
				for ar in 3:
					var arrow = Polygon2D.new()
					arrow.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(0, 13)])
					arrow.color = Color(0.95, 0.8, 0.15, 0.8)
					arrow.position = Vector2(hole_x + hole_width * 0.5, surface_y - 30 + ar * 16)
					arrow.z_index = 2
					main._add_to_level(arrow)
				var hole_v = ColorRect.new()
				hole_v.size = Vector2(hole_width, soil_top_y - surface_y + 10)
				hole_v.position = Vector2(hole_x, surface_y)
				hole_v.color = Color(0.04, 0.02, 0.01)
				hole_v.z_index = -13
				main._add_to_level(hole_v)

		seg_start = hole_x + hole_width

	for i in range(int(STAGE_LENGTH / 110)):
		var tx2 = 100 + i * 110 + randf_range(-40, 40)
		var dice = randf()
		if dice < 0.25: main._create_palm_tree(Vector2(tx2, surface_y))
		elif dice < 0.45: main._create_giant_ancient_tree(Vector2(tx2, surface_y))
		elif dice < 0.65: main._create_dense_shrub(Vector2(tx2, surface_y))
		elif dice < 0.80: main._create_jungle_fern(Vector2(tx2, surface_y))
		else: main._create_rock(Vector2(tx2, surface_y))
		if randf() < 0.20:
			for b in 3:
				var bamboo = ColorRect.new()
				bamboo.size = Vector2(4, randf_range(80, 180))
				bamboo.position = Vector2(tx2 + b * 8, surface_y - bamboo.size.y)
				bamboo.color = Color(0.1, 0.35, 0.05)
				bamboo.z_index = 1
				main._add_to_level(bamboo)

	var lower_floor = StaticBody2D.new()
	var tfcol = CollisionShape2D.new()
	var tfshape = WorldBoundaryShape2D.new()
	tfshape.normal = Vector2.UP
	tfcol.shape = tfshape
	lower_floor.position.y = tunnel_y
	lower_floor.add_child(tfcol)
	main._add_to_level(lower_floor)

	var tfloor_v = ColorRect.new()
	tfloor_v.size = Vector2(STAGE_LENGTH + 400, 8)
	tfloor_v.position = Vector2(-200, tunnel_y - 4)
	tfloor_v.color = Color(0.19, 0.11, 0.06)
	tfloor_v.z_index = -11
	main._add_to_level(tfloor_v)

	var corr_h = tunnel_y - soil_top_y
	for i in range(int(STAGE_LENGTH / 250)):
		var tx = i * 250
		var corridor = ColorRect.new()
		corridor.size = Vector2(255, corr_h + 5)
		corridor.position = Vector2(tx, soil_top_y)
		corridor.color = Color(0.085, 0.05, 0.028)
		corridor.z_index = -12
		main._add_to_level(corridor)
	
	# --- NEW DECORATIONS ---
	# Spawn Rats in the tunnels
	for i in range(12):
		var rx = randf_range(500, STAGE_LENGTH - 500)
		main._create_tunnel_rat(Vector2(rx, tunnel_y - 2))
		
	# Spawn US Bulldozers (Rome Plows) on the surface
	for i in range(4):
		var bz_x = 1500 + i * 2500 + randf_range(-200, 200)
		main._create_war_bulldozer(Vector2(bz_x, surface_y))

	main._stage_terrain.clear()
	main._stage_terrain.append(Vector2(-200, surface_y))
	main._stage_terrain.append(Vector2(STAGE_LENGTH + 400, surface_y))

	# --- Tunnel torches: every 400px along tunnel ceiling ---
	for i in range(int(STAGE_LENGTH / 400)):
		var tx3 := i * 400.0 + 200.0
		var torch_root := Node2D.new()
		torch_root.position = Vector2(tx3, soil_top_y + 8.0)
		torch_root.z_index = 2
		main._add_to_level(torch_root)
		# Stick
		var stick := ColorRect.new()
		stick.size = Vector2(4, 14); stick.position = Vector2(-2, 0)
		stick.color = Color(0.4, 0.22, 0.08); torch_root.add_child(stick)
		# Flame polygon
		var flame := Polygon2D.new()
		flame.polygon = PackedVector2Array([
			Vector2(-5, 0), Vector2(5, 0), Vector2(3, -16), Vector2(0, -20), Vector2(-3, -16)
		])
		flame.color = Color(1.0, 0.65, 0.1, 0.9)
		flame.position = Vector2(0, 0); torch_root.add_child(flame)
		# Flicker tween
		var ftw: Tween = flame.create_tween().set_loops()
		ftw.tween_property(flame, "modulate:a", 0.6, randf_range(0.08, 0.18))
		ftw.tween_property(flame, "modulate:a", 1.0, randf_range(0.08, 0.18))
		ftw.tween_property(flame, "scale:x", 1.3, randf_range(0.1, 0.2)).set_trans(Tween.TRANS_SINE)
		ftw.tween_property(flame, "scale:x", 0.8, randf_range(0.1, 0.2)).set_trans(Tween.TRANS_SINE)
		# Orange floor glow
		var glow := ColorRect.new()
		glow.size = Vector2(30, 8); glow.position = Vector2(-15, 14)
		glow.color = Color(1.0, 0.5, 0.1, 0.18); torch_root.add_child(glow)

	# --- Water drips: random positions aligned to tunnel ceiling ---
	for _di in 20:
		var dripx := randf_range(50.0, STAGE_LENGTH - 50.0)
		var drip := ColorRect.new()
		drip.size = Vector2(2, 6)
		drip.color = Color(0.4, 0.55, 0.7, 0.7)
		drip.position = Vector2(dripx, soil_top_y + 4.0)
		drip.z_index = 3
		main._add_to_level(drip)
		var dtw: Tween = drip.create_tween().set_loops()
		dtw.tween_interval(randf_range(0.8, 3.5))
		dtw.tween_property(drip, "position:y", soil_top_y + 80.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		dtw.tween_callback(func(): drip.position.y = soil_top_y + 4.0)

	# --- Entrance frames: dark arch around each hole ---
	var hole_x2: float = 0.0 - hole_gap
	while hole_x2 < STAGE_LENGTH:
		hole_x2 += hole_gap
		if hole_x2 < 0 or hole_x2 > STAGE_LENGTH: continue
		# Left jamb
		var lj := ColorRect.new()
		lj.size = Vector2(10, soil_top_y - surface_y + 14)
		lj.position = Vector2(hole_x2 - 10, surface_y - 7)
		lj.color = Color(0.02, 0.01, 0.005, 0.85); lj.z_index = -8
		main._add_to_level(lj)
		# Right jamb
		var rj := ColorRect.new()
		rj.size = Vector2(10, soil_top_y - surface_y + 14)
		rj.position = Vector2(hole_x2 + hole_width, surface_y - 7)
		rj.color = Color(0.02, 0.01, 0.005, 0.85); rj.z_index = -8
		main._add_to_level(rj)

	main._spawn_background_soldiers(6)
	main._spawn_enemy_wave(18, 0.30)
	main._spawn_enemy(400, surface_y - 50)
	main._bomber_timer = 4.0

	# --- AA gun emplacements covering the tunnels from above ---
	for i in 3:
		var aax := 1400.0 + i * 3000.0 + randf_range(-300.0, 300.0)
		main._create_aa_gun_bg(Vector2(aax, surface_y))

	# --- Gaz supply trucks (enemy logistics) ---
	for i in 3:
		var gtx := 2000.0 + i * 3200.0 + randf_range(-250.0, 250.0)
		main._create_gaz_truck_bg(Vector2(gtx, surface_y))

	# --- Bicycle convoys on the surface path ---
	for i in 3:
		var bcx := 1600.0 + i * 3500.0 + randf_range(-300.0, 300.0)
		main._create_bicycle_convoy_bg(Vector2(bcx, surface_y))

	# --- Bomb craters from US air strikes on the surface ---
	for i in 10:
		var crx := randf_range(500.0, STAGE_LENGTH - 500.0)
		main._create_crater(Vector2(crx, surface_y))

	# --- Rocky outcrops scattered on the surface as cover ---
	for i in 5:
		var rrx := randf_range(400.0, STAGE_LENGTH - 400.0)
		main._create_rocky_outcrop(Vector2(rrx, surface_y))

	# --- Hanging vines over the tunnel entrance holes ---
	for i in 8:
		var vvx := randf_range(300.0, STAGE_LENGTH - 300.0)
		main._create_hanging_vine_detailed(vvx)

	# --- Burning wreckage from previous raids ---
	for i in 8:
		var bwx := randf_range(600.0, STAGE_LENGTH - 600.0)
		main._create_burning_wreckage(Vector2(bwx, surface_y))

	# --- Sandbag fortifications at key tunnel approaches ---
	for i in 4:
		var sfx := 1200.0 + i * 2500.0 + randf_range(-200.0, 200.0)
		main._create_sandbag_fort(Vector2(sfx, surface_y), 45.0)

	# --- Extra jungle ferns and shrubs on surface ---
	for i in 14:
		var jfx := randf_range(300.0, STAGE_LENGTH - 300.0)
		main._create_jungle_fern(Vector2(jfx, surface_y))
	for i in 10:
		var dsx := randf_range(300.0, STAGE_LENGTH - 300.0)
		main._create_dense_shrub(Vector2(dsx, surface_y))

	# --- Additional rocky outcrops as cover on surface ---
	for i in 8:
		var rrx2 := randf_range(400.0, STAGE_LENGTH - 400.0)
		main._create_rocky_outcrop(Vector2(rrx2, surface_y))

	# --- Palm trees lining the surface edge (start to end) ---
	for i in range(int(STAGE_LENGTH / 1500) + 1):
		var ptx := 200.0 + i * 1500.0 + randf_range(-200.0, 200.0)
		main._create_palm_tree(Vector2(ptx, surface_y))

	# --- Giant ancient trees from start to end ---
	for i in range(int(STAGE_LENGTH / 1700) + 1):
		var atx := 300.0 + i * 1700.0 + randf_range(-300.0, 300.0)
		main._create_giant_ancient_tree(Vector2(atx, surface_y))

	# Health and Checkpoints
	main._create_health_kit(Vector2(2500, surface_y - 40))
	main._create_health_kit(Vector2(4500, surface_y - 40))
	main._create_health_kit(Vector2(5500, tunnel_y - 40)) # One in the tunnel
	main._create_health_kit(Vector2(7500, surface_y - 40))
	main._create_health_kit(Vector2(9500, surface_y - 40))

	main._create_checkpoint(Vector2(STAGE_LENGTH * 0.25, surface_y))
	main._create_checkpoint(Vector2(STAGE_LENGTH * 0.50, surface_y))
	main._create_checkpoint(Vector2(STAGE_LENGTH * 0.75, surface_y))
