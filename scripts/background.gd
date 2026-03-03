extends Node2D
# background.gd -- 2.5D deep-space parallax

const STAR_COUNTS: Array = [70, 38, 16, 6]   # was [150,85,42,14]
const STAR_SPEEDS: Array = [3.0, 11.0, 28.0, 72.0]
const STAR_SIZES:  Array = [0.55, 1.1, 1.9, 3.0]
const NEBULA_COUNT: int  = 4              # was 7
const GRID_V_LINES:    int   = 10        # was 14
const GRID_H_ROWS:     int   = 8         # was 12
const GRID_SCROLL_SPD: float = 55.0
const GRID_VP_Y_RATIO: float = 0.20

var _vp: Vector2 = Vector2(1152, 720)
var _t:  float   = 0.0
var _grid_scroll: float = 0.0
var _stars:    Array = []
var _nebulae:  Array = []
var _planets:  Array = []
var _shooters: Array = []
var _shoot_cd: float = 2.2

func _ready() -> void:
	_vp = get_viewport_rect().size
	_gen_stars()
	_gen_nebulae()
	_gen_planets()

func _process(delta: float) -> void:
	_t           += delta
	_grid_scroll += GRID_SCROLL_SPD * delta
	for s in _stars:
		s[1] = float(s[1]) + float(STAR_SPEEDS[int(s[2])]) * delta
		if float(s[1]) > _vp.y + 5.0:
			s[1] = randf_range(-18.0, -2.0)
			s[0] = randf() * _vp.x
	for n in _nebulae:
		n[1] = float(n[1]) + float(n[5]) * delta
		if float(n[1]) - float(n[3]) > _vp.y + 40.0:
			n[1] = -float(n[3])
			n[0] = randf() * _vp.x
	_shoot_cd -= delta
	if _shoot_cd <= 0.0:
		_spawn_shooter()
		_shoot_cd = randf_range(1.4, 3.8)
	var i := 0
	while i < _shooters.size():
		var sh: Array = _shooters[i]
		sh[4] = float(sh[4]) - delta
		sh[0] = float(sh[0]) + float(sh[2]) * delta
		sh[1] = float(sh[1]) + float(sh[3]) * delta
		if float(sh[4]) <= 0.0:
			_shooters.remove_at(i)
		else:
			_shooters[i] = sh
			i += 1
	queue_redraw()

func _draw() -> void:
	var gp := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(_vp.x, 0.0),
		Vector2(_vp.x, _vp.y), Vector2(0.0, _vp.y)
	])
	var gc := PackedColorArray([
		Color(0.010, 0.008, 0.055),
		Color(0.010, 0.008, 0.055),
		Color(0.002, 0.002, 0.022),
		Color(0.002, 0.002, 0.022),
	])
	draw_polygon(gp, gc)
	_draw_grid()
	_draw_galaxy_band()
	for n in _nebulae:
		_draw_nebula(float(n[0]), float(n[1]), float(n[2]), float(n[3]), n[4] as Color, float(n[6]))
	for pl in _planets:
		_draw_planet(Vector2(float(pl[0]), float(pl[1])), float(pl[2]), pl[3] as Color, pl[4] as Color, pl[5] as bool, float(pl[6]))
	for s in _stars:
		var layer: int   = int(s[2])
		var sz: float    = float(STAR_SIZES[layer])
		# Only expensive flicker for bright layers (2,3)
		if layer >= 2:
			var flicker := 0.55 + 0.45 * sin(_t * (2.0 + float(s[4]) * 0.5) + float(s[4]))
			sz *= flicker
			var c: Color = s[3] as Color
			draw_circle(Vector2(float(s[0]), float(s[1])), sz, Color(c.r, c.g, c.b, c.a * flicker))
			if layer == 3 and sz > 2.0:
				var fc := Color(c.r, c.g, c.b, c.a * 0.35 * flicker)
				draw_line(Vector2(float(s[0]) - sz * 2.4, float(s[1])), Vector2(float(s[0]) + sz * 2.4, float(s[1])), fc, 0.9)
				draw_line(Vector2(float(s[0]), float(s[1]) - sz * 2.4), Vector2(float(s[0]), float(s[1]) + sz * 2.4), fc, 0.9)
		else:
			var c2: Color = s[3] as Color
			draw_circle(Vector2(float(s[0]), float(s[1])), sz, c2)
	for sh in _shooters:
		_draw_shooter(sh as Array)

func _draw_grid() -> void:
	var cx  := _vp.x * 0.5
	var vpy := _vp.y * GRID_VP_Y_RATIO
	var by  := _vp.y
	for i in range(GRID_V_LINES + 1):
		var t  := float(i) / float(GRID_V_LINES)
		var bx := _vp.x * t
		var a  := clampf(0.048 - absf(t - 0.5) * 0.025, 0.012, 0.06)
		draw_line(Vector2(bx, by), Vector2(cx, vpy), Color(0.12, 0.40, 0.88, a), 1.0)
	var gfrac := fmod(_grid_scroll / _vp.y, 1.0)
	for i in range(GRID_H_ROWS + 2):
		var t := (float(i) - gfrac) / float(GRID_H_ROWS)
		if t < 0.0 or t > 1.0:
			continue
		var sy := vpy + (by - vpy) * (t * t)
		var hw := (t * t) * (_vp.x * 0.5)
		draw_line(Vector2(cx - hw, sy), Vector2(cx + hw, sy), Color(0.12, 0.40, 0.88, t * t * 0.052), 1.0)

func _draw_galaxy_band() -> void:
	var cx := _vp.x * 0.5
	var cy := _vp.y * 0.28
	for i in range(3):   # was 6
		var ratio := 1.0 - float(i) * 0.30
		var a     := maxf(0.0, 0.024 - float(i) * 0.007)
		_draw_ellipse(Vector2(cx, cy), _vp.x * 0.58 * ratio, _vp.y * 0.065 * ratio, Color(0.52, 0.42, 0.80, a))

func _draw_nebula(x: float, y: float, rx: float, ry: float, c: Color, phase: float) -> void:
	var pulse := 0.82 + 0.18 * sin(_t * 0.38 + phase)
	for i in range(3):   # was 5 layers
		var ratio := 1.0 - float(i) * 0.32
		var a     := maxf(0.0, c.a * (0.052 - float(i) * 0.012) * pulse)
		_draw_ellipse(Vector2(x, y), rx * ratio, ry * ratio, Color(c.r, c.g, c.b, a))

func _draw_planet(pos: Vector2, r: float, body: Color, glow: Color, has_ring: bool, ring_tilt: float) -> void:
	for i in range(2):   # was 4 glow circles
		var gr := r * (2.2 - float(i) * 0.55)
		var ga := maxf(0.0, 0.032 - float(i) * 0.012)
		draw_circle(pos, gr, Color(glow.r, glow.g, glow.b, ga))
	if has_ring:
		var rback := PackedVector2Array()
		for i in range(13):   # was 19
			var a := PI + PI * float(i) / 12.0
			rback.append(pos + Vector2(cos(a) * r * 2.1, sin(a) * r * ring_tilt))
		draw_polyline(rback, Color(glow.r * 0.6, glow.g * 0.6, glow.b * 0.7, 0.28), 4.5)
	draw_circle(pos, r, body)
	for j in range(3):   # was 4 bands
		var band_y := pos.y - r * 0.60 + float(j) * r * 0.50
		var dy     := band_y - pos.y
		if absf(dy) < r * 0.98:
			var hw := sqrt(maxf(0.0, r * r - dy * dy)) * 0.92
			var bc := Color(body.r * 0.55, body.g * 0.55, body.b * 0.72, maxf(0.0, 0.20 - float(j) * 0.06))
			draw_line(Vector2(pos.x - hw, band_y), Vector2(pos.x + hw, band_y), bc, 2.5)
	var rim := PackedVector2Array()
	for i in range(17):   # was 37
		var a := TAU * float(i) / 16.0
		rim.append(pos + Vector2(cos(a), sin(a)) * r)
	draw_polyline(rim, Color(glow.r, glow.g, glow.b, 0.30), 3.0, true)
	if has_ring:
		var rfront := PackedVector2Array()
		for i in range(13):   # was 19
			var a := PI * float(i) / 12.0
			rfront.append(pos + Vector2(cos(a) * r * 2.1, sin(a) * r * ring_tilt))
		draw_polyline(rfront, Color(glow.r, glow.g, glow.b, 0.40), 4.5)
		draw_polyline(rfront, Color(1.0, 1.0, 1.0, 0.10), 2.0)

func _draw_shooter(sh: Array) -> void:
	var cx: float      = float(sh[0])
	var cy: float      = float(sh[1])
	var vx: float      = float(sh[2])
	var vy: float      = float(sh[3])
	var life: float    = float(sh[4])
	var maxlife: float = float(sh[5])
	var c: Color       = sh[6] as Color
	var alpha := (life / maxf(0.001, maxlife)) * 0.88
	var spd   := maxf(1.0, absf(vx) + absf(vy))
	var tlen  := 32.0
	draw_line(Vector2(cx, cy), Vector2(cx - vx / spd * tlen, cy - vy / spd * tlen), Color(c.r, c.g, c.b, alpha), 1.6)
	draw_circle(Vector2(cx, cy), 1.8, Color(c.r, c.g, c.b, minf(1.0, alpha * 1.3)))

func _spawn_shooter() -> void:
	var sx  := randf() * _vp.x
	var sy  := randf() * _vp.y * 0.45
	var spd := randf_range(260.0, 440.0)
	var ang := PI * 0.38 + randf() * (PI * 0.24)
	var palette: Array = [Color(1.0, 1.0, 1.0), Color(0.85, 0.90, 1.0), Color(1.00, 0.95, 0.72), Color(0.72, 0.88, 1.0)]
	var c: Color  = palette[randi() % palette.size()]
	var ml: float = randf_range(0.18, 0.42)
	_shooters.append([sx, sy, cos(ang) * spd, sin(ang) * spd, ml, ml, c])

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts    := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(14):   # was 28 segments
		var a := TAU * float(i) / 14.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		colors.append(color)
	draw_polygon(pts, colors)

func _gen_stars() -> void:
	_stars.clear()
	var palettes: Array = [Color(1.00, 1.00, 1.00, 0.45), Color(0.72, 0.83, 1.00, 0.55), Color(1.00, 0.93, 0.65, 0.62), Color(0.90, 0.72, 1.00, 0.52), Color(0.65, 1.00, 0.88, 0.48)]
	for layer in range(4):
		for _i in range(STAR_COUNTS[layer]):
			var x        := randf() * _vp.x
			var y        := randf() * _vp.y
			var c: Color  = palettes[randi() % palettes.size()]
			c.a *= 0.32 + float(layer) * 0.23
			var phase    := randf() * TAU
			_stars.append([x, y, layer, c, phase])

func _gen_nebulae() -> void:
	_nebulae.clear()
	var nebula_colors: Array = [Color(0.28, 0.14, 0.88, 1.0), Color(0.08, 0.32, 0.92, 1.0), Color(0.90, 0.12, 0.55, 1.0), Color(0.12, 0.72, 0.65, 1.0), Color(0.65, 0.20, 0.92, 1.0), Color(0.92, 0.38, 0.10, 1.0), Color(0.18, 0.55, 0.88, 1.0)]
	for i in range(NEBULA_COUNT):
		var x:     float = randf() * _vp.x
		var y:     float = randf() * _vp.y
		var rx:    float = randf_range(95.0, 275.0)
		var ry:    float = randf_range(60.0, 165.0)
		var c:     Color = nebula_colors[i % nebula_colors.size()]
		var spd:   float = randf_range(1.1, 3.2)
		var phase: float = randf() * TAU
		_nebulae.append([x, y, rx, ry, c, spd, phase])

func _gen_planets() -> void:
	_planets.clear()
	var vp := _vp
	_planets.append([vp.x * 0.83, vp.y * 0.17, 66.0, Color(0.12, 0.10, 0.30), Color(0.40, 0.32, 0.90), false, 0.0])
	_planets.append([vp.x * 0.14, vp.y * 0.30, 40.0, Color(0.08, 0.20, 0.28), Color(0.18, 0.72, 0.85), true, 0.23])
	_planets.append([vp.x * 0.52, vp.y * 0.09, 23.0, Color(0.26, 0.16, 0.09), Color(0.74, 0.50, 0.20), false, 0.0])