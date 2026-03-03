extends Node2D
# level_select.gd — Màn hình chọn màn chơi
# Mỗi phiên: sinh ngẫu nhiên LEVEL_COUNT màn từ pool, độ khó random trong giới hạn
# Người chơi có thể chọn bất kỳ màn nào để chơi ngay

const LEVEL_COUNT := 9      # số ô hiển thị trên màn chọn
const MAX_WAVES   := 30     # giới hạn wave tối đa ở bất kỳ màn nào

# ── Tên + mô tả màu + thông tin base cho từng "loại" màn ───────────────────
const LEVEL_THEMES: Array = [
	{
		"name"    : "Asteroid Belt",
		"desc"    : "Mưa thiên thạch liên tục",
		"icon"    : "☄",
		"accent"  : Color(0.9, 0.65, 0.2),
		"asteroid_rate": 0.6,   # tỉ lệ wave asteroid
	},
	{
		"name"    : "Enemy Swarm",
		"desc"    : "Đàn địch đông đúc, nhiều hình thái",
		"icon"    : "👾",
		"accent"  : Color(0.2, 0.85, 0.4),
		"asteroid_rate": 0.1,
	},
	{
		"name"    : "Boss Rush",
		"desc"    : "Boss liên tiếp, không lính thường",
		"icon"    : "☠",
		"accent"  : Color(1.0, 0.2, 0.2),
		"asteroid_rate": 0.0,
	},
	{
		"name"    : "Deep Space",
		"desc"    : "Tối tăm, địch tốc độ cao",
		"icon"    : "🌌",
		"accent"  : Color(0.3, 0.4, 1.0),
		"asteroid_rate": 0.2,
	},
	{
		"name"    : "Nebula Storm",
		"desc"    : "Máu địch cao, sát thương lớn",
		"icon"    : "🔥",
		"accent"  : Color(1.0, 0.45, 0.0),
		"asteroid_rate": 0.15,
	},
	{
		"name"    : "Carrier Assault",
		"desc"    : "Tàu địch gọi quân liên tục",
		"icon"    : "🚀",
		"accent"  : Color(0.8, 0.8, 0.1),
		"asteroid_rate": 0.1,
	},
	{
		"name"    : "Ice Field",
		"desc"    : "Thiên thạch băng + địch Ice",
		"icon"    : "❄",
		"accent"  : Color(0.4, 0.9, 1.0),
		"asteroid_rate": 0.35,
	},
	{
		"name"    : "Nova Rift",
		"desc"    : "Mothership xuất hiện sớm",
		"icon"    : "💫",
		"accent"  : Color(0.8, 0.2, 1.0),
		"asteroid_rate": 0.05,
	},
]

# Mỗi màn được sinh ra trong phiên
var _levels: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.load_data()
	_generate_levels()
	_build_ui()

# ── Sinh ngẫu nhiên LEVEL_COUNT màn với độ khó rải từ 1–10 ───────────────
func _generate_levels() -> void:
	_levels.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Tạo danh sách indices ngẫu nhiên cho theme
	var theme_pool: Array = range(LEVEL_THEMES.size())
	theme_pool.shuffle()

	for i in range(LEVEL_COUNT):
		var theme_idx: int = theme_pool[i % theme_pool.size()]
		var theme: Dictionary = LEVEL_THEMES[theme_idx]

		# Độ khó ngẫu nhiên 1–10 (phân bố đều)
		var diff: int = rng.randi_range(1, 10)

		# Số wave = CLAMP(diff * 3, 5, 30)
		var waves: int = clampi(diff * 3, 5, MAX_WAVES)

		# Bội số máu địch tăng theo độ khó
		var hp_m: float    = 1.0 + float(diff - 1) * 0.22
		var boss_hp_m: float = 1.0 + float(diff - 1) * 0.35

		_levels.append({
			"theme"         : theme_idx,
			"name"          : theme["name"],
			"icon"          : theme["icon"],
			"accent"        : theme["accent"],
			"desc"          : theme["desc"],
			"difficulty"    : diff,
			"max_waves"     : waves,
			"hp_mult"       : hp_m,
			"boss_hp_mult"  : boss_hp_m,
			"asteroid_rate" : theme["asteroid_rate"],
		})

# ── Xây dựng UI ──────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var vp := get_viewport_rect().size

	# ── Nền gradient ──────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.03, 0.03, 0.10)
	add_child(bg)

	# Lưới sao trang trí
	var star_node := Node2D.new()
	add_child(star_node)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	for _i in range(120):
		var star := ColorRect.new()
		var sz := rng2.randf_range(1.0, 2.5)
		star.size  = Vector2(sz, sz)
		star.color = Color(1.0, 1.0, 1.0, rng2.randf_range(0.3, 0.85))
		star.position = Vector2(rng2.randf_range(0, vp.x), rng2.randf_range(0, vp.y))
		star_node.add_child(star)

	# ── Tiêu đề ────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "✦  CHỌN MÀN CHƠI  ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 14)
	title.size = Vector2(vp.x, 44)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.45, 0.90, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.5, 0.9, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	add_child(title)

	# ── Sub-hint ────────────────────────────────────────────────────────────────
	var hint := Label.new()
	hint.text = "Mỗi phiên chơi các màn được tạo ngẫu nhiên · Chọn bất kỳ màn nào để bắt đầu"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 46)
	hint.size = Vector2(vp.x, 22)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9, 0.8))
	add_child(hint)

	# ── Grid 3×3 ────────────────────────────────────────────────────────────────
	var cols    := 3
	var rows    := 3
	var pad_x   := 22.0
	var pad_y   := 72.0
	var sp_x    := 14.0
	var sp_y    := 12.0
	var cell_w  := (vp.x - pad_x * 2 - sp_x * (cols - 1)) / cols
	var cell_h  := (vp.y - pad_y - 60.0 - sp_y * (rows - 1)) / rows

	for idx in range(LEVEL_COUNT):
		var col := idx % cols
		var row := idx / cols
		var cx  := pad_x + col * (cell_w + sp_x)
		var cy  := pad_y + row * (cell_h + sp_y)
		_make_level_card(idx, Vector2(cx, cy), Vector2(cell_w, cell_h))

	# ── Nút Back ────────────────────────────────────────────────────────────────
	var back_btn := Button.new()
	back_btn.text     = "◀  Trở về Menu"
	back_btn.size     = Vector2(160, 38)
	back_btn.position = Vector2((vp.x - 160) * 0.5, vp.y - 52)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	var sback := StyleBoxFlat.new()
	sback.bg_color     = Color(0.06, 0.10, 0.22, 0.9)
	sback.border_color = Color(0.3, 0.55, 0.8, 0.7)
	sback.border_width_left   = 1; sback.border_width_right  = 1
	sback.border_width_top    = 1; sback.border_width_bottom = 1
	sback.corner_radius_top_left     = 6; sback.corner_radius_top_right    = 6
	sback.corner_radius_bottom_left  = 6; sback.corner_radius_bottom_right = 6
	back_btn.add_theme_stylebox_override("normal",  sback)
	var sh := sback.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.1, 0.22, 0.45, 1.0)
	back_btn.add_theme_stylebox_override("hover",   sh)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

func _make_level_card(idx: int, pos: Vector2, sz: Vector2) -> void:
	var lv: Dictionary = _levels[idx]
	var accent: Color  = lv["accent"]
	var diff: int      = lv["difficulty"]

	# Outer panel
	var panel := Panel.new()
	panel.position = pos
	panel.size     = sz
	var sty := StyleBoxFlat.new()
	sty.bg_color          = Color(0.05, 0.06, 0.16, 0.92)
	sty.border_color      = accent
	sty.border_width_left   = 2; sty.border_width_right  = 2
	sty.border_width_top    = 2; sty.border_width_bottom = 2
	sty.corner_radius_top_left     = 8; sty.corner_radius_top_right    = 8
	sty.corner_radius_bottom_left  = 8; sty.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", sty)
	add_child(panel)

	# Difficulty color fill across top
	var top_bar := Panel.new()
	top_bar.size = Vector2(sz.x - 4, 5)
	top_bar.position = Vector2(2, 2)
	var sty_top := StyleBoxFlat.new()
	sty_top.bg_color = Color(accent.r, accent.g, accent.b, 0.55)
	sty_top.corner_radius_top_left    = 6; sty_top.corner_radius_top_right   = 6
	top_bar.add_theme_stylebox_override("panel", sty_top)
	panel.add_child(top_bar)

	# Icon + Name
	var icon_lbl := Label.new()
	icon_lbl.text = lv["icon"]
	icon_lbl.position = Vector2(8, 8)
	icon_lbl.add_theme_font_size_override("font_size", 22)
	panel.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = lv["name"]
	name_lbl.position = Vector2(40, 10)
	name_lbl.size = Vector2(sz.x - 46, 24)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(accent.r * 1.2, accent.g * 1.2, accent.b * 1.2, 1.0).clamp())
	panel.add_child(name_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text        = lv["desc"]
	desc_lbl.position    = Vector2(8, 36)
	desc_lbl.size        = Vector2(sz.x - 16, 32)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.85))
	panel.add_child(desc_lbl)

	# Difficulty stars
	var diff_lbl := Label.new()
	var stars := ""
	for _s in range(diff):         stars += "★"
	for _s in range(10 - diff):    stars += "☆"
	diff_lbl.text = stars
	diff_lbl.position = Vector2(6, sz.y - 52)
	diff_lbl.size     = Vector2(sz.x - 12, 18)
	var star_col := Color(0.3, 1.0, 0.3) if diff <= 3 else (Color(1.0, 0.85, 0.0) if diff <= 6 else Color(1.0, 0.25, 0.25))
	diff_lbl.add_theme_color_override("font_color", star_col)
	diff_lbl.add_theme_font_size_override("font_size", 10)
	panel.add_child(diff_lbl)

	# Wave count
	var wave_lbl := Label.new()
	wave_lbl.text = "⚡ %d waves" % lv["max_waves"]
	wave_lbl.position = Vector2(8, sz.y - 36)
	wave_lbl.size     = Vector2(sz.x * 0.55, 18)
	wave_lbl.add_theme_font_size_override("font_size", 10)
	wave_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	panel.add_child(wave_lbl)

	# HP multiplier
	var hp_lbl := Label.new()
	hp_lbl.text = "❤ ×%.1f" % lv["hp_mult"]
	hp_lbl.position = Vector2(sz.x * 0.55, sz.y - 36)
	hp_lbl.size     = Vector2(sz.x * 0.45, 18)
	hp_lbl.add_theme_font_size_override("font_size", 10)
	hp_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	panel.add_child(hp_lbl)

	# Play button
	var play_btn := Button.new()
	play_btn.text     = "▶  PLAY"
	play_btn.size     = Vector2(sz.x - 16, 30)
	play_btn.position = Vector2(8, sz.y - 38)
	play_btn.add_theme_font_size_override("font_size", 12)
	play_btn.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	var sp_n := StyleBoxFlat.new()
	sp_n.bg_color     = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.9)
	sp_n.border_color = accent
	sp_n.border_width_left   = 1; sp_n.border_width_right  = 1
	sp_n.border_width_top    = 1; sp_n.border_width_bottom = 1
	sp_n.corner_radius_top_left     = 5; sp_n.corner_radius_top_right    = 5
	sp_n.corner_radius_bottom_left  = 5; sp_n.corner_radius_bottom_right = 5
	var sp_h := sp_n.duplicate() as StyleBoxFlat
	sp_h.bg_color = Color(accent.r * 0.65, accent.g * 0.65, accent.b * 0.65, 1.0)
	play_btn.add_theme_stylebox_override("normal", sp_n)
	play_btn.add_theme_stylebox_override("hover",  sp_h)
	play_btn.pressed.connect(_on_level_chosen.bind(idx))
	panel.add_child(play_btn)

func _on_level_chosen(idx: int) -> void:
	PlayerData.current_level = _levels[idx]
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
