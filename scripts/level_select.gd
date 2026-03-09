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
	# Chỉ sinh màn mới nếu chưa có danh sách trong phiên này
	if PlayerData.session_level_list.is_empty():
		_generate_levels()
	else:
		_levels = PlayerData.session_level_list
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

		# Số wave = CLAMP(diff * 3, 5, 25)
		var waves: int = clampi(diff * 3, 5, 25)

		# Bội số máu địch tăng theo độ khó
		var hp_m: float    = 1.0 + float(diff - 1) * 0.17
		var boss_hp_m: float = 1.0 + float(diff - 1) * 0.26

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
	# Lưu vào PlayerData để giữ nguyên khi quay lại màn chọn
	PlayerData.session_level_list = _levels.duplicate()

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

	# ── Thanh tiến trình phiên chơi ────────────────────────────────────────────
	var done: int = PlayerData.session_levels_completed
	var prog_stars := ""
	for _ps in range(done):                    prog_stars += "★"
	for _ps in range(PlayerData.SESSION_GOAL - done): prog_stars += "☆"
	var prog_lbl := Label.new()
	prog_lbl.text = "Phiên: %s  (%d/%d)" % [prog_stars, done, PlayerData.SESSION_GOAL]
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prog_lbl.position = Vector2(0, 58)
	prog_lbl.size = Vector2(vp.x, 18)
	prog_lbl.add_theme_font_size_override("font_size", 10)
	var prog_col := Color(0.35, 1.0, 0.45) if done >= PlayerData.SESSION_GOAL else Color(0.75, 0.82, 0.6, 0.8)
	prog_lbl.add_theme_color_override("font_color", prog_col)
	add_child(prog_lbl)

	# ── Grid 3×3 ────────────────────────────────────────────────────────────────
	var cols    := 3
	var rows    := 3
	var pad_x   := 22.0
	var pad_y   := 84.0
	var sp_x    := 14.0
	var sp_y    := 12.0
	var cell_w  := (vp.x - pad_x * 2 - sp_x * (cols - 1)) / cols
	var cell_h  := (vp.y - pad_y - 118.0 - sp_y * (rows - 1)) / rows

	for idx in range(LEVEL_COUNT):
		var col := idx % cols
		var row := idx / cols
		var cx  := pad_x + col * (cell_w + sp_x)
		var cy  := pad_y + row * (cell_h + sp_y)
		_make_level_card(idx, Vector2(cx, cy), Vector2(cell_w, cell_h))

	# ── Boss Challenge row — chỉ hiện khi đã hoàn thành cả 9 màn ───────────────
	var row_y: float = pad_y + rows * (cell_h + sp_y) + 4.0
	var half_w: float = (vp.x - pad_x * 2 - sp_x) * 0.5
	var boss_unlocked: bool = (PlayerData.session_levels_completed >= PlayerData.SESSION_GOAL)
	if boss_unlocked:
		_make_boss_challenge_card(
			false,
			Vector2(pad_x,              row_y),
			Vector2(half_w, 48.0)
		)
		_make_boss_challenge_card(
			true,
			Vector2(pad_x + half_w + sp_x, row_y),
			Vector2(half_w, 48.0)
		)
	else:
		# Hiện 2 ô khoá mờ
		for bi in range(2):
			var bx := pad_x + float(bi) * (half_w + sp_x)
			var lock_panel := Panel.new()
			lock_panel.position = Vector2(bx, row_y)
			lock_panel.size     = Vector2(half_w, 48.0)
			var ls := StyleBoxFlat.new()
			ls.bg_color     = Color(0.07, 0.07, 0.10, 0.80)
			ls.border_color = Color(0.30, 0.30, 0.35, 0.60)
			ls.border_width_left   = 1; ls.border_width_right  = 1
			ls.border_width_top    = 1; ls.border_width_bottom = 1
			ls.corner_radius_top_left    = 6; ls.corner_radius_top_right   = 6
			ls.corner_radius_bottom_left = 6; ls.corner_radius_bottom_right = 6
			lock_panel.add_theme_stylebox_override("panel", ls)
			add_child(lock_panel)
			var lock_lbl := Label.new()
			lock_lbl.text = "🔒  %s  —  Hoàn thành %d/%d màn để mở khoá" % [
				["DREADFORT", "AERIAL HQ"][bi],
				PlayerData.session_levels_completed,
				PlayerData.SESSION_GOAL
			]
			lock_lbl.size     = Vector2(half_w - 12.0, 48.0)
			lock_lbl.position = Vector2(6.0, 0.0)
			lock_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			lock_lbl.add_theme_font_size_override("font_size", 11)
			lock_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50, 0.75))
			lock_panel.add_child(lock_lbl)

	# ── Nút Back + đặc biệt ────────────────────────────────────────────────────
	var session_done: bool = (PlayerData.session_levels_completed >= PlayerData.SESSION_GOAL)

	if session_done:
		# ── Panel nổi bật: màn đặc biệt mở khóa ───────────────────────────────
		var sp_panel := Panel.new()
		var sp_w: float = vp.x - 44.0
		var sp_h: float = 48.0
		sp_panel.size     = Vector2(sp_w, sp_h)
		sp_panel.position = Vector2(22.0, vp.y - 110.0)
		var sp_sty := StyleBoxFlat.new()
		sp_sty.bg_color     = Color(0.18, 0.12, 0.03, 0.95)
		sp_sty.border_color = Color(1.0, 0.82, 0.1)
		sp_sty.border_width_left   = 2; sp_sty.border_width_right  = 2
		sp_sty.border_width_top    = 2; sp_sty.border_width_bottom = 2
		sp_sty.corner_radius_top_left    = 6; sp_sty.corner_radius_top_right   = 6
		sp_sty.corner_radius_bottom_left = 6; sp_sty.corner_radius_bottom_right = 6
		sp_panel.add_theme_stylebox_override("panel", sp_sty)
		add_child(sp_panel)
		# Nút chơi màn đặc biệt
		var sp_btn := Button.new()
		sp_btn.text     = "⚡  SPECIAL MISSION  — 30 Waves · 6 Bosses · Final Boss  ⚡"
		sp_btn.size     = Vector2(sp_w - 4.0, sp_h - 4.0)
		sp_btn.position = Vector2(2.0, 2.0)
		sp_btn.add_theme_font_size_override("font_size", 14)
		sp_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25))
		var sp_btn_n := StyleBoxFlat.new()
		sp_btn_n.bg_color = Color(0.22, 0.14, 0.02, 0.0)
		sp_btn.add_theme_stylebox_override("normal", sp_btn_n)
		var sp_btn_h := sp_btn_n.duplicate() as StyleBoxFlat
		sp_btn_h.bg_color = Color(0.4, 0.28, 0.04, 0.5)
		sp_btn.add_theme_stylebox_override("hover", sp_btn_h)
		sp_btn.pressed.connect(_on_special_mission)
		sp_panel.add_child(sp_btn)
		# Hai nút nhỏ phía dưới
		var back_btn2 := Button.new()
		back_btn2.text     = "◀  Trở về Menu"
		back_btn2.size     = Vector2(160, 34)
		back_btn2.position = Vector2((vp.x * 0.5) - 172.0, vp.y - 50.0)
		back_btn2.add_theme_font_size_override("font_size", 12)
		back_btn2.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		var sb2 := StyleBoxFlat.new()
		sb2.bg_color     = Color(0.06, 0.10, 0.22, 0.9)
		sb2.border_color = Color(0.3, 0.55, 0.8, 0.7)
		sb2.border_width_left   = 1; sb2.border_width_right  = 1
		sb2.border_width_top    = 1; sb2.border_width_bottom = 1
		sb2.corner_radius_top_left = 5; sb2.corner_radius_top_right    = 5
		sb2.corner_radius_bottom_left = 5; sb2.corner_radius_bottom_right = 5
		back_btn2.add_theme_stylebox_override("normal", sb2)
		var sh2 := sb2.duplicate() as StyleBoxFlat; sh2.bg_color = Color(0.1, 0.22, 0.45, 1.0)
		back_btn2.add_theme_stylebox_override("hover", sh2)
		back_btn2.pressed.connect(_on_back)
		add_child(back_btn2)
		var rst_btn := Button.new()
		rst_btn.text     = "🔄  Reset Session"
		rst_btn.size     = Vector2(160, 34)
		rst_btn.position = Vector2((vp.x * 0.5) + 12.0, vp.y - 50.0)
		rst_btn.add_theme_font_size_override("font_size", 12)
		rst_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
		var srst := StyleBoxFlat.new()
		srst.bg_color     = Color(0.18, 0.06, 0.02, 0.9)
		srst.border_color = Color(0.9, 0.4, 0.1, 0.7)
		srst.border_width_left   = 1; srst.border_width_right  = 1
		srst.border_width_top    = 1; srst.border_width_bottom = 1
		srst.corner_radius_top_left = 5; srst.corner_radius_top_right    = 5
		srst.corner_radius_bottom_left = 5; srst.corner_radius_bottom_right = 5
		rst_btn.add_theme_stylebox_override("normal", srst)
		var srst_h := srst.duplicate() as StyleBoxFlat; srst_h.bg_color = Color(0.35, 0.12, 0.04, 1.0)
		rst_btn.add_theme_stylebox_override("hover", srst_h)
		rst_btn.pressed.connect(_on_reset_session)
		add_child(rst_btn)
	else:
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
	var is_done: bool  = PlayerData.session_completed_indices.has(idx)

	# Màn đã hoàn thành: hiện dạng ận mờ
	if is_done:
		var done_panel := Panel.new()
		done_panel.position = pos
		done_panel.size     = sz
		var ds := StyleBoxFlat.new()
		ds.bg_color     = Color(0.04, 0.08, 0.04, 0.70)
		ds.border_color = Color(0.25, 0.55, 0.25, 0.50)
		ds.border_width_left   = 1; ds.border_width_right  = 1
		ds.border_width_top    = 1; ds.border_width_bottom = 1
		ds.corner_radius_top_left    = 8; ds.corner_radius_top_right   = 8
		ds.corner_radius_bottom_left = 8; ds.corner_radius_bottom_right = 8
		done_panel.add_theme_stylebox_override("panel", ds)
		add_child(done_panel)
		var chk := Label.new()
		chk.text = "✔  %s  —  Hoàn thành" % lv["name"]
		chk.size = Vector2(sz.x - 12.0, sz.y)
		chk.position = Vector2(6.0, 0.0)
		chk.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		chk.add_theme_font_size_override("font_size", 12)
		chk.add_theme_color_override("font_color", Color(0.35, 0.75, 0.35, 0.65))
		done_panel.add_child(chk)
		return

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

func _make_boss_challenge_card(is_aerial: bool, pos: Vector2, sz: Vector2) -> void:
	var accent: Color
	var icon:   String
	var label:  String
	if is_aerial:
		accent = Color(0.55, 0.85, 0.30)
		icon   = "✈"
		label  = "✈  AERIAL HQ  —  1 Wave · AI Carrier → Giant Bomber"
	else:
		accent = Color(1.0, 0.42, 0.08)
		icon   = "⚠"
		label  = "⚠  DREADFORT  —  1 Wave · Fortress Final Boss"

	var panel := Panel.new()
	panel.position = pos
	panel.size     = sz
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(accent.r * 0.15, accent.g * 0.15, accent.b * 0.10, 0.92)
	sty.border_color = accent
	sty.border_width_left   = 2; sty.border_width_right  = 2
	sty.border_width_top    = 2; sty.border_width_bottom = 2
	sty.corner_radius_top_left    = 6; sty.corner_radius_top_right   = 6
	sty.corner_radius_bottom_left = 6; sty.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", sty)
	add_child(panel)

	var btn := Button.new()
	btn.text     = label
	btn.size     = Vector2(sz.x - 4.0, sz.y - 4.0)
	btn.position = Vector2(2.0, 2.0)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(accent.r * 1.2, accent.g * 1.2, accent.b * 1.2, 1.0).clamp())
	var sn := StyleBoxFlat.new(); sn.bg_color = Color(0, 0, 0, 0)
	var sh2 := StyleBoxFlat.new(); sh2.bg_color = Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.15, 0.55)
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover",  sh2)
	btn.pressed.connect(_on_boss_challenge.bind(is_aerial))
	panel.add_child(btn)

func _on_boss_challenge(is_aerial: bool) -> void:
	PlayerData.current_level = {
		"name"             : ("✈ AERIAL HQ" if is_aerial else "⚠ DREADFORT"),
		"icon"             : ("✈" if is_aerial else "⚠"),
		"accent"           : (Color(0.55, 0.85, 0.30) if is_aerial else Color(1.0, 0.42, 0.08)),
		"desc"             : "Boss Challenge",
		"difficulty"       : 10,
		"max_waves"        : 1,
		"hp_mult"          : 1.0,
		"boss_hp_mult"     : 1.0,
		"asteroid_rate"    : 0.0,
		"is_special"       : false,
		"is_boss_challenge": true,
		"challenge_aerial" : is_aerial,
	}
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_level_chosen(idx: int) -> void:
	var lv: Dictionary = _levels[idx].duplicate()
	lv["level_idx"] = idx
	PlayerData.current_level = lv
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_special_mission() -> void:
	# Thiết lập màn chơi đặc biệt: 30 wave, 6 boss, boss cuối đặc biệt
	var diff: int = 10
	PlayerData.current_level = {
		"name"          : "⚡ SPECIAL MISSION",
		"icon"          : "⚡",
		"accent"        : Color(1.0, 0.85, 0.1),
		"desc"          : "Màn chơi đặc biệt — Boss cuối cùng chờ đợi",
		"difficulty"    : diff,
		"max_waves"     : 30,
		"hp_mult"       : 2.0,
		"boss_hp_mult"  : 2.5,
		"asteroid_rate" : 0.15,
		"is_special"    : true,
	}
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_reset_session() -> void:
	PlayerData.session_levels_completed = 0
	PlayerData.session_level_list.clear()
	PlayerData.session_completed_indices.clear()
	_generate_levels()
	# Xây lại UI
	for ch in get_children(): ch.queue_free()
	await get_tree().process_frame
	_build_ui()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
